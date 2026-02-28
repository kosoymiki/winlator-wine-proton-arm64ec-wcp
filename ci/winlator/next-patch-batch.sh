#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCH_DIR="${1:-${ROOT_DIR}/ci/winlator/patches}"

: "${WINLATOR_PATCH_BATCH_PLAN_FILE:=${ROOT_DIR}/ci/winlator/patch-batch-plan.tsv}"
: "${WINLATOR_PATCH_BATCH_PHASE:=}"
: "${WINLATOR_PATCH_BATCH_PROFILE:=standard}"
: "${WINLATOR_PATCH_BATCH_SIZE:=5}"
: "${WINLATOR_PATCH_BATCH_FIRST:=1}"
: "${WINLATOR_PATCH_BATCH_LAST:=0}"
: "${WINLATOR_PATCH_BATCH_CURSOR:=0}"

fail() { printf '[next-patch-batch][error] %s\n' "$*" >&2; exit 1; }

[[ -d "${PATCH_DIR}" ]] || fail "Patch dir not found: ${PATCH_DIR}"
[[ "${WINLATOR_PATCH_BATCH_CURSOR}" =~ ^[0-9]+$ ]] || fail "WINLATOR_PATCH_BATCH_CURSOR must be numeric"

selected_line="$(WINLATOR_PATCH_BATCH_PLAN_FILE="${WINLATOR_PATCH_BATCH_PLAN_FILE}" \
  WINLATOR_PATCH_BATCH_PHASE="${WINLATOR_PATCH_BATCH_PHASE}" \
  WINLATOR_PATCH_BATCH_PROFILE="${WINLATOR_PATCH_BATCH_PROFILE}" \
  WINLATOR_PATCH_BATCH_SIZE="${WINLATOR_PATCH_BATCH_SIZE}" \
  WINLATOR_PATCH_BATCH_FIRST="${WINLATOR_PATCH_BATCH_FIRST}" \
  WINLATOR_PATCH_BATCH_LAST="${WINLATOR_PATCH_BATCH_LAST}" \
  bash "${ROOT_DIR}/ci/winlator/list-patch-batches.sh" "${PATCH_DIR}" | awk -F '\t' -v cursor="${WINLATOR_PATCH_BATCH_CURSOR}" '
    NR == 1 { next }
    ($2 + 0) > cursor { print; exit }
  ')"

[[ -n "${selected_line}" ]] || fail "No next batch found after cursor=${WINLATOR_PATCH_BATCH_CURSOR}"

IFS=$'\t' read -r batch first_idx last_idx first_patch last_patch size <<< "${selected_line}"
printf 'batch=%s\n' "${batch}"
printf 'first_idx=%s\n' "${first_idx}"
printf 'last_idx=%s\n' "${last_idx}"
printf 'first_patch=%s\n' "${first_patch}"
printf 'last_patch=%s\n' "${last_patch}"
printf 'size=%s\n' "${size}"
printf 'cursor_next=%s\n' "${last_idx}"
