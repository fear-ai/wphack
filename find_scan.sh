#!/usr/bin/env bash
# find_scan.sh  -- portable replacement avoiding mapfile -d usage
. "$(dirname "$0")/common_wph.sh"
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$SCRIPT_DIR/common.sh"

LISTS=()
TARGETS=()
CASE="sensitive"

usage(){ cat <<EOF
Usage: $0 --list <file> [--list <file> ...] [--case sensitive|insensitive] <targets...>
Note: Each --list is a newline file of filenames (one per line), no inline comments.
EOF
}

# parse args
while (($#)); do
  case "$1" in
    --list) shift; [[ -f "${1:-}" ]] || die "list not found: ${1:-}"; LISTS+=("$1");;
    --list=*) f="${1#*=}"; [[ -f "$f" ]] || die "list not found: $f"; LISTS+=("$f");;
    --case) shift; CASE="${1:-sensitive}";;
    --case=*) CASE="${1#*=}";;
    -h|--help) usage; exit 0;;
    -*) die "unknown option: $1";;
    *) TARGETS+=("$1");;
  esac
  shift
done

((${#LISTS[@]})) || die "No --list provided"
((${#TARGETS[@]})) || TARGETS+=(.)

for list in "${LISTS[@]}"; do
  info "===== LIST: $list ====="
  # build_name_expr returns NUL-delimited '-name' args (or '-iname' if case-insensitive)
  NAME_EXPR=()
  # read NUL-delimited output into array (portable)
  while IFS= read -r -d '' item; do
    NAME_EXPR+=("$item")
  done < <(build_name_expr "$list" "$CASE")

  if ((${#NAME_EXPR[@]} == 0)); then
    warn "Empty list after filtering: $list"
    continue
  fi

  # Now invoke find once per target with the constructed -name/-iname arguments.
  # We want: find "$target" -type f \( -name "a" -o -name "b" ... \) -print
  # NAME_EXPR already contains initial "-o -name ..." components; we'll use it safely.
  for target in "${TARGETS[@]}"; do
    [[ -e "$target" ]] || { warn "target missing: $target"; continue; }
    # Build a find expression: we expect NAME_EXPR like: -name X -o -name Y ...
    # But earlier code used the first element as "-name X" and subsequent "-o -name Y".
    # Our build_name_expr produces that pattern; just expand it.
    # Use eval safely by constructing an array for find args.
    find_args=( "$target" -type f "(" )
    # append the NAME_EXPR contents
    find_args+=( "${NAME_EXPR[@]}" )
    find_args+=( ")" -print )
    # Run find (no eval): note: arrays preserve entries with spaces correctly
    find "${find_args[@]}"
  done
done

