# Path to the sdb.exe tool
$sdbPath = "C:\tizen-studio\tools\sdb.exe"  # Ensure this path is correct

# Get the Kiosk IP address
$kioskIp = Read-Host "Enter the IP address of the Kiosk"
Write-Host "Connecting to the Kiosk at IP: $kioskIp..."

# Attempt to connect to the Kiosk
Write-Host "Attempting to connect to Kiosk at IP: $kioskIp..."
$connectionResult = & $sdbPath connect $kioskIp
Write-Host "Connection result: $connectionResult"



# Start the debug session with the app
Write-Host "Starting debug session with the app..."
$debugCommand = "$sdbPath -s $kioskIp shell 0 debug hzZUoCHQMZ.GrubbrrKioskV2"
Write-Host "Running debug command: $debugCommand"
$debugOutput = & cmd.exe /c $debugCommand 2>&1

# Log the debug command output
Write-Host "Debug command output: $debugOutput"

if (-Not $debugOutput) {
    Write-Host "Error: Debug session did not return a response. Check if the Kiosk app is running."
    exit
}

# Extract the debug port from the output
$debugPortMatch = $debugOutput | Select-String -Pattern "port: (\d+)" | ForEach-Object { $_.Matches.Groups[1].Value }
if (-Not $debugPortMatch) {
    Write-Host "Failed to retrieve debug port. Ensure the app is running on the Kiosk."
    exit
}
$debugPort = $debugPortMatch.Trim()
Write-Host "Debug port retrieved: $debugPort"

# Open Chrome for remote debugging setup
Write-Host "Opening Chrome for remote debugging setup..."
$chromeUrl = "chrome://inspect/#devices"
Start-Process "chrome" $chromeUrl

Write-Host "Manual Step: Configure 'Discover network targets' in Chrome with ${kioskIp}:${debugPort}."
Write-Host "Press any key to exit once configuration is complete..."
Read-Host
