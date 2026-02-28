#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${WLT_PACKAGE:=by.aero.so.benchmark}"
: "${WLT_OUT_DIR:=/tmp/winlator-harvard-suite-$(date +%Y%m%d_%H%M%S)}"
: "${WLT_SCENARIO_MATRIX:=wine11:1 protonwine10:2 protonge10:3 gamenative104:4}"
: "${WLT_BASELINE_LABEL:=gamenative104}"
: "${WLT_BUNDLE_MODE:=per_scenario}"
: "${WLT_FAIL_ON_MISMATCH:=0}"
: "${WLT_FAIL_ON_SEVERITY_AT_OR_ABOVE:=medium}"
: "${WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE:=off}"
: "${WLT_RUN_SEED:=0}"
: "${WLT_RUN_ARTIFACT_REFRESH:=0}"
: "${WLT_SEED_CONTAINER_ID:=1}"
: "${WLT_TARGET_CONTAINERS:=2 3 4}"
: "${WLT_CONTAINER_PROFILE_MAP:=}"
: "${WLT_ARTIFACT_KEYS:=wine11 protonwine10 protonge10 gamenative104}"
: "${WLT_CAPTURE_DUMPSYS:=1}"
: "${WLT_CAPTURE_PSI:=1}"
: "${WLT_CAPTURE_PREFS:=1}"
: "${WLT_CAPTURE_UI:=1}"
: "${WLT_CAPTURE_RUNTIME_CONTENTS:=1}"
: "${WLT_CAPTURE_NETWORK_DIAG:=1}"

log() { printf '[forensic-harvard] %s\n' "$*"; }
fail() { printf '[forensic-harvard][error] %s\n' "$*" >&2; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"; }

pick_serial() {
  local serial
  serial="${ADB_SERIAL:-}"
  if [[ -n "${serial}" ]]; then
    printf '%s\n' "${serial}"
    return 0
  fi
  adb devices | awk 'NR>1 && $2=="device" {print $1; exit}'
}

adb_s() { adb -s "${ADB_SERIAL_PICKED}" "$@"; }

sanitize_label() {
  local raw="$1"
  local safe
  safe="$(printf '%s' "${raw}" | tr -cs '[:alnum:]._:-' '_' | tr ':' '_')"
  safe="${safe##_}"
  safe="${safe%%_}"
  [[ -n "${safe}" ]] || safe="scenario"
  printf '%s\n' "${safe}"
}

extract_meta_field() {
  local file="$1"
  local key="$2"
  awk -F= -v k="${key}" '$1==k {print substr($0, index($0,$2)); exit}' "${file}" 2>/dev/null || true
}

collect_extra_scenario_artifacts() {
  local scenario_dir="$1"

  if [[ "${WLT_CAPTURE_DUMPSYS}" == "1" ]]; then
    adb_s shell dumpsys activity processes > "${scenario_dir}/dumpsys-activity-processes.txt" 2>/dev/null || true
    adb_s shell dumpsys meminfo "${WLT_PACKAGE}" > "${scenario_dir}/dumpsys-meminfo-package.txt" 2>/dev/null || true
    adb_s shell dumpsys package "${WLT_PACKAGE}" > "${scenario_dir}/dumpsys-package.txt" 2>/dev/null || true
  fi

  if [[ "${WLT_CAPTURE_PSI}" == "1" ]]; then
    adb_s shell cat /proc/pressure/cpu > "${scenario_dir}/psi-cpu.txt" 2>/dev/null || true
    adb_s shell cat /proc/pressure/memory > "${scenario_dir}/psi-memory.txt" 2>/dev/null || true
    adb_s shell cat /proc/pressure/io > "${scenario_dir}/psi-io.txt" 2>/dev/null || true
  fi

  if [[ "${WLT_CAPTURE_PREFS}" == "1" ]]; then
    adb_s shell "run-as ${WLT_PACKAGE} sh -c 'for f in ./shared_prefs/*.xml; do [ -f \"\$f\" ] || continue; echo ===== \$f =====; cat \"\$f\"; echo; done'" \
      > "${scenario_dir}/shared-prefs-extra.xml" 2>/dev/null || true
  fi

  if [[ "${WLT_CAPTURE_UI}" == "1" && ! -f "${scenario_dir}/ui.xml" ]]; then
    adb_s shell uiautomator dump /sdcard/winlator_ui.xml >/dev/null 2>&1 || true
    adb_s shell cat /sdcard/winlator_ui.xml > "${scenario_dir}/ui.xml" 2>/dev/null || true
  fi
}

main() {
  local mismatch_rc=0
  local conflict_rc=0
  local scenario_dir label container_id safe_label zip_path

  require_cmd adb
  require_cmd python3
  require_cmd jq
  require_cmd zip

  [[ "${WLT_FAIL_ON_MISMATCH}" =~ ^[01]$ ]] || fail "WLT_FAIL_ON_MISMATCH must be 0 or 1"
  [[ "${WLT_RUN_SEED}" =~ ^[01]$ ]] || fail "WLT_RUN_SEED must be 0 or 1"
  [[ "${WLT_RUN_ARTIFACT_REFRESH}" =~ ^[01]$ ]] || fail "WLT_RUN_ARTIFACT_REFRESH must be 0 or 1"
  [[ "${WLT_CAPTURE_NETWORK_DIAG}" =~ ^[01]$ ]] || fail "WLT_CAPTURE_NETWORK_DIAG must be 0 or 1"
  [[ "${WLT_BUNDLE_MODE}" =~ ^(per_scenario|single|both)$ ]] || fail "WLT_BUNDLE_MODE must be one of: per_scenario, single, both"
  [[ "${WLT_FAIL_ON_SEVERITY_AT_OR_ABOVE}" =~ ^(off|info|low|medium|high)$ ]] || \
    fail "WLT_FAIL_ON_SEVERITY_AT_OR_ABOVE must be one of: off, info, low, medium, high"
  [[ "${WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE}" =~ ^(off|info|low|medium|high)$ ]] || \
    fail "WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE must be one of: off, info, low, medium, high"

  mkdir -p "${WLT_OUT_DIR}"

  ADB_SERIAL_PICKED="$(pick_serial)"
  [[ -n "${ADB_SERIAL_PICKED}" ]] || fail "no active adb device"

  log "device=${ADB_SERIAL_PICKED} package=${WLT_PACKAGE}"
  log "scenarios=${WLT_SCENARIO_MATRIX} baseline=${WLT_BASELINE_LABEL}"

  if [[ "${WLT_RUN_SEED}" == "1" ]]; then
    log "seeding container matrix"
    ADB_SERIAL="${ADB_SERIAL_PICKED}" \
    WLT_PACKAGE="${WLT_PACKAGE}" \
    WLT_SEED_CONTAINER_ID="${WLT_SEED_CONTAINER_ID}" \
    WLT_TARGET_CONTAINERS="${WLT_TARGET_CONTAINERS}" \
    WLT_CONTAINER_PROFILE_MAP="${WLT_CONTAINER_PROFILE_MAP}" \
    WLT_OUT_DIR="${WLT_OUT_DIR}/seed" \
      bash "${ROOT_DIR}/ci/winlator/adb-container-seed-matrix.sh"
  fi

  if [[ "${WLT_RUN_ARTIFACT_REFRESH}" == "1" ]]; then
    log "refreshing latest artifacts"
    ADB_SERIAL="${ADB_SERIAL_PICKED}" \
    WLT_PACKAGE="${WLT_PACKAGE}" \
    WLT_TARGET_KEYS="${WLT_ARTIFACT_KEYS}" \
    WLT_OUT_DIR="${WLT_OUT_DIR}/artifacts" \
      bash "${ROOT_DIR}/ci/winlator/adb-ensure-artifacts-latest.sh"
  fi

  if [[ "${WLT_CAPTURE_NETWORK_DIAG}" == "1" ]]; then
    log "capturing network source diagnostics"
    ADB_SERIAL="${ADB_SERIAL_PICKED}" \
    WLT_PACKAGE="${WLT_PACKAGE}" \
    WLT_OUT_DIR="${WLT_OUT_DIR}/network" \
      bash "${ROOT_DIR}/ci/winlator/adb-network-source-diagnostics.sh" || true
  fi

  log "running complete forensic matrix"
  ADB_SERIAL="${ADB_SERIAL_PICKED}" \
  WLT_PACKAGE="${WLT_PACKAGE}" \
  WLT_SCENARIOS="${WLT_SCENARIO_MATRIX}" \
  WLT_OUT_DIR="${WLT_OUT_DIR}" \
  WLT_CAPTURE_UI="${WLT_CAPTURE_UI}" \
  WLT_CAPTURE_PREFS="${WLT_CAPTURE_PREFS}" \
  WLT_CAPTURE_RUNTIME_CONTENTS="${WLT_CAPTURE_RUNTIME_CONTENTS}" \
    bash "${ROOT_DIR}/ci/winlator/forensic-adb-complete-matrix.sh"

  log "building runtime mismatch matrix"
  set +e
  mismatch_args=(
    --input "${WLT_OUT_DIR}"
    --baseline-label "${WLT_BASELINE_LABEL}"
    --output-prefix "${WLT_OUT_DIR}/runtime-mismatch-matrix"
  )
  if [[ "${WLT_FAIL_ON_MISMATCH}" == "1" ]]; then
    mismatch_args+=(--fail-on-mismatch)
  fi
  if [[ "${WLT_FAIL_ON_SEVERITY_AT_OR_ABOVE}" != "off" ]]; then
    mismatch_args+=(--fail-on-severity-at-or-above "${WLT_FAIL_ON_SEVERITY_AT_OR_ABOVE}")
  fi
  python3 "${ROOT_DIR}/ci/winlator/forensic-runtime-mismatch-matrix.py" "${mismatch_args[@]}"
  mismatch_rc=$?
  set -e

  log "building runtime conflict contour matrix"
  set +e
  python3 "${ROOT_DIR}/ci/winlator/forensic-runtime-conflict-contour.py" \
    --input "${WLT_OUT_DIR}" \
    --baseline-label "${WLT_BASELINE_LABEL}" \
    --output-prefix "${WLT_OUT_DIR}/runtime-conflict-contour" \
    --fail-on-severity-at-or-above "${WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE}"
  conflict_rc=$?
  set -e
  if [[ -f "${WLT_OUT_DIR}/runtime-conflict-contour.summary.txt" ]]; then
    log "runtime conflict contour summary:"
    sed 's/^/[forensic-harvard]   /' "${WLT_OUT_DIR}/runtime-conflict-contour.summary.txt"
  fi

  mkdir -p "${WLT_OUT_DIR}/bundles"
  : > "${WLT_OUT_DIR}/bundles/index.tsv"
  printf 'label\tcontainer_id\tscenario_dir\tzip_path\n' > "${WLT_OUT_DIR}/bundles/index.tsv"

  while IFS= read -r scenario_dir; do
    [[ -d "${scenario_dir}" ]] || continue
    [[ -f "${scenario_dir}/scenario_meta.txt" ]] || continue

    collect_extra_scenario_artifacts "${scenario_dir}"

    if [[ "${WLT_BUNDLE_MODE}" == "per_scenario" || "${WLT_BUNDLE_MODE}" == "both" ]]; then
      label="$(extract_meta_field "${scenario_dir}/scenario_meta.txt" "label")"
      container_id="$(extract_meta_field "${scenario_dir}/scenario_meta.txt" "container_id")"
      safe_label="$(sanitize_label "${label:-$(basename -- "${scenario_dir}")}")"
      zip_path="${WLT_OUT_DIR}/bundles/${safe_label}.zip"
      (cd "${WLT_OUT_DIR}" && zip -qr "${zip_path}" "$(basename -- "${scenario_dir}")")
      printf '%s\t%s\t%s\t%s\n' "${label}" "${container_id}" "$(basename -- "${scenario_dir}")" "${zip_path}" >> "${WLT_OUT_DIR}/bundles/index.tsv"
    fi
  done < <(find "${WLT_OUT_DIR}" -mindepth 1 -maxdepth 1 -type d | sort)

  if [[ "${WLT_BUNDLE_MODE}" == "single" || "${WLT_BUNDLE_MODE}" == "both" ]]; then
    (cd "${WLT_OUT_DIR}" && zip -qr "${WLT_OUT_DIR}/bundles/forensic-suite-full.zip" .)
  fi

  python3 - "${WLT_OUT_DIR}" <<'PY'
import csv
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
idx = root / "bundles" / "index.tsv"
out = root / "bundles" / "index.json"
rows = []
if idx.exists():
    with idx.open("r", encoding="utf-8", newline="") as h:
        reader = csv.DictReader(h, delimiter="\t")
        for row in reader:
            rows.append(row)
summary = {
    "generatedAt": __import__("datetime").datetime.now().astimezone().isoformat(),
    "bundleMode": __import__("os").environ.get("WLT_BUNDLE_MODE", ""),
    "baselineLabel": __import__("os").environ.get("WLT_BASELINE_LABEL", ""),
    "scenarioCount": len(rows),
    "scenarios": rows,
    "runtimeMismatchSummary": str(root / "runtime-mismatch-matrix.summary.txt"),
}
out.write_text(json.dumps(summary, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
PY

  printf 'time=%s\nserial=%s\npackage=%s\nscenarios=%s\nbaseline=%s\nmismatch_rc=%s\nconflict_rc=%s\nconflict_threshold=%s\n' \
    "$(date -Is)" "${ADB_SERIAL_PICKED}" "${WLT_PACKAGE}" "${WLT_SCENARIO_MATRIX}" "${WLT_BASELINE_LABEL}" "${mismatch_rc}" "${conflict_rc}" "${WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE}" \
    > "${WLT_OUT_DIR}/session-meta.txt"

  log "bundle index: ${WLT_OUT_DIR}/bundles/index.json"
  log "done: ${WLT_OUT_DIR}"

  if [[ "${mismatch_rc}" -ne 0 ]]; then
    fail "runtime mismatch threshold reached (rc=${mismatch_rc})"
  fi
  if [[ "${conflict_rc}" -ne 0 ]]; then
    fail "runtime conflict contour threshold reached (rc=${conflict_rc})"
  fi
}

main "$@"
