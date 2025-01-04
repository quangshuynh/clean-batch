@echo off
:: Clean temp files
echo Cleaning up temporary files...
del /s /f /q "%temp%\*.*"
rd /s /q "%temp%"
mkdir "%temp%"

:: Clean user temp files
echo Cleaning up local temp files...
del /s /f /q "%USERPROFILE%\AppData\Local\Temp\*.*"
rd /s /q "%USERPROFILE%\AppData\Local\Temp"
mkdir "%USERPROFILE%\AppData\Local\Temp"

:: Clean user LocalLow temp files
echo Cleaning up LocalLow temp files...
del /s /f /q "%USERPROFILE%\AppData\LocalLow\Temp\*.*"
rd /s /q "%USERPROFILE%\AppData\LocalLow\Temp"
mkdir "%USERPROFILE%\AppData\LocalLow\Temp"

:: Clean user roaming temp files
if exist "%USERPROFILE%\AppData\Roaming\Temp" (
    echo Cleaning up Roaming temp files...
    del /s /f /q "%USERPROFILE%\AppData\Roaming\Temp\*.*"
    rd /s /q "%USERPROFILE%\AppData\Roaming\Temp"
    mkdir "%USERPROFILE%\AppData\Roaming\Temp"
)

:: Clean Windows temp files
echo Cleaning up Windows temp files...
del /s /f /q "C:\Windows\Temp\*.*"
rd /s /q "C:\Windows\Temp"
mkdir "C:\Windows\Temp"

:: Clean prefetch files
echo Cleaning up prefetch files...
del /s /f /q "C:\Windows\Prefetch\*.*"

:: Clean recycling bin
echo Emptying Recycle Bin...
rd /s /q %systemdrive%\$Recycle.Bin

:: Clean system cache files
echo Cleaning up system cache...
del /s /f /q "%systemroot%\SoftwareDistribution\Download\*.*"

:: Clear DNS cache
echo Clearing DNS cache...
ipconfig /flushdns

:: Additional cleanup tasks
echo Performing additional cleanup tasks...
del /q C:\Temp\*.*
del /q C:\Windows\Temp\*.*
del /q "%USERPROFILE%\AppData\Local\Temp\*.*"

del /q "%USERPROFILE%\AppData\LocalLow\NVIDIA\PerDriverVersion\DXCache\*.*"
del /q "%USERPROFILE%\AppData\Local\AMD\DxCache\*.*"
del /q "%USERPROFILE%\AppData\Local\AMD\DxcCache\*.*"

del /q "%USERPROFILE%\AppData\Roaming\Arrowhead\Helldivers2\shader_cache\*.*"

for /d %%d in (C:\Temp\*) do rd /s /q "%%d"
for /d %%d in (C:\Windows\Temp\*) do rd /s /q "%%d"
for /d %%d in ("%USERPROFILE%\AppData\Local\Temp\*") do rd /s /q "%%d"

for /d %%d in ("%USERPROFILE%\AppData\LocalLow\NVIDIA\PerDriverVersion\DXCache\*") do rd /s /q "%%d"
for /d %%d in ("%USERPROFILE%\AppData\Local\AMD\DxCache\*") do rd /s /q "%%d"
for /d %%d in ("%USERPROFILE%\AppData\Local\AMD\DxcCache\*") do rd /s /q "%%d"

for /d %%d in ("%USERPROFILE%\AppData\Roaming\Arrowhead\Helldivers2\shader_cache\*") do rd /s /q "%%d"

echo Cleanup completed!
pause
