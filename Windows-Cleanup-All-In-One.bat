@echo off
setlocal EnableExtensions DisableDelayedExpansion
title Safe Windows Cleanup - All in One
set "SELF=%~f0"
where powershell.exe >nul 2>&1 || (echo ERROR: Windows PowerShell is required.& pause & exit /b 1)
:MENU
cls
echo ===============================================================
echo              SAFE WINDOWS CLEANUP - ALL IN ONE
echo ===============================================================
echo  1 - Preview ordinary cleanup (no deletion)
echo  2 - Run ordinary cleanup
 echo  3 - Preview deep cleanup (no deletion)
echo  4 - Run deep cleanup (includes old shader cache files)
echo  5 - Inspect large Claude / Docker storage (no deletion)
echo  6 - Exit
echo.
set "CHOICE="
set /p "CHOICE=Choose 1-6: "
if "%CHOICE%"=="6" exit /b 0
if "%CHOICE%"=="1" set "CLEAN_MODE=preview"
if "%CHOICE%"=="2" set "CLEAN_MODE=clean"
if "%CHOICE%"=="3" set "CLEAN_MODE=previewdeep"
if "%CHOICE%"=="4" set "CLEAN_MODE=cleandeep"
if "%CHOICE%"=="5" set "CLEAN_MODE=inspect"
if not defined CLEAN_MODE goto MENU
set "PSFILE=%TEMP%\safe-clean-%RANDOM%-%RANDOM%.ps1"
powershell.exe -NoProfile -Command "$a=[IO.File]::ReadAllLines($env:SELF); $i=[Array]::IndexOf($a,'#__POWERSHELL_BELOW__'); if($i -lt 0){exit 2}; [IO.File]::WriteAllLines($env:PSFILE,[string[]]$a[($i+1)..($a.Length-1)],[Text.UTF8Encoding]::new($false))"
if errorlevel 1 (
 echo Could not extract embedded cleanup engine.
 pause
 exit /b 1
)
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PSFILE%" -Mode "%CLEAN_MODE%"
set "RESULT=%ERRORLEVEL%"
del /f /q "%PSFILE%" >nul 2>&1
set "CLEAN_MODE="
echo.
if not "%RESULT%"=="0" echo Cleanup script exited with code %RESULT%.
pause
goto MENU
#__POWERSHELL_BELOW__
param([ValidateSet('preview','clean','previewdeep','cleandeep','inspect')][string]$Mode='preview')
$ErrorActionPreference='Stop'
$Preview = $Mode -in @('preview','previewdeep','inspect')
$Deep = $Mode -in @('previewdeep','cleandeep')
$Now = Get-Date
$stats = New-Object System.Collections.Generic.List[object]
$problems = New-Object System.Collections.Generic.List[string]
$Skipped = New-Object System.Collections.Generic.List[string]
$script:MaxPerGroup = 150000
function GB($bytes) { '{0:N2} GiB' -f ([double]$bytes / 1GB) }
function SafeJoin([string]$a,[string]$b) { if ([string]::IsNullOrWhiteSpace($a)) { return $null }; Join-Path -Path $a -ChildPath $b }
function Running([string[]]$Names) {
    foreach($name in $Names) { if (Get-Process -Name $name -ErrorAction SilentlyContinue) { return $true } }
    return $false
}
function Add-Target([string]$Label,[string]$Path,[int]$Age,[bool]$Recursive=$true,[string[]]$Processes=@()) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return }
    # All paths are assembled from explicit locations in this script, never from user input.
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { return }
    if (Running $Processes) { $Skipped.Add("$Label : application running") ; return }
    try { $root=(Get-Item -LiteralPath $Path -Force -ErrorAction Stop) } catch { return }
    if (($root.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { $Skipped.Add("$Label : reparse point root") ; return }
    $Cutoff=$Now.AddDays(-$Age)
    [long]$candidates=0; [long]$potential=0; [long]$deleted=0; [long]$released=0
    $stack=New-Object 'System.Collections.Generic.Stack[System.IO.DirectoryInfo]'
    $stack.Push([IO.DirectoryInfo]$root)
    [long]$visited=0
    while ($stack.Count -gt 0) {
        $dir=$stack.Pop()
        if (($dir.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
        try { $files=$dir.EnumerateFiles() } catch { $problems.Add("$Label : cannot list $($dir.FullName)"); continue }
        try {
            foreach($f in $files) {
                $visited++
                if ($visited -gt $script:MaxPerGroup) { $Skipped.Add("$Label : safety scan limit reached") ; break }
                try {
                    if (($f.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
                    if ($f.LastWriteTime -ge $Cutoff) { continue }
                    $candidates++; $potential += $f.Length
                    if ($Preview) { continue }
                    # Re-check age and file type immediately before deletion.
                    $f.Refresh()
                    if (-not $f.Exists -or $f.LastWriteTime -ge $Cutoff -or (($f.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) { continue }
                    [long]$size=$f.Length
                    $f.Delete()
                    $deleted++; $released += $size
                } catch {
                    if ($problems.Count -lt 30) { $problems.Add("$Label : could not delete $($f.FullName)") }
                }
            }
        } catch { if ($problems.Count -lt 30) { $problems.Add("$Label : scan failed") } }
        if ($visited -gt $script:MaxPerGroup) { break }
        if (-not $Recursive) { continue }
        try { $dirs=$dir.EnumerateDirectories() } catch { continue }
        try {
            foreach ($child in $dirs) {
                try {
                    if (($child.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0) { $stack.Push($child) }
                } catch { }
            }
        } catch { }
    }
    $stats.Add([pscustomobject]@{Category=$Label;Candidates=$candidates;Potential=$potential;Deleted=$deleted;Released=$released})
    if ($candidates -gt 0) {
       Write-Host ('{0,-35} {1,8} files | {2,11}' -f $Label,$candidates,(GB $potential))
    }
}
function Scan-Claude([string]$Root, [string]$Description) {
    if (-not (Test-Path -LiteralPath $Root -PathType Container)) { return }
    $claudeProcesses=@('Claude','claude','claude-code','claude-code-vm')
    foreach($leaf in @('Cache','Code Cache','GPUCache','GrShaderCache')) {
        Add-Target "$Description $leaf" (SafeJoin $Root $leaf) 14 $true $claudeProcesses
    }
    Add-Target "$Description logs" (SafeJoin $Root 'logs') 30 $true $claudeProcesses
}
function Show-Storage([string]$Label,[string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        Write-Host ("  {0}: {1}" -f $Label,$Path)
        $entry=Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
        if ($entry -is [IO.FileInfo]) { Write-Host ("    File size: {0}" -f (GB $entry.Length)) }
        else { Write-Host '    Folder size: see your disk analyzer; NOT removed' }
    }
}
Write-Host "`nSAFE WINDOWS CLEANUP | Mode: $Mode | Preview: $Preview | Deep: $Deep"
Write-Host 'Retention: Temp 7d, caches 14d, logs 30d. Files only; folders are preserved.'
Write-Host 'No forced app shutdown. Junctions/symlinks are never followed.'
Write-Host 'NEVER cleans Claude VM bundles, sessions, configs, Docker VHDX, repos or WSL.'
$local=$env:LOCALAPPDATA; $roaming=$env:APPDATA; $profile=$env:USERPROFILE
if ($Mode -eq 'inspect') {
    Write-Host "`nLarge storage inventory (read-only):"
    foreach($pkg in @(Get-ChildItem -LiteralPath (SafeJoin $local 'Packages') -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue)) {
        Show-Storage 'Claude LocalCache' (SafeJoin $pkg.FullName 'LocalCache')
        Show-Storage 'Claude VM bundles' (SafeJoin $pkg.FullName 'LocalCache\vm_bundles')
    }
    $claudeData=SafeJoin $local 'Claude-Data'
    if (Test-Path -LiteralPath $claudeData) {
        foreach($item in @(Get-ChildItem -LiteralPath $claudeData -Directory -ErrorAction SilentlyContinue)) {
            Show-Storage 'Claude-Data' $item.FullName
            Show-Storage 'Claude-Data VM bundles' (SafeJoin $item.FullName 'vm_bundles')
        }
    }
    Show-Storage 'Docker WSL data' (SafeJoin $local 'Docker\wsl\disk\docker_data.vhdx')
    Write-Host "`nDo not delete VM bundles or VHDX directly. Check Claude settings and Docker Desktop storage tools."
    exit 0
}
# TEMP: top-level only; avoid recursively deleting agent projects, installers, or recovery folders.
Add-Target 'User Temp top-level' $env:TEMP 7 $false
Add-Target 'Local Temp top-level' (SafeJoin $local 'Temp') 7 $false
Add-Target 'LocalLow Temp top-level' (SafeJoin $profile 'AppData\LocalLow\Temp') 7 $false
Add-Target 'Roaming Temp top-level' (SafeJoin $roaming 'Temp') 7 $false
# Browser caches. Only disposable HTTP / code / GPU cache locations, not cookies, profiles or credentials.
foreach($browser in @(
    @{ Name='Chrome'; Root=(SafeJoin $local 'Google\Chrome\User Data'); Procs=@('chrome') },
    @{ Name='Edge'; Root=(SafeJoin $local 'Microsoft\Edge\User Data'); Procs=@('msedge') },
    @{ Name='Brave'; Root=(SafeJoin $local 'BraveSoftware\Brave-Browser\User Data'); Procs=@('brave') }
)) {
    if (-not (Test-Path -LiteralPath $browser.Root -PathType Container)) { continue }
    foreach($p in @(Get-ChildItem -LiteralPath $browser.Root -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' })) {
        foreach($sub in @('Cache','Network\Cache','Code Cache','GPUCache')) {
            Add-Target "$($browser.Name) $($p.Name) $sub" (SafeJoin $p.FullName $sub) 14 $true $browser.Procs
        }
    }
}
$firefox=SafeJoin $local 'Mozilla\Firefox\Profiles'
if (Test-Path -LiteralPath $firefox -PathType Container) {
    foreach($p in @(Get-ChildItem -LiteralPath $firefox -Directory -ErrorAction SilentlyContinue)) {
        foreach($sub in @('cache2','startupCache')) { Add-Target "Firefox $sub" (SafeJoin $p.FullName $sub) 14 $true @('firefox') }
    }
}
# Editors & apps. Only explicit cache or diagnostic paths.
foreach($t in @(
    @('VS Code Cache',(SafeJoin $roaming 'Code\Cache'),14,'Code'),
    @('VS Code CachedData',(SafeJoin $roaming 'Code\CachedData'),14,'Code'),
    @('VS Code Code Cache',(SafeJoin $roaming 'Code\Code Cache'),14,'Code'),
    @('VS Code GPUCache',(SafeJoin $roaming 'Code\GPUCache'),14,'Code'),
    @('VS Code old logs',(SafeJoin $roaming 'Code\logs'),30,'Code'),
    @('Discord cache',(SafeJoin $roaming 'discord\Cache'),14,'Discord'),
    @('Discord Code Cache',(SafeJoin $roaming 'discord\Code Cache'),14,'Discord'),
    @('Discord GPUCache',(SafeJoin $roaming 'discord\GPUCache'),14,'Discord'),
    @('Steam HTML cache',(SafeJoin $local 'Steam\htmlcache'),14,'steam'),
    @('Spotify app cache',(SafeJoin $local 'Spotify\Storage'),14,'Spotify')
)) { Add-Target $t[0] $t[1] ([int]$t[2]) $true @($t[3]) }
$epic=SafeJoin $local 'EpicGamesLauncher\Saved'
if(Test-Path -LiteralPath $epic -PathType Container) {
    foreach($folder in @(Get-ChildItem -LiteralPath $epic -Directory -Filter 'webcache*' -ErrorAction SilentlyContinue)) {
        Add-Target 'Epic Launcher webcache' $folder.FullName 14 $true @('EpicGamesLauncher')
    }
}
# Claude Windows Store packaged client and optional Claude-Data caches.
$packages=SafeJoin $local 'Packages'
if (Test-Path -LiteralPath $packages -PathType Container) {
    foreach($pkg in @(Get-ChildItem -LiteralPath $packages -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue)) {
        Scan-Claude (SafeJoin $pkg.FullName 'LocalCache') 'Claude packaged'
    }
}
$claudeData=SafeJoin $local 'Claude-Data'
if (Test-Path -LiteralPath $claudeData -PathType Container) {
    foreach($item in @(Get-ChildItem -LiteralPath $claudeData -Directory -ErrorAction SilentlyContinue)) {
        if($item.Name -like 'Claude_*') { Scan-Claude $item.FullName 'Claude-Data' }
    }
}
# Claude Code/Codex: only named debug/log files; never touch session/history directories.
Add-Target 'Claude Code old debug logs' (SafeJoin $profile '.claude\debug') 30 $true @('claude','Claude')
Add-Target 'Codex old logs' (SafeJoin $profile '.codex\log') 30 $true @('codex')
Add-Target 'Codex old log files' (SafeJoin $profile '.codex\logs') 30 $true @('codex')
# Deep mode: old shader cache files are regenerable but might cause compilation stutter.
if ($Deep) {
    foreach($t in @(
        @('DirectX shaders',(SafeJoin $local 'D3DSCache')),
        @('NVIDIA DX shaders',(SafeJoin $local 'NVIDIA\DXCache')),
        @('NVIDIA GL shaders',(SafeJoin $local 'NVIDIA\GLCache')),
        @('AMD DX shaders',(SafeJoin $local 'AMD\DxCache')),
        @('AMD Dxc shaders',(SafeJoin $local 'AMD\DxcCache')),
        @('AMD GL shaders',(SafeJoin $local 'AMD\GLCache')),
        @('AMD Vulkan shaders',(SafeJoin $local 'AMD\VkCache')),
        @('Intel shaders',(SafeJoin $local 'Intel\ShaderCache'))
    )) { Add-Target $t[0] $t[1] 14 $true @() }
}
[long]$totalPotential=0; [long]$totalReleased=0; [long]$totalCount=0
foreach($s in $stats) { $totalPotential += $s.Potential; $totalReleased += $s.Released; $totalCount += $s.Candidates }
Write-Host "`n=================== SUMMARY ==================="
Write-Host ("Eligible files: {0:N0} | Estimated reclaimable: {1}" -f $totalCount,(GB $totalPotential))
if(-not $Preview) { Write-Host ("Deleted tracked bytes: {0} (actual disk free may differ)" -f (GB $totalReleased)) }
if($Skipped.Count -gt 0) {
    Write-Host "`nSkipped categories:"
    $Skipped | Select-Object -Unique | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" }
}
if($problems.Count -gt 0) {
    Write-Host "`nAccess/other errors (up to 20):"
    $problems | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" }
}
Write-Host "`nNot touched: Claude vm_bundles, Claude Code/Codex sessions, Docker disk, WSL disks, npm/pip caches, Prefetch, Windows Update, Recycle Bin."
if($Preview) { Write-Host 'PREVIEW ONLY: no files were deleted.' }
exit 0
