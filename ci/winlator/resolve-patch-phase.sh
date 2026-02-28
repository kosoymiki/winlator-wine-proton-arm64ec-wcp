#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PHASE="${1:-}"
PLAN_FILE="${2:-${ROOT_DIR}/ci/winlator/patch-batch-plan.tsv}"

fail() { printf '[patch-phase][error] %s\n' "$*" >&2; exit 1; }

[[ -n "${PHASE}" ]] || fail "usage: $0 <phase> [plan-file]"
[[ -f "${PLAN_FILE}" ]] || fail "Plan file not found: ${PLAN_FILE}"

found=0
while IFS=$'\t' read -r phase first last note; do
  [[ -n "${phase}" ]] || continue
  [[ "${phase}" == \#* ]] && continue
  if [[ "${phase}" != "${PHASE}" ]]; then
    continue
  fi
  printf 'phase=%s\n' "${phase}"
  printf 'first=%s\n' "${first}"
  printf 'last=%s\n' "${last}"
  printf 'note=%s\n' "${note:-}"
  found=1
  break
done < "${PLAN_FILE}"

(( found == 1 )) || fail "Phase not found: ${PHASE}"
