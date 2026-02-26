#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCH_DIR="${1:-${ROOT_DIR}/ci/winlator/patches}"
REFLECTIVE_OUT="${2:-${ROOT_DIR}/docs/PATCH_STACK_REFLECTIVE_AUDIT.md}"
RUNTIME_OUT="${3:-${ROOT_DIR}/docs/PATCH_STACK_RUNTIME_CONTRACT_AUDIT.md}"

log() { printf '[winlator-audit] %s\n' "$*"; }
fail() { printf '[winlator-audit][error] %s\n' "$*" >&2; exit 1; }

[[ -d "${PATCH_DIR}" ]] || fail "Patch directory not found: ${PATCH_DIR}"

log "Validating patch numbering contract"
bash "${ROOT_DIR}/ci/winlator/validate-patch-sequence.sh" "${PATCH_DIR}"

log "Running reflective overlap audit"
python3 "${ROOT_DIR}/ci/winlator/patch-stack-reflective-audit.py" \
  --patch-dir "${PATCH_DIR}" \
  --output "${REFLECTIVE_OUT}" \
  --strict

log "Running runtime contract audit"
python3 "${ROOT_DIR}/ci/winlator/patch-stack-runtime-contract-audit.py" \
  --patch-dir "${PATCH_DIR}" \
  --output "${RUNTIME_OUT}" \
  --strict

log "Audit reports updated"
