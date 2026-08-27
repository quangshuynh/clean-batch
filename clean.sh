#!/usr/bin/env bash
set -u

# Clean Batch macOS implementation.
# Removes only explicit, regenerable cache/temp/diagnostic targets.
# Use --dry-run to preview. Use --include-optional for Trash, Homebrew cache,
# and Xcode Archives.

DRY_RUN=0
INCLUDE_OPTIONAL=0

usage() {
  cat <<'EOF'
Usage: ./clean.sh [--dry-run] [--include-optional] [--help]

  --dry-run           Print cleanup actions without deleting anything.
  --include-optional  Also clean Trash, Homebrew download cache, and Xcode Archives.
  --help              Show this help text.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --include-optional) INCLUDE_OPTIONAL=1 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "ERROR: Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: clean.sh supports macOS only." >&2
  exit 1
fi

if [[ -z "${HOME:-}" || "$HOME" == "/" ]]; then
  echo "ERROR: HOME is not a safe cleanup root." >&2
  exit 1
fi

if [[ -z "${TMPDIR:-}" || "$TMPDIR" == "/" ]]; then
  echo "ERROR: TMPDIR is not a safe cleanup root." >&2
  exit 1
fi

free_bytes() {
  df -k "$HOME" | awk 'NR==2 {print $4 * 1024}'
}

BEFORE_FREE="$(free_bytes)"

safe_remove_contents() {
  local target="$1"

  [[ -n "$target" ]] || return 0
  [[ "$target" != "/" && "$target" != "$HOME" ]] || {
    echo "Refusing unsafe cleanup target: $target" >&2
    return 1
  }
  [[ "$target" == "$HOME"/* || "$target" == "$TMPDIR"* ]] || {
    echo "Refusing cleanup target outside approved roots: $target" >&2
    return 1
  }
  [[ -d "$target" ]] || return 0

  if (( DRY_RUN )); then
    echo "Would clean: $target"
    return 0
  fi

  echo "Cleaning: $target"
  find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true
}

safe_remove_dir() {
  local target="$1"

  [[ -n "$target" ]] || return 0
  [[ "$target" != "/" && "$target" != "$HOME" ]] || {
    echo "Refusing unsafe cleanup target: $target" >&2
    return 1
  }
  [[ "$target" == "$HOME"/* || "$target" == "$TMPDIR"* ]] || {
    echo "Refusing cleanup target outside approved roots: $target" >&2
    return 1
  }
  [[ -e "$target" ]] || return 0

  if (( DRY_RUN )); then
    echo "Would remove: $target"
  else
    echo "Removing: $target"
    rm -rf -- "$target" 2>/dev/null || true
  fi
}

run_cache_command() {
  local tool="$1"
  shift
  command -v "$tool" >/dev/null 2>&1 || return 0
  if (( DRY_RUN )); then
    printf 'Would run:'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@" >/dev/null 2>&1 || true
  fi
}

echo "Cleaning temporary files..."
safe_remove_contents "$TMPDIR"

echo "Cleaning browser caches..."
for root in \
  "$HOME/Library/Caches/Google/Chrome" \
  "$HOME/Library/Caches/BraveSoftware/Brave-Browser" \
  "$HOME/Library/Caches/Microsoft Edge" \
  "$HOME/Library/Caches/Firefox"; do
  safe_remove_contents "$root"
done

# Chromium browsers also keep per-profile regenerable cache directories under
# Application Support. Preserve profiles and remove only named cache folders.
for user_data in \
  "$HOME/Library/Application Support/Google/Chrome" \
  "$HOME/Library/Application Support/BraveSoftware/Brave-Browser" \
  "$HOME/Library/Application Support/Microsoft Edge"; do
  [[ -d "$user_data" ]] || continue
  while IFS= read -r -d '' profile; do
    safe_remove_dir "$profile/Cache"
    safe_remove_dir "$profile/Code Cache"
    safe_remove_dir "$profile/GPUCache"
  done < <(find "$user_data" -maxdepth 1 -type d \( -name Default -o -name 'Profile *' \) -print0 2>/dev/null)
done

# Firefox cache2 lives outside the profile data directory on current macOS installs.
if [[ -d "$HOME/Library/Caches/Firefox/Profiles" ]]; then
  while IFS= read -r -d '' profile; do
    safe_remove_dir "$profile/cache2"
    safe_remove_dir "$profile/startupCache"
  done < <(find "$HOME/Library/Caches/Firefox/Profiles" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
fi

echo "Cleaning application caches..."
for target in \
  "$HOME/Library/Caches/com.hnc.Discord" \
  "$HOME/Library/Application Support/discord/Cache" \
  "$HOME/Library/Application Support/discord/Code Cache" \
  "$HOME/Library/Application Support/discord/GPUCache" \
  "$HOME/Library/Caches/com.spotify.client" \
  "$HOME/Library/Application Support/Spotify/PersistentCache" \
  "$HOME/Library/Application Support/Steam/htmlcache" \
  "$HOME/Library/Application Support/Code/Cache" \
  "$HOME/Library/Application Support/Code/CachedData" \
  "$HOME/Library/Application Support/Code/Code Cache" \
  "$HOME/Library/Application Support/Code/GPUCache" \
  "$HOME/Library/Application Support/Code/logs"; do
  safe_remove_contents "$target"
done

echo "Cleaning developer-tool caches..."
run_cache_command npm npm cache clean --force
if command -v python3 >/dev/null 2>&1; then
  run_cache_command python3 python3 -m pip cache purge
elif command -v python >/dev/null 2>&1; then
  run_cache_command python python -m pip cache purge
fi
run_cache_command dotnet dotnet nuget locals http-cache --clear

echo "Cleaning Xcode caches..."
safe_remove_contents "$HOME/Library/Developer/Xcode/DerivedData"
safe_remove_contents "$HOME/Library/Developer/Xcode/ModuleCache.noindex"

echo "Cleaning user diagnostics..."
safe_remove_contents "$HOME/Library/DiagnosticReports"

if (( INCLUDE_OPTIONAL )); then
  echo "Cleaning optional targets..."
  safe_remove_contents "$HOME/.Trash"
  safe_remove_contents "$HOME/Library/Developer/Xcode/Archives"

  if command -v brew >/dev/null 2>&1; then
    if (( DRY_RUN )); then
      echo "Would clean Homebrew download cache."
    else
      brew cleanup --prune=all >/dev/null 2>&1 || true
    fi
  fi
fi

AFTER_FREE="$(free_bytes)"
DELTA=$(( AFTER_FREE - BEFORE_FREE ))
(( DELTA < 0 )) && DELTA=0

awk -v bytes="$DELTA" 'BEGIN {
  printf "\nCleanup completed!\n"
  printf "Cleared: %.2f GB (%.0f MB, %.0f bytes)\n", bytes / 1073741824, bytes / 1048576, bytes
}'

if (( DRY_RUN )); then
  echo "Dry run only; no files were intentionally removed."
fi
