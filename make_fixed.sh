#!/usr/bin/env bash
#
# make_fixed.sh — Build verified file manifests for each directory.
# Compatible with macOS (BSD find, Bash 3.2).
#
# Usage:
#   ./make_fixed.sh --targets dir1 dir2 --outdir fixed [--depth N]
#

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"
. "$SCRIPT_DIR/common_wph.sh"

OUTDIR="fixed"
DEPTH=0
TARGETS=()

usage() {
  cat <<EOF
Usage: $0 [options]
  --targets DIRS...   Directories to scan
  --outdir PATH       Output directory (default: fixed)
  --depth N           Limit find recursion depth (0 = unlimited)
EOF
}

# Parse arguments
while [ "$#" -gt 0 ]; do
  case "$1" in
    --targets)
      shift
      while [ "$#" -gt 0 ] && [ "${1#-}" = "$1" ]; do
        TARGETS+=("$1")
        shift
      done
      ;;
    --outdir) shift; OUTDIR="${1:-fixed}";;
    --outdir=*) OUTDIR="${1#*=}";;
    --depth) shift; DEPTH="${1:-0}";;
    --depth=*) DEPTH="${1#*=}";;
    -h|--help) usage; exit 0;;
    -*) die "Unknown option: $1";;
    *) TARGETS+=("$1");;
  esac
  shift || true
done

[ "${#TARGETS[@]}" -gt 0 ] || die "No targets specified"
mkdir -p -- "$OUTDIR"

for root in "${TARGETS[@]}"; do
  [[ -d "$root" ]] || { warn "skip non-dir: $root"; continue; }
  domain="$(basename "$root")"
  out="$OUTDIR/fixed-$domain.csv"
  echo "filename,relative_path,size,sha256" > "$out"

  # simple string for compatibility (no arrays)
  maxdepth_args=""
  if (( DEPTH > 0 )); then
    maxdepth_args="-maxdepth $DEPTH"
  fi

  (
    cd "$root"
    # BSD find: use eval to insert optional depth argument
    eval "find . $maxdepth_args -type f ! -path './.git/*' -print0" |
      while IFS= read -r -d '' file; do
        rel="${file#./}"
        size=$(fsize "$rel")
        sum=$(sha256 "$rel")
        base="$(basename "$rel")"
        dir="$(dirname "$rel")"
        [[ "$dir" == "." ]] && dir="."
        printf '%s,%s,%s,%s\n' "$base" "$dir" "$size" "$sum"
      done
  ) >> "$out"

  info "wrote $out"
done

info "All manifests generated in: $OUTDIR"
