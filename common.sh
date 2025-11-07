#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
umask 022
die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
warn(){ printf 'WARN: %s\n' "$*" >&2; }
info(){ printf 'INFO: %s\n' "$*" >&2; }
has(){ command -v "$1" >/dev/null 2>&1; }
fsize(){
  if has stat && stat --version >/dev/null 2>&1; then
    stat -c '%s' -- "$1"
  else
    stat -f '%z' -- "$1"
  fi
}
sha256(){
  if has sha256sum; then sha256sum -- "$1" | awk '{print $1}'
  elif has shasum; then shasum -a 256 -- "$1" | awk '{print $1}'
  else die "No sha256 tool found"
  fi
}
read_list(){
  local path="$1"
  [[ -f "$path" ]] || die "list not found: $path"
  cat -- "$path" | tr -d '\r' | sed -e '1s/^\xEF\xBB\xBF//' | awk 'NF && $1 !~ /^#/{print}'
}
build_name_expr(){
  local list="$1" caseflag="$2"
  local out=() pat
  while IFS= read -r pat; do
    [[ -z "$pat" ]] && continue
    if [[ "$caseflag" == "insensitive" ]]; then
      out+=(-o -iname "$pat")
    else
      out+=(-o -name "$pat")
    fi
  done < <(read_list "$list")
  if ((${#out[@]})); then
    printf '%s\0' "${out[@]:1}"
  fi
}
