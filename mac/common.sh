#!/usr/bin/env bash
# common.sh - portable helpers and wrappers for WPH scripts
set -euo pipefail
IFS=$'\n\t'
if [ -z "${BASH_VERSION:-}" ]; then
  echo "FATAL: This script requires bash. Run it with 'bash'." >&2
  exit 2
fi
info(){ printf "INFO: %s\n" "$*" >&2; }
warn(){ printf "WARN: %s\n" "$*" >&2; }
die(){ printf "ERROR: %s\n" "$*" >&2; exit 1; }
ensure_cmd(){ command -v "$1" >/dev/null 2>&1 || die "required command '$1' not found in PATH"; }
safe_md5(){ local f="$1"; if command -v md5sum >/dev/null 2>&1; then md5sum "$f" | awk '{print $1}'; elif command -v md5 >/dev/null 2>&1; then md5 -q "$f"; else echo "(md5 unavailable)"; fi; }
read_list_into_array(){
  local _arrname="$1"; shift; local _file="$1"; shift; local lines=()
  [ -f "$_file" ] || die "list file not found: $_file"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    line="$(printf '%s' "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [ -z "$line" ] && continue
    case "$line" in \#*) continue ;; esac
    lines+=( "$line" )
  done < "$_file"
  eval "$_arrname=(\"\${lines[@]}\")"
}
read_null_array(){ local _arrname="$1"; shift; local -a tmp; while IFS= read -r -d '' item; do tmp+=( "$item" ); done; eval "$_arrname=(\"\${tmp[@]}\")"; }
join_by(){ local IFS="$1"; shift; echo "$*"; }
: "${DEFAULT_CASE:=sensitive}"

