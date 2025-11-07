#!/usr/bin/env bash
. "$(dirname "$0")/common_wph.sh"
set -euo pipefail; IFS=$'\n\t'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"
HACKER_LIST="${HACKER_LIST:-$SCRIPT_DIR/hacker}"
VAR_LIST="${VAR_LIST:-$SCRIPT_DIR/var}"
PAT_FILE="${PAT_FILE:-$SCRIPT_DIR/pat.txt}"
FIX_DIR="${FIX_DIR:-$SCRIPT_DIR/fixed}"
usage(){ cat <<EOF
Usage: $0 [--hacker FILE] [--var FILE] [--pat FILE] [--fixdir DIR] <targets...>
Runs filename scan (hacker,var) → pattern scan (php) → integrity check (if fixed-<domain>.csv exists in fixdir).
EOF
}
TARGETS=()
while (($#)); do
  case "$1" in
    --hacker) shift; HACKER_LIST="${1:-}";;
    --hacker=*) HACKER_LIST="${1#*=}";;
    --var) shift; VAR_LIST="${1:-}";;
    --var=*) VAR_LIST="${1#*=}";;
    --pat) shift; PAT_FILE="${1:-}";;
    --pat=*) PAT_FILE="${1#*=}";;
    --fixdir) shift; FIX_DIR="${1:-}";;
    --fixdir=*) FIX_DIR="${1#*=}";;
    -h|--help) usage; exit 0;;
    -*) die "unknown option: $1";;
    *) TARGETS+=("$1");;
  esac; shift
done
((${#TARGETS[@]})) || { usage; exit 2; }
[[ -x "$SCRIPT_DIR/find_scan.sh" ]] || die "find_scan.sh missing"
[[ -x "$SCRIPT_DIR/scan_pat.sh"  ]] || die "scan_pat.sh missing"
[[ -x "$SCRIPT_DIR/check_fixed.sh" ]] || die "check_fixed.sh missing"
if [[ -f "$HACKER_LIST" ]]; then "$SCRIPT_DIR/find_scan.sh" --list "$HACKER_LIST" "${TARGETS[@]}" || true; else warn "skip hacker list: $HACKER_LIST"; fi
if [[ -f "$VAR_LIST"    ]]; then "$SCRIPT_DIR/find_scan.sh" --list "$VAR_LIST"    "${TARGETS[@]}" || true; else warn "skip var list: $VAR_LIST"; fi
if [[ -f "$PAT_FILE"    ]]; then "$SCRIPT_DIR/scan_pat.sh"  --pat "$PAT_FILE" --php "${TARGETS[@]}" || true; else warn "skip patterns: $PAT_FILE"; fi
mkdir -p -- "$FIX_DIR"
for t in "${TARGETS[@]}"; do
  dom="$(basename "$t")"
  csv="$FIX_DIR/fixed-$dom.csv"
  if [[ -f "$csv" ]]; then
    "$SCRIPT_DIR/check_fixed.sh" --file "$csv" --target "$t" || true
  else
    warn "no baseline: $csv"
  fi
done
