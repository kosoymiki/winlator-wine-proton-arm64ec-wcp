#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC_DIR="${1:-}"
PATCH_DIR="${2:-${ROOT_DIR}/ci/winlator/patches}"
PLAN_FILE="${3:-${ROOT_DIR}/ci/winlator/patch-batch-plan.tsv}"

: "${WINLATOR_PATCH_BASE_PROFILE:=standard}"
: "${WINLATOR_PATCH_BASE_PHASE:=all}"
: "${WINLATOR_PATCH_BASE_OUT_DIR:=/tmp/winlator-patch-base-$(date +%Y%m%d_%H%M%S)}"
: "${WINLATOR_PATCH_BASE_CONTINUE_ON_FAIL:=0}"
: "${WINLATOR_PATCH_BASE_SANITIZE:=1}"

log() { printf '[patch-base] %s\n' "$*"; }
fail() { printf '[patch-base][error] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
usage: ci/winlator/run-patch-base-cycle.sh <winlator-src-git-dir> [patch-dir] [plan-file]

Runs the Winlator patch base in named contiguous phase windows using the lighter
batch checker.

Environment:
  WINLATOR_PATCH_BASE_PROFILE=standard  standard|wide|single
  WINLATOR_PATCH_BASE_PHASE=all         all or one phase from patch-batch-plan.tsv
  WINLATOR_PATCH_BASE_OUT_DIR=/tmp/...  Output directory for per-phase logs/meta
  WINLATOR_PATCH_BASE_CONTINUE_ON_FAIL=0 Continue to next phase after failure
  WINLATOR_PATCH_BASE_SANITIZE=1         Remove stray .rej/.orig hunks from patch files
EOF
}

[[ -n "${SRC_DIR}" ]] || { usage; exit 1; }
[[ -d "${SRC_DIR}/.git" ]] || fail "Not a git checkout: ${SRC_DIR}"
[[ -d "${PATCH_DIR}" ]] || fail "Patch dir not found: ${PATCH_DIR}"
[[ -f "${PLAN_FILE}" ]] || fail "Plan file not found: ${PLAN_FILE}"
[[ "${WINLATOR_PATCH_BASE_PROFILE}" =~ ^(standard|wide|single)$ ]] || fail "WINLATOR_PATCH_BASE_PROFILE must be standard, wide or single"
[[ "${WINLATOR_PATCH_BASE_CONTINUE_ON_FAIL}" =~ ^[01]$ ]] || fail "WINLATOR_PATCH_BASE_CONTINUE_ON_FAIL must be 0 or 1"
[[ "${WINLATOR_PATCH_BASE_SANITIZE}" =~ ^[01]$ ]] || fail "WINLATOR_PATCH_BASE_SANITIZE must be 0 or 1"

mkdir -p "${WINLATOR_PATCH_BASE_OUT_DIR}"
summary_tsv="${WINLATOR_PATCH_BASE_OUT_DIR}/phase-summary.tsv"
printf 'phase\tfirst\tlast\tprofile\tstatus\tlog\n' > "${summary_tsv}"

if [[ "${WINLATOR_PATCH_BASE_SANITIZE}" == "1" ]]; then
  log "sanitizing patch stack (.rej/.orig cleanup)"
  bash "${ROOT_DIR}/ci/winlator/sanitize-patch-stack.sh" "${PATCH_DIR}"
fi

selected=0
failed=0

while IFS=$'\t' read -r phase first last note; do
  [[ -n "${phase}" ]] || continue
  [[ "${phase}" == \#* ]] && continue
  if [[ "${WINLATOR_PATCH_BASE_PHASE}" != "all" && "${phase}" != "${WINLATOR_PATCH_BASE_PHASE}" ]]; then
    continue
  fi
  selected=$((selected + 1))
  phase_log="${WINLATOR_PATCH_BASE_OUT_DIR}/${phase}.log"
  phase_meta="${WINLATOR_PATCH_BASE_OUT_DIR}/${phase}.meta"

  log "phase ${phase}: ${first}..${last} (${WINLATOR_PATCH_BASE_PROFILE})"
  if WINLATOR_PATCH_BATCH_PROFILE="${WINLATOR_PATCH_BASE_PROFILE}" \
     WINLATOR_PATCH_BATCH_FIRST="${first}" \
     WINLATOR_PATCH_BATCH_LAST="${last}" \
     WINLATOR_PATCH_BATCH_OUT_FILE="${phase_meta}" \
     bash "${ROOT_DIR}/ci/winlator/check-patch-batches.sh" "${SRC_DIR}" "${PATCH_DIR}" \
     > "${phase_log}" 2>&1; then
    printf '%s\t%s\t%s\t%s\tok\t%s\n' "${phase}" "${first}" "${last}" "${WINLATOR_PATCH_BASE_PROFILE}" "${phase_log}" >> "${summary_tsv}"
  else
    failed=$((failed + 1))
    printf '%s\t%s\t%s\t%s\tfailed\t%s\n' "${phase}" "${first}" "${last}" "${WINLATOR_PATCH_BASE_PROFILE}" "${phase_log}" >> "${summary_tsv}"
    if [[ "${WINLATOR_PATCH_BASE_CONTINUE_ON_FAIL}" != "1" ]]; then
      tail -n 80 "${phase_log}" >&2 || true
      fail "phase failed: ${phase} (see ${phase_log})"
    fi
  fi
done < "${PLAN_FILE}"

(( selected > 0 )) || fail "No phases selected for WINLATOR_PATCH_BASE_PHASE=${WINLATOR_PATCH_BASE_PHASE}"

{
  printf 'time_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'profile=%s\n' "${WINLATOR_PATCH_BASE_PROFILE}"
  printf 'phase=%s\n' "${WINLATOR_PATCH_BASE_PHASE}"
  printf 'selected=%s\n' "${selected}"
  printf 'failed=%s\n' "${failed}"
  printf 'plan_file=%s\n' "${PLAN_FILE}"
} > "${WINLATOR_PATCH_BASE_OUT_DIR}/summary.meta"

if (( failed > 0 )); then
  fail "patch-base cycle completed with ${failed} failed phase(s); see ${summary_tsv}"
fi

log "patch-base cycle ready: ${WINLATOR_PATCH_BASE_OUT_DIR}"
