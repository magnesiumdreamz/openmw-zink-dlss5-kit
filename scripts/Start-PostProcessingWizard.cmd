@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-PostProcessingWizard.ps1"
exit /b %ERRORLEVEL%
