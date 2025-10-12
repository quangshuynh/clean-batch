@echo off
setlocal EnableExtensions EnableDelayedExpansion

:: Capture free space BEFORE (in bytes) on the system drive
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "(Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':'))).Free"`) do set "BEFORE_FREE=%%A"

:: Define commonly used directories
set "TEMP_DIR=%temp%"
set "LOCAL_TEMP=%USERPROFILE%\AppData\Local\Temp"
set "LOCALLOW_TEMP=%USERPROFILE%\AppData\LocalLow\Temp"
set "ROAMING_TEMP=%USERPROFILE%\AppData\Roaming\Temp"
set "WINDOWS_TEMP=C:\Windows\Temp"
set "PREFETCH_DIR=C:\Windows\Prefetch"
set "DOWNLOAD_DIR=%SYSTEMROOT%\SoftwareDistribution\Download"

:: Clean temporary files
echo Cleaning up temporary files...
del /s /f /q "%TEMP_DIR%\*.*" 2>nul
rd /s /q "%TEMP_DIR%" 2>nul
mkdir "%TEMP_DIR%" 2>nul

echo Cleaning up Local Temp files...
del /s /f /q "%LOCAL_TEMP%\*.*" 2>nul
rd /s /q "%LOCAL_TEMP%" 2>nul
mkdir "%LOCAL_TEMP%" 2>nul

echo Cleaning up LocalLow Temp files...
del /s /f /q "%LOCALLOW_TEMP%\*.*" 2>nul
rd /s /q "%LOCALLOW_TEMP%" 2>nul
mkdir "%LOCALLOW_TEMP%" 2>nul

if exist "%ROAMING_TEMP%" (
    echo Cleaning up Roaming Temp files...
    del /s /f /q "%ROAMING_TEMP%\*.*" 2>nul
    rd /s /q "%ROAMING_TEMP%" 2>nul
    mkdir "%ROAMING_TEMP%" 2>nul
)

echo Cleaning up Windows Temp files...
del /s /f /q "%WINDOWS_TEMP%\*.*" 2>nul
rd /s /q "%WINDOWS_TEMP%" 2>nul
mkdir "%WINDOWS_TEMP%" 2>nul

:: Clean prefetch and system files
echo Cleaning up Prefetch files...
del /s /f /q "%PREFETCH_DIR%\*.*" 2>nul

echo Cleaning up Windows Update cache files...
del /s /f /q "%DOWNLOAD_DIR%\*.*" 2>nul

echo Clearing DNS cache...
ipconfig /flushdns

:: Additional cleanup tasks
echo Performing additional cleanup tasks...
del /q C:\Temp\*.* 2>nul
del /q C:\Windows\Temp\*.* 2>nul
del /q "%LOCAL_TEMP%\*.*" 2>nul

del /q "%USERPROFILE%\AppData\LocalLow\NVIDIA\PerDriverVersion\DXCache\*.*" 2>nul
del /q "%USERPROFILE%\AppData\Local\AMD\DxCache\*.*" 2>nul
del /q "%USERPROFILE%\AppData\Local\AMD\DxcCache\*.*" 2>nul
del /q "%USERPROFILE%\AppData\Roaming\Arrowhead\Helldivers2\shader_cache\*.*" 2>nul

for /d %%d in (C:\Temp\*) do rd /s /q "%%d" 2>nul
for /d %%d in (C:\Windows\Temp\*) do rd /s /q "%%d" 2>nul
for /d %%d in ("%LOCAL_TEMP%\*") do rd /s /q "%%d" 2>nul
for /d %%d in ("%USERPROFILE%\AppData\LocalLow\NVIDIA\PerDriverVersion\DXCache\*") do rd /s /q "%%d" 2>nul
for /d %%d in ("%USERPROFILE%\AppData\Local\AMD\DxCache\*") do rd /s /q "%%d" 2>nul
for /d %%d in ("%USERPROFILE%\AppData\Local\AMD\DxcCache\*") do rd /s /q "%%d" 2>nul
for /d %%d in ("%USERPROFILE%\AppData\Roaming\Arrowhead\Helldivers2\shader_cache\*") do rd /s /q "%%d" 2>nul

:: Additional cleanup for Discord
if exist "%APPDATA%\discord\Cache" (
    echo Cleaning Discord cache...
    del /s /f /q "%APPDATA%\discord\Cache\*.*" 2>nul
    for /d %%d in ("%APPDATA%\discord\Cache\*") do rd /s /q "%%d" 2>nul
)

:: Additional cleanup for Visual Studio Code
if exist "%APPDATA%\Code\Cache" (
    echo Cleaning VS Code Cache...
    del /s /f /q "%APPDATA%\Code\Cache\*.*" 2>nul
    for /d %%d in ("%APPDATA%\Code\Cache\*") do rd /s /q "%%d" 2>nul
)
if exist "%APPDATA%\Code\CachedData" (
    del /s /f /q "%APPDATA%\Code\CachedData\*.*" 2>nul
    for /d %%d in ("%APPDATA%\Code\CachedData\*") do rd /s /q "%%d" 2>nul
)
if exist "%APPDATA%\Code\logs" (
    del /s /f /q "%APPDATA%\Code\logs\*.*" 2>nul
    for /d %%d in ("%APPDATA%\Code\logs\*") do rd /s /q "%%d" 2>nul
)

echo Emptying Recycle Bin...
rd /s /q %systemdrive%\$Recycle.Bin 2>nul

:: Capture free space AFTER (in bytes) on the system drive
for /f "usebackq delims=" %%A in (`powershell -NoProfile -Command "(Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':'))).Free"`) do set "AFTER_FREE=%%A"

:: Compute and display how much storage was freed
for /f "usebackq delims=" %%A in (`
  powershell -NoProfile -Command ^
    "$before=[double]'%BEFORE_FREE%'; $after=[double]'%AFTER_FREE%'; $delta=$after-$before; " ^
    "if ($delta -lt 0) { $delta = 0 } ;" ^
    "$gb='{0:N2} GB' -f ($delta/1GB); $mb='{0:N0} MB' -f ($delta/1MB); " ^
    "Write-Output ('Cleared: ' + $gb + ' (' + $mb + ', ' + [string]([math]::Round($delta)) + ' bytes)')"
`) do set "CLEARED_RESULT=%%A"

echo.
echo Cleanup completed!
echo %CLEARED_RESULT%
echo.

pause
