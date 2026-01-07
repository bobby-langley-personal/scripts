echo Running PowerShell script as administrator...
powershell -Command "Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned"

powershell -Command "Start-Process powershell -ArgumentList '-ExecutionPolicy Bypass -File NTP_over_UDP_UTC.ps1' -Verb RunAs -Wait"