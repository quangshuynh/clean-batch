@echo off
setlocal EnableExtensions
cd /d "%~dp0"
if not exist "%~dp0Safe-Windows-Cleanup.ps1" (
 echo Missing Safe-Windows-Cleanup.ps1 in the same folder.
  pause
  exit /b 1
)
echo.
echo   SAFE WINDOWS CLEANUP v2.1
echo   1 - Preview ordinary cleanup [recommended first]
echo   2 - Run ordinary cleanup
echo   3 - Preview deep cleanup (includes shader caches)
echo   4 - Run deep cleanup (includes shader caches)
echo   5 - Exit
 echo.
choice /C 12345 /N /M "Choose 1-5: "
if errorlevel 5 exit /b 0
if errorlevel 4 (
  set "PARAMS=-Deep -Apply"
  goto run
)
if errorlevel 3 (
  set "PARAMS=-Deep"
  goto run
)
if errorlevel 2 (
  set "PARAMS=-Apply"
  goto run
)
set "PARAMS="
:run
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Safe-Windows-Cleanup.ps1" %PARAMS%
echo.
pause
endlocal
