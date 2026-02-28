#!/usr/bin/env bash
set -euo pipefail

log() { printf '[app-capture] %s\n' "$*"; }
fail() { printf '[app-capture][error] %s\n' "$*" >&2; exit 1; }

count_matches() {
  local pattern="$1"
  shift || true
  if command -v rg >/dev/null 2>&1; then
    (rg -n -i "$pattern" "$@" 2>/dev/null || true) | wc -l | tr -d ' '
  else
    (grep -RinE "$pattern" "$@" 2>/dev/null || true) | wc -l | tr -d ' '
  fi
}

SCENARIO="${1:-}"
[[ -n "$SCENARIO" ]] || fail "usage: $0 <scenario-name>"

command -v adb >/dev/null 2>&1 || fail "adb not found"

PKG="${APP_PKG:-}"
[[ -n "$PKG" ]] || fail "APP_PKG is required"
COMPONENT="${APP_COMPONENT:-}"
DURATION="${APP_DURATION:-60}"
PS_INTERVAL="${APP_PS_INTERVAL:-3}"
WARMUP_SEC="${APP_WARMUP_SEC:-8}"
START_APP="${APP_START_APP:-1}"
CLEAR_LOGCAT="${APP_CLEAR_LOGCAT:-1}"
PULL_EXTERNAL_LOGS="${APP_PULL_EXTERNAL_LOGS:-1}"
OUT_ROOT="${APP_OUT_ROOT:-$(pwd)/out/app-forensics}"

PKG_REGEX="${PKG//./[.]}"

SERIAL="${ADB_SERIAL:-}"
if [[ -z "$SERIAL" ]]; then
  SERIAL="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
fi
[[ -n "$SERIAL" ]] || fail "no active adb device"

if [[ -z "$COMPONENT" ]]; then
  COMPONENT="$(adb -s "$SERIAL" shell cmd package resolve-activity --brief "$PKG" 2>/dev/null | tail -n 1 | tr -d '\r')"
fi

TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="${OUT_ROOT}/${TS}_${SCENARIO}"
mkdir -p "$OUT_DIR" "$OUT_DIR/external_logs"

log "serial=${SERIAL} pkg=${PKG} component=${COMPONENT} scenario=${SCENARIO} duration=${DURATION}s"

{
  echo "timestamp=${TS}"
  echo "scenario=${SCENARIO}"
  echo "serial=${SERIAL}"
  echo "package=${PKG}"
  echo "component=${COMPONENT}"
  echo "duration=${DURATION}"
  echo "start_app=${START_APP}"
  echo "warmup_sec=${WARMUP_SEC}"
  echo "clear_logcat=${CLEAR_LOGCAT}"
} >"$OUT_DIR/metadata.txt"

if [[ "$CLEAR_LOGCAT" == "1" ]]; then
  adb -s "$SERIAL" logcat -c || true
fi

if [[ "$START_APP" == "1" && -n "$COMPONENT" ]]; then
  adb -s "$SERIAL" shell am start -n "$COMPONENT" >"$OUT_DIR/am_start.txt" 2>&1 || true
  if [[ "$WARMUP_SEC" -gt 0 ]]; then
    sleep "$WARMUP_SEC"
  fi
fi

adb -s "$SERIAL" logcat -v threadtime >"$OUT_DIR/logcat_threadtime.txt" 2>&1 &
LOGCAT_PID=$!

END_EPOCH=$(( $(date +%s) + DURATION ))
while [[ $(date +%s) -lt $END_EPOCH ]]; do
  {
    echo "=== sample $(date +%Y-%m-%dT%H:%M:%S%z) ==="
    adb -s "$SERIAL" shell "ps -A -o USER,PID,PPID,NAME,ARGS | awk 'BEGIN{IGNORECASE=1} NR==1{print;next} {name=\$4; line=\$0; if (line ~ /${PKG_REGEX}/ || name ~ /(wine|wineserver|jwm|box64|fex|xserver|dxvk|vkd3d|linker64)/) print}'"
    echo
  } >>"$OUT_DIR/ps_samples.txt" 2>/dev/null || true
  sleep "$PS_INTERVAL"
done

kill "$LOGCAT_PID" >/dev/null 2>&1 || true
wait "$LOGCAT_PID" >/dev/null 2>&1 || true

adb -s "$SERIAL" shell "ps -A -o USER,PID,PPID,NAME,ARGS | awk 'BEGIN{IGNORECASE=1} NR==1{print;next} {name=\$4; line=\$0; if (line ~ /${PKG_REGEX}/ || name ~ /(wine|wineserver|jwm|box64|fex|xserver|dxvk|vkd3d|linker64)/) print}'" >"$OUT_DIR/ps_final.txt" 2>/dev/null || true
adb -s "$SERIAL" shell dumpsys activity processes >"$OUT_DIR/dumpsys_activity_processes.txt" 2>/dev/null || true
adb -s "$SERIAL" shell dumpsys activity top >"$OUT_DIR/dumpsys_activity_top.txt" 2>/dev/null || true
adb -s "$SERIAL" shell dumpsys package "$PKG" >"$OUT_DIR/dumpsys_package.txt" 2>/dev/null || true
adb -s "$SERIAL" shell pm path "$PKG" >"$OUT_DIR/pm_path.txt" 2>/dev/null || true

if [[ "$PULL_EXTERNAL_LOGS" == "1" ]]; then
  BASE="/storage/emulated/0/Android/data/${PKG}/files"
  if adb -s "$SERIAL" shell "[ -d '$BASE' ]" >/dev/null 2>&1; then
    adb -s "$SERIAL" pull "$BASE" "$OUT_DIR/external_logs/" >/dev/null 2>&1 || true
  fi
fi

KEY_PATTERN="(${PKG}|MainActivity|WineActivity|X11|BufferQueue|wineserver|winePath=|container|proton|box64|fex|dxvk|vkd3d|FATAL EXCEPTION|ANR|SIGSEGV|abort|Exception|SocketTimeout|SSL|DNS|login|auth|token)"
if command -v rg >/dev/null 2>&1; then
  rg -n "${KEY_PATTERN}" -i "$OUT_DIR/logcat_threadtime.txt" >"$OUT_DIR/key_events_logcat.txt" 2>/dev/null || true
  rg -n "${KEY_PATTERN}" -i "$OUT_DIR/external_logs" >"$OUT_DIR/key_events_external.txt" 2>/dev/null || true
else
  grep -RinE "${KEY_PATTERN}" "$OUT_DIR/logcat_threadtime.txt" >"$OUT_DIR/key_events_logcat.txt" 2>/dev/null || true
  grep -RinE "${KEY_PATTERN}" "$OUT_DIR/external_logs" >"$OUT_DIR/key_events_external.txt" 2>/dev/null || true
fi
cat "$OUT_DIR/key_events_logcat.txt" "$OUT_DIR/key_events_external.txt" >"$OUT_DIR/key_events.txt" 2>/dev/null || true

PS_WINESERVER_COUNT="$(count_matches 'wineserver' "$OUT_DIR/ps_samples.txt")"
PS_WINE_COUNT="$(count_matches '\\bwine\\b' "$OUT_DIR/ps_samples.txt")"
LOGCAT_AUTH_COUNT="$(count_matches 'auth|login|token|steam' "$OUT_DIR/logcat_threadtime.txt")"
EXTERNAL_AUTH_COUNT="$(count_matches 'auth|login|token|steam' "$OUT_DIR/external_logs")"
LOGCAT_X11_COUNT="$(count_matches 'X11Controller|Windows Changed: 0 x 0|BufferQueue has been abandoned|WineActivity|destroySurface|NO_SURFACE|setWindowStopped stopped:true|Starting up|startup' "$OUT_DIR/logcat_threadtime.txt")"
EXTERNAL_X11_COUNT="$(count_matches 'X11Controller|Windows Changed: 0 x 0|BufferQueue has been abandoned|WineActivity|destroySurface|NO_SURFACE|setWindowStopped stopped:true|Starting up|startup' "$OUT_DIR/external_logs")"
LOGCAT_NET_COUNT="$(count_matches 'SocketTimeout|SSLHandshake|UnknownHost|failed to connect|DNS|timeout' "$OUT_DIR/logcat_threadtime.txt")"
EXTERNAL_NET_COUNT="$(count_matches 'SocketTimeout|SSLHandshake|UnknownHost|failed to connect|DNS|timeout' "$OUT_DIR/external_logs")"
EXTERNAL_CONTAINER_SETUP_COUNT="$(count_matches 'PcEmuSetup|winePath=|Install Container|container setup|container ready|container installed' "$OUT_DIR/external_logs")"
WINE_PROCESS_PRESENT=0
if [[ "$PS_WINESERVER_COUNT" -gt 0 || "$PS_WINE_COUNT" -gt 0 ]]; then
  WINE_PROCESS_PRESENT=1
fi

{
  echo "ps_wineserver_count=$PS_WINESERVER_COUNT"
  echo "ps_wine_count=$PS_WINE_COUNT"
  echo "wine_process_present=$WINE_PROCESS_PRESENT"
  echo "logcat_auth_count=$LOGCAT_AUTH_COUNT"
  echo "external_auth_count=$EXTERNAL_AUTH_COUNT"
  echo "logcat_x11_count=$LOGCAT_X11_COUNT"
  echo "external_x11_count=$EXTERNAL_X11_COUNT"
  echo "logcat_net_count=$LOGCAT_NET_COUNT"
  echo "external_net_count=$EXTERNAL_NET_COUNT"
  echo "external_container_setup_count=$EXTERNAL_CONTAINER_SETUP_COUNT"
} >"$OUT_DIR/metrics.env"

python3 - "$OUT_DIR" "$SCENARIO" "$PKG" <<'PY'
import json
import sys
from pathlib import Path

out = Path(sys.argv[1])
scenario = sys.argv[2]
pkg = sys.argv[3]
env = {}
for line in (out / "metrics.env").read_text(encoding="utf-8").splitlines():
    if "=" not in line:
        continue
    k, v = line.split("=", 1)
    try:
        env[k] = int(v)
    except ValueError:
        env[k] = v
summary = {
    "scenario": scenario,
    "package": pkg,
    "metrics": env,
}
(out / "metrics.json").write_text(json.dumps(summary, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
PY

(
  cd "$OUT_ROOT"
  tar -czf "${TS}_${SCENARIO}.tar.gz" "${TS}_${SCENARIO}"
)

log "capture ready: $OUT_DIR"
log "archive: ${OUT_ROOT}/${TS}_${SCENARIO}.tar.gz"
