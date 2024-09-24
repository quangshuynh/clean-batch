@echo off
:: claen temp files
echo Cleaning up temporary files...
del /s /f /q "%temp%\*.*"
rd /s /q "%temp%"
mkdir "%temp%"

:: clean user temp files
echo Cleaning up Quang's local temp files...
del /s /f /q "C:\Users\Quang\AppData\Local\Temp\*.*"
rd /s /q "C:\Users\Quang\AppData\Local\Temp"
mkdir "C:\Users\Quang\AppData\Local\Temp"

:: clean user localLow temp files 
echo Cleaning up Quang's LocalLow temp files...
del /s /f /q "C:\Users\Quang\AppData\LocalLow\Temp\*.*"
rd /s /q "C:\Users\Quang\AppData\LocalLow\Temp"
mkdir "C:\Users\Quang\AppData\LocalLow\Temp"

:: clean user roam temp files
if exist "C:\Users\Quang\AppData\Roaming\Temp" (
    echo Cleaning up Quang's Roaming temp files...
    del /s /f /q "C:\Users\Quang\AppData\Roaming\Temp\*.*"
    rd /s /q "C:\Users\Quang\AppData\Roaming\Temp"
    mkdir "C:\Users\Quang\AppData\Roaming\Temp"
)

:: clean window temp files
echo Cleaning up Windows temp files...
del /s /f /q "C:\Windows\Temp\*.*"
rd /s /q "C:\Windows\Temp"
mkdir "C:\Windows\Temp"

:: clean prefetch files
echo Cleaning up prefetch files...
del /s /f /q "C:\Windows\Prefetch\*.*"

:: clean recycling bin
echo Emptying Recycle Bin...
rd /s /q %systemdrive%\$Recycle.Bin

:: clean system cache files
echo Cleaning up system cache...
del /s /f /q "%systemroot%\SoftwareDistribution\Download\*.*"

:: clear cache cashe
echo Clearing DNS cache...
ipconfig /flushdns

echo Cleanup completed!
pause
