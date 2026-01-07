# Configuration
$downloadUrl = "https://builds.grubbrr.net/kiosk/v2/release-14.7.0/14.7.0%2B1361744/production/Grubbrr%20Kiosk_14.7.0.136_x64_en-US.msi"
$outputFile = "$env:TEMP\kiosk_test_download.msi"
$logFile = "$env:TEMP\network_diagnostics_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Utility function
function Format-FileSize($bytes) {
    if ($bytes -gt 1GB) { "{0:N2} GB" -f ($bytes / 1GB) }
    elseif ($bytes -gt 1MB) { "{0:N2} MB" -f ($bytes / 1MB) }
    elseif ($bytes -gt 1KB) { "{0:N2} KB" -f ($bytes / 1KB) }
    else { "$bytes B" }
}

function Log-And-Write {
    param ($message)
    Write-Host $message
    Add-Content -Path $logFile -Value $message
}

# 1. Public IP Info
function Get-NetworkInfo {
    Log-And-Write "`n==== Network Information ===="
    
    try {
        $localIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Ethernet*' | Where-Object {$_.IPAddress -notlike '169.*'} | Select-Object -First 1).IPAddress
        if (-not $localIP) { $localIP = "Unavailable" }

        $publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json").ip
        $hostname = $env:COMPUTERNAME
    }
    catch { $publicIP = "Unavailable" }

    Log-And-Write "Hostname     : $hostname"
    Log-And-Write "Local IP     : $localIP"
    Log-And-Write "Public IP    : $publicIP"
}

# 2. DNS Resolution
function Test-DNSResolution {
    Log-And-Write "`n==== DNS Resolution Test ===="
    $testDomain = "google.com"

    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($testDomain)
        Log-And-Write "Resolved $testDomain to: $($resolved.IPAddressToString -join ', ')"
    }
    catch {
        Log-And-Write "❌ DNS resolution failed: $_"
    }
}

# 3. Ping Test
function Run-PingTest {
    Log-And-Write "`n==== Ping Test ===="
    $target = "8.8.8.8"

    try {
        $pingResult = Test-Connection -ComputerName $target -Count 4 -ErrorAction Stop
        $avgTime = ($pingResult | Measure-Object -Property ResponseTime -Average).Average
        Log-And-Write "Ping to $target successful. Avg response time: $([math]::Round($avgTime,2)) ms"
    }
    catch {
        Log-And-Write "❌ Ping failed: $_"
    }
}

# 4. Download Speed Test
function Test-DownloadSpeed {
    param ($url, $destination)
    
    Log-And-Write "`n==== Download Speed Test ===="
    Log-And-Write "Starting download from: $url"

    try {
        $webClient = New-Object System.Net.WebClient
        $start = Get-Date
        $webClient.DownloadFile($url, $destination)
        $end = Get-Date
        $duration = ($end - $start).TotalSeconds
        $fileSize = (Get-Item $destination).Length
        $speedMbps = [math]::Round((($fileSize * 8) / 1MB) / $duration, 2)

        Log-And-Write "✅ Download Successful!"
        Log-And-Write "Downloaded Size : $(Format-FileSize $fileSize)"
        Log-And-Write "Time Taken      : $duration sec"
        Log-And-Write "Estimated Speed : $speedMbps Mbps"
    }
    catch {
        Log-And-Write "❌ Download failed: $_"
    }
    finally {
        if (Test-Path $destination) {
            Remove-Item $destination -Force
            Log-And-Write "Cleaned up downloaded file."
        }
    }
}

# Run all tests
Get-NetworkInfo
Test-DNSResolution
Run-PingTest
Test-DownloadSpeed -url $downloadUrl -destination $outputFile

Log-And-Write "`nResults saved to: $logFile"
