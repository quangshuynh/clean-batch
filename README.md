# Clean Batch

[![CI](https://github.com/quangshuynh/clean-batch/actions/workflows/ci.yml/badge.svg)](https://github.com/quangshuynh/clean-batch/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=windows&logoColor=white)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Clean Batch is a focused Windows Batch utility that removes regenerable temporary files, application and browser caches, diagnostic data, and developer-tool caches. It measures free space before and after cleanup and reports the approximate amount reclaimed. Some system locations require administrator privileges.

## Highlights

- Remains a single, dependency-free Batch application.
- Covers common Windows, browser, graphics, application, and development caches.
- Detects optional developer tools before invoking them.
- Continues past locked, missing, or access-restricted files.
- Reports reclaimed space in GB, MB, and bytes.

## What It Cleans

| Category | Targets |
| --- | --- |
| Windows | User and system temporary files, Prefetch, Windows Update downloads, Recycle Bin, DNS cache, Delivery Optimization data, thumbnails/icons, internet cache, upgrade logs, and recovered CHKDSK files |
| Diagnostics | Windows Error Reporting data, crash dumps, minidumps, and LiveKernelReports |
| Browsers | Cache, Code Cache, and GPUCache data for Microsoft Edge, Google Chrome, and Brave profiles; Firefox `cache2` and `startupCache` |
| Graphics | DirectX, NVIDIA, AMD, and Intel shader caches |
| Applications | Discord, Spotify, Steam, Epic Games Launcher, Battle.net, Visual Studio Code (VS Code), Visual Studio, and the Helldivers 2 shader cache |
| Developer tools | NuGet HTTP cache, npm cache, and pip cache |

The script targets cache contents and known diagnostic locations. It does not intentionally delete browser profiles, bookmarks, saved passwords, or installed applications.

## Requirements

- Windows 10 or Windows 11
- PowerShell, included with supported Windows versions, for disk-space measurement
- Administrator privileges recommended; several system locations cannot be fully cleaned without elevation

The NuGet, npm, and pip cleanup steps run only when `dotnet`, `npm`, and Python, respectively, are available.

## Usage

1. Download or clone this repository.
2. Close browsers, games, launchers, editors, and other applications whose caches may be locked.
3. Review `clean.bat` so you understand the selected cleanup locations.
4. Right-click `clean.bat` and select **Run as administrator**.
5. Review the reclaimed-space summary when cleanup completes.

Typical output ends with:

```text
Cleanup completed!
Cleared: 2.35 GB (2,406 MB, 2522873856 bytes)
```

The exact amount varies by system. A negative measurement is clamped to zero.

## Safety and Important Notes

> [!WARNING]
> This script performs forced and recursive deletion in explicit temporary, cache, diagnostic, and system locations. Review it before use and keep backups of important data.

- Environment roots used in deletion paths are validated before cleanup begins.
- Paths containing spaces are quoted, and optional command-line tools are availability-checked.
- Most missing-file, locked-file, and access-denied errors are suppressed so one inaccessible target does not stop later cleanup steps.
- Closing affected applications lets the script remove more cached files.
- Cache removal can make the next application or game launch slower while data is rebuilt; shader regeneration may cause temporary stutter.
- The script does not stop services before clearing Windows Update data, so files in use may remain.

There is intentionally no `--dry-run` mode. Accurately simulating every Batch deletion and external cache command would require duplicating or wrapping most operations, adding complexity disproportionate to this small utility. Automated tests therefore use static safety and regression checks and never execute destructive cleanup.

## How It Works

The script records free space on the Windows system drive, processes each cleanup category, records free space again, and formats the non-negative difference through PowerShell. `dotnet`, `npm`, and Python commands are guarded with `where` checks; unavailable tools are skipped.

Windows Disk Cleanup (`cleanmgr`) and component-store servicing (`DISM`) are not run. Clean Batch limits itself to the explicit locations and cache commands visible in `clean.bat`.

## Testing

The dependency-free PowerShell suite performs structural, documentation-consistency, and safety regression checks. It verifies the major cleanup categories, browser and developer-cache coverage, optional-tool guards, environment-variable guards, bounded and quoted recursive removals, disk-space reporting, README accuracy, and CI configuration.

Run it locally from the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\CleanBatch.Tests.ps1
```

GitHub Actions runs the same suite on a Windows runner. CI intentionally does **not** execute `clean.bat` or perform real cleanup. Static checks reduce regression risk but cannot prove that every deletion is safe on every Windows installation; manual review remains important.

## License

Licensed under the [MIT License](LICENSE).
