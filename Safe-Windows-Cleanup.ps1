#requires -Version 5.1
<#
.SYNOPSIS
  Conservative Windows cache and stale-file cleaner.
.DESCRIPTION
  Defaults to preview mode. Deletes ordinary files only within an explicit allowlist.
  Never deletes directory trees or follows junctions/symlinks. Skips application
  caches while relevant applications are running and keeps recent files.

  Intentionally preserves agent session/history/config/auth files, Git repositories,
  worktrees, environments, package installations, and user documents.

.EXAMPLE
  .\Safe-Windows-Cleanup.ps1
.EXAMPLE
  .\Safe-Windows-Cleanup.ps1 -Apply
.EXAMPLE
  .\Safe-Windows-Cleanup.ps1 -Deep -Apply -ReportPath "$env:USERPROFILE\Desktop\cleanup.csv"
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$Deep,
    [ValidateRange(1,365)][int]$TempDays = 7,
    [ValidateRange(1,365)][int]$CacheDays = 14,
    [ValidateRange(1,365)][int]$LogDays = 30,
    [switch]$EmptyRecycleBin,
    [switch]$RunComponentCleanup,
    [string]$ReportPath
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# Never allow empty or malformed environment roots to broaden a deletion target.
$required = @('USERPROFILE','LOCALAPPDATA','APPDATA','TEMP','SystemRoot','ProgramData','SystemDrive')
foreach ($name in $required) {
    $value = [Environment]::GetEnvironmentVariable($name)
    if ([string]::IsNullOrWhiteSpace($value) -or
        ($name -eq 'SystemDrive' -and $value -notmatch '^[A-Za-z]:$') -or
        ($name -ne 'SystemDrive' -and -not [IO.Path]::IsPathRooted($value))) {
        throw "Missing/invalid environment path: $name"
    }
}

$script:Now = Get-Date
$script:Entries = New-Object System.Collections.Generic.List[object]
$script:Targets = New-Object System.Collections.Generic.List[object]
$script:Skipped = New-Object System.Collections.Generic.List[string]
$script:KnownRoots = @(
    [IO.Path]::GetFullPath($env:USERPROFILE),
    [IO.Path]::GetFullPath($env:LOCALAPPDATA),
    [IO.Path]::GetFullPath($env:APPDATA),
    [IO.Path]::GetFullPath($env:TEMP),
    [IO.Path]::GetFullPath($env:SystemRoot),
    [IO.Path]::GetFullPath($env:ProgramData)
)

function Test-IsSafeSubpath {
    param([string]$Path)
    try {
        $absolute = [IO.Path]::GetFullPath($Path).TrimEnd('\')
        foreach ($root in $script:KnownRoots) {
            $base = $root.TrimEnd('\')
            if ($absolute.StartsWith($base + '\', [StringComparison]::OrdinalIgnoreCase)) { return $true }
        }
    } catch { }
    return $false
}

function Test-Running {
    param([string[]]$Names)
    foreach ($name in $Names) {
        if (Get-Process -Name $name -ErrorAction SilentlyContinue) { return $true }
    }
    return $false
}

function Add-Target {
    param(
        [string]$Category,
        [string]$Path,
        [int]$AgeDays,
        [string[]]$ProcessNames = @(),
        [string[]]$Extensions = @(),
        [switch]$TopLevelOnly,
        [switch]$DeepOnly
    )
    if ($DeepOnly -and -not $Deep) { return }
    if (-not (Test-IsSafeSubpath $Path)) {
        $script:Skipped.Add("REJECTED unsafe root: $Category ($Path)")
        return
    }
    $script:Targets.Add([pscustomobject]@{
        Category = $Category; Path = $Path; AgeDays = $AgeDays;
        Processes = $ProcessNames; Extensions = $Extensions;
        TopLevelOnly = [bool]$TopLevelOnly
    })
}

function Scan-Target {
    param($Target)
    $path = $Target.Path
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { return }
    if (Test-Running $Target.Processes) {
        $script:Skipped.Add("Running app; skipped $($Target.Category): $path")
        return
    }
    # Reject links anywhere in the path, including an allowlisted target itself.
    $cursor = [IO.Path]::GetFullPath($path).TrimEnd('\')
    while ($cursor) {
        try {
            $attribute = [IO.File]::GetAttributes($cursor)
            if (($attribute -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                $script:Skipped.Add("Link/junction; skipped: $path")
                return
            }
        } catch {
            $script:Skipped.Add("Cannot validate path; skipped: $path")
            return
        }
        $parent = [IO.Directory]::GetParent($cursor)
        if ($null -eq $parent) { break }
        $cursor = $parent.FullName
    }
    $cutoff = $script:Now.AddDays(-$Target.AgeDays)
    $queue = New-Object 'System.Collections.Generic.Queue[string]'
    $queue.Enqueue($path)
    while ($queue.Count -gt 0) {
        $dir = $queue.Dequeue()
        try { $items = Get-ChildItem -LiteralPath $dir -Force -ErrorAction Stop }
        catch { $script:Skipped.Add("Cannot list: $dir"); continue }
        foreach ($item in $items) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { continue }
            if ($item.PSIsContainer) {
                if (-not $Target.TopLevelOnly) { $queue.Enqueue($item.FullName) }
                continue
            }
            if ($item.LastWriteTime -ge $cutoff) { continue }
            if ($Target.Extensions.Count -gt 0 -and
                $Target.Extensions -notcontains $item.Extension.ToLowerInvariant()) { continue }
            $script:Entries.Add([pscustomobject]@{
                Category = $Target.Category
                Path = $item.FullName
                Bytes = [long]$item.Length
                LastModified = $item.LastWriteTime
                Result = 'Preview'
            })
        }
    }
}

# Baseline: user temp files, only loose files at root to avoid touching project trees.
# More nested temp files are scanned conservatively but no directories are removed.
Add-Target 'User temporary files' $env:TEMP $TempDays @() @() -TopLevelOnly
Add-Target 'LocalLow temporary files' (Join-Path $env:USERPROFILE 'AppData\LocalLow\Temp') $TempDays @() @() -TopLevelOnly
Add-Target 'Roaming temporary files' (Join-Path $env:APPDATA 'Temp') $TempDays @() @() -TopLevelOnly

# VS Code / Visual Studio caches (not user-data, extensions or workspace state).
foreach ($part in @('Cache','CachedData','Code Cache','GPUCache')) {
    Add-Target 'VS Code cache' (Join-Path $env:APPDATA "Code\$part") $CacheDays @('Code')
}
Add-Target 'VS Code diagnostic logs' (Join-Path $env:APPDATA 'Code\logs') $LogDays @('Code')
$visualStudio = Join-Path $env:LOCALAPPDATA 'Microsoft\VisualStudio'
if (Test-Path -LiteralPath $visualStudio -PathType Container) {
    Get-ChildItem -LiteralPath $visualStudio -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Add-Target 'Visual Studio component cache' (Join-Path $_.FullName 'ComponentModelCache') $CacheDays @('devenv')
    }
}

# Browser profiles: do not touch cookies, sessions, history, Local Storage, or service workers.
$chromium = @(
    @{ Name='Edge'; Root=(Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data'); Processes=@('msedge') },
    @{ Name='Chrome'; Root=(Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data'); Processes=@('chrome') },
    @{ Name='Brave'; Root=(Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data'); Processes=@('brave') }
)
foreach ($browser in $chromium) {
    if (-not (Test-Path -LiteralPath $browser.Root -PathType Container)) { continue }
    $profiles = Get-ChildItem -LiteralPath $browser.Root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' }
    foreach ($profile in $profiles) {
        foreach ($part in @('Cache','Network\Cache','Code Cache','GPUCache')) {
            Add-Target "$($browser.Name) cache" (Join-Path $profile.FullName $part) $CacheDays $browser.Processes
        }
    }
}
$firefoxProfiles = Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox\Profiles'
if (Test-Path -LiteralPath $firefoxProfiles -PathType Container) {
    Get-ChildItem -LiteralPath $firefoxProfiles -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        foreach ($part in @('cache2','startupCache')) {
            Add-Target 'Firefox cache' (Join-Path $_.FullName $part) $CacheDays @('firefox')
        }
    }
}

# Common desktop application caches; skip while the application is open.
foreach ($part in @('Cache','Code Cache','GPUCache')) {
    Add-Target 'Discord cache' (Join-Path $env:APPDATA "discord\$part") $CacheDays @('Discord')
}
Add-Target 'Steam web cache' (Join-Path $env:LOCALAPPDATA 'Steam\htmlcache') $CacheDays @('steam','steamwebhelper')
$epicSaved = Join-Path $env:LOCALAPPDATA 'EpicGamesLauncher\Saved'
if (Test-Path -LiteralPath $epicSaved -PathType Container) {
    Get-ChildItem -LiteralPath $epicSaved -Directory -Filter 'webcache*' -ErrorAction SilentlyContinue | ForEach-Object {
        Add-Target 'Epic Games web cache' $_.FullName $CacheDays @('EpicGamesLauncher')
    }
}

# Coding agents: diagnostic logs ONLY. Never remove sessions, history, auth, settings,
# checkpoints, plans, tasks, project memory, or the agent root directories.
Add-Target 'Claude Code debug logs' (Join-Path $env:USERPROFILE '.claude\debug') $LogDays @('claude') @('.log','.txt')
Add-Target 'Codex diagnostic logs' (Join-Path $env:USERPROFILE '.codex\log') $LogDays @('codex') @('.log','.txt')

# Deep mode: expensive-to-rebuild caches; off by default.
Add-Target 'DirectX shader cache' (Join-Path $env:LOCALAPPDATA 'D3DSCache') $CacheDays @('dwm','game') @() -DeepOnly
foreach ($part in @('DXCache','GLCache')) {
    Add-Target 'NVIDIA shader cache' (Join-Path $env:LOCALAPPDATA "NVIDIA\$part") $CacheDays @('nvcontainer') @() -DeepOnly
}
foreach ($part in @('DxCache','DxcCache','GLCache','VkCache')) {
    Add-Target 'AMD shader cache' (Join-Path $env:LOCALAPPDATA "AMD\$part") $CacheDays @() @() -DeepOnly
}
Add-Target 'Intel shader cache' (Join-Path $env:LOCALAPPDATA 'Intel\ShaderCache') $CacheDays @() @() -DeepOnly

# Directly deleting package caches is purposely excluded; use package-manager-specific
# commands after separately inspecting their sizes. Docker/WSL/Playwright excluded too.

Write-Host ''
Write-Host 'SAFE WINDOWS CLEANUP' -ForegroundColor Cyan
Write-Host ('Mode: ' + $(if ($Apply) { 'DELETE matching files' } else { 'PREVIEW ONLY' }))
Write-Host "Retention: Temp $TempDays d | Cache $CacheDays d | Logs $LogDays d"
Write-Host "Deep caches: $([bool]$Deep)"
Write-Host ''

$drive = $env:SystemDrive.TrimEnd(':','\')
$before = $null
try { $before = (Get-PSDrive -Name $drive -ErrorAction Stop).Free } catch { }
foreach ($target in $script:Targets) { Scan-Target $target }

if ($Apply) {
    foreach ($entry in $script:Entries) {
        try {
            # Revalidate immediately prior to each deletion; refuse symlinks and directories.
            $file = Get-Item -LiteralPath $entry.Path -Force -ErrorAction Stop
            if ($file.PSIsContainer -or
                (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) -or
                $file.LastWriteTime -ge $script:Now.AddDays(-$(
                    if ($entry.Category -match 'temporary') { $TempDays }
                    elseif ($entry.Category -match 'log') { $LogDays }
                    else { $CacheDays }
                ))) {
                $entry.Result = 'Skipped (changed)'
                continue
            }
            Remove-Item -LiteralPath $entry.Path -Force -ErrorAction Stop
            $entry.Result = 'Deleted'
        } catch {
            $entry.Result = 'Skipped (locked/denied/missing)'
        }
    }
}

if ($EmptyRecycleBin) {
    if ($Apply) {
        Write-Warning 'Emptying the Recycle Bin permanently deletes items that may be recoverable otherwise.'
        $confirmation = Read-Host 'Type EMPTY to confirm'
        if ($confirmation -ceq 'EMPTY') {
            try { Clear-RecycleBin -Force -ErrorAction Stop; Write-Host 'Recycle Bin emptied.' }
            catch { Write-Warning "Recycle Bin operation failed: $($_.Exception.Message)" }
        }
    } else { Write-Host 'Recycle Bin: requested, but preview does not empty it.' }
}

if ($RunComponentCleanup) {
    if ($Apply) {
        Write-Warning 'DISM component cleanup can remove the ability to uninstall superseded updates.'
        $confirmation = Read-Host 'Type DISM to confirm (requires elevation)'
        if ($confirmation -ceq 'DISM') { & DISM.exe /Online /Cleanup-Image /StartComponentCleanup }
    } else { Write-Host 'DISM: requested, but preview does not run it.' }
}

$wouldBytes = [long](($script:Entries | Measure-Object -Property Bytes -Sum).Sum)
$done = @($script:Entries | Where-Object { $_.Result -eq 'Deleted' })
$doneBytes = [long](($done | Measure-Object -Property Bytes -Sum).Sum)
Write-Host ''
Write-Host ('Candidate files: {0:N0} | Candidate bytes: {1:N2} MB' -f $script:Entries.Count,($wouldBytes / 1MB))
if ($Apply) {
    Write-Host ('Deleted files: {0:N0} | Deleted logical bytes: {1:N2} MB' -f $done.Count,($doneBytes / 1MB))
    try {
        $after = (Get-PSDrive -Name $drive -ErrorAction Stop).Free
        if ($null -ne $before) { Write-Host ('System drive free-space change: {0:N2} MB' -f (($after - $before) / 1MB)) }
    } catch { }
}
$script:Entries | Group-Object Category | Sort-Object Name | ForEach-Object {
    $sum = ($_.Group | Measure-Object Bytes -Sum).Sum
    Write-Host ('  {0,-32} {1,7} files   {2,10:N2} MB' -f $_.Name,$_.Count,($sum / 1MB))
}
if ($script:Skipped.Count -gt 0) {
    Write-Host "`nSkipped targets / access warnings:"
    $script:Skipped | Select-Object -Unique | ForEach-Object { Write-Host "  $_" }
}
if (-not [string]::IsNullOrWhiteSpace($ReportPath)) {
    try {
        $reportFull = [IO.Path]::GetFullPath($ReportPath)
        $parent = Split-Path -Parent $reportFull
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) { throw 'Report parent folder does not exist.' }
        $script:Entries | Export-Csv -LiteralPath $reportFull -NoTypeInformation -Encoding UTF8
        Write-Host "Report: $reportFull"
    } catch { Write-Warning "Could not export report: $($_.Exception.Message)" }
}
Write-Host "`nFinished. No project directories or agent session files were targeted."
