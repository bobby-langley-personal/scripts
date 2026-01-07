$logFilePath = "C:\scripts\SvchostServiceStatus.log"

# Ensure the folder exists
if (-not (Test-Path -Path "C:\scripts")) {
    New-Item -ItemType Directory -Path "C:\scripts"
}

while ($true) {
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Get all svchost.exe processes
    $svchostProcesses = Get-Process svchost -IncludeUserName | Where-Object { $_.Path -like "*svchost.exe" }

    # Loop through each svchost process and get associated services
    foreach ($process in $svchostProcesses) {
        $processId = $process.Id
        
        # Get services running under this svchost process
        $associatedServices = Get-WmiObject Win32_Service | Where-Object { $_.ProcessId -eq $processId }

        # Log the process details
        $logEntry = "$time - Process ID: $processId - CPU: $($process.CPU) - Handles: $($process.Handles) - User: $($process.UserName) - Path: $($process.Path)`n"
        
        # Log details of the services
        $associatedServices | ForEach-Object {
            $logEntry += "  Service Name: $($_.Name) - Display Name: $($_.DisplayName) - State: $($_.State) - StartMode: $($_.StartMode) - ProcessId: $($_.ProcessId)`n"
        }
        
        $logEntry += "`n"

        # Write the log entry to the file
        Add-Content -Path $logFilePath -Value $logEntry
    }
    
    # Wait for 1 second before the next check
    Start-Sleep -Seconds 1
}
