#!/usr/bin/env bash
set -euo pipefail

PATCH_DIR="${1:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/patches" && pwd)}"

log() { printf '[patch-seq] %s\n' "$*"; }
fail() { printf '[patch-seq][error] %s\n' "$*" >&2; exit 1; }

[[ -d "${PATCH_DIR}" ]] || fail "Patch directory not found: ${PATCH_DIR}"

mapfile -t patch_names < <(find "${PATCH_DIR}" -maxdepth 1 -type f -name '*.patch' -printf '%f\n' | sort)
(( ${#patch_names[@]} > 0 )) || fail "No patch files found in ${PATCH_DIR}"
first_patch="${patch_names[0]}"
last_patch="${patch_names[$((${#patch_names[@]} - 1))]}"

expected=""
for idx in "${!patch_names[@]}"; do
  name="${patch_names[$idx]}"
  if [[ ! "${name}" =~ ^([0-9]{4})- ]]; then
    fail "Invalid patch filename (missing NNNN- prefix): ${name}"
  fi
  num="${BASH_REMATCH[1]}"
  if [[ -z "${expected}" ]]; then
    expected="${num}"
  fi
  if [[ "${num}" != "${expected}" ]]; then
    fail "Patch numbering gap or disorder: expected ${expected}-*.patch, got ${name}"
  fi
  expected="$(printf '%04d' "$((10#${expected} + 1))")"
done

log "Patch numbering is contiguous (${first_patch} .. ${last_patch})"
