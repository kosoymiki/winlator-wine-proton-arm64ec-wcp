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
    'ForensicLogger|RUNTIME_(GRAPHICS_SUITABILITY|PERF_PRESET_DOWNGRADED|UPSCALER_GUARD_APPLIED|SWFG_EFFECTIVE_CONFIG|SWFG_DISABLED_BY_GUARD|CONTAINER_UPSCALE_CONFIG_APPLIED|UPSCALE_LAUNCH_ENV_NORMALIZED|GLIBC_COMPAT_APPLIED|GLIBC_PRELOAD_STRIPPED)|LAUNCH_EXEC_(SUBMIT|EXIT)|SESSION_EXIT_|PARSER_(LOAD_SUMMARY|CONTAINER_MISSING_CONFIG)|ROUTE_(INTENT_RECEIVED|RESOLVED)|CONTAINER_CREATE_' \
    | tail -n "${WLT_LOGCAT_LINES}" > "${out_file}" || true
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

  local spec label
  for spec in "${scenario_specs[@]}"; do
    label="${spec%%:*}"
    cid="${spec##*:}"
    local before_runtime_index
    scenario_dir="${WLT_OUT_DIR}/${label}"
    mkdir -p "${scenario_dir}"
    before_runtime_index="${scenario_dir}/sdcard-runtime-before.txt"
    printf 'label=%s\ncontainer_id=%s\ntime=%s\n' "${label}" "${cid}" "$(iso_now)" > "${scenario_dir}/scenario_meta.txt"

    adb_s logcat -c || true
    snapshot_sdcard_runtime_index "${before_runtime_index}"
    trace_id="$(start_direct_route "${cid}" "${label}")"
    printf '%s\n' "${trace_id}" > "${scenario_dir}/trace_id.txt"
    wait_for_trace_settle "${trace_id}" "${scenario_dir}"

    adb_s logcat -d > "${scenario_dir}/logcat-full.txt" || true
    collect_logcat_filtered "${scenario_dir}/logcat-filtered.txt"
    collect_device_state "${scenario_dir}"
    dump_ui "${scenario_dir}"
    collect_app_snapshots "${scenario_dir}"
    collect_sdcard_runtime_logs "${scenario_dir}" "${before_runtime_index}"
  done

  log "Artifacts saved to ${WLT_OUT_DIR}"
}

main "$@"
