@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-OpenMWDLSS5Wizard.ps1"
exit /b %ERRORLEVEL%
