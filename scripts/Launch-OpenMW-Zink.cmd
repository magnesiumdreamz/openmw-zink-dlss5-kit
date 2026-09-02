@echo off
setlocal
tasklist /FI "IMAGENAME eq openmw.exe" 2>NUL | find /I "openmw.exe" >NUL
if not errorlevel 1 exit /b 2
set "GALLIUM_DRIVER=zink"
set "MESA_LOADER_DRIVER_OVERRIDE=zink"
set "MESA_LOG_FILE=%~dp0mesa-zink.log"
pushd "%~dp0"
"%~dp0openmw.exe"
set "OPENMW_EXIT=%ERRORLEVEL%"
popd
exit /b %OPENMW_EXIT%
