$ErrorActionPreference = 'Stop'

$script:Passed = 0
$script:Failed = 0
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repositoryRoot 'clean.bat'
$readmePath = Join-Path $repositoryRoot 'README.md'
$workflowPath = Join-Path $repositoryRoot '.github\workflows\ci.yml'

function Test-Case {
    param([Parameter(Mandatory)] [string] $Name, [Parameter(Mandatory)] [scriptblock] $Test)
    try {
        & $Test
        $script:Passed++
        Write-Host "PASS: $Name" -ForegroundColor Green
    }
    catch {
        $script:Failed++
        Write-Host "FAIL: $Name" -ForegroundColor Red
        Write-Host "      $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Assert-True {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Match {
    param([string] $Text, [string] $Pattern, [string] $Message)
    if ($Text -notmatch $Pattern) { throw $Message }
}

Test-Case 'Required repository files exist' {
    Assert-True (Test-Path -LiteralPath $scriptPath -PathType Leaf) 'clean.bat is missing.'
    Assert-True (Test-Path -LiteralPath $readmePath -PathType Leaf) 'README.md is missing.'
    Assert-True (Test-Path -LiteralPath $workflowPath -PathType Leaf) 'The CI workflow is missing.'
}

$batch = Get-Content -Raw -LiteralPath $scriptPath
$readme = Get-Content -Raw -LiteralPath $readmePath
$workflow = Get-Content -Raw -LiteralPath $workflowPath

Test-Case 'Batch execution settings and disk-space reporting remain present' {
    Assert-Match $batch '(?im)^setlocal EnableExtensions EnableDelayedExpansion\s*$' 'Required cmd.exe settings are missing.'
    Assert-Match $batch '(?i)set "BEFORE_FREE=' 'The before-cleanup measurement is missing.'
    Assert-Match $batch '(?i)set "AFTER_FREE=' 'The after-cleanup measurement is missing.'
    Assert-Match $batch '(?i)AFTER_FREE.*BEFORE_FREE|after-\$before' 'Reclaimed space is not calculated from both measurements.'
    Assert-Match $batch '(?i)Cleared:' 'The reclaimed-space result is not displayed.'
}

Test-Case 'Major cleanup categories remain represented' {
    foreach ($heading in @('TEMPORARY FILES', 'WINDOWS SYSTEM CACHES', 'WINDOWS DIAGNOSTICS AND REPORTING', 'GRAPHICS AND SHADER CACHES', 'WEB BROWSER CACHES', 'APPLICATION CACHES', 'DEVELOPER TOOL CACHES', 'WINDOWS MAINTENANCE')) {
        Assert-Match $batch ([regex]::Escape($heading)) "Missing cleanup category: $heading"
    }
}

Test-Case 'Browser cache targets remain represented' {
    foreach ($browserPath in @('Microsoft\Edge', 'Google\Chrome', 'BraveSoftware\Brave-Browser', 'Mozilla\Firefox')) {
        Assert-Match $batch ([regex]::Escape($browserPath)) "Missing browser target: $browserPath"
    }
}

Test-Case 'Developer cache targets remain represented' {
    foreach ($target in @('%APPDATA%\Code', 'dotnet nuget locals http-cache --clear', 'npm cache clean --force', 'python -m pip cache purge')) {
        Assert-Match $batch ([regex]::Escape($target)) "Missing developer cache target: $target"
    }
}

Test-Case 'Optional developer tools are guarded by availability checks' {
    foreach ($tool in @('dotnet', 'npm', 'python')) {
        $guardedCommand = '(?is)where\s+' + [regex]::Escape($tool) + '\s+>nul\s+2>&1\s*\r?\nif not errorlevel 1\s*\('
        Assert-Match $batch $guardedCommand "$tool is invoked without the expected availability guard."
    }
}

Test-Case 'Required environment roots are validated before cleanup' {
    $firstDelete = $batch.IndexOf('del /', [StringComparison]::OrdinalIgnoreCase)
    Assert-True ($firstDelete -gt 0) 'No deletion commands were found.'
    foreach ($variable in @('SystemDrive', 'SystemRoot', 'USERPROFILE', 'LOCALAPPDATA', 'APPDATA', 'ProgramData', 'TEMP')) {
        $guardPosition = $batch.IndexOf("if not defined $variable", [StringComparison]::OrdinalIgnoreCase)
        Assert-True ($guardPosition -ge 0 -and $guardPosition -lt $firstDelete) "$variable is not validated before deletion begins."
    }
}

Test-Case 'Recursive directory removals use quoted, bounded targets' {
    $directoryRemovals = [regex]::Matches($batch, '(?im)^\s*rd\s+/s\s+/q\s+(.+?)(?:\s+2>nul)?\s*$')
    Assert-True ($directoryRemovals.Count -gt 0) 'No recursive directory removals were found.'
    foreach ($match in $directoryRemovals) {
        $target = $match.Groups[1].Value.Trim()
        Assert-True ($target.StartsWith('"') -and $target.EndsWith('"')) "Unquoted recursive removal target: $target"
        Assert-True ($target -notmatch '^"(?:%SystemDrive%|[A-Za-z]:)\\?"$') "Drive-root removal target detected: $target"
        Assert-True ($target -notmatch '^"%USERPROFILE%\\?"$') "User-profile removal target detected: $target"
    }
}

Test-Case 'README describes implemented behavior without stale maintenance claims' {
    foreach ($name in @('Microsoft Edge', 'Google Chrome', 'Brave', 'Firefox', 'Visual Studio Code', 'NuGet', 'npm', 'pip')) {
        Assert-Match $readme ([regex]::Escape($name)) "README no longer documents $name."
    }
    Assert-True ($readme -notmatch '(?i)Running Windows Disk Cleanup|component store') 'README claims an unimplemented Windows maintenance operation.'
    Assert-Match $readme '(?i)static|structural|regression' 'README does not explain the test strategy.'
}

Test-Case 'CI is Windows-only and invokes tests without running cleanup' {
    Assert-Match $workflow '(?m)^name:\s*CI\s*$' 'Workflow name should be CI.'
    Assert-Match $workflow '(?m)^\s*runs-on:\s*windows-latest\s*$' 'CI must use a Windows runner.'
    Assert-Match $workflow '(?i)CleanBatch\.Tests\.ps1' 'CI does not invoke the test suite.'
    Assert-True ($workflow -notmatch '(?im)(?:^|[\\/\s])clean\.bat(?:\s|$)') 'CI must not execute clean.bat.'
    Assert-Match $workflow '(?m)^permissions:\s*\r?\n\s*contents:\s*read\s*$' 'CI permissions should be read-only.'
}

Write-Host "`n$($script:Passed) passed, $($script:Failed) failed."
if ($script:Failed -gt 0) { exit 1 }
