# Path to Node.js (ensure this is correct based on your environment)
$nodePath = "C:\Program Files\nodejs\node.exe"  # Enclose path in quotes to handle spaces

# Path to your JavaScript file
$launchScript = "C:\Users\Bobby\Projects\Kiosk-Tizen-V2\cli\src\launch_chrome_debugger.js"

# Get Kiosk settings (replace with actual way to retrieve Kiosk settings if necessary)
$kioskSettings = @{
    ip = "10.0.0.66"
    debugPort = 51969  # Example port, replace with actual dynamic port if needed
}

# Prepare the arguments for the JS function (URLs can be added dynamically)
$urls = @("")  # List of URLs, adjust if needed

# Run the JavaScript function via Node.js
Write-Host "Launching Chrome Debugger..."

# Create the argument list
$nodeArgs = @(
    $launchScript,
    $kioskSettings.ip,
    $kioskSettings.debugPort.ToString(),  # Ensure it's a string
    ($urls -join ",")  # Join the URLs into a single string
)

# Prepare the full command string for Start-Process
$nodeCommand = "$nodePath `"$launchScript`" $($nodeArgs -join ' ')"

Write-Host "Running command: $nodeCommand"

# Use Start-Process with the correct ArgumentList
Start-Process -FilePath $nodePath -ArgumentList $launchScript, $kioskSettings.ip, $kioskSettings.debugPort.ToString(), ($urls -join ",") -WorkingDirectory "C:\Users\Bobby\Projects\Kiosk-Tizen-V2\cli"

Write-Host "Chrome Debugger launched successfully."
