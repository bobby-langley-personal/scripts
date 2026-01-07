# Get Script Root, fallback-safe
try {
    $scriptPath = $MyInvocation.MyCommand.Definition
    if (-not $scriptPath) {
        $scriptPath = $PSCommandPath  # works in some shells
    }
    if (-not $scriptPath) {
        throw "Script path could not be resolved."
    }
    $PSScriptRoot = Split-Path -Parent $scriptPath
} catch {
    Write-Host "Failed to determine script root. Exiting." -ForegroundColor Red
    exit 1
}

# Setup log directory relative to script location
$logDir = Join-Path $PSScriptRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

# Create log file with timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$mainLogFile = Join-Path $logDir "network_diagnostics_$timestamp.log"

# Logging helper
function Write-Log {
    param (
        [string]$Message
    )
    Add-Content -Path $mainLogFile -Value $Message
    Write-Output $Message
}
Write-Output "`$MyInvocation.MyCommand.Definition = '$($MyInvocation.MyCommand.Definition)'"
Write-Output "`$PSCommandPath = '$PSCommandPath'"
Write-Output "`$PSScriptRoot = '$PSScriptRoot'"

# Load Config
$configPath = Join-Path $PSScriptRoot "whitelist_domains.json"
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$tests = $config.Domains
$ntpServers = $config.NTPServers

# Logging Helper
function Log-And-Write {
    param ([string]$Message)
    Write-Host $Message
    Add-Content -Path $mainLogFile -Value $Message
}

# Format Bytes to Human Readable
function Format-FileSize($bytes) {
    if ($bytes -gt 1GB) { "{0:N2} GB" -f ($bytes / 1GB) }
    elseif ($bytes -gt 1MB) { "{0:N2} MB" -f ($bytes / 1MB) }
    elseif ($bytes -gt 1KB) { "{0:N2} KB" -f ($bytes / 1KB) }
    else { "$bytes B" }
}

# Test TCP Port
function Test-Port {
    param ([string]$TargetHost, [int]$Port)
    try {
        $tcp = New-Object Net.Sockets.TcpClient
        $async = $tcp.BeginConnect($TargetHost, $Port, $null, $null)
        $wait = $async.AsyncWaitHandle.WaitOne(3000, $false)
        if ($wait -and $tcp.Connected) {
            $tcp.EndConnect($async); $tcp.Close(); return $true
        }
        $tcp.Close(); return $false
    } catch { return $false }
}

# NTP Time Query
function Get-NtpTime {
    param ([string]$NtpServer)
    $NtpData = New-Object byte[] 48; $NtpData[0] = 0x1B
    try {
        $address = [System.Net.Dns]::GetHostAddresses($NtpServer) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
        $endPoint = New-Object System.Net.IPEndPoint $address, 123
        $udpClient = New-Object System.Net.Sockets.UdpClient
        $udpClient.Client.ReceiveTimeout = 3000
        $udpClient.Send($NtpData, $NtpData.Length, $endPoint) | Out-Null
        $remoteEP = $null
        $response = $udpClient.Receive([ref]$remoteEP)
        $udpClient.Close()

        $intPart = [BitConverter]::ToUInt32($response[43..40], 0)
        $fracPart = [BitConverter]::ToUInt32($response[47..44], 0)
        $epoch = Get-Date "1900-01-01 00:00:00Z"
        $seconds = $intPart + ($fracPart / [math]::Pow(2, 32))
        return $epoch.AddSeconds($seconds)
    } catch {
        Log-And-Write "NTP: $NtpServer => [FAIL] $_"
        return $null
    }
}

# Start Diagnostics
$passed = @(); $failed = @()

Log-And-Write "`n=== Site Readiness Checks ==="
foreach ($entry in $tests) {
    foreach ($domain in $entry.Domains) {
        foreach ($port in $entry.Ports) {
            $display = "${domain}: TCP/$port"
            $result = Test-Port -TargetHost $domain -Port $port
            $status = if ($result) { "[PASS]" } else { "[FAIL]"; $failed += $display }
            if ($result) { $passed += $display }
            Log-And-Write "$display => $status"
        }
    }
}

Log-And-Write "`n=== NTP Server Checks ==="
foreach ($server in $ntpServers) {
    $ntpTime = Get-NtpTime -NtpServer $server
    if ($ntpTime) {
        $msg = "NTP: $server => [PASS] $($ntpTime.ToUniversalTime()) (UTC)"
        $passed += $msg
        Log-And-Write $msg
    } else {
        $msg = "NTP: $server => [FAIL] No response"
        $failed += $msg
        Log-And-Write $msg
    }
}

# Network Info
function Get-NetworkInfo {
    Log-And-Write "`n=== Network Information ==="
    try {
        $localIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Ethernet*' | Where-Object {$_.IPAddress -notlike '169.*'} | Select-Object -First 1).IPAddress
        if (-not $localIP) { $localIP = "Unavailable" }
        $publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json").ip
        $hostname = $env:COMPUTERNAME
    } catch { $publicIP = "Unavailable" }
    Log-And-Write "Hostname : $hostname"
    Log-And-Write "Local IP : $localIP"
    Log-And-Write "Public IP: $publicIP"
}

# DNS Test
function Test-DNSResolution {
    Log-And-Write "`n=== DNS Resolution Test ==="
    try {
        $resolved = [System.Net.Dns]::GetHostAddresses("google.com")
        Log-And-Write "Resolved google.com to: $($resolved.IPAddressToString -join ', ')"
    } catch {
        Log-And-Write "DNS resolution => [FAIL] $_"
    }
}

# Ping Test
function Run-PingTest {
    Log-And-Write "`n=== Ping Test ==="
    try {
        $pingResult = Test-Connection -ComputerName "8.8.8.8" -Count 4 -ErrorAction Stop
        $avg = ($pingResult | Measure-Object -Property ResponseTime -Average).Average
        Log-And-Write "Ping to 8.8.8.8 => [PASS] Avg response: $([math]::Round($avg, 2)) ms"
    } catch {
        Log-And-Write "Ping => [FAIL] $_"
    }
}

# Download Speed Test
function Test-DownloadSpeed {
    param ($url, $destination)
    Log-And-Write "`n=== Download Speed Test ==="
    try {
        $webClient = New-Object System.Net.WebClient
        $start = Get-Date
        $webClient.DownloadFile($url, $destination)
        $end = Get-Date
        $duration = ($end - $start).TotalSeconds
        $fileSize = (Get-Item $destination).Length
        $speedMbps = [math]::Round((($fileSize * 8) / 1MB) / $duration, 2)
        Log-And-Write "Download => [PASS]"
        Log-And-Write "Size     : $(Format-FileSize $fileSize)"
        Log-And-Write "Duration : $duration sec"
        Log-And-Write "Speed    : $speedMbps Mbps"
    } catch {
        Log-And-Write "Download => [FAIL] $_"
    } finally {
        if (Test-Path $destination) { Remove-Item $destination -Force }
    }
}

# Run All
$downloadUrl = "https://builds.grubbrr.net/kiosk/v2/release-14.7.0/14.7.0%2B1361744/production/Grubbrr%20Kiosk_14.7.0.136_x64_en-US.msi"
$outputFile = "$env:TEMP\kiosk_test_download.msi"
Get-NetworkInfo
Test-DNSResolution
Run-PingTest
Test-DownloadSpeed -url $downloadUrl -destination $outputFile

# Final Output Summary
$passFile = Join-Path $logDir "passed_$timestamp.txt"
$failFile = Join-Path $logDir "failed_$timestamp.txt"
$passed | Out-File -Encoding UTF8 $passFile
$failed | Out-File -Encoding UTF8 $failFile

Log-And-Write "`n--- Summary Logs Saved ---"
Log-And-Write "[PASS] Log: $passFile"
Log-And-Write "[FAIL] Log: $failFile"
