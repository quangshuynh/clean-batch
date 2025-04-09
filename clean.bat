@echo off
setlocal

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
del /s /f /q "%TEMP_DIR%\*.*"
rd /s /q "%TEMP_DIR%"
mkdir "%TEMP_DIR%"

echo Cleaning up Local Temp files...
del /s /f /q "%LOCAL_TEMP%\*.*"
rd /s /q "%LOCAL_TEMP%"
mkdir "%LOCAL_TEMP%"

echo Cleaning up LocalLow Temp files...
del /s /f /q "%LOCALLOW_TEMP%\*.*"
rd /s /q "%LOCALLOW_TEMP%"
mkdir "%LOCALLOW_TEMP%"

if exist "%ROAMING_TEMP%" (
    echo Cleaning up Roaming Temp files...
    del /s /f /q "%ROAMING_TEMP%\*.*"
    rd /s /q "%ROAMING_TEMP%"
    mkdir "%ROAMING_TEMP%"
)

echo Cleaning up Windows Temp files...
del /s /f /q "%WINDOWS_TEMP%\*.*"
rd /s /q "%WINDOWS_TEMP%"
mkdir "%WINDOWS_TEMP%"

:: Clean prefetch and system files
echo Cleaning up Prefetch files...
del /s /f /q "%PREFETCH_DIR%\*.*"

echo Emptying Recycle Bin...
rd /s /q %systemdrive%\$Recycle.Bin

echo Cleaning up system cache files...
del /s /f /q "%DOWNLOAD_DIR%\*.*"

echo Clearing DNS cache...
ipconfig /flushdns

:: Additional cleanup tasks
echo Performing additional cleanup tasks...
del /q C:\Temp\*.*
del /q C:\Windows\Temp\*.*
del /q "%LOCAL_TEMP%\*.*"

del /q "%USERPROFILE%\AppData\LocalLow\NVIDIA\PerDriverVersion\DXCache\*.*"
del /q "%USERPROFILE%\AppData\Local\AMD\DxCache\*.*"
del /q "%USERPROFILE%\AppData\Local\AMD\DxcCache\*.*"
del /q "%USERPROFILE%\AppData\Roaming\Arrowhead\Helldivers2\shader_cache\*.*"

for /d %%d in (C:\Temp\*) do rd /s /q "%%d"
for /d %%d in (C:\Windows\Temp\*) do rd /s /q "%%d"
for /d %%d in ("%LOCAL_TEMP%\*") do rd /s /q "%%d"
for /d %%d in ("%USERPROFILE%\AppData\LocalLow\NVIDIA\PerDriverVersion\DXCache\*") do rd /s /q "%%d"
for /d %%d in ("%USERPROFILE%\AppData\Local\AMD\DxCache\*") do rd /s /q "%%d"
for /d %%d in ("%USERPROFILE%\AppData\Local\AMD\DxcCache\*") do rd /s /q "%%d"
for /d %%d in ("%USERPROFILE%\AppData\Roaming\Arrowhead\Helldivers2\shader_cache\*") do rd /s /q "%%d"

:: Additional cleanup for Discord
if exist "%APPDATA%\discord\Cache" (
    del /s /f /q "%APPDATA%\discord\Cache\*.*"
    for /d %%d in ("%APPDATA%\discord\Cache\*") do rd /s /q "%%d"
)

:: Additional cleanup for Visual Studio Code
if exist "%APPDATA%\Code\Cache" (
    del /s /f /q "%APPDATA%\Code\Cache\*.*"
    for /d %%d in ("%APPDATA%\Code\Cache\*") do rd /s /q "%%d"
)
if exist "%APPDATA%\Code\CachedData" (
    del /s /f /q "%APPDATA%\Code\CachedData\*.*"
    for /d %%d in ("%APPDATA%\Code\CachedData\*") do rd /s /q "%%d"
)
if exist "%APPDATA%\Code\logs" (
    del /s /f /q "%APPDATA%\Code\logs\*.*"
    for /d %%d in ("%APPDATA%\Code\logs\*") do rd /s /q "%%d"
)

echo Cleanup completed!
pause
