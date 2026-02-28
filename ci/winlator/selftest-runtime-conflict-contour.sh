#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { printf '[runtime-conflict-selftest] %s\n' "$*"; }
fail() { printf '[runtime-conflict-selftest][error] %s\n' "$*" >&2; exit 1; }

tmp_dir="$(mktemp -d /tmp/runtime_conflict_selftest_XXXXXX)"
cleanup() { rm -rf "${tmp_dir}"; }
trap cleanup EXIT

mk_scenario() {
  local label="$1" cid="$2" coverage="$3" conflicts="${4:-none}" conflict_events="${5:-0}"
  local dir="${tmp_dir}/${label}"
  mkdir -p "${dir}"
  cat > "${dir}/scenario_meta.txt" <<EOF
label=${label}
container_id=${cid}
EOF
  cat > "${dir}/wait-status.txt" <<EOF
trace_id=${label}-trace
elapsed_sec=2
EOF
  cat > "${dir}/trace_id.txt" <<EOF
${label}-trace
EOF
  cat > "${dir}/logcat-filtered.txt" <<EOF
AERO_RUNTIME_SUBSYSTEMS_SHA256=11111111111111111111111111111111
AERO_LIBRARY_COMPONENT_STREAM_SHA256=22222222222222222222222222222222
AERO_RUNTIME_LOGGING_MODE=strict
AERO_RUNTIME_LOGGING_REQUIRED=x11,turnip,dxvk,vkd3d,ddraw,layout,translator,loader
AERO_RUNTIME_LOGGING_COVERAGE=${coverage}
AERO_RUNTIME_LOGGING_COVERAGE_SHA256=33333333333333333333333333333333
AERO_RUNTIME_DISTRIBUTION=ae.solator
AERO_LIBRARY_CONFLICTS=${conflicts}
RUNTIME_SUBSYSTEM_SNAPSHOT
RUNTIME_LOGGING_CONTRACT_SNAPSHOT
RUNTIME_LIBRARY_COMPONENT_SIGNAL
EOF
  if [[ "${conflict_events}" != "0" ]]; then
    printf '%s\n' "RUNTIME_LIBRARY_CONFLICT_DETECTED" >> "${dir}/logcat-filtered.txt"
  fi
  : > "${dir}/logcat-full.txt"
  : > "${dir}/forensics-jsonl-tail.txt"
  : > "${dir}/logcat-runtime-conflict-contour.txt"
}

mk_scenario "gamenative104" "4" "x11=1;turnip=1;dxvk=1;vkd3d=1;ddraw=1;layout=1;translator=1;loader=1"
mk_scenario "dxvk-gap" "1" "x11=1;turnip=1;dxvk=0;vkd3d=1;ddraw=1;layout=1;translator=1;loader=1"
mk_scenario "vkd3d-gap" "2" "x11=1;turnip=1;dxvk=1;vkd3d=0;ddraw=1;layout=1;translator=1;loader=1"
mk_scenario "ddraw-gap" "3" "x11=1;turnip=1;dxvk=1;vkd3d=1;ddraw=0;layout=1;translator=1;loader=1"
mk_scenario "multi-gap" "5" "x11=1;turnip=1;dxvk=0;vkd3d=0;ddraw=1;layout=1;translator=1;loader=1"
mk_scenario "signature-gap" "6" "x11=1;turnip=1;dxvk=1;vkd3d=1;ddraw=1;layout=1;translator=1;loader=1" "dxvk_artifact_source_unset" "1"

out_prefix="${tmp_dir}/out/runtime-conflict-contour"
mkdir -p "$(dirname -- "${out_prefix}")"

if python3 "${ROOT_DIR}/ci/winlator/forensic-runtime-conflict-contour.py" \
  --input "${tmp_dir}" \
  --baseline-label gamenative104 \
  --output-prefix "${out_prefix}" \
  --fail-on-severity-at-or-above high; then
  fail "expected --fail-on-severity-at-or-above high to return non-zero"
else
  rc=$?
  [[ "${rc}" == "3" ]] || fail "expected exit code 3 for severity threshold, got ${rc}"
fi

python3 "${ROOT_DIR}/ci/winlator/forensic-runtime-conflict-contour.py" \
  --input "${tmp_dir}" \
  --baseline-label gamenative104 \
  --output-prefix "${out_prefix}" >/dev/null

python3 - "${out_prefix}.json" "${out_prefix}.summary.txt" <<'PY'
import json
import sys
from pathlib import Path

json_path = Path(sys.argv[1])
summary_path = Path(sys.argv[2])

payload = json.loads(json_path.read_text(encoding="utf-8"))
rows = {row["label"]: row for row in payload["rows"]}

assert rows["gamenative104"]["status"] == "baseline"
assert rows["gamenative104"]["severity"] == "info"

assert rows["dxvk-gap"]["status"] == "wrapper_dxvk_missing"
assert rows["dxvk-gap"]["severity"] == "high"
assert rows["dxvk-gap"]["severity_rank"] == "3"

assert rows["vkd3d-gap"]["status"] == "wrapper_vkd3d_missing"
assert rows["vkd3d-gap"]["severity"] == "high"
assert rows["vkd3d-gap"]["severity_rank"] == "3"

assert rows["ddraw-gap"]["status"] == "wrapper_ddraw_missing"
assert rows["ddraw-gap"]["severity"] == "high"
assert rows["ddraw-gap"]["severity_rank"] == "3"

assert rows["multi-gap"]["status"] == "wrapper_multi_missing"
assert rows["multi-gap"]["severity"] == "high"
assert rows["multi-gap"]["severity_rank"] == "3"
assert rows["signature-gap"]["status"] == "component_conflict_dxvk_artifact_source_unset"
assert rows["signature-gap"]["severity"] == "high"
assert rows["signature-gap"]["severity_rank"] == "3"
assert rows["signature-gap"]["recommended_focus"] == "dxvk-artifact-source"
assert "wcp_common.sh" in rows["signature-gap"]["patch_hint"]
assert rows["signature-gap"]["library_conflicts"] == "dxvk_artifact_source_unset"
assert rows["signature-gap"]["library_conflict_signatures"] == "dxvk_artifact_source_unset"
assert rows["signature-gap"]["library_conflict_signature_count"] == "1"

summary = summary_path.read_text(encoding="utf-8")
assert "status_counts=baseline:1,component_conflict_dxvk_artifact_source_unset:1,wrapper_ddraw_missing:1,wrapper_dxvk_missing:1,wrapper_multi_missing:1,wrapper_vkd3d_missing:1" in summary
assert "severity_counts=high:5,info:1" in summary
PY

log "runtime conflict contour selftest passed"
