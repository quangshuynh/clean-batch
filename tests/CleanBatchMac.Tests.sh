#!/usr/bin/env bash
set -u

passed=0
failed=0
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/clean.sh"
readme="$repo_root/README.md"
workflow="$repo_root/.github/workflows/ci.yml"

check() {
  local name="$1"
  shift
  if "$@"; then
    echo "PASS: $name"
    passed=$((passed + 1))
  else
    echo "FAIL: $name"
    failed=$((failed + 1))
  fi
}

contains() { grep -Eq -- "$2" "$1"; }
not_contains() { ! grep -Eq -- "$2" "$1"; }

check "Required repository files exist" test -f "$script"
check "macOS platform guard is present" contains "$script" 'uname -s.*Darwin'
check "HOME safety guard is present" contains "$script" 'HOME.*safe cleanup root'
check "TMPDIR safety guard is present" contains "$script" 'TMPDIR.*safe cleanup root'
check "Dry-run option is implemented" contains "$script" -- '--dry-run'
check "Optional cleanup flag is implemented" contains "$script" -- '--include-optional'
check "Deletion helper rejects root and HOME" contains "$script" 'target.*!= "/".*target.*!=.*HOME'
check "Bounded deletion uses find with mindepth" contains "$script" 'find .*mindepth 1.*maxdepth 1.*rm -rf'
check "Browser targets are represented" contains "$script" 'Google/Chrome|BraveSoftware/Brave-Browser|Microsoft Edge|Firefox'
check "Developer cache commands are represented" contains "$script" 'npm cache clean --force'
check "pip cache purge is represented" contains "$script" 'pip cache purge'
check "NuGet cache cleanup is represented" contains "$script" 'dotnet nuget locals http-cache --clear'
check "Xcode DerivedData cleanup is represented" contains "$script" 'Xcode/DerivedData'
check "Xcode Archives are optional" contains "$script" 'INCLUDE_OPTIONAL'
check "README documents macOS" contains "$readme" 'macOS'
check "CI uses a macOS runner" contains "$workflow" 'macos-latest'
check "CI invokes macOS static tests" contains "$workflow" 'CleanBatchMac.Tests.sh'
check "CI never invokes clean.sh directly" not_contains "$workflow" 'run:.*clean\.sh'

printf '\n%d passed, %d failed.\n' "$passed" "$failed"
(( failed == 0 ))
