if (-not $PSScriptRoot) {
    $PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
}

$configPath = Join-Path $PSScriptRoot "whitelist_domains.json"
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$tests = $config.Domains
$ntpServers = $config.NTPServers

function Test-Port {
    param (
        [string]$TargetHost,
        [int]$Port
    )
    try {
        $tcp = New-Object Net.Sockets.TcpClient
        $async = $tcp.BeginConnect($TargetHost, $Port, $null, $null)
        $wait = $async.AsyncWaitHandle.WaitOne(3000, $false)
        if ($wait -and $tcp.Connected) {
            $tcp.EndConnect($async)
            $tcp.Close()
            return $true
        }
        $tcp.Close()
        return $false
    } catch {
        return $false
    }
}





$passed = @()
$failed = @()
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logPath = "C:\Users\Bobby\Documents\Automation\Whitelisting\whitelist_logs"
New-Item -ItemType Directory -Force -Path $logPath | Out-Null

Write-Host "`n--- Checking Site Readiness ---`n"

foreach ($entry in $tests) {
    foreach ($domain in $entry.Domains) {
        foreach ($port in $entry.Ports) {
            $display = "${domain}: TCP/$port"
            if ($port -eq 'UDP123') {
                $result = Test-UDP123 -TargetHost $domain
                $display = "${domain}: UDP/123"
            } else {
                $result = Test-Port -TargetHost $domain -Port $port
            }

            if ($result) {
                Write-Host "$display => ✅"
                $passed += $display
            } else {
                Write-Host "$display => ❌"
                $failed += $display
            }
        }
    }
}

# --- Step 2: Define NTP Query Function ---

function Get-NtpTime {
    param (
        [string]$NtpServer
    )

    $NtpData = New-Object byte[] 48
    $NtpData[0] = 0x1B  # LI = 0, VN = 3, Mode = 3 (client)

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
    }
    catch {
        Write-Host "Failed to get time from ${NtpServer}: $_" -ForegroundColor Red
        return $null
    }
}

$validTimes = @()
Write-Host "`n--Server Response(s)--"
foreach ($server in $ntpServers) {
    $ntpTime = Get-NtpTime -NtpServer $server
    if ($ntpTime) {
        $msg = "NTP: $server => ✅ $($ntpTime.ToUniversalTime()) (UTC)"
        Write-Host $msg
        $validTimes += $ntpTime.ToUniversalTime()
        $passed += $msg
    } else {
        $msg = "NTP: $server => ❌ No response"
        Write-Host $msg
        $failed += $msg
    }
}




# Save logs
$passFile = Join-Path $logPath "passed_$timestamp.txt"
$failFile = Join-Path $logPath "failed_$timestamp.txt"

$passed | Out-File -Encoding UTF8 $passFile
$failed | Out-File -Encoding UTF8 $failFile

Write-Host "`n--- Done. Logs saved to '$logPath' ---"
Write-Host "✅ Passed Log: $passFile"
Write-Host "❌ Failed Log: $failFile"
