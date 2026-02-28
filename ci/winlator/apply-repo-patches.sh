#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
WINLATOR_SRC_DIR="${1:-}"
PATCH_DIR="${2:-${ROOT_DIR}/ci/winlator/patches}"
: "${WINLATOR_PATCH_FROM:=}"
: "${WINLATOR_PATCH_TO:=}"

log()  { printf '[winlator-patch] %s\n' "$*"; }
fail() { printf '[winlator-patch][error] %s\n' "$*" >&2; exit 1; }

[[ -n "${WINLATOR_SRC_DIR}" ]] || fail "usage: $0 <winlator-src-dir> [patch-dir]"
[[ -d "${WINLATOR_SRC_DIR}/.git" ]] || fail "Not a git checkout: ${WINLATOR_SRC_DIR}"
[[ -d "${PATCH_DIR}" ]] || fail "Patch directory not found: ${PATCH_DIR}"
[[ -z "${WINLATOR_PATCH_FROM}" || "${WINLATOR_PATCH_FROM}" =~ ^[0-9]{4}$ ]] || fail "WINLATOR_PATCH_FROM must be empty or NNNN"
[[ -z "${WINLATOR_PATCH_TO}" || "${WINLATOR_PATCH_TO}" =~ ^[0-9]{4}$ ]] || fail "WINLATOR_PATCH_TO must be empty or NNNN"

WINLATOR_SRC_DIR="$(cd -- "${WINLATOR_SRC_DIR}" && pwd)"
PATCH_DIR="$(cd -- "${PATCH_DIR}" && pwd)"

if [[ -n "${WINLATOR_PATCH_FROM}" && -n "${WINLATOR_PATCH_TO}" ]]; then
  (( 10#${WINLATOR_PATCH_FROM} <= 10#${WINLATOR_PATCH_TO} )) || fail "WINLATOR_PATCH_FROM must be <= WINLATOR_PATCH_TO"
fi

shopt -s nullglob
patches=("${PATCH_DIR}"/*.patch)
shopt -u nullglob

(( ${#patches[@]} )) || { log "No patches found in ${PATCH_DIR}; skipping"; exit 0; }

filter_patch_window() {
  local selected=()
  local patch name num

  if [[ -z "${WINLATOR_PATCH_FROM}" && -z "${WINLATOR_PATCH_TO}" ]]; then
    return 0
  fi

  for patch in "${patches[@]}"; do
    name="$(basename -- "${patch}")"
    [[ "${name}" =~ ^([0-9]{4})- ]] || fail "Invalid patch filename (missing NNNN- prefix): ${name}"
    num="${BASH_REMATCH[1]}"
    if [[ -n "${WINLATOR_PATCH_FROM}" ]] && (( 10#${num} < 10#${WINLATOR_PATCH_FROM} )); then
      continue
    fi
    if [[ -n "${WINLATOR_PATCH_TO}" ]] && (( 10#${num} > 10#${WINLATOR_PATCH_TO} )); then
      continue
    fi
    selected+=("${patch}")
  done

  patches=("${selected[@]}")
}

filter_patch_window

(( ${#patches[@]} )) || {
  log "No patches matched requested window (${WINLATOR_PATCH_FROM:-start}..${WINLATOR_PATCH_TO:-end}); skipping"
  exit 0
}

if [[ -n "${WINLATOR_PATCH_FROM}" || -n "${WINLATOR_PATCH_TO}" ]]; then
  log "Selected patch window: ${WINLATOR_PATCH_FROM:-start} .. ${WINLATOR_PATCH_TO:-end} (${#patches[@]} patches)"
fi

heal_known_rejects() {
  local patch_name="$1"
  local rejs
  local strings_file strings_rej

  case "${patch_name}" in
    0001-mainline-full-stack-consolidated.patch)
      strings_file="${WINLATOR_SRC_DIR}/app/src/main/res/values/strings.xml"
      strings_rej="${strings_file}.rej"
      mapfile -t rejs < <(find "${WINLATOR_SRC_DIR}" -name '*.rej' -type f | sort)
      [[ "${#rejs[@]}" -eq 1 && "${rejs[0]}" == "${strings_rej}" ]] || return 1

      grep -Fq 'setCompositeRemoteProfiles(' "${WINLATOR_SRC_DIR}/app/src/main/java/com/winlator/cmod/contents/ContentsManager.java" || return 1
      grep -Fq 'DASH_PLACEHOLDER' "${WINLATOR_SRC_DIR}/app/src/main/java/com/winlator/cmod/ContentsFragment.java" || return 1

      python3 - "${strings_file}" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

replacements = [
    (
        r'<string name="get_more_contents_form_github">.*?</string>',
        '<string name="get_more_contents_form_github">Content packages are loaded from WCP Hub, while Wine/Proton packages are provided from Ae.solator releases.</string>',
    ),
    (
        r'<string name="show_beta_releases">.*?</string>',
        '<string name="show_beta_releases">Show beta / nightly builds (WCP Hub content)</string>',
    ),
]

updated = text
for pattern, repl in replacements:
    updated, count = re.subn(pattern, repl, updated, count=1)
    if count != 1:
        raise SystemExit(f"targeted reject-heal failed: pattern not found: {pattern}")

path.write_text(updated, encoding="utf-8")
PY

      rm -f "${strings_rej}"
      git -C "${WINLATOR_SRC_DIR}" add "app/src/main/res/values/strings.xml"
      log "Applied targeted reject-heal for ${patch_name} (strings.xml drift in contents branding block)"
      return 0
      ;;
  esac

  return 1
}

apply_one() {
  local patch="$1"
  local name; name="$(basename -- "$patch")"

  # If patch already applied, reverse-check succeeds -> skip
  if git -C "$WINLATOR_SRC_DIR" apply --reverse --check --recount --ignore-whitespace "$patch" >/dev/null 2>&1; then
    log "Already applied: $name (skipping)"
    return 0
  fi

  # Try clean apply (3way + stage)
  if git -C "$WINLATOR_SRC_DIR" apply --index --3way --recount --whitespace=nowarn --ignore-whitespace "$patch" >/dev/null 2>&1; then
    log "Applied: $name"
    return 0
  fi

  # Fallback: generate rejects (NO --3way with --reject)
  log "Conflicts, generating *.rej: $name"
  git -C "$WINLATOR_SRC_DIR" apply --recount --reject --whitespace=nowarn --ignore-whitespace "$patch" || true

  if heal_known_rejects "$name"; then
    return 0
  fi

  fail "Failed to apply $name. Show *.rej:\n  find \"$WINLATOR_SRC_DIR\" -name '*.rej' -maxdepth 4 -print -exec sed -n '1,160p' {} \\;"
}

for patch in "${patches[@]}"; do
  log "Applying $(basename -- "$patch")"
  apply_one "$patch"
done

log "All patches applied"
