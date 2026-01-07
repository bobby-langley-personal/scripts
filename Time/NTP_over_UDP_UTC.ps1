 Write-Host "`n--- Beginning System vs NTP time comparison ---"

 # --- Step 1: Get Local Time Info First ---

$localUtcTime = (Get-Date).ToUniversalTime()

$timeZone = [System.TimeZoneInfo]::Local
$dstActive = $timeZone.IsDaylightSavingTime($localUtcTime)

if ($dstActive) {
    $localUtcTime = $localUtcTime.AddHours(-1)
    Write-Host "`n*(DST is active. Adjusting system time by subtracting 1 hour.)"
} else {
    Write-Host "`n*(DST is not active. No adjustment needed.)"
}

Write-Host "`n--Local machine info--"
Write-Host "Local System Time (UTC): $localUtcTime"
Write-Host "Current Time Zone: $($timeZone.DisplayName)"
Write-Host "Is Daylight Saving Time active? $dstActive"
Write-Host "Local Time Offset (with DST adjusted): $($timeZone.GetUtcOffset($localUtcTime).TotalHours) hours"

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

# --- Step 3: Query NTP Servers ---

$ntpServers = @(
    "time.windows.com",
    "time.google.com",
    "pool.ntp.org",
    "time.apple.com"
)

$validTimes = @()
Write-Host "`n--Server Response(s)--"
foreach ($server in $ntpServers) {
    $ntpTime = Get-NtpTime -NtpServer $server
    if ($ntpTime) {
        Write-Host "$server responded: $ntpTime (UTC)"
        $validTimes += $ntpTime.ToUniversalTime()
    }
}

if ($validTimes.Count -eq 0) {
    Write-Host "`nNo NTP servers responded successfully." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    return
}

# --- Step 4: Compute Offset and Output Results ---

$avgTicks = [math]::Round(($validTimes | ForEach-Object { $_.Ticks } | Measure-Object -Average).Average)
$avgNtpTime = [DateTime]::new($avgTicks, [DateTimeKind]::Utc)

$offset = ($localUtcTime - $avgNtpTime).TotalSeconds

Write-Host "`n--Time Comparisons--"
Write-Host "Average NTP Time: $avgNtpTime (UTC)"
Write-Host "Adjusted Local System Time (UTC): $localUtcTime"
Write-Host "Time Offset: $offset seconds"

if ([math]::Abs($offset) -gt 1) {
    Write-Host "`nSystem time is off by more than 1 second." -ForegroundColor Red
} else {
    Write-Host "`nSystem time is within acceptable range." -ForegroundColor Green
}

Read-Host "Press Enter to exit"