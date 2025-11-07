#!/usr/bin/env bash
. "$(dirname "$0")/common_wph.sh"
# scan_pat.sh - optimized pattern scanner
# - Default: scan *.php files in cwd recursively
# - Patterns file: one pattern (ERE) per line, '#' comments and blanks ignored
# - Usage:
#     ./scan_pat.sh [--pat=pat.txt] [--files=files.txt] [--sep=true|false] [--all]
#
set -euo pipefail

# Defaults
PAT_FILE="pat.txt"
FILES_LIST=""
SEP=false      # false -> combined (fast); true -> per-pattern (detailed)
SCAN_PHP_ONLY=true

# Parse args (simple; explicit)
for arg in "$@"; do
  case "$arg" in
    --pat=*)   PAT_FILE="${arg#*=}" ;;
    --files=*) FILES_LIST="${arg#*=}" ;;
    --sep=*)   SEP="${arg#*=}" ;;
    --all)     SCAN_PHP_ONLY=false ;;
    --php)     SCAN_PHP_ONLY=true ;;
    --help)
      cat <<'USAGE'
scan_pat.sh - optimized pattern scanner

Usage:
  ./scan_pat.sh [--pat=pat.txt] [--files=files.txt] [--sep=true|false] [--all]

Options:
  --pat=FILE     Pattern file (one ERE per line). Defaults to pat.txt
  --files=FILE   File containing newline-separated file paths to scan (optional)
  --sep=true     Run patterns one-by-one and report pattern number with matching file
  --sep=false    Combine all patterns (fast; default)
  --all          Scan all files (default scans only *.php)
  --php          Scan only *.php (default)
  --help         Show this help

Notes:
  - Pattern file lines beginning with '#' or blank lines are ignored.
  - CRLF is stripped; patterns containing literal newline or CR are rejected.
USAGE
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 2
      ;;
  esac
done

# Validate pattern file exists
if [[ ! -f "$PAT_FILE" ]]; then
  echo "Pattern file not found: $PAT_FILE" >&2
  exit 3
fi

# Create a cleaned temporary pattern file (safe)
TMP_PAT=$(mktemp) || exit 4
trap 'rm -f "$TMP_PAT"' EXIT

# Load, normalize, and write cleaned patterns into TMP_PAT:
# - strip CR (\r), trim leading/trailing whitespace
# - ignore blank lines and lines starting with '#'
# - write one pattern per line
sed -e 's/\r$//' "$PAT_FILE" \
  | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
  | grep -vE '^\s*(#|$)' > "$TMP_PAT"

# Verify we actually have patterns
if [[ ! -s "$TMP_PAT" ]]; then
  echo "No patterns (after cleanup) in $PAT_FILE" >&2
  exit 5
fi

# Disallow patterns with embedded newline or CR just to be safe (shouldn't happen now)
while IFS= read -r p || [[ -n "$p" ]]; do
  if [[ "$p" == *$'\n'* || "$p" == *$'\r'* ]]; then
    echo "Invalid pattern contains newline/CR: [$p]" >&2
    exit 6
  fi
done < "$TMP_PAT"

# Build list of target files (null-delimited)
# If FILES_LIST provided, read it (strip blanks)
TARGETS_STDIN=false
TMP_FILES_LIST=""
if [[ -n "$FILES_LIST" ]]; then
  if [[ ! -f "$FILES_LIST" ]]; then
    echo "Files list not found: $FILES_LIST" >&2
    exit 7
  fi
  # create a temp file with null-delimited entries (trim blanks)
  TMP_FILES_LIST=$(mktemp) || exit 8
  trap 'rm -f "$TMP_PAT" "$TMP_FILES_LIST"' EXIT
  # keep exact paths as lines; ignore blank lines
  grep -vE '^\s*$' "$FILES_LIST" | sed -e 's/\r$//' > "$TMP_FILES_LIST"
  TARGETS_STDIN=true
else
  # default: find files in current dir
  if $SCAN_PHP_ONLY; then
    # use find and write to TMP_FILES_LIST as null-delimited
    TMP_FILES_LIST=$(mktemp) || exit 9
    find . -type f -name '*.php' -print0 > "$TMP_FILES_LIST"
    # note: file is null-delimited; marker to consumer below
  else
    TMP_FILES_LIST=$(mktemp) || exit 10
    find . -type f -print0 > "$TMP_FILES_LIST"
  fi
  TARGETS_STDIN=true
fi

# Helper: run grep on a null-delimited file list
# args: (pattern-spec) -> uses xargs -0 to call grep with filenames
run_grep_on_filelist_combined() {
  # uses -f "$TMP_PAT" to read patterns from file (ERE per line)
  # -I treat binary files as non-matching; -l print filenames; -E extended regex
  # Using xargs -0 preserves null-delimited input
  xargs -0 --no-run-if-empty grep -Il --binary-files=without-match -E -f "$TMP_PAT" 2>/dev/null
}

run_grep_on_filelist_singlepat() {
  # args: $1 = single pattern
  local pat="$1"
  xargs -0 --no-run-if-empty grep -Il --binary-files=without-match -E -e "$pat" 2>/dev/null
}

# Now perform the scan
if [[ "$SEP" == "false" ]]; then
  # Combined (fast): use grep -f with the cleaned pattern file
  # If TMP_FILES_LIST is null-delimited (it is), feed through xargs -0
  # Some TMP_FILES_LIST variants may be newline separated (if user-supplied); detect that:
  # We'll detect if the file contains a NUL; if yes, use xargs -0 with read -r -d '' trick.
  if grep -q $'\0' "$TMP_FILES_LIST" 2>/dev/null; then
    # file contains NULs; stream it directly to xargs -0
    # use awk to convert NUL stream into proper xargs input (xargs -0 reads NUL)
    # but it's already NUL-delimited so just cat it
    cat "$TMP_FILES_LIST" | run_grep_on_filelist_combined
  else
    # newline-delimited paths (common for --files); convert to null-delimited safely
    # Use while read to handle spaces in filenames
    # We'll produce null-delimited output into a subprocess
    # shellcheck disable=SC2010
    while IFS= read -r line; do printf '%s\0' "$line"; done < "$TMP_FILES_LIST" | run_grep_on_filelist_combined
  fi
else
  # SEP=true: per-pattern scanning with pattern numbers
  # iterate patterns from TMP_PAT
  idx=0
  while IFS= read -r pat || [[ -n "$pat" ]]; do
    idx=$((idx+1))
    if grep -q $'\0' "$TMP_FILES_LIST" 2>/dev/null; then
      cat "$TMP_FILES_LIST" | run_grep_on_filelist_singlepat "$pat" | sed "s|^|pattern#${idx} |"
    else
      # newline list -> convert
      while IFS= read -r line; do printf '%s\0' "$line"; done < "$TMP_FILES_LIST" | run_grep_on_filelist_singlepat "$pat" | sed "s|^|pattern#${idx} |"
    fi
  done < "$TMP_PAT"
fi

# Clean exit (trap will remove tempfiles)
exit 0

