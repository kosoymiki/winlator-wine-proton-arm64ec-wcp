#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PLAN_FILE="${1:-${ROOT_DIR}/ci/winlator/patch-batch-plan.tsv}"

fail() { printf '[patch-phase-list][error] %s\n' "$*" >&2; exit 1; }

[[ -f "${PLAN_FILE}" ]] || fail "Plan file not found: ${PLAN_FILE}"

printf 'phase\tfirst\tlast\tnote\n'
while IFS=$'\t' read -r phase first last note; do
  [[ -n "${phase}" ]] || continue
  [[ "${phase}" == \#* ]] && continue
  printf '%s\t%s\t%s\t%s\n' "${phase}" "${first}" "${last}" "${note:-}"
done < "${PLAN_FILE}"
