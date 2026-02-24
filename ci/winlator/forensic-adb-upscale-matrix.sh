#!/usr/bin/env bash
set -euo pipefail

: "${WLT_PACKAGE:=by.aero.so.benchmark}"
: "${WLT_ACTIVITY:=com.winlator.cmod.XServerDisplayActivity}"
: "${WLT_CONTAINER_IDS:=1 2}"
: "${WLT_WAIT_SEC:=4}"
: "${WLT_LOGCAT_LINES:=1200}"
: "${WLT_OUT_DIR:=/tmp/winlator-upscale-forensics-$(date +%Y%m%d_%H%M%S)}"

log() { printf '[forensic-upscale] %s\n' "$*"; }
fail() { printf '[forensic-upscale][error] %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

pick_serial() {
  local serial
  serial="${ADB_SERIAL:-}"
  if [[ -n "${serial}" ]]; then
    printf '%s\n' "${serial}"
    return 0
  fi
  adb devices | awk 'NR>1 && $2=="device" {print $1; exit}'
}

adb_s() {
  adb -s "${ADB_SERIAL_PICKED}" "$@"
}

start_direct_route() {
  local container_id="$1"
  local trace_id="upscale-${container_id}-$(date +%s)"
  log "Start direct forensic route container=${container_id} trace=${trace_id}"
  adb_s shell am start \
    -n "${WLT_PACKAGE}/${WLT_ACTIVITY}" \
    --ez forensic_mode true \
    --es forensic_trace_id "${trace_id}" \
    --es forensic_route_source direct_diag_adb \
    --ez forensic_skip_playtime true \
    --ei container_id "${container_id}" >/dev/null
  printf '%s\n' "${trace_id}"
}

dump_ui() {
  local out_dir="$1"
  adb_s shell uiautomator dump /sdcard/winlator_ui.xml >/dev/null 2>&1 || true
  adb_s shell cat /sdcard/winlator_ui.xml > "${out_dir}/ui.xml" 2>/dev/null || true
  adb_s exec-out screencap -p > "${out_dir}/screen.png" 2>/dev/null || true
}

collect_logcat_filtered() {
  local out_file="$1"
  adb_s logcat -d | grep -E \
    'ForensicLogger|RUNTIME_(GRAPHICS_SUITABILITY|PERF_PRESET_DOWNGRADED|UPSCALER_GUARD_APPLIED|SWFG_EFFECTIVE_CONFIG|SWFG_DISABLED_BY_GUARD|CONTAINER_UPSCALE_CONFIG_APPLIED|UPSCALE_LAUNCH_ENV_NORMALIZED)|LAUNCH_EXEC_(SUBMIT|EXIT)|SESSION_EXIT_' \
    | tail -n "${WLT_LOGCAT_LINES}" > "${out_file}" || true
}

collect_app_snapshots() {
  local out_dir="$1"
  mkdir -p "${out_dir}"
  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'find ./files/imagefs/home -maxdepth 2 -name .container -print | sort'" \
    > "${out_dir}/containers-list.txt" 2>&1 || true
  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'for f in ./files/imagefs/home/xuser-*/.container; do [ -f \"\$f\" ] || continue; echo ===== \$f =====; cat \"\$f\"; echo; done'" \
    > "${out_dir}/containers-json.txt" 2>&1 || true
  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'find ./files/Winlator/logs -type f 2>/dev/null | sort'" \
    > "${out_dir}/app-log-files.txt" 2>&1 || true
  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'find ./files/Winlator/logs/forensics -type f 2>/dev/null | sort'" \
    > "${out_dir}/forensics-files.txt" 2>&1 || true
  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'for f in ./files/contents/Wine/*/profile.json; do [ -f \"\$f\" ] || continue; echo ===== \$f =====; cat \"\$f\"; echo; done'" \
    > "${out_dir}/wine-profiles.txt" 2>&1 || true
}

collect_sdcard_runtime_logs() {
  local out_dir="$1"
  adb_s shell "find /sdcard/Winlator/logs -maxdepth 1 -type f 2>/dev/null | sort" \
    > "${out_dir}/sdcard-runtime-logs-index.txt" 2>&1 || true
}

main() {
  local cid trace_id scenario_dir

  require_cmd adb
  mkdir -p "${WLT_OUT_DIR}"
  ADB_SERIAL_PICKED="$(pick_serial)"
  [[ -n "${ADB_SERIAL_PICKED}" ]] || fail "No active adb device"
  export ADB_SERIAL_PICKED

  log "Using device ${ADB_SERIAL_PICKED}"
  printf 'package=%s\nserial=%s\ntime=%s\n' "${WLT_PACKAGE}" "${ADB_SERIAL_PICKED}" "$(date -Is)" \
    > "${WLT_OUT_DIR}/session_meta.txt"

  for cid in ${WLT_CONTAINER_IDS}; do
    scenario_dir="${WLT_OUT_DIR}/container-${cid}"
    mkdir -p "${scenario_dir}"

    adb_s logcat -c || true
    trace_id="$(start_direct_route "${cid}")"
    printf '%s\n' "${trace_id}" > "${scenario_dir}/trace_id.txt"
    sleep "${WLT_WAIT_SEC}"

    adb_s logcat -d > "${scenario_dir}/logcat-full.txt" || true
    collect_logcat_filtered "${scenario_dir}/logcat-filtered.txt"
    adb_s shell dumpsys activity top > "${scenario_dir}/dumpsys-activity-top.txt" 2>/dev/null || true
    adb_s shell pidof "${WLT_PACKAGE}" > "${scenario_dir}/pid.txt" 2>/dev/null || true
    dump_ui "${scenario_dir}"
    collect_app_snapshots "${scenario_dir}"
    collect_sdcard_runtime_logs "${scenario_dir}"
  done

  log "Artifacts saved to ${WLT_OUT_DIR}"
}

main "$@"
