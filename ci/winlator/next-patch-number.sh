#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCH_DIR="${1:-${ROOT_DIR}/ci/winlator/patches}"
SLUG="${2:-}"

fail() { printf '[next-patch][error] %s\n' "$*" >&2; exit 1; }

[[ -d "${PATCH_DIR}" ]] || fail "Patch dir not found: ${PATCH_DIR}"

mapfile -t patch_names < <(find "${PATCH_DIR}" -maxdepth 1 -type f -name '*.patch' -printf '%f\n' | sort)
(( ${#patch_names[@]} > 0 )) || fail "No patch files found in ${PATCH_DIR}"

last_patch="${patch_names[$((${#patch_names[@]} - 1))]}"
[[ "${last_patch}" =~ ^([0-9]{4})- ]] || fail "Invalid patch filename (missing NNNN- prefix): ${last_patch}"
next_num="$(printf '%04d' "$((10#${BASH_REMATCH[1]} + 1))")"

printf 'next_number=%s\n' "${next_num}"
if [[ -n "${SLUG}" ]]; then
  printf 'suggested_file=%s/%s-%s.patch\n' "${PATCH_DIR}" "${next_num}" "${SLUG}"
else
  printf 'suggested_file=%s/%s-<slug>.patch\n' "${PATCH_DIR}" "${next_num}"
fi
