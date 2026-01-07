# Set log file path dynamically
$LogFilePath = "$env:USERPROFILE\Downloads\restart_log.txt"

# Function to write log messages to file
function Write-Log {
    param(
        [string]$Message
    )

    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "$TimeStamp - $Message"
    Add-Content -Path $LogFilePath -Value $LogMessage
    Write-Output $LogMessage
}

# Main script logic starts here
$processName = "ServiceHost"
$processPath = "C:\Micros\Simphony\WebServer\ServiceHost.exe"
$maxRetries = 3
$retryDelay = 5
$processStartTimeout = 60  # Maximum time to wait for the process to start in seconds

Write-Log "Script started."

# Function to find and restart the process
function Find-And-Restart-Process {
    $retries = 0

    do {
        $found = $false
        $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
        if ($processes) {
            foreach ($process in $processes) {
                Write-Log "$processName found with PID $($process.Id). Attempting to terminate..."
                try {
                    $process | Stop-Process -Force -ErrorAction Stop
                    Write-Log "$processName process with PID $($process.Id) terminated successfully."
                } catch {
                    Write-Log "Failed to terminate $processName with PID $($process.Id). Error: $_"
                }
            }
        } else {
            Write-Log "$processName process not found."
        }

        # Start the process
        try {
            Start-Process -FilePath $processPath -ErrorAction Stop
            Write-Log "$processName process started successfully."
        } catch {
            Write-Log "Failed to start $processName process. Error: $_"
        }

        # Wait for the process to start
        $waitTime = 0
        while ($waitTime -lt $processStartTimeout) {
            Start-Sleep -Seconds 2
            $waitTime += 2
            $processes = Get-Process -Name $processName -ErrorAction SilentlyContinue
            if ($processes) {
                Write-Log "$processName restarted successfully."
                return $true  # Indicate success
            }
        }

        Write-Log "Error restarting $processName. Retrying (attempt $($retries + 1) of $maxRetries)..."
        $retries++
        Start-Sleep -Seconds $retryDelay
    } while ($retries -lt $maxRetries)

    if ($retries -ge $maxRetries) {
        Write-Log "Max retries reached. Failed to restart $processName."
        return $false  # Indicate failure
    }
}

# Call the function to find and restart the process
$result = Find-And-Restart-Process

Write-Log "Script finished."

# Return appropriate exit code based on the result
if ($result) {
    exit 0  # Success
} else {
    exit 1  # Failure
}

# Close the PowerShell window
exit
