#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { printf '[runtime-matrix-selftest] %s\n' "$*"; }
fail() { printf '[runtime-matrix-selftest][error] %s\n' "$*" >&2; exit 1; }

tmp_dir="$(mktemp -d /tmp/runtime_mismatch_selftest_XXXXXX)"
cleanup() { rm -rf "${tmp_dir}"; }
trap cleanup EXIT

mk_scenario() {
  local label="$1" cid="$2" saw_submit="$3" saw_terminal="$4" runtime_class="$5" with_exit="$6" mismatch_reason="${7:-}"
  local dir="${tmp_dir}/${label}"
  mkdir -p "${dir}"
  cat > "${dir}/scenario_meta.txt" <<EOF
label=${label}
container_id=${cid}
EOF
  cat > "${dir}/wait-status.txt" <<EOF
trace_id=${label}-trace
elapsed_sec=3
saw_intent=1
saw_submit=${saw_submit}
saw_terminal=${saw_terminal}
EOF
  cat > "${dir}/trace_id.txt" <<EOF
${label}-trace
EOF
  {
    echo 'ROUTE_INTENT_RECEIVED'
    echo 'LAUNCH_EXEC_SUBMIT'
    [[ "${with_exit}" == "1" ]] && echo 'LAUNCH_EXEC_EXIT'
    echo "runtimeClass=${runtime_class}"
    [[ -n "${mismatch_reason}" ]] && echo "runtimeMismatchReason=${mismatch_reason}"
    echo 'WINLATOR_SIGNAL_POLICY=external-only'
    echo 'WINLATOR_SIGNAL_INPUT_ROUTE=shortcut'
    echo 'WINLATOR_SIGNAL_INPUT_LAUNCH_KIND=guest'
    echo 'fex'
    echo 'vulkan'
    echo 'turnip'
    echo 'external'
  } > "${dir}/logcat-filtered.txt"
  : > "${dir}/logcat-full.txt"
  : > "${dir}/forensics-jsonl-tail.txt"
}

mk_scenario "steven104" "3" "1" "1" "bionic-native" "1"
mk_scenario "wine11" "1" "1" "0" "bionic-native" "0"
mk_scenario "protonwine10" "2" "1" "1" "glibc_wrapped" "1"
mk_scenario "guarded" "4" "1" "0" "bionic-native" "0" "runtime_class_guard_failed"

out_prefix="${tmp_dir}/out/runtime-mismatch-matrix"
mkdir -p "$(dirname -- "${out_prefix}")"

if python3 "${ROOT_DIR}/ci/winlator/forensic-runtime-mismatch-matrix.py" \
  --input "${tmp_dir}" \
  --baseline-label steven104 \
  --output-prefix "${out_prefix}" \
  --fail-on-mismatch; then
  fail "expected --fail-on-mismatch to return non-zero"
else
  rc=$?
  [[ "${rc}" == "2" ]] || fail "expected exit code 2 for mismatch, got ${rc}"
fi

if python3 "${ROOT_DIR}/ci/winlator/forensic-runtime-mismatch-matrix.py" \
  --input "${tmp_dir}" \
  --baseline-label steven104 \
  --output-prefix "${out_prefix}" \
  --fail-on-severity-at-or-above medium; then
  fail "expected --fail-on-severity-at-or-above medium to return non-zero"
else
  rc=$?
  [[ "${rc}" == "3" ]] || fail "expected exit code 3 for severity threshold, got ${rc}"
fi

python3 "${ROOT_DIR}/ci/winlator/forensic-runtime-mismatch-matrix.py" \
  --input "${tmp_dir}" \
  --baseline-label steven104 \
  --output-prefix "${out_prefix}" >/dev/null

python3 - "${out_prefix}.json" "${out_prefix}.summary.txt" <<'PY'
import json
import sys
from pathlib import Path

json_path = Path(sys.argv[1])
summary_path = Path(sys.argv[2])

payload = json.loads(json_path.read_text(encoding="utf-8"))
rows = {row["label"]: row for row in payload["rows"]}

assert rows["steven104"]["status"] == "baseline"
assert rows["wine11"]["status"] == "hang_after_submit"
assert rows["wine11"]["severity"] == "high"
assert rows["wine11"]["severity_rank"] == "3"
assert "GuestProgramLauncherComponent.java" in rows["wine11"]["patch_hint"]
assert rows["protonwine10"]["status"] == "runtime_class_mismatch"
assert rows["protonwine10"]["severity"] == "high"
assert rows["protonwine10"]["severity_rank"] == "3"
assert "wcp_common.sh" in rows["protonwine10"]["patch_hint"]
assert rows["guarded"]["status"] == "runtime_guard_blocked"
assert rows["guarded"]["severity"] == "high"
assert rows["guarded"]["severity_rank"] == "3"
assert "XServerDisplayActivity.java" in rows["guarded"]["patch_hint"]

summary = summary_path.read_text(encoding="utf-8")
assert "rows_with_mismatch=3" in summary
assert "status_counts=baseline:1,hang_after_submit:1,runtime_class_mismatch:1,runtime_guard_blocked:1" in summary
PY

log "runtime mismatch matrix selftest passed"
