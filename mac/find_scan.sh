#!/usr/bin/env bash
# find_scan.sh - find files matching name lists (portable)
set -euo pipefail
IFS=$'\n\t'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/common_wph.sh" ] || { echo "ERROR: common_wph.sh not found in $SCRIPT_DIR" >&2; exit 2; }
. "$SCRIPT_DIR/common_wph.sh"
LISTS=(); TARGETS=(); CASE="$DEFAULT_CASE"; DEBUG=0
usage(){ cat <<'U'; echo "U"; }
Usage: find_scan.sh --list <file> [--list <file>] [--case sensitive|insensitive] [--debug] [targets...]
  --list <file>       file with one filename pattern per line (no inline comments)
  --case sensitive|insensitive   (default: sensitive)
  --debug             print debug info (NAME_EXPR tokens)
  targets...          directories to search (default: .)
U

while (($#)); do
  case "$1" in
    --list) shift; [ $# -gt 0 ] || die "--list requires an argument"; LISTS+=( "$1" ); shift;;
    --list=*) LISTS+=( "${1#*=}" ); shift;;
    --case) shift; [ $# -gt 0 ] || die "--case requires argument"; CASE="$1"; shift;;
    --case=*) CASE="${1#*=}"; shift;;
    --debug) DEBUG=1; shift;;
    -h|--help) usage; exit 0;;
    --) shift; break;;
    -*) die "unknown option: $1";;
    *) TARGETS+=( "$1" ); shift;;
  esac
done
[ ${#TARGETS[@]} -gt 0 ] || TARGETS=(.)
[ ${#LISTS[@]} -gt 0 ] || die "No --list provided; nothing to do."
for list in "${LISTS[@]}"; do
  info "===== LIST: $list ====="
  validate_list_file "$list"
  NAME_EXPR=()
  read_null_array NAME_EXPR < <(build_name_expr "$list" "$CASE")
  if [ ${#NAME_EXPR[@]} -eq 0 ]; then warn "No patterns generated from $list (empty or all commented out)"; continue; fi
  if [ "$DEBUG" -eq 1 ]; then
    info "NAME_EXPR tokens (count=${#NAME_EXPR[@]}):"
    for t in "${NAME_EXPR[@]}"; do printf '  -> [%s]\n' "$t"; done
  fi
  for tgt in "${TARGETS[@]}"; do
    [ -e "$tgt" ] || { warn "target does not exist: $tgt"; continue; }
    find_args=( "$tgt" -type f "(" ); find_args+=( "${NAME_EXPR[@]}" ); find_args+=( ")" -print )
    find "${find_args[@]}"
  done
done
