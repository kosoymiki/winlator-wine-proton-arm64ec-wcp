#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${WLT_PATCH_BASE_CONTRACT_OUT_DIR:=/tmp/patch-base-contract-$(date +%Y%m%d_%H%M%S)}"
: "${WLT_PATCH_BASE_CONTRACT_SOURCE_DIRS:=${ROOT_DIR}/work/winlator-ludashi/src,/tmp/winlator-ludashi-src}"
: "${WLT_PATCH_BASE_CONTRACT_REQUIRED:=0}"
: "${WLT_PATCH_BASE_CONTRACT_PROFILE:=standard}"
: "${WLT_PATCH_BASE_CONTRACT_PHASE:=all}"
: "${WLT_PATCH_BASE_CONTRACT_CONTINUE_ON_FAIL:=0}"
: "${WLT_PATCH_BASE_CONTRACT_SANITIZE:=1}"
: "${WLT_PATCH_BASE_CONTRACT_PATCH_DIR:=${ROOT_DIR}/ci/winlator/patches}"
: "${WLT_PATCH_BASE_CONTRACT_PLAN_FILE:=${ROOT_DIR}/ci/winlator/patch-batch-plan.tsv}"

log() { printf '[patch-base-contract] %s\n' "$*" >&2; }
fail() { printf '[patch-base-contract][error] %s\n' "$*" >&2; exit 1; }

[[ "${WLT_PATCH_BASE_CONTRACT_REQUIRED}" =~ ^[01]$ ]] || fail "WLT_PATCH_BASE_CONTRACT_REQUIRED must be 0 or 1"
[[ "${WLT_PATCH_BASE_CONTRACT_PROFILE}" =~ ^(standard|wide|single)$ ]] || fail "WLT_PATCH_BASE_CONTRACT_PROFILE must be standard, wide or single"
[[ "${WLT_PATCH_BASE_CONTRACT_CONTINUE_ON_FAIL}" =~ ^[01]$ ]] || fail "WLT_PATCH_BASE_CONTRACT_CONTINUE_ON_FAIL must be 0 or 1"
[[ "${WLT_PATCH_BASE_CONTRACT_SANITIZE}" =~ ^[01]$ ]] || fail "WLT_PATCH_BASE_CONTRACT_SANITIZE must be 0 or 1"
[[ -d "${WLT_PATCH_BASE_CONTRACT_PATCH_DIR}" ]] || fail "Patch dir not found: ${WLT_PATCH_BASE_CONTRACT_PATCH_DIR}"
[[ -f "${WLT_PATCH_BASE_CONTRACT_PLAN_FILE}" ]] || fail "Plan file not found: ${WLT_PATCH_BASE_CONTRACT_PLAN_FILE}"

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "${value}"
}

pick_source_dir() {
  local raw candidate
  IFS=',' read -r -a raw <<< "${WLT_PATCH_BASE_CONTRACT_SOURCE_DIRS}"
  for candidate in "${raw[@]}"; do
    candidate="$(trim "${candidate}")"
    [[ -n "${candidate}" ]] || continue
    if [[ -d "${candidate}/.git" ]]; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done
  return 1
}

run_capture() {
  local name="$1"; shift
  local out="${WLT_PATCH_BASE_CONTRACT_OUT_DIR}/${name}.log"
  log "running ${name}"
  if "$@" > "${out}" 2>&1; then
    log "ok: ${name}"
    printf '0\n'
  else
    local rc=$?
    tail -n 120 "${out}" >&2 || true
    log "failed: ${name} (rc=${rc})"
    printf '%s\n' "${rc}"
  fi
}

mkdir -p "${WLT_PATCH_BASE_CONTRACT_OUT_DIR}"

source_dir=""
if source_dir="$(pick_source_dir)"; then
  source_dir="$(cd -- "${source_dir}" && pwd)"
else
  if [[ "${WLT_PATCH_BASE_CONTRACT_REQUIRED}" == "1" ]]; then
    fail "No source dir with .git found in WLT_PATCH_BASE_CONTRACT_SOURCE_DIRS=${WLT_PATCH_BASE_CONTRACT_SOURCE_DIRS}"
  fi
  {
    printf 'time_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'source_found=0\n'
    printf 'source_dir=\n'
    printf 'required=%s\n' "${WLT_PATCH_BASE_CONTRACT_REQUIRED}"
    printf 'profile=%s\n' "${WLT_PATCH_BASE_CONTRACT_PROFILE}"
    printf 'phase=%s\n' "${WLT_PATCH_BASE_CONTRACT_PHASE}"
    printf 'continue_on_fail=%s\n' "${WLT_PATCH_BASE_CONTRACT_CONTINUE_ON_FAIL}"
    printf 'sanitize=%s\n' "${WLT_PATCH_BASE_CONTRACT_SANITIZE}"
    printf 'patch_dir=%s\n' "${WLT_PATCH_BASE_CONTRACT_PATCH_DIR}"
    printf 'plan_file=%s\n' "${WLT_PATCH_BASE_CONTRACT_PLAN_FILE}"
    printf 'patch_base_cycle_rc=0\n'
    printf 'patch_stack_rc=0\n'
    printf 'skipped=1\n'
  } > "${WLT_PATCH_BASE_CONTRACT_OUT_DIR}/summary.meta"
  log "skip: no local Winlator source checkout found"
  exit 0
fi

patch_base_cycle_rc="$(run_capture patch-base-cycle \
  env \
    WINLATOR_PATCH_BASE_OUT_DIR="${WLT_PATCH_BASE_CONTRACT_OUT_DIR}/patch-base-cycle" \
    WINLATOR_PATCH_BASE_PROFILE="${WLT_PATCH_BASE_CONTRACT_PROFILE}" \
    WINLATOR_PATCH_BASE_PHASE="${WLT_PATCH_BASE_CONTRACT_PHASE}" \
    WINLATOR_PATCH_BASE_CONTINUE_ON_FAIL="${WLT_PATCH_BASE_CONTRACT_CONTINUE_ON_FAIL}" \
    WINLATOR_PATCH_BASE_SANITIZE="${WLT_PATCH_BASE_CONTRACT_SANITIZE}" \
    bash "${ROOT_DIR}/ci/winlator/run-patch-base-cycle.sh" \
      "${source_dir}" \
      "${WLT_PATCH_BASE_CONTRACT_PATCH_DIR}" \
      "${WLT_PATCH_BASE_CONTRACT_PLAN_FILE}")"

patch_stack_rc="$(run_capture patch-stack \
  env \
    WINLATOR_PATCH_SANITIZE="${WLT_PATCH_BASE_CONTRACT_SANITIZE}" \
    bash "${ROOT_DIR}/ci/winlator/check-patch-stack.sh" \
      "${source_dir}" \
      "${WLT_PATCH_BASE_CONTRACT_PATCH_DIR}")"

{
  printf 'time_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'source_found=1\n'
  printf 'source_dir=%s\n' "${source_dir}"
  printf 'source_dirs=%s\n' "${WLT_PATCH_BASE_CONTRACT_SOURCE_DIRS}"
  printf 'required=%s\n' "${WLT_PATCH_BASE_CONTRACT_REQUIRED}"
  printf 'profile=%s\n' "${WLT_PATCH_BASE_CONTRACT_PROFILE}"
  printf 'phase=%s\n' "${WLT_PATCH_BASE_CONTRACT_PHASE}"
  printf 'continue_on_fail=%s\n' "${WLT_PATCH_BASE_CONTRACT_CONTINUE_ON_FAIL}"
  printf 'sanitize=%s\n' "${WLT_PATCH_BASE_CONTRACT_SANITIZE}"
  printf 'patch_dir=%s\n' "${WLT_PATCH_BASE_CONTRACT_PATCH_DIR}"
  printf 'plan_file=%s\n' "${WLT_PATCH_BASE_CONTRACT_PLAN_FILE}"
  printf 'patch_base_cycle_rc=%s\n' "${patch_base_cycle_rc}"
  printf 'patch_stack_rc=%s\n' "${patch_stack_rc}"
  printf 'skipped=0\n'
} > "${WLT_PATCH_BASE_CONTRACT_OUT_DIR}/summary.meta"

if [[ "${patch_base_cycle_rc}" != "0" || "${patch_stack_rc}" != "0" ]]; then
  fail "patch-base contract failed (summary: ${WLT_PATCH_BASE_CONTRACT_OUT_DIR}/summary.meta)"
fi

log "patch-base contract passed: ${WLT_PATCH_BASE_CONTRACT_OUT_DIR}"
