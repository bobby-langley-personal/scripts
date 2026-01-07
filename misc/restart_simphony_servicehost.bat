@echo off
setlocal

:: Set variables
set "psScriptUrl=https://tizen-builds.s3.amazonaws.com/agent/restart_simphony_servicehost.ps1"
set "psScriptPath=%USERPROFILE%\Downloads\restart_simphony_servicehost.ps1"
set "logFilePath=%USERPROFILE%\Downloads\restart_log.txt"

:: Download the PowerShell script
powershell.exe -Command "Invoke-WebRequest -Uri '%psScriptUrl%' -OutFile '%psScriptPath%'"

:: Check if the script was downloaded successfully
if exist "%psScriptPath%" (
    :: Execute the PowerShell script as administrator and wait for it to finish
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%psScriptPath%"

    :: Check the exit code of the PowerShell script
    if %ERRORLEVEL% equ 0 (
        :: Delete the PowerShell script
        del "%psScriptPath%"
        :: Delete the log file
        del "%logFilePath%"
    ) else (
        echo "PowerShell script execution failed."
    )
) else (
    echo "Failed to download the PowerShell script."
)

:: Ensure to close the Command Prompt window after execution
exit /b %ERRORLEVEL%
