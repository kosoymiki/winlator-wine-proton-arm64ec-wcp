#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCH_DIR="${1:-${ROOT_DIR}/ci/winlator/patches}"
REFLECTIVE_OUT="${2:-${ROOT_DIR}/docs/PATCH_STACK_REFLECTIVE_AUDIT.md}"
RUNTIME_OUT="${3:-${ROOT_DIR}/docs/PATCH_STACK_RUNTIME_CONTRACT_AUDIT.md}"
: "${WLT_REFLECTIVE_AUDIT_STRICT:=0}"

log() { printf '[winlator-audit] %s\n' "$*"; }
fail() { printf '[winlator-audit][error] %s\n' "$*" >&2; exit 1; }

[[ -d "${PATCH_DIR}" ]] || fail "Patch directory not found: ${PATCH_DIR}"
[[ "${WLT_REFLECTIVE_AUDIT_STRICT}" =~ ^[01]$ ]] || fail "WLT_REFLECTIVE_AUDIT_STRICT must be 0 or 1"

strict_args=()
if [[ "${WLT_REFLECTIVE_AUDIT_STRICT}" == "1" ]]; then
  strict_args+=(--strict)
fi

log "Validating patch numbering contract"
bash "${ROOT_DIR}/ci/winlator/validate-patch-sequence.sh" "${PATCH_DIR}"

log "Running reflective overlap audit"
python3 "${ROOT_DIR}/ci/winlator/patch-stack-reflective-audit.py" \
  --patch-dir "${PATCH_DIR}" \
  --output "${REFLECTIVE_OUT}" \
  "${strict_args[@]}"

log "Running runtime contract audit"
python3 "${ROOT_DIR}/ci/winlator/patch-stack-runtime-contract-audit.py" \
  --patch-dir "${PATCH_DIR}" \
  --output "${RUNTIME_OUT}" \
  "${strict_args[@]}"

log "Audit reports updated"
