@echo off
cls

REM Define the path to the PowerShell script directly
set "scriptPath=%USERPROFILE%\Downloads\uninstall_old_install_latest_or_select_from_list_or_input_URL.ps1"

REM Check if the script exists before trying to run it
if exist "%scriptPath%" (
    echo Running PowerShell script as administrator...
    powershell -Command "Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File \"%scriptPath%\"' -Verb RunAs -Wait"
) else (
    echo PowerShell script not found at %scriptPath%.
)

pause
