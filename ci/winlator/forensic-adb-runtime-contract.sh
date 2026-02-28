#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${WLT_OUT_DIR:=/tmp/winlator-runtime-contract-$(date +%Y%m%d_%H%M%S)}"
: "${WLT_BASELINE_LABEL:=gamenative104}"
: "${WLT_SCENARIOS:=wine11:1 protonwine10:2 gamenative104:3}"
: "${WLT_FAIL_ON_MISMATCH:=0}"
: "${WLT_FAIL_ON_SEVERITY_AT_OR_ABOVE:=off}"
: "${WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE:=off}"

log() { printf '[forensic-runtime] %s\n' "$*"; }
fail() { printf '[forensic-runtime][error] %s\n' "$*" >&2; exit 1; }

command -v adb >/dev/null 2>&1 || fail "adb not found"
command -v python3 >/dev/null 2>&1 || fail "python3 not found"
[[ "${WLT_FAIL_ON_MISMATCH}" =~ ^[01]$ ]] || fail "WLT_FAIL_ON_MISMATCH must be 0 or 1"
[[ "${WLT_FAIL_ON_SEVERITY_AT_OR_ABOVE}" =~ ^(off|info|low|medium|high)$ ]] || \
  fail "WLT_FAIL_ON_SEVERITY_AT_OR_ABOVE must be one of: off, info, low, medium, high"
[[ "${WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE}" =~ ^(off|info|low|medium|high)$ ]] || \
  fail "WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE must be one of: off, info, low, medium, high"

log "Running complete ADB forensic matrix"
log "scenarios=${WLT_SCENARIOS}"
WLT_OUT_DIR="${WLT_OUT_DIR}" \
WLT_SCENARIOS="${WLT_SCENARIOS}" \
  bash "${ROOT_DIR}/ci/winlator/forensic-adb-complete-matrix.sh"

log "Building runtime mismatch matrix"
args=(
  --input "${WLT_OUT_DIR}"
  --baseline-label "${WLT_BASELINE_LABEL}"
  --output-prefix "${WLT_OUT_DIR}/runtime-mismatch-matrix"
)
if [[ "${WLT_FAIL_ON_MISMATCH}" == "1" ]]; then
  args+=(--fail-on-mismatch)
fi
if [[ "${WLT_FAIL_ON_SEVERITY_AT_OR_ABOVE}" != "off" ]]; then
  args+=(--fail-on-severity-at-or-above "${WLT_FAIL_ON_SEVERITY_AT_OR_ABOVE}")
fi
python3 "${ROOT_DIR}/ci/winlator/forensic-runtime-mismatch-matrix.py" \
  "${args[@]}"

log "Building runtime conflict contour matrix"
set +e
python3 "${ROOT_DIR}/ci/winlator/forensic-runtime-conflict-contour.py" \
  --input "${WLT_OUT_DIR}" \
  --baseline-label "${WLT_BASELINE_LABEL}" \
  --output-prefix "${WLT_OUT_DIR}/runtime-conflict-contour" \
  --fail-on-severity-at-or-above "${WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE}"
conflict_rc=$?
set -e
if [[ "${conflict_rc}" -ne 0 ]]; then
  fail "runtime conflict contour threshold reached (rc=${conflict_rc})"
fi

summary_file="${WLT_OUT_DIR}/runtime-mismatch-matrix.summary.txt"
if [[ -f "${summary_file}" ]]; then
  log "Summary:"
  sed 's/^/[forensic-runtime]   /' "${summary_file}"
fi

conflict_summary_file="${WLT_OUT_DIR}/runtime-conflict-contour.summary.txt"
if [[ -f "${conflict_summary_file}" ]]; then
  log "Conflict contour summary:"
  sed 's/^/[forensic-runtime]   /' "${conflict_summary_file}"
fi

json_file="${WLT_OUT_DIR}/runtime-mismatch-matrix.json"
if [[ -f "${json_file}" ]]; then
  log "Actionable drift rows (status|severity|label|patch_hint|mismatch_keys):"
  python3 - "${json_file}" <<'PY'
import json
import sys
from pathlib import Path

rows = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")).get("rows", [])
printed = False
for row in rows:
    if row.get("status") in {"baseline", "ok"}:
        continue
    print(
        "[forensic-runtime]   {status}|{severity}|{label}|{patch_hint}|{mismatch_keys}".format(
            status=row.get("status", "-"),
            severity=row.get("severity", "-"),
            label=row.get("label", "-"),
            patch_hint=row.get("patch_hint", "-"),
            mismatch_keys=row.get("mismatch_keys", "-"),
        )
    )
    printed = True
if not printed:
    print("[forensic-runtime]   none")
PY
fi

conflict_json_file="${WLT_OUT_DIR}/runtime-conflict-contour.json"
if [[ -f "${conflict_json_file}" ]]; then
  log "Actionable conflict rows (status|severity|label|patch_hint|missing_components):"
  python3 - "${conflict_json_file}" <<'PY'
import json
import sys
from pathlib import Path

rows = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8")).get("rows", [])
printed = False
for row in rows:
    if row.get("status") in {"baseline", "ok"}:
        continue
    print(
        "[forensic-runtime]   {status}|{severity}|{label}|{patch_hint}|{missing}".format(
            status=row.get("status", "-"),
            severity=row.get("severity", "-"),
            label=row.get("label", "-"),
            patch_hint=row.get("patch_hint", "-"),
            missing=row.get("logging_missing_components", "-"),
        )
    )
    printed = True
if not printed:
    print("[forensic-runtime]   none")
PY
fi

log "Done: ${WLT_OUT_DIR}"
