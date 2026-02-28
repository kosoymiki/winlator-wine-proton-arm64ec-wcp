#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

APK_GAMEHUB="${APK_GAMEHUB:-/home/mikhail/GameHub+5.3.5.Lite_RM.mod_DocProv_mod.apk}"
APK_GAMENATIVE="${APK_GAMENATIVE:-/home/mikhail/gamenative-v0.7.2.apk}"
RUN_CAPTURES="${RUN_CAPTURES:-1}"
CAPTURE_DURATION="${CAPTURE_DURATION:-90}"
SERIAL="${ADB_SERIAL:-}"

log() { printf '[full-cycle] %s\n' "$*"; }
fail() { printf '[full-cycle][error] %s\n' "$*" >&2; exit 1; }

[[ -f "$APK_GAMEHUB" ]] || fail "Missing APK_GAMEHUB: $APK_GAMEHUB"
[[ -f "$APK_GAMENATIVE" ]] || fail "Missing APK_GAMENATIVE: $APK_GAMENATIVE"

python3 ci/reverse/apk_native_reflective_cycle.py \
  --apk "$APK_GAMEHUB" \
  --out-dir docs/reverse/gamehub-5.3.5-native-cycle

python3 ci/reverse/apk_native_reflective_cycle.py \
  --apk "$APK_GAMENATIVE" \
  --out-dir docs/reverse/gamenative-0.7.2-native-cycle

python3 ci/reverse/compare_apk_native_cycles.py \
  --a docs/reverse/gamehub-5.3.5-native-cycle/SUMMARY.json \
  --b docs/reverse/gamenative-0.7.2-native-cycle/SUMMARY.json \
  --out docs/reverse/gamehub-vs-gamenative/CROSS_APK_NATIVE_COMPARISON.md

if [[ "$RUN_CAPTURES" == "1" ]]; then
  if [[ -z "$SERIAL" ]]; then
    SERIAL="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
  fi
  [[ -n "$SERIAL" ]] || fail "No adb device for capture stage"

  APP_START_APP=1 APP_DURATION="$CAPTURE_DURATION" APP_WARMUP_SEC=5 ADB_SERIAL="$SERIAL" \
    APP_PKG=app.gamenative APP_COMPONENT=app.gamenative/.MainActivityAliasDefault \
    ci/forensics/app_capture.sh gamenative_startup_live

  APP_START_APP=1 APP_DURATION="$CAPTURE_DURATION" APP_WARMUP_SEC=5 ADB_SERIAL="$SERIAL" \
    APP_PKG=com.miHoYo.GenshinImpact APP_COMPONENT=com.miHoYo.GenshinImpact/com.xj.app.DeepLinkRouterActivity \
    ci/forensics/app_capture.sh gamehub_startup_live

  APP_START_APP=1 APP_DURATION="$CAPTURE_DURATION" APP_WARMUP_SEC=5 ADB_SERIAL="$SERIAL" \
    APP_PKG=by.aero.so.benchmark APP_COMPONENT=by.aero.so.benchmark/com.winlator.cmod.MainActivity \
    ci/forensics/app_capture.sh aesolator_startup_live
fi

LATEST_GN="$(ls -1dt out/app-forensics/*gamenative_startup_live 2>/dev/null | head -n1 || true)"
LATEST_GH="$(ls -1dt out/app-forensics/*gamehub_startup_live 2>/dev/null | head -n1 || true)"
LATEST_AE="$(ls -1dt out/app-forensics/*aesolator_startup_live 2>/dev/null | head -n1 || true)"

REPORT="docs/reverse/gamehub-vs-gamenative/FULL_CYCLE_REPORT_$(date +%Y-%m-%d).md"
{
  echo "# Full Reflective Cycle Report"
  echo
  echo "- Date: $(date -Iseconds)"
  printf -- '- GameHub APK: `%s`\n' "$APK_GAMEHUB"
  printf -- '- GameNative APK: `%s`\n' "$APK_GAMENATIVE"
  printf -- '- Capture serial: `%s`\n' "${SERIAL:-n/a}"
  echo
  echo "## Static reverse outputs"
  echo
  echo "- \`docs/reverse/gamehub-5.3.5-native-cycle/\`"
  echo "- \`docs/reverse/gamenative-0.7.2-native-cycle/\`"
  echo "- \`docs/reverse/gamehub-vs-gamenative/CROSS_APK_NATIVE_COMPARISON.md\`"
  echo
  echo "## Runtime capture outputs"
  echo
  printf -- '- GameNative: `%s`\n' "${LATEST_GN:-missing}"
  printf -- '- GameHub: `%s`\n' "${LATEST_GH:-missing}"
  printf -- '- Ae.solator: `%s`\n' "${LATEST_AE:-missing}"
  echo
  for d in "$LATEST_GN" "$LATEST_GH" "$LATEST_AE"; do
    [[ -n "$d" && -d "$d" ]] || continue
    bn="$(basename "$d")"
    printf -- '## Capture metrics: `%s`\n' "$bn"
    echo
    if [[ -f "$d/metrics.env" ]]; then
      # shellcheck source=/dev/null
      . "$d/metrics.env"
      echo "- wineserver lines in ps_samples: **${ps_wineserver_count:-0}**"
      echo "- wine lines in ps_samples: **${ps_wine_count:-0}**"
      echo "- auth markers (logcat): **${logcat_auth_count:-0}**"
      echo "- auth markers (external): **${external_auth_count:-0}**"
      echo "- x11 markers (logcat): **${logcat_x11_count:-0}**"
      echo "- x11 markers (external): **${external_x11_count:-0}**"
      echo "- network markers (logcat): **${logcat_net_count:-0}**"
      echo "- network markers (external): **${external_net_count:-0}**"
      echo "- container setup markers (external): **${external_container_setup_count:-0}**"
    else
      wineserver_count="$( (rg -n 'wineserver' "$d/ps_samples.txt" 2>/dev/null || true) | wc -l | tr -d ' ' )"
      wine_count="$( (rg -n '\bwine\b' "$d/ps_samples.txt" 2>/dev/null || true) | wc -l | tr -d ' ' )"
      auth_count="$( (rg -n -i 'auth|login|token|steam' "$d/logcat_threadtime.txt" "$d/external_logs" 2>/dev/null || true) | wc -l | tr -d ' ' )"
      x11_count="$( (rg -n -i 'X11Controller|Windows Changed: 0 x 0|BufferQueue has been abandoned|WineActivity|destroySurface|NO_SURFACE|setWindowStopped stopped:true' "$d/logcat_threadtime.txt" "$d/external_logs" 2>/dev/null || true) | wc -l | tr -d ' ' )"
      net_count="$( (rg -n -i 'SocketTimeout|SSLHandshake|UnknownHost|failed to connect|DNS' "$d/logcat_threadtime.txt" "$d/external_logs" 2>/dev/null || true) | wc -l | tr -d ' ' )"
      echo "- wineserver lines in ps_samples: **$wineserver_count**"
      echo "- wine lines in ps_samples: **$wine_count**"
      echo "- auth/login/token/steam lines: **$auth_count**"
      echo "- x11/window teardown markers: **$x11_count**"
      echo "- network timeout/dns markers: **$net_count**"
    fi
    echo
  done

  echo "## Compliance note"
  echo
  echo "- This cycle does not include bypassing third-party authentication/account controls."
  echo "- Any gated container/emulation path that requires account rights is logged as an external constraint."
} > "$REPORT"

log "Report written: $REPORT"
