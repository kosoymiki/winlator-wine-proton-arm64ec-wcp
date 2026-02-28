#!/usr/bin/env bash
set -euo pipefail

log() { printf '[gamehub-capture] %s\n' "$*"; }
fail() { printf '[gamehub-capture][error] %s\n' "$*" >&2; exit 1; }

SCENARIO="${1:-}"
[[ -n "$SCENARIO" ]] || fail "usage: $0 <scenario-name>"

command -v adb >/dev/null 2>&1 || fail "adb not found"

PKG="${GH_PKG:-com.miHoYo.GenshinImpact}"
LAUNCH_COMPONENT="${GH_LAUNCH_COMPONENT:-${PKG}/com.xj.app.DeepLinkRouterActivity}"
DURATION="${GH_DURATION:-45}"
PS_INTERVAL="${GH_PS_INTERVAL:-3}"
WARMUP_SEC="${GH_WARMUP_SEC:-8}"
START_APP="${GH_START_APP:-1}"
CLEAR_LOGCAT="${GH_CLEAR_LOGCAT:-1}"
PULL_EXTERNAL_LOGS="${GH_PULL_EXTERNAL_LOGS:-1}"
OUT_ROOT="${GH_OUT_ROOT:-$(pwd)/out/gamehub-forensics}"
PKG_REGEX="${PKG//./[.]}"

SERIAL="${ADB_SERIAL:-}"
if [[ -z "$SERIAL" ]]; then
  SERIAL="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
fi
[[ -n "$SERIAL" ]] || fail "no active adb device"

TS="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="${OUT_ROOT}/${TS}_${SCENARIO}"
mkdir -p "$OUT_DIR" "$OUT_DIR/external_logs"

log "serial=${SERIAL} pkg=${PKG} scenario=${SCENARIO} duration=${DURATION}s"

{
  echo "timestamp=${TS}"
  echo "scenario=${SCENARIO}"
  echo "serial=${SERIAL}"
  echo "package=${PKG}"
  echo "duration=${DURATION}"
  echo "launch_component=${LAUNCH_COMPONENT}"
  echo "start_app=${START_APP}"
  echo "warmup_sec=${WARMUP_SEC}"
  echo "clear_logcat=${CLEAR_LOGCAT}"
} >"$OUT_DIR/metadata.txt"

if [[ "$CLEAR_LOGCAT" == "1" ]]; then
  adb -s "$SERIAL" logcat -c || true
fi

if [[ "$START_APP" == "1" ]]; then
  adb -s "$SERIAL" shell am start -n "$LAUNCH_COMPONENT" >"$OUT_DIR/am_start.txt" 2>&1 || true
  if [[ "$WARMUP_SEC" -gt 0 ]]; then
    sleep "$WARMUP_SEC"
  fi
fi

log "starting logcat capture"
adb -s "$SERIAL" logcat -v threadtime >"$OUT_DIR/logcat_threadtime.txt" 2>&1 &
LOGCAT_PID=$!

# Poll process tree repeatedly to correlate lifecycle and child process churn.
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
  for sub in log logs XiaoKunLogcat; do
    REMOTE="/storage/emulated/0/Android/data/${PKG}/files/${sub}"
    if adb -s "$SERIAL" shell "[ -d '$REMOTE' ]" >/dev/null 2>&1; then
      adb -s "$SERIAL" pull "$REMOTE" "$OUT_DIR/external_logs/" >/dev/null 2>&1 || true
    fi
  done
fi

if command -v rg >/dev/null 2>&1; then
  rg -n "(WineActivity|X11Controller|BufferQueue has been abandoned|stopWineLoading|setSelectContainer|winePath=|wineserver|wine C:|proton|box64|dxvk|vkd3d|FATAL EXCEPTION|ANR|SIGSEGV|abort|Exception)" -i \
    "$OUT_DIR/logcat_threadtime.txt" "$OUT_DIR/external_logs" >"$OUT_DIR/key_events.txt" 2>/dev/null || true
else
  grep -RinE "WineActivity|X11Controller|BufferQueue has been abandoned|stopWineLoading|setSelectContainer|winePath=|wineserver|wine C:|proton|box64|dxvk|vkd3d|FATAL EXCEPTION|ANR|SIGSEGV|abort|Exception" \
    "$OUT_DIR/logcat_threadtime.txt" "$OUT_DIR/external_logs" >"$OUT_DIR/key_events.txt" 2>/dev/null || true
fi

(
  cd "$OUT_ROOT"
  tar -czf "${TS}_${SCENARIO}.tar.gz" "${TS}_${SCENARIO}"
)

log "capture ready: $OUT_DIR"
log "archive: ${OUT_ROOT}/${TS}_${SCENARIO}.tar.gz"
