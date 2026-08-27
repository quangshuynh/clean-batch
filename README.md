# Clean Batch

[![CI](https://github.com/quangshuynh/clean-batch/actions/workflows/ci.yml/badge.svg)](https://github.com/quangshuynh/clean-batch/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11%20%7C%20macOS-lightgrey)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Clean Batch is a focused, dependency-free cleanup utility for Windows and macOS. It removes explicit regenerable temporary files, application and browser caches, diagnostic data, and developer-tool caches, then reports the approximate amount of disk space reclaimed.

The implementations remain native to each platform: `clean.bat` for Windows and `clean.sh` for macOS.

## Highlights

- Dependency-free native scripts for Windows and macOS.
- Explicit, reviewable cleanup targets instead of blanket user-data deletion.
- Covers common browser, application, diagnostic, and developer-tool caches.
- Detects optional developer tools before invoking them.
- Continues past locked, missing, or access-restricted files.
- Reports reclaimed space in GB, MB, and bytes.
- macOS includes a `--dry-run` preview and keeps higher-impact cleanup opt-in.

## What It Cleans

| Category | Windows | macOS |
| --- | --- | --- |
| Temporary files | User and system temporary locations | `$TMPDIR` |
| Browsers | Edge, Chrome, Brave, Firefox caches | Edge, Chrome, Brave, Firefox caches |
| Applications | Discord, Spotify, Steam, Epic Games Launcher, Battle.net, VS Code, Visual Studio | Discord, Spotify, Steam, VS Code |
| Developer tools | NuGet HTTP cache, npm cache, pip cache | NuGet HTTP cache, npm cache, pip cache |
| Diagnostics | Windows Error Reporting, crash dumps, minidumps, LiveKernelReports | User DiagnosticReports |
| Graphics / development | DirectX, NVIDIA, AMD, Intel shader caches | Xcode DerivedData and ModuleCache |
| Platform maintenance | Windows Update downloads, Recycle Bin, thumbnails/icons, upgrade logs, CHKDSK recovery files | Homebrew cache, Trash, and Xcode Archives are opt-in |

The scripts target cache contents and known diagnostic locations. They do not intentionally delete browser profiles, bookmarks, saved passwords, source code, installed applications, or normal user documents.

## Requirements

### Windows

- Windows 10 or Windows 11
- PowerShell, included with supported Windows versions, for disk-space measurement
- Administrator privileges recommended; several system locations cannot be fully cleaned without elevation

### macOS

- macOS with Bash and standard command-line utilities
- No administrator privileges required for the default user-scoped cleanup

NuGet, npm, pip, and Homebrew cleanup steps run only when their corresponding tools are available. Homebrew cleanup is opt-in on macOS.

## Usage

### Windows

1. Download or clone this repository.
2. Close browsers, games, launchers, editors, and other applications whose caches may be locked.
3. Review `clean.bat` so you understand the selected cleanup locations.
4. Right-click `clean.bat` and select **Run as administrator**.
5. Review the reclaimed-space summary when cleanup completes.

### macOS

Clone the repository and review the selected targets first. Preview cleanup without deleting anything:

```bash
bash clean.sh --dry-run
```

Run the default cleanup:

```bash
bash clean.sh
```

Include higher-impact optional targets such as Trash, Homebrew cleanup, and Xcode Archives:

```bash
bash clean.sh --include-optional
```

You can combine the flags to preview optional cleanup:

```bash
bash clean.sh --dry-run --include-optional
```

Typical output ends with:

```text
Cleanup completed!
Cleared: 2.35 GB (2,406 MB, 2522873856 bytes)
```

The exact amount varies by system. A negative measurement is clamped to zero.

## Safety and Important Notes

> [!WARNING]
> These scripts perform recursive deletion in explicit temporary, cache, diagnostic, and system locations. Review the implementation before use and keep backups of important data.

- Cleanup roots are validated before deletion begins.
- Recursive removals are bounded to explicit known locations.
- Missing, locked, and inaccessible targets do not stop later cleanup steps.
- Closing affected applications lets the scripts remove more cached files.
- Cache removal can make the next application, browser, game, or development-tool launch slower while data is rebuilt.
- The Windows implementation does not intentionally delete browser profiles, bookmarks, saved passwords, or installed applications.
- The macOS implementation provides `--dry-run` and makes Trash, Homebrew cleanup, and Xcode Archives opt-in via `--include-optional`.

Windows intentionally has no `--dry-run` mode. Accurately simulating every Batch deletion and external cache command would require duplicating or wrapping most operations, adding complexity disproportionate to the small utility. The macOS shell implementation can centralize destructive operations, so it provides a practical preview mode without duplicating the cleanup logic.

## How It Works

Both implementations record free space before cleanup, process platform-appropriate cleanup categories, record free space afterward, and report the non-negative difference.

Windows uses explicit Batch deletion commands and guarded PowerShell/tool invocations. macOS routes filesystem deletion through bounded helper functions that reject `/` and the home directory itself; `--dry-run` prints the selected targets instead of deleting them.

Windows Disk Cleanup (`cleanmgr`) and component-store servicing (`DISM`) are not run. Clean Batch limits itself to the explicit locations and cache commands visible in the scripts.

## Testing

Clean Batch uses structural and safety regression tests rather than performing destructive cleanup in CI.

The Windows PowerShell suite verifies cleanup categories, browser and developer-cache coverage, optional-tool guards, environment-variable guards, bounded and quoted recursive removals, disk-space reporting, README accuracy, and CI configuration.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\CleanBatch.Tests.ps1
```

The macOS Bash suite verifies the Darwin platform guard, cleanup-root validation, dry-run and optional-cleanup support, bounded deletion helpers, browser/developer/Xcode targets, README documentation, and macOS CI coverage.

```bash
bash tests/CleanBatchMac.Tests.sh
```

GitHub Actions runs the Windows suite on `windows-latest` and the macOS suite on `macos-latest`. CI intentionally does **not** execute either cleanup utility. Static checks reduce regression risk but cannot prove that every deletion is safe on every installation; manual review remains important.

## License

Licensed under the [MIT License](LICENSE).
