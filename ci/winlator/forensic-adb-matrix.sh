#!/usr/bin/env bash
set -euo pipefail

: "${WLT_PACKAGE:=by.aero.so.benchmark}"
: "${WLT_ACTIVITY:=com.winlator.cmod.XServerDisplayActivity}"
: "${WLT_CONTAINER_ID:=1}"
: "${WLT_LOGCAT_LINES:=400}"

log() { printf '[forensic-adb] %s\n' "$*"; }
fail() { printf '[forensic-adb][error] %s\n' "$*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

adb_start_direct_forensic() {
  local trace_id
  trace_id="adb-$(date +%s)"
  log "Starting direct forensic route (container=${WLT_CONTAINER_ID}, trace=${trace_id})"
  adb shell am start \
    -n "${WLT_PACKAGE}/${WLT_ACTIVITY}" \
    --ez forensic_mode true \
    --es forensic_trace_id "${trace_id}" \
    --es forensic_route_source direct_diag_adb \
    --ez forensic_skip_playtime true \
    --ei container_id "${WLT_CONTAINER_ID}" >/dev/null
  printf '%s\n' "${trace_id}"
}

collect_logcat_forensic() {
  local out_file="$1"
  adb logcat -d | grep -E 'ForensicLogger|Forensic' | tail -n "${WLT_LOGCAT_LINES}" > "${out_file}" || true
}

collect_app_forensic_files() {
  local out_dir="$1"
  mkdir -p "${out_dir}"
  adb shell "run-as ${WLT_PACKAGE} sh -c 'find ./files -type f | grep -E \"forensics_.*\\.jsonl$|/forensics/\" | sort'" \
    > "${out_dir}/app-forensics-files.txt" 2>&1 || true
}

main() {
  local tmp_dir trace_id
  require_cmd adb
  tmp_dir="${TMPDIR:-/tmp}/forensic-adb-$(date +%s)"
  mkdir -p "${tmp_dir}"

  adb logcat -c || true
  trace_id="$(adb_start_direct_forensic)"
  sleep 3

  collect_logcat_forensic "${tmp_dir}/logcat-forensics.txt"
  collect_app_forensic_files "${tmp_dir}"

  log "Artifacts saved to ${tmp_dir}"
  log "trace_id=${trace_id}"
  log "Tip: inspect ${tmp_dir}/logcat-forensics.txt and app-forensics-files.txt"
}

main "$@"
