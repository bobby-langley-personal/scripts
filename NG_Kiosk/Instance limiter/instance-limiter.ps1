# Define variables
$taskName = "Grubbrr Kiosk Task"
$appPath = "C:\Program Files\Grubbrr Kiosk\Grubbrr Kiosk.exe"
$trigger = New-ScheduledTaskTrigger -AtStartup
$action = New-ScheduledTaskAction -Execute $appPath

# Log: Starting task creation
Write-Host "Starting task creation for '$taskName'..." -ForegroundColor Green

# Debug: Log paths and settings
Write-Host "App Path: $appPath"
Write-Host "Task Name: $taskName"

try {
    # Create the task with valid parameters
    Register-ScheduledTask -TaskName $taskName `
        -Trigger $trigger `
        -Action $action `
        -Settings (New-ScheduledTaskSettingsSet -StartWhenAvailable -DoNotAllowNewInstance)

    Write-Host "Scheduled Task '$taskName' created successfully." -ForegroundColor Green
} catch {
    # Log error details
    Write-Host "ERROR: Failed to create scheduled task. $_" -ForegroundColor Red
}

