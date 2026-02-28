#!/usr/bin/env bash
set -euo pipefail

: "${WLT_PACKAGE:=by.aero.so.benchmark}"
: "${WLT_ACTIVITY:=com.winlator.cmod.XServerDisplayActivity}"
: "${WLT_CONTAINER_IDS:=1 2}"
: "${WLT_SCENARIOS:=}"
: "${WLT_OUT_DIR:=/tmp/winlator-complete-forensics-$(date +%Y%m%d_%H%M%S)}"
: "${WLT_WAIT_TIMEOUT_SEC:=20}"
: "${WLT_POLL_SEC:=1}"
: "${WLT_LOGCAT_LINES:=4000}"
: "${WLT_CAPTURE_UI:=1}"
: "${WLT_CAPTURE_PREFS:=1}"
: "${WLT_CAPTURE_RUNTIME_CONTENTS:=1}"
: "${WLT_CAPTURE_CONFLICT_LOGS:=1}"
: "${WLT_PROCESS_SAMPLES:=6}"
: "${WLT_PROCESS_SAMPLE_SEC:=1}"

log() { printf '[forensic-complete] %s\n' "$*" >&2; }
fail() { printf '[forensic-complete][error] %s\n' "$*" >&2; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }

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

iso_now() { date -Is; }

sanitize_label() {
  local raw="$1" safe
  safe="$(printf '%s' "${raw}" | tr -cs '[:alnum:]._:-' '_')"
  safe="${safe//:/_}"
  safe="${safe##_}"
  safe="${safe%%_}"
  [[ -n "${safe}" ]] || safe="scenario"
  printf '%s\n' "${safe}"
}

logcat_has_trace_event() {
  local file="$1"
  local trace_id="$2"
  local event_id="$3"
  grep -F "\"trace_id\":\"${trace_id}\"" "${file}" >/dev/null 2>&1 \
    && grep -F "\"event_id\":\"${event_id}\"" "${file}" >/dev/null 2>&1
}

start_direct_route() {
  local container_id="$1"
  local trace_suffix="${2:-}"
  local trace_id="complete-${container_id}-$(date +%s)"
  [[ -n "${trace_suffix}" ]] && trace_id="${trace_suffix}-$(date +%s)"
  log "Start direct forensic route container=${container_id} trace=${trace_id}"
  adb_s shell am start -W -S \
    -n "${WLT_PACKAGE}/${WLT_ACTIVITY}" \
    --ez forensic_mode true \
    --es forensic_trace_id "${trace_id}" \
    --es forensic_route_source direct_diag_adb \
    --ez forensic_skip_playtime true \
    --ei container_id "${container_id}" >/dev/null
  printf '%s\n' "${trace_id}"
}

wait_for_trace_settle() {
  local trace_id="$1"
  local out_dir="$2"
  local elapsed=0
  local saw_intent=0
  local saw_submit=0
  local saw_terminal=0
  while (( elapsed < WLT_WAIT_TIMEOUT_SEC )); do
    adb_s logcat -d > "${out_dir}/_poll.logcat" 2>/dev/null || true
    if logcat_has_trace_event "${out_dir}/_poll.logcat" "${trace_id}" "ROUTE_INTENT_RECEIVED"; then
      saw_intent=1
    fi
    if logcat_has_trace_event "${out_dir}/_poll.logcat" "${trace_id}" "LAUNCH_EXEC_SUBMIT"; then
      saw_submit=1
    fi
    if logcat_has_trace_event "${out_dir}/_poll.logcat" "${trace_id}" "LAUNCH_EXEC_EXIT" \
      || logcat_has_trace_event "${out_dir}/_poll.logcat" "${trace_id}" "SESSION_EXIT_COMPLETED"; then
      saw_terminal=1
      break
    fi
    sleep "${WLT_POLL_SEC}"
    elapsed=$((elapsed + WLT_POLL_SEC))
  done
  printf 'trace_id=%s\nelapsed_sec=%s\nsaw_intent=%s\nsaw_submit=%s\nsaw_terminal=%s\n' \
    "${trace_id}" "${elapsed}" "${saw_intent}" "${saw_submit}" "${saw_terminal}" > "${out_dir}/wait-status.txt"
  rm -f "${out_dir}/_poll.logcat"
}

dump_ui() {
  local out_dir="$1"
  [[ "${WLT_CAPTURE_UI}" == "1" ]] || return 0
  adb_s shell uiautomator dump /sdcard/winlator_ui.xml >/dev/null 2>&1 || true
  adb_s shell cat /sdcard/winlator_ui.xml > "${out_dir}/ui.xml" 2>/dev/null || true
  adb_s exec-out screencap -p > "${out_dir}/screen.png" 2>/dev/null || true
}

collect_logcat_filtered() {
  local out_file="$1"
  adb_s logcat -d | grep -E \
    'ForensicLogger|RUNTIME_(GRAPHICS_SUITABILITY|PERF_PRESET_DOWNGRADED|UPSCALER_GUARD_APPLIED|SWFG_EFFECTIVE_CONFIG|SWFG_DISABLED_BY_GUARD|CONTAINER_UPSCALE_CONFIG_APPLIED|UPSCALE_LAUNCH_ENV_NORMALIZED|GLIBC_COMPAT_APPLIED|GLIBC_PRELOAD_STRIPPED|SUBSYSTEM_SNAPSHOT|LOGGING_CONTRACT_SNAPSHOT|LIBRARY_COMPONENT_SIGNAL|LIBRARY_COMPONENT_CONFLICT|LIBRARY_CONFLICT_(SNAPSHOT|DETECTED)|DX_CAPABILITY_ENVELOPE|DX_ROUTE_POLICY|UPSCALE_RUNTIME_MATRIX)|AERO_(RUNTIME|LIBRARY|DXVK|VKD3D|UPSCALE|TURNIP|X11)_|WINLATOR_SIGNAL_|LAUNCH_EXEC_(SUBMIT|EXIT)|SESSION_EXIT_|PARSER_(LOAD_SUMMARY|CONTAINER_MISSING_CONFIG)|ROUTE_(INTENT_RECEIVED|RESOLVED)|CONTAINER_CREATE_' \
    | tail -n "${WLT_LOGCAT_LINES}" > "${out_file}" || true
}

collect_runtime_conflict_contour() {
  local out_dir="$1"
  [[ "${WLT_CAPTURE_CONFLICT_LOGS}" == "1" ]] || return 0

  local contour_file="${out_dir}/logcat-runtime-conflict-contour.txt"
  local source_files=(
    "${out_dir}/logcat-full.txt"
    "${out_dir}/forensics-jsonl-tail.txt"
    "${out_dir}/runtime-logs"
  )

  {
    rg -n \
      'RUNTIME_(SUBSYSTEM_SNAPSHOT|LOGGING_CONTRACT_SNAPSHOT|LIBRARY_COMPONENT_SIGNAL|LIBRARY_COMPONENT_CONFLICT|LIBRARY_CONFLICT_(SNAPSHOT|DETECTED)|DX_CAPABILITY_ENVELOPE|UPSCALE_RUNTIME_MATRIX)|AERO_(RUNTIME|LIBRARY|DXVK|VKD3D|UPSCALE|TURNIP|X11)_|WINLATOR_SIGNAL_' \
      "${source_files[@]}" -S 2>/dev/null || true
  } > "${contour_file}"

  python3 - "${contour_file}" > "${out_dir}/runtime-conflict-contour.summary.txt" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""
tokens = {
    "runtime_subsystem_snapshot": r"RUNTIME_SUBSYSTEM_SNAPSHOT",
    "runtime_logging_contract_snapshot": r"RUNTIME_LOGGING_CONTRACT_SNAPSHOT",
    "runtime_library_component_signal": r"RUNTIME_LIBRARY_COMPONENT_SIGNAL",
    "runtime_library_component_conflict": r"RUNTIME_LIBRARY_COMPONENT_CONFLICT",
    "runtime_library_conflict_snapshot": r"RUNTIME_LIBRARY_CONFLICT_SNAPSHOT",
    "runtime_library_conflict_detected": r"RUNTIME_LIBRARY_CONFLICT_DETECTED",
    "aero_runtime_markers": r"AERO_RUNTIME_",
    "aero_library_markers": r"AERO_LIBRARY_",
    "aero_dxvk_markers": r"AERO_DXVK_",
    "aero_vkd3d_markers": r"AERO_VKD3D_",
    "aero_upscale_markers": r"AERO_UPSCALE_",
    "aero_turnip_markers": r"AERO_TURNIP_",
    "aero_x11_markers": r"AERO_X11_",
    "signal_input_markers": r"WINLATOR_SIGNAL_INPUT_",
}
print("runtime_conflict_contour")
for key, pattern in tokens.items():
    print(f"{key}={len(re.findall(pattern, text))}")
PY
}

collect_app_snapshots() {
  local out_dir="$1"
  mkdir -p "${out_dir}"
  # Android toybox find doesn't support -maxdepth on many devices.
  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'find ./files/imagefs/home -type f -name .container 2>/dev/null | sort'" \
    > "${out_dir}/containers-list.txt" 2>&1 || true
  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'for f in ./files/imagefs/home/xuser-*/.container; do [ -f \"\$f\" ] || continue; echo ===== \$f =====; cat \"\$f\"; echo; done'" \
    > "${out_dir}/containers-json.txt" 2>&1 || true
  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'find ./files/Winlator/logs -type f 2>/dev/null | sort'" \
    > "${out_dir}/app-log-files.txt" 2>&1 || true
  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'find ./files/Winlator/logs/forensics -type f 2>/dev/null | sort'" \
    > "${out_dir}/forensics-files.txt" 2>&1 || true
  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'for f in ./files/contents/Wine/*/profile.json; do [ -f \"\$f\" ] || continue; echo ===== \$f =====; cat \"\$f\"; echo; done'" \
    > "${out_dir}/wine-profiles.txt" 2>&1 || true
  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'for f in ./files/Winlator/logs/forensics/*.jsonl; do [ -f \"\$f\" ] || continue; echo ===== \$f =====; tail -n 200 \"\$f\"; echo; done'" \
    > "${out_dir}/forensics-jsonl-tail.txt" 2>&1 || true
  if [[ "${WLT_CAPTURE_PREFS}" == "1" ]]; then
    adb_s shell "run-as ${WLT_PACKAGE} sh -c 'for f in ./shared_prefs/*.xml; do [ -f \"\$f\" ] || continue; echo ===== \$f =====; cat \"\$f\"; echo; done'" \
      > "${out_dir}/shared-prefs.xml" 2>&1 || true
  fi
}

snapshot_sdcard_runtime_index() {
  local out_file="$1"
  adb_s shell "sh -c 'for f in /sdcard/Winlator/logs/*; do [ -f \"\$f\" ] && printf \"%s\n\" \"\$f\"; done | sort'" \
    > "${out_file}" 2>&1 || true
}

collect_sdcard_runtime_logs() {
  local out_dir="$1"
  local before_index="${2:-}"
  local after_index="${out_dir}/sdcard-runtime-logs-index.txt"
  adb_s shell "sh -c 'for f in /sdcard/Winlator/logs/*; do [ -f \"\$f\" ] && printf \"%s\n\" \"\$f\"; done | sort'" \
    > "${after_index}" 2>&1 || true
  [[ "${WLT_CAPTURE_RUNTIME_CONTENTS}" == "1" ]] || return 0
  mkdir -p "${out_dir}/runtime-logs"
  if [[ -n "${before_index}" && -f "${before_index}" ]]; then
    comm -13 <(sort "${before_index}") <(sort "${after_index}") > "${out_dir}/sdcard-runtime-logs-new.txt" || true
  else
    cp "${after_index}" "${out_dir}/sdcard-runtime-logs-new.txt" 2>/dev/null || true
  fi
  : > "${out_dir}/sdcard-runtime-logs-new-ls.txt"
  while IFS= read -r path; do
    [[ "${path}" == /sdcard/Winlator/logs/* ]] || continue
    local base
    base="$(basename "${path}")"
    adb_s shell "ls -l '${path}'" >> "${out_dir}/sdcard-runtime-logs-new-ls.txt" 2>&1 </dev/null || true
    adb_s shell "cat '${path}'" > "${out_dir}/runtime-logs/${base}" 2>/dev/null </dev/null || true
  done < "${out_dir}/sdcard-runtime-logs-new.txt"
}

collect_device_state() {
  local out_dir="$1"
  adb_s shell dumpsys activity top > "${out_dir}/dumpsys-activity-top.txt" 2>/dev/null || true
  adb_s shell pidof "${WLT_PACKAGE}" > "${out_dir}/pid.txt" 2>/dev/null || true
}

collect_process_emergence() {
  local out_dir="$1"
  local sample_file="${out_dir}/ps-emergence-samples.txt"
  local i
  : > "${sample_file}"
  for ((i=1; i<=WLT_PROCESS_SAMPLES; i++)); do
    {
      printf '=== sample %s ===\n' "$(iso_now)"
      adb_s shell "ps -A -o USER,PID,PPID,NAME,ARGS | awk 'BEGIN{IGNORECASE=1} NR==1{print;next} {n=\$4; l=\$0; if (n ~ /(wine|wineserver|jwm|box64|fex|xserver|dxvk|vkd3d|linker64)/ || l ~ /${WLT_PACKAGE//./[.]}/) print}'"
      printf '\n'
    } >> "${sample_file}" 2>/dev/null || true
    sleep "${WLT_PROCESS_SAMPLE_SEC}"
  done
  local ws_count
  local wine_count
  ws_count="$(grep -i -c 'wineserver' "${sample_file}" 2>/dev/null || true)"
  wine_count="$(grep -E -i -c '\bwine\b' "${sample_file}" 2>/dev/null || true)"
  local present=0
  if [[ "${ws_count}" -gt 0 || "${wine_count}" -gt 0 ]]; then
    present=1
  fi
  printf 'ps_wineserver_count=%s\nps_wine_count=%s\nwine_process_present=%s\n' \
    "${ws_count}" "${wine_count}" "${present}" > "${out_dir}/process-emergence.env"
}

collect_artifact_picker_ui() {
  local out_dir="$1"
  mkdir -p "${out_dir}"
  adb_s logcat -c || true
  adb_s shell am start -n "${WLT_PACKAGE}/com.winlator.cmod.MainActivity" >/dev/null || true
  sleep 2
  dump_ui "${out_dir}"
  collect_device_state "${out_dir}"
  adb_s logcat -d > "${out_dir}/logcat-full.txt" || true
  collect_logcat_filtered "${out_dir}/logcat-filtered.txt"
  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'for f in ./files/contents/Wine/*/profile.json; do [ -f \"\$f\" ] || continue; echo ===== \$f =====; cat \"\$f\"; echo; done'" \
    > "${out_dir}/wine-profiles.txt" 2>&1 || true
}

main() {
  local cid trace_id scenario_dir
  require_cmd adb
  require_cmd python3
  [[ "${WLT_CAPTURE_CONFLICT_LOGS}" =~ ^[01]$ ]] || fail "WLT_CAPTURE_CONFLICT_LOGS must be 0 or 1"
  mkdir -p "${WLT_OUT_DIR}"
  ADB_SERIAL_PICKED="$(pick_serial)"
  [[ -n "${ADB_SERIAL_PICKED}" ]] || fail "No active adb device"
  export ADB_SERIAL_PICKED

  log "Using device ${ADB_SERIAL_PICKED}"
  printf 'package=%s\nserial=%s\ntime=%s\ncontainer_ids=%s\nscenarios=%s\n' \
    "${WLT_PACKAGE}" "${ADB_SERIAL_PICKED}" "$(iso_now)" "${WLT_CONTAINER_IDS}" "${WLT_SCENARIOS}" > "${WLT_OUT_DIR}/session_meta.txt"

  collect_artifact_picker_ui "${WLT_OUT_DIR}/ui-baseline" || true

  local scenario_specs=()
  if [[ -n "${WLT_SCENARIOS}" ]]; then
    # Format: label:containerId [label2:containerId2 ...]
    # Example: WLT_SCENARIOS="n2_scaleforce:1 wine11_scaleforce:2"
    read -r -a scenario_specs <<< "${WLT_SCENARIOS}"
  else
    for cid in ${WLT_CONTAINER_IDS}; do
      scenario_specs+=("container-${cid}:${cid}")
    done
  fi

  local spec label safe_label
  local -A seen_labels=()
  for spec in "${scenario_specs[@]}"; do
    [[ "${spec}" == *:* ]] || fail "Invalid scenario spec '${spec}' (expected label:containerId)"
    label="${spec%%:*}"
    cid="${spec##*:}"
    [[ -n "${label}" ]] || fail "Scenario label cannot be empty in '${spec}'"
    [[ "${cid}" =~ ^[0-9]+$ ]] || fail "Scenario container id must be numeric in '${spec}'"
    safe_label="$(sanitize_label "${label}")"
    if [[ -n "${seen_labels[${safe_label}]:-}" ]]; then
      fail "Duplicate scenario label after sanitization: '${label}' -> '${safe_label}'"
    fi
    seen_labels["${safe_label}"]=1
    local before_runtime_index
    scenario_dir="${WLT_OUT_DIR}/${safe_label}"
    mkdir -p "${scenario_dir}"
    before_runtime_index="${scenario_dir}/sdcard-runtime-before.txt"
    printf 'label=%s\nsafe_label=%s\ncontainer_id=%s\ntime=%s\n' "${label}" "${safe_label}" "${cid}" "$(iso_now)" > "${scenario_dir}/scenario_meta.txt"

    adb_s logcat -c || true
    snapshot_sdcard_runtime_index "${before_runtime_index}"
    trace_id="$(start_direct_route "${cid}" "${safe_label}")"
    printf '%s\n' "${trace_id}" > "${scenario_dir}/trace_id.txt"
    wait_for_trace_settle "${trace_id}" "${scenario_dir}"

    adb_s logcat -d > "${scenario_dir}/logcat-full.txt" || true
    collect_logcat_filtered "${scenario_dir}/logcat-filtered.txt"
    collect_device_state "${scenario_dir}"
    collect_process_emergence "${scenario_dir}"
    dump_ui "${scenario_dir}"
    collect_app_snapshots "${scenario_dir}"
    collect_runtime_conflict_contour "${scenario_dir}"
    collect_sdcard_runtime_logs "${scenario_dir}" "${before_runtime_index}"
  done

  log "Artifacts saved to ${WLT_OUT_DIR}"
}

main "$@"
