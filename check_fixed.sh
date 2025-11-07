#!/usr/bin/env bash
. "$(dirname "$0")/common_wph.sh"
set -euo pipefail; IFS=$'\n\t'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"
FIXFILE=""; TARGET=""
usage(){ cat <<EOF
Usage: $0 --file fixed-<domain>.csv --target <dir>
Outputs: CSV status,relative_path,details
EOF
}
while (($#)); do
  case "$1" in
    --file) shift; FIXFILE="${1:-}";;
    --file=*) FIXFILE="${1#*=}";;
    --target) shift; TARGET="${1:-}";;
    --target=*) TARGET="${1#*=}";;
    -h|--help) usage; exit 0;;
    -*) die "unknown option: $1";;
    *) die "unknown arg: $1";;
  esac; shift
done
[[ -f "$FIXFILE" ]] || die "--file missing"
[[ -d "$TARGET" ]] || die "--target missing or not a dir"
echo "status,relative_path,details"
bad=0
tail -n +2 -- "$FIXFILE" | while IFS=, read -r fname rel size hash; do
  rel="${rel%/}"; [[ "$rel" == "" ]] && rel="."
  path="$TARGET/$rel/$fname"
  if [[ ! -f "$path" ]]; then
    echo "MISSING,$rel/$fname,"; bad=1; continue
  fi
  got_size=$(fsize "$path") || got_size=""
  if [[ -n "${size:-}" && "$size" != "$got_size" ]]; then
    echo "SIZE_MISMATCH,$rel/$fname,exp=$size got=$got_size"; bad=1; continue
  fi
  if [[ -n "${hash:-}" ]]; then
    got_hash=$(sha256 "$path")
    if [[ "$hash" != "$got_hash" ]]; then
      echo "HASH_MISMATCH,$rel/$fname,exp=$hash got=$got_hash"; bad=1; continue
    fi
  fi
  echo "OK,$rel/$fname,"
done
exit ${bad:-0}
