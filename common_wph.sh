#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then . "${SCRIPT_DIR}/common.sh"; fi
: "${WPH_QUIET:=0}"; : "${WPH_DEBUG:=0}"
log_info() { [[ "${WPH_QUIET}" -eq 0 ]] && printf '[INFO] %s\n' "$*" >&2 || true; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_err()  { printf '[ERROR] %s\n' "$*" >&2; }
die()      { log_err "$*"; exit 1; }
choose_grep() { if command -v rg >/dev/null 2>&1; then echo "rg"; else echo "grep"; fi; }
sha256_file() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$f" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$f" | awk '{print $1}'
  else openssl dgst -sha256 "$f" | awk '{print $2}'; fi
}
file_size() { local f="$1"; if stat --version >/dev/null 2>&1; then stat -c %s "$f"; else stat -f %z "$f"; fi; }
load_lines() { sed '1s/^\xEF\xBB\xBF//' "$1" | tr -d '\r' | awk 'NF && $1 !~ /^#/' ; }
count_lines(){ load_lines "$1" | wc -l | awk '{print $1}' ; }
build_name_expr() {
  local mode="$1"; shift
  local names=()
  if [[ "$mode" == "file" ]]; then
    while IFS= read -r line; do names+=("$line"); done < <(load_lines "$1")
  else names=("$@"); fi
  local first=1
  for n in "${names[@]}"; do
    [[ -z "$n" ]] && continue
    if [[ $first -eq 1 ]]; then printf -- "-name %q " "$n"; first=0
    else printf -- "-o -name %q " "$n"; fi
  done
}
