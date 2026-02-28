#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${WLT_PACKAGE:=by.aero.so.benchmark}"
: "${WLT_HOME_ROOT:=files/imagefs/home}"
: "${WLT_OUT_DIR:=/tmp/winlator-rc005-matrix-$(date +%Y%m%d_%H%M%S)}"
: "${WLT_FLAVOR_MAP:=wine11:1 protonwine10:2 protonge10:3 gamenative104:4}"
: "${WLT_VPN_STATES:=off on}"
: "${WLT_NVAPI_STATES:=0 1}"
: "${WLT_FSR_MODES:=quality balanced performance ultra}"
: "${WLT_FSR_STRENGTH:=2}"
: "${WLT_VPN_APPLY_HOOK:=}"
: "${WLT_RUN_NETWORK_DIAG:=1}"
: "${WLT_CAPTURE_UI:=1}"
: "${WLT_CAPTURE_PREFS:=1}"
: "${WLT_CAPTURE_RUNTIME_CONTENTS:=1}"
: "${WLT_CAPTURE_CONFLICT_LOGS:=1}"
: "${WLT_WAIT_TIMEOUT_SEC:=20}"
: "${WLT_POLL_SEC:=1}"
: "${WLT_LOGCAT_LINES:=4000}"
: "${WLT_PROCESS_SAMPLES:=6}"
: "${WLT_PROCESS_SAMPLE_SEC:=1}"
: "${WLT_FAIL_ON_MISMATCH:=0}"
: "${WLT_FAIL_ON_SEVERITY_AT_OR_ABOVE:=off}"
: "${WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE:=off}"
: "${WLT_VALIDATE_RC005:=1}"
: "${WLT_BASELINE_LABEL:=}"

SCENARIO_INDEX_TSV=""
ADB_SERIAL_PICKED=""
FSR_PREF_FILE=""

log() { printf '[forensic-rc005] %s\n' "$*"; }
fail() { printf '[forensic-rc005][error] %s\n' "$*" >&2; exit 1; }

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
  local raw="$1" safe
  safe="$(printf '%s' "${raw}" | tr -cs '[:alnum:]._:-' '_')"
  safe="${safe//:/_}"
  safe="${safe##_}"
  safe="${safe%%_}"
  [[ -n "${safe}" ]] || safe="scenario"
  printf '%s\n' "${safe}"
}

trim() {
  local s="$1"
  s="${s#${s%%[![:space:]]*}}"
  s="${s%${s##*[![:space:]]}}"
  printf '%s' "${s}"
}

split_list() {
  local raw="$1"
  local -n out_ref="$2"
  local token
  out_ref=()
  for token in ${raw}; do
    token="$(trim "${token}")"
    [[ -n "${token}" ]] || continue
    out_ref+=("${token}")
  done
}

run_vpn_hook_if_set() {
  local vpn_state="$1"
  [[ -n "${WLT_VPN_APPLY_HOOK}" ]] || return 0
  log "running VPN hook for state=${vpn_state}"
  ADB_SERIAL="${ADB_SERIAL_PICKED}" \
  WLT_PACKAGE="${WLT_PACKAGE}" \
  WLT_VPN_STATE="${vpn_state}" \
    bash -lc "${WLT_VPN_APPLY_HOOK}"
}

discover_fsr_pref_file() {
  local pref
  pref="$(adb_s shell "run-as ${WLT_PACKAGE} sh -c 'for f in ./shared_prefs/*.xml; do [ -f \"\$f\" ] || continue; if grep -q "'"'adrenotools_upscale_proton_fsr_mode'"'" "\$f"; then echo "\$f"; exit 0; fi; done; if [ -f ./shared_prefs/com.winlator.cmod_preferences.xml ]; then echo ./shared_prefs/com.winlator.cmod_preferences.xml; fi'" 2>/dev/null | tr -d '\r' | head -n1 || true)"
  if [[ -z "${pref}" ]]; then
    pref="./shared_prefs/com.winlator.cmod_preferences.xml"
  fi
  printf '%s\n' "${pref}"
}

set_global_fsr_mode() {
  local fsr_mode="$1"
  local fsr_strength="$2"
  local pref_rel="$3"
  local tmp_xml

  tmp_xml="$(mktemp "${WLT_OUT_DIR}/.prefs.XXXXXX.xml")"
  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'cat ${pref_rel}'" > "${tmp_xml}" 2>/dev/null || true
  if [[ ! -s "${tmp_xml}" ]]; then
    printf '<map/>\n' > "${tmp_xml}"
  fi

  python3 - "${tmp_xml}" "${fsr_mode}" "${fsr_strength}" <<'PY'
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

xml_path = Path(sys.argv[1])
mode = sys.argv[2]
strength = int(sys.argv[3])

raw = xml_path.read_text(encoding="utf-8", errors="ignore").strip()
if not raw:
    root = ET.Element("map")
else:
    try:
        root = ET.fromstring(raw)
    except ET.ParseError:
        root = ET.Element("map")

if root.tag != "map":
    root = ET.Element("map")


def find_node(tag: str, name: str):
    for child in root.findall(tag):
        if child.get("name") == name:
            return child
    return None


def set_string(name: str, value: str):
    node = find_node("string", name)
    if node is None:
        node = ET.SubElement(root, "string", {"name": name})
    node.text = value


def set_int(name: str, value: int):
    node = find_node("int", name)
    if node is None:
        node = ET.SubElement(root, "int", {"name": name, "value": str(value)})
    else:
        node.set("value", str(value))

set_string("adrenotools_upscale_proton_fsr_mode", mode)
set_int("adrenotools_upscale_proton_fsr_strength", strength)

try:
    ET.indent(root, space="  ")
except AttributeError:
    pass

tree = ET.ElementTree(root)
tree.write(xml_path, encoding="utf-8", xml_declaration=True)
PY

  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'mkdir -p ./shared_prefs && cat > ${pref_rel}'" < "${tmp_xml}"
  rm -f "${tmp_xml}"
}

set_container_nvapi_flag() {
  local container_id="$1"
  local nvapi_state="$2"
  local tmp_json

  tmp_json="$(mktemp "${WLT_OUT_DIR}/.container-${container_id}.XXXXXX.json")"

  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'cat ${WLT_HOME_ROOT}/xuser-${container_id}/.container'" > "${tmp_json}" \
    || fail "failed to read xuser-${container_id}/.container"

  python3 - "${tmp_json}" "${nvapi_state}" <<'PY'
import json
import sys
from pathlib import Path

json_path = Path(sys.argv[1])
nvapi_state = "1" if sys.argv[2] in {"1", "true", "on", "yes"} else "0"

obj = json.loads(json_path.read_text(encoding="utf-8"))
config_raw = str(obj.get("dxwrapperConfig", ""))

ordered_keys = []
values = {}
for token in config_raw.split(","):
    token = token.strip()
    if not token or "=" not in token:
        continue
    key, value = token.split("=", 1)
    key = key.strip()
    value = value.strip()
    if not key:
        continue
    if key not in values:
        ordered_keys.append(key)
    values[key] = value

if "nvapi" not in values:
    ordered_keys.append("nvapi")
values["nvapi"] = nvapi_state

obj["dxwrapperConfig"] = ",".join(f"{k}={values[k]}" for k in ordered_keys)
json_path.write_text(json.dumps(obj, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
PY

  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'cat > ${WLT_HOME_ROOT}/xuser-${container_id}/.container'" < "${tmp_json}"
  rm -f "${tmp_json}"
}

append_scenario_matrix_meta() {
  local scenario_dir="$1"
  local flavor="$2"
  local vpn_state="$3"
  local nvapi_state="$4"
  local fsr_mode="$5"

  {
    printf 'flavor=%s\n' "${flavor}"
    printf 'vpn_state=%s\n' "${vpn_state}"
    printf 'nvapi_requested=%s\n' "${nvapi_state}"
    printf 'proton_fsr_mode=%s\n' "${fsr_mode}"
    printf 'proton_fsr_strength=%s\n' "${WLT_FSR_STRENGTH}"
  } > "${scenario_dir}/scenario-matrix.env"

  {
    printf 'flavor=%s\n' "${flavor}"
    printf 'vpn_state=%s\n' "${vpn_state}"
    printf 'nvapi_requested=%s\n' "${nvapi_state}"
    printf 'proton_fsr_mode=%s\n' "${fsr_mode}"
    printf 'proton_fsr_strength=%s\n' "${WLT_FSR_STRENGTH}"
  } >> "${scenario_dir}/scenario_meta.txt"
}

capture_single_scenario() {
  local label="$1"
  local flavor="$2"
  local container_id="$3"
  local vpn_state="$4"
  local nvapi_state="$5"
  local fsr_mode="$6"
  local safe_label scenario_dir run_dir

  safe_label="$(sanitize_label "${label}")"
  run_dir="$(mktemp -d "${WLT_OUT_DIR}/.run-${safe_label}.XXXXXX")"

  log "capture label=${label} container=${container_id} vpn=${vpn_state} nvapi=${nvapi_state} fsr=${fsr_mode}"

  ADB_SERIAL="${ADB_SERIAL_PICKED}" \
  WLT_PACKAGE="${WLT_PACKAGE}" \
  WLT_SCENARIOS="${label}:${container_id}" \
  WLT_OUT_DIR="${run_dir}" \
  WLT_WAIT_TIMEOUT_SEC="${WLT_WAIT_TIMEOUT_SEC}" \
  WLT_POLL_SEC="${WLT_POLL_SEC}" \
  WLT_LOGCAT_LINES="${WLT_LOGCAT_LINES}" \
  WLT_CAPTURE_UI="${WLT_CAPTURE_UI}" \
  WLT_CAPTURE_PREFS="${WLT_CAPTURE_PREFS}" \
  WLT_CAPTURE_RUNTIME_CONTENTS="${WLT_CAPTURE_RUNTIME_CONTENTS}" \
  WLT_CAPTURE_CONFLICT_LOGS="${WLT_CAPTURE_CONFLICT_LOGS}" \
  WLT_PROCESS_SAMPLES="${WLT_PROCESS_SAMPLES}" \
  WLT_PROCESS_SAMPLE_SEC="${WLT_PROCESS_SAMPLE_SEC}" \
    bash "${ROOT_DIR}/ci/winlator/forensic-adb-complete-matrix.sh"

  scenario_dir="${run_dir}/${safe_label}"
  [[ -d "${scenario_dir}" ]] || fail "scenario output missing: ${scenario_dir}"

  append_scenario_matrix_meta "${scenario_dir}" "${flavor}" "${vpn_state}" "${nvapi_state}" "${fsr_mode}"

  if [[ -d "${run_dir}/ui-baseline" && ! -d "${WLT_OUT_DIR}/ui-baseline" ]]; then
    cp -a "${run_dir}/ui-baseline" "${WLT_OUT_DIR}/ui-baseline"
  fi

  [[ ! -d "${WLT_OUT_DIR}/${safe_label}" ]] || fail "scenario already exists: ${safe_label}"
  mv "${scenario_dir}" "${WLT_OUT_DIR}/${safe_label}"

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
    "${label}" "${flavor}" "${container_id}" "${vpn_state}" "${nvapi_state}" "${fsr_mode}" \
    >> "${SCENARIO_INDEX_TSV}"

  rm -rf "${run_dir}"
}

build_bundles() {
  local bundles_dir index_tsv index_json label flavor container_id vpn_state nvapi_state fsr_mode safe_label zip_path

  bundles_dir="${WLT_OUT_DIR}/bundles"
  index_tsv="${bundles_dir}/index.tsv"
  index_json="${bundles_dir}/index.json"

  mkdir -p "${bundles_dir}"
  printf 'label\tflavor\tcontainer_id\tvpn_state\tnvapi_requested\tproton_fsr_mode\tscenario_dir\tzip_path\n' > "${index_tsv}"

  while IFS=$'\t' read -r label flavor container_id vpn_state nvapi_state fsr_mode; do
    [[ "${label}" == "label" ]] && continue
    [[ -n "${label}" ]] || continue
    safe_label="$(sanitize_label "${label}")"
    [[ -d "${WLT_OUT_DIR}/${safe_label}" ]] || fail "missing scenario dir for bundle: ${safe_label}"
    zip_path="${bundles_dir}/${safe_label}.zip"
    (cd "${WLT_OUT_DIR}" && zip -qr "${zip_path}" "${safe_label}")
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "${label}" "${flavor}" "${container_id}" "${vpn_state}" "${nvapi_state}" "${fsr_mode}" "${safe_label}" "${zip_path}" \
      >> "${index_tsv}"
  done < "${SCENARIO_INDEX_TSV}"

  python3 - "${index_tsv}" "${index_json}" <<'PY'
import csv
import json
import sys
from datetime import datetime
from pathlib import Path

index_tsv = Path(sys.argv[1])
index_json = Path(sys.argv[2])
rows = []
if index_tsv.exists():
    with index_tsv.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        for row in reader:
            rows.append(row)

payload = {
    "generatedAt": datetime.now().astimezone().isoformat(),
    "scenarioCount": len(rows),
    "scenarios": rows,
}
index_json.write_text(json.dumps(payload, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
PY
}

resolve_default_baseline() {
  local baseline
  baseline="$(awk -F'\t' '$2=="gamenative104" && $4=="off" && $5=="0" && $6=="quality" {print $1; exit}' "${SCENARIO_INDEX_TSV}" || true)"
  if [[ -z "${baseline}" ]]; then
    baseline="$(awk -F'\t' 'NR==2 {print $1}' "${SCENARIO_INDEX_TSV}" || true)"
  fi
  printf '%s\n' "${baseline}"
}

run_matrix_reports() {
  local baseline mismatch_rc conflict_rc validate_rc

  baseline="${WLT_BASELINE_LABEL}"
  if [[ -z "${baseline}" ]]; then
    baseline="$(resolve_default_baseline)"
  fi
  [[ -n "${baseline}" ]] || fail "unable to resolve baseline label"

  log "baseline=${baseline}"

  set +e
  mismatch_args=(
    --input "${WLT_OUT_DIR}"
    --baseline-label "${baseline}"
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

  python3 "${ROOT_DIR}/ci/winlator/forensic-runtime-conflict-contour.py" \
    --input "${WLT_OUT_DIR}" \
    --baseline-label "${baseline}" \
    --output-prefix "${WLT_OUT_DIR}/runtime-conflict-contour" \
    --fail-on-severity-at-or-above "${WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE}"
  conflict_rc=$?

  validate_rc=0
  if [[ "${WLT_VALIDATE_RC005}" == "1" ]]; then
    python3 "${ROOT_DIR}/ci/winlator/validate-rc005-device-matrix.py" \
      --input "${WLT_OUT_DIR}" \
      --strict \
      --output "${WLT_OUT_DIR}/rc005-validation.md"
    validate_rc=$?
  fi
  set -e

  printf 'time=%s\nserial=%s\npackage=%s\nbaseline=%s\nscenarios_tsv=%s\nmismatch_rc=%s\nconflict_rc=%s\nvalidate_rc=%s\n' \
    "$(date -Is)" "${ADB_SERIAL_PICKED}" "${WLT_PACKAGE}" "${baseline}" "${SCENARIO_INDEX_TSV}" "${mismatch_rc}" "${conflict_rc}" "${validate_rc}" \
    > "${WLT_OUT_DIR}/session-meta.txt"

  [[ "${mismatch_rc}" -eq 0 ]] || fail "runtime mismatch threshold reached (rc=${mismatch_rc})"
  [[ "${conflict_rc}" -eq 0 ]] || fail "runtime conflict threshold reached (rc=${conflict_rc})"
  [[ "${validate_rc}" -eq 0 ]] || fail "rc005 validation failed (rc=${validate_rc})"
}

main() {
  local -a flavors vpn_states nvapi_states fsr_modes
  local spec flavor container_id vpn_state nvapi_state fsr_mode
  local total expected

  require_cmd adb
  require_cmd python3
  require_cmd jq
  require_cmd zip

  [[ "${WLT_RUN_NETWORK_DIAG}" =~ ^[01]$ ]] || fail "WLT_RUN_NETWORK_DIAG must be 0 or 1"
  [[ "${WLT_CAPTURE_UI}" =~ ^[01]$ ]] || fail "WLT_CAPTURE_UI must be 0 or 1"
  [[ "${WLT_CAPTURE_PREFS}" =~ ^[01]$ ]] || fail "WLT_CAPTURE_PREFS must be 0 or 1"
  [[ "${WLT_CAPTURE_RUNTIME_CONTENTS}" =~ ^[01]$ ]] || fail "WLT_CAPTURE_RUNTIME_CONTENTS must be 0 or 1"
  [[ "${WLT_CAPTURE_CONFLICT_LOGS}" =~ ^[01]$ ]] || fail "WLT_CAPTURE_CONFLICT_LOGS must be 0 or 1"
  [[ "${WLT_VALIDATE_RC005}" =~ ^[01]$ ]] || fail "WLT_VALIDATE_RC005 must be 0 or 1"
  [[ "${WLT_FAIL_ON_MISMATCH}" =~ ^[01]$ ]] || fail "WLT_FAIL_ON_MISMATCH must be 0 or 1"
  [[ "${WLT_FAIL_ON_SEVERITY_AT_OR_ABOVE}" =~ ^(off|info|low|medium|high)$ ]] || \
    fail "WLT_FAIL_ON_SEVERITY_AT_OR_ABOVE must be one of: off, info, low, medium, high"
  [[ "${WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE}" =~ ^(off|info|low|medium|high)$ ]] || \
    fail "WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE must be one of: off, info, low, medium, high"

  mkdir -p "${WLT_OUT_DIR}"

  split_list "${WLT_FLAVOR_MAP}" flavors
  split_list "${WLT_VPN_STATES}" vpn_states
  split_list "${WLT_NVAPI_STATES}" nvapi_states
  split_list "${WLT_FSR_MODES}" fsr_modes

  [[ "${#flavors[@]}" -gt 0 ]] || fail "WLT_FLAVOR_MAP resolved to empty set"
  [[ "${#vpn_states[@]}" -gt 0 ]] || fail "WLT_VPN_STATES resolved to empty set"
  [[ "${#nvapi_states[@]}" -gt 0 ]] || fail "WLT_NVAPI_STATES resolved to empty set"
  [[ "${#fsr_modes[@]}" -gt 0 ]] || fail "WLT_FSR_MODES resolved to empty set"

  ADB_SERIAL_PICKED="$(pick_serial)"
  [[ -n "${ADB_SERIAL_PICKED}" ]] || fail "no active adb device"

  FSR_PREF_FILE="$(discover_fsr_pref_file)"

  SCENARIO_INDEX_TSV="${WLT_OUT_DIR}/matrix-scenarios.tsv"
  printf 'label\tflavor\tcontainer_id\tvpn_state\tnvapi_requested\tproton_fsr_mode\n' > "${SCENARIO_INDEX_TSV}"

  total=0
  expected=$(( ${#flavors[@]} * ${#vpn_states[@]} * ${#nvapi_states[@]} * ${#fsr_modes[@]} ))
  log "device=${ADB_SERIAL_PICKED} package=${WLT_PACKAGE}"
  log "fsr_pref_file=${FSR_PREF_FILE}"
  log "expected_scenarios=${expected}"

  for vpn_state in "${vpn_states[@]}"; do
    run_vpn_hook_if_set "${vpn_state}"

    if [[ "${WLT_RUN_NETWORK_DIAG}" == "1" ]]; then
      ADB_SERIAL="${ADB_SERIAL_PICKED}" \
      WLT_PACKAGE="${WLT_PACKAGE}" \
      WLT_OUT_DIR="${WLT_OUT_DIR}/network/vpn-${vpn_state}" \
        bash "${ROOT_DIR}/ci/winlator/adb-network-source-diagnostics.sh" || true
    fi

    for nvapi_state in "${nvapi_states[@]}"; do
      [[ "${nvapi_state}" =~ ^[01]$ ]] || fail "WLT_NVAPI_STATES entries must be 0 or 1: ${nvapi_state}"

      for spec in "${flavors[@]}"; do
        [[ "${spec}" == *:* ]] || fail "invalid flavor map entry '${spec}' (expected label:containerId)"
        flavor="${spec%%:*}"
        container_id="${spec##*:}"
        [[ -n "${flavor}" ]] || fail "empty flavor label in '${spec}'"
        [[ "${container_id}" =~ ^[0-9]+$ ]] || fail "non-numeric container id in '${spec}'"

        set_container_nvapi_flag "${container_id}" "${nvapi_state}"

        for fsr_mode in "${fsr_modes[@]}"; do
          set_global_fsr_mode "${fsr_mode}" "${WLT_FSR_STRENGTH}" "${FSR_PREF_FILE}"
          capture_single_scenario \
            "${flavor}__vpn-${vpn_state}__nvapi-${nvapi_state}__fsr-${fsr_mode}" \
            "${flavor}" "${container_id}" "${vpn_state}" "${nvapi_state}" "${fsr_mode}"
          total=$((total + 1))
          log "progress ${total}/${expected}"
        done
      done
    done
  done

  build_bundles
  run_matrix_reports

  log "done: ${WLT_OUT_DIR}"
}

main "$@"
