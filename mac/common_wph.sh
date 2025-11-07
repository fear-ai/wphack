#!/usr/bin/env bash
# common_wph.sh - WordPress-hack specific helpers
_THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$_THIS_DIR/common.sh" ]; then . "$_THIS_DIR/common.sh"; else echo "ERROR: common.sh not found in $_THIS_DIR" >&2; exit 2; fi
read_named_list(){ local outname="$1"; shift; local listfile="$1"; shift; read_list_into_array "$outname" "$listfile"; }
build_name_expr(){
  local listfile="$1"; shift; local caseflag="${1:-$DEFAULT_CASE}"; shift || true
  local __items; read_list_into_array __items "$listfile"
  local out=() pat
  for pat in "${__items[@]}"; do
    if [ "$caseflag" = "insensitive" ]; then out+=( -o -iname "$pat" ); else out+=( -o -name "$pat" ); fi
  done
  ((${#out[@]})) && printf '%s\0' "${out[@]:1}"
}
validate_list_file(){ local f="$1"; [ -f "$f" ] || die "list file not found: $f"; [ -s "$f" ] || warn "list file is empty: $f"; }
show_find_command(){ local target="$1"; shift; local -a args=( "$target" -type f "(" "$@" ")" -print ); printf '%s\n' "${args[@]}"; }

