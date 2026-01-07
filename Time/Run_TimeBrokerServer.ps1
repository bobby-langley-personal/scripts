# Define the service name
$serviceName = "TimeBrokerSvc"

# Start the Time Broker service on demand
function Start-TimeBrokerService {
    # Check if the service is already running
    $service = Get-Service -Name $serviceName
    if ($service.Status -ne 'Running') {
        Write-Host "Starting the $serviceName service..."
        Start-Service -Name $serviceName
        Start-Sleep -Seconds 5 # Allow a brief pause for the service to start
    } else {
        Write-Host "$serviceName service is already running."
    }
}

# Log events from the Event Viewer related to time sync or Time Broker service
function Log-ServiceEvents {
    # Get events related to the Time Broker service from the Event Log
    try {
        $eventLogs = Get-WinEvent -LogName "System" | Where-Object {
            $_.ProviderName -eq "Microsoft-Windows-Time-Service" -or $_.ProviderName -eq "Time Broker"
        }

        # Filter for relevant event IDs (e.g., 35 for successful time sync)
        $filteredLogs = $eventLogs | Where-Object { $_.Id -eq 1 }

        if ($filteredLogs) {
            Write-Host "Recent Time Sync Events:"
            $filteredLogs | ForEach-Object { 
                Write-Host ("Time Sync Event: " + $_.Message) 
            }
        } else {
            Write-Host "No time synchronization events found."
        }
    } catch {
        Write-Host "Error while retrieving event logs: $_"
    }
}

# Check the last time the system time was synced
function Check-LastTimeSync {
    # Get the latest time synchronization event
    try {
        $timeSyncEvent = Get-WinEvent -LogName "System" | Where-Object { 
            $_.ProviderName -eq "Microsoft-Windows-Time-Service" -and $_.Id -eq 35
        } | Select-Object -First 1

        if ($timeSyncEvent) {
            Write-Host "Last time synchronization event:"
            Write-Host ("Time: " + $timeSyncEvent.TimeCreated)
            Write-Host ("Message: " + $timeSyncEvent.Message)
        } else {
            Write-Host "No time synchronization event found."
        }
    } catch {
        Write-Host "Error while retrieving time synchronization event: $_"
    }
}

# Start the Time Broker service
Start-TimeBrokerService

# Log events related to time sync
Log-ServiceEvents

# Check the last time the system time was synchronized
Check-LastTimeSync
