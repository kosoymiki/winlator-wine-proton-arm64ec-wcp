#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

ADB_SERIAL="${ADB_SERIAL:-}"
WCP_PROTON104="${WCP_PROTON104:-/home/mikhail/Загрузки/proton-10-4-arm64ec.wcp.xz}"
GAMEHUB_APK_LOCAL="${GAMEHUB_APK_LOCAL:-/home/mikhail/GameHub+5.3.5.Lite_RM.mod_DocProv_mod.apk}"
GAMENATIVE_APK_LOCAL="${GAMENATIVE_APK_LOCAL:-/home/mikhail/gamenative-v0.7.2.apk}"
OUT_ROOT="${OUT_ROOT:-docs/reverse/deep-ide}"
SRC_ROOT="${SRC_ROOT:-out/reverse/sources}"
SKIP_ANALYSIS="${SKIP_ANALYSIS:-0}"
DEEP_FAIL_ON_CAPTURE_CONTRACT="${DEEP_FAIL_ON_CAPTURE_CONTRACT:-0}"

log() { printf '[deep-ide] %s\n' "$*"; }
warn() { printf '[deep-ide][warn] %s\n' "$*" >&2; }

mkdir -p "$OUT_ROOT" "$SRC_ROOT/device"

if [[ -z "$ADB_SERIAL" ]]; then
  ADB_SERIAL="$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')"
fi

if [[ -z "$ADB_SERIAL" ]]; then
  warn "No adb device detected; device sources will be skipped"
fi

declare -a ANALYSIS_TARGETS=()

add_target() {
  local label="$1"
  local src="$2"
  if [[ -e "$src" ]]; then
    ANALYSIS_TARGETS+=("$label|$src")
  else
    warn "Missing source for $label: $src"
  fi
}

add_target "proton104_wcp_local" "$WCP_PROTON104"
add_target "gamehub_apk_local" "$GAMEHUB_APK_LOCAL"
add_target "gamenative_apk_local" "$GAMENATIVE_APK_LOCAL"

if [[ -n "$ADB_SERIAL" ]]; then
  log "Collecting device APKs and package artifacts from $ADB_SERIAL"

  for pkg in app.gamenative com.miHoYo.GenshinImpact by.aero.so.benchmark; do
    apk_path="$(adb -s "$ADB_SERIAL" shell pm path "$pkg" 2>/dev/null | sed -n 's/^package://p' | head -n1 | tr -d '\r')"
    if [[ -n "$apk_path" ]]; then
      out_apk="$SRC_ROOT/device/${pkg//./_}.base.apk"
      adb -s "$ADB_SERIAL" pull "$apk_path" "$out_apk" >/dev/null
      add_target "${pkg//./_}_apk_device" "$out_apk"
    else
      warn "Unable to resolve package path for $pkg"
    fi
  done

  # Pull downloadable package files that are commonly used in the current workflow.
  while IFS= read -r remote_file; do
    [[ -n "$remote_file" ]] || continue
    base="$(basename "$remote_file")"
    out_file="$SRC_ROOT/device/$base"
    adb -s "$ADB_SERIAL" pull "$remote_file" "$out_file" >/dev/null || { warn "Failed to pull $remote_file"; continue; }
    add_target "device_${base//[^A-Za-z0-9_]/_}" "$out_file"
  done < <(
    adb -s "$ADB_SERIAL" shell \
      'find /sdcard/Download -maxdepth 2 -type f 2>/dev/null | grep -Ei "(proton|wine|vkd3d|arm64ec|\\.wcp(\\.xz)?$)"' \
      | tr -d '\r'
  )

  # Pull Ae.solator container Wine contents for per-library reflective analysis.
  for wine_dir in 10.0-4-arm64ec-1 11-arm64ec-1; do
    local_tar="$SRC_ROOT/device/by_aero_so_benchmark_${wine_dir}.tar"
    local_dir="$SRC_ROOT/device/by_aero_so_benchmark_${wine_dir}"
    if adb -s "$ADB_SERIAL" exec-out run-as by.aero.so.benchmark \
      sh -c "tar -cf - -C files/contents/Wine \"$wine_dir\" 2>/dev/null" > "$local_tar"; then
      mkdir -p "$local_dir"
      tar -xf "$local_tar" -C "$local_dir"
      add_target "aesolator_contents_${wine_dir//[^A-Za-z0-9_]/_}" "$local_dir/$wine_dir"
    else
      warn "Unable to extract by.aero.so.benchmark contents/$wine_dir via run-as"
    fi
  done

  # Pull external logs from GameHub package for forensic correlation.
  gamehub_log_dir="$SRC_ROOT/device/gamehub_external_logs"
  mkdir -p "$gamehub_log_dir"
  adb -s "$ADB_SERIAL" pull /sdcard/Android/data/com.miHoYo.GenshinImpact/files "$gamehub_log_dir" >/dev/null 2>&1 || true
fi

log "Running IDE reflective cycle on ${#ANALYSIS_TARGETS[@]} sources"

declare -a SUMMARIES=()
declare -a FAILED_TARGETS=()
if [[ "$SKIP_ANALYSIS" == "1" ]]; then
  for row in "${ANALYSIS_TARGETS[@]}"; do
    label="${row%%|*}"
    out_dir="$OUT_ROOT/$label"
    if [[ -f "$out_dir/SUMMARY.json" ]]; then
      SUMMARIES+=("$out_dir/SUMMARY.json")
    fi
  done
else
  for row in "${ANALYSIS_TARGETS[@]}"; do
    label="${row%%|*}"
    src="${row#*|}"
    out_dir="$OUT_ROOT/$label"
    if python3 ci/reverse/elf_ide_reflective_cycle.py \
      --source "$src" \
      --label "$label" \
      --out-dir "$out_dir"; then
      SUMMARIES+=("$out_dir/SUMMARY.json")
    else
      warn "Analyzer failed for $label ($src)"
      FAILED_TARGETS+=("$label")
    fi
  done
fi

if [[ "${#SUMMARIES[@]}" -ge 2 ]]; then
  cmd=(python3 ci/reverse/compare_ide_cycles.py)
  for s in "${SUMMARIES[@]}"; do
    cmd+=(--summary "$s")
  done
  cmd+=(--out "$OUT_ROOT/CROSS_SOURCE_IDE_COMPARISON.md")
  "${cmd[@]}"
fi

REPORT="$OUT_ROOT/DEEP_IDE_CYCLE_REPORT_$(date +%Y-%m-%d).md"
LATEST_GN="$(ls -1dt out/app-forensics/*_gamenative_deep_ide 2>/dev/null | head -n1 || true)"
LATEST_GH="$(ls -1dt out/app-forensics/*_gamehub_deep_ide 2>/dev/null | head -n1 || true)"
LATEST_AE="$(ls -1dt out/app-forensics/*_aesolator_deep_ide 2>/dev/null | head -n1 || true)"
CONTRACT_DIR="$OUT_ROOT/capture-contracts"
mkdir -p "$CONTRACT_DIR"
contract_rc=0

if [[ -n "$LATEST_GN" && -d "$LATEST_GN" && -f "$LATEST_GN/metrics.json" ]]; then
  python3 ci/validation/check-app-capture-contract.py \
    --capture-dir "$LATEST_GN" \
    --expect-wine-process optional \
    --min-external-container-setup-count 0 \
    --out "$CONTRACT_DIR/gamenative.md" || contract_rc=1
fi

if [[ -n "$LATEST_GH" && -d "$LATEST_GH" && -f "$LATEST_GH/metrics.json" ]]; then
  python3 ci/validation/check-app-capture-contract.py \
    --capture-dir "$LATEST_GH" \
    --expect-wine-process optional \
    --min-external-container-setup-count 1 \
    --out "$CONTRACT_DIR/gamehub.md" || contract_rc=1
fi

if [[ -n "$LATEST_AE" && -d "$LATEST_AE" && -f "$LATEST_AE/metrics.json" ]]; then
  python3 ci/validation/check-app-capture-contract.py \
    --capture-dir "$LATEST_AE" \
    --expect-wine-process required \
    --min-external-container-setup-count 0 \
    --out "$CONTRACT_DIR/aesolator.md" || contract_rc=1
fi

{
  echo "# Deep IDE Reflective Cycle Report"
  echo
  echo "- Date: $(date -Iseconds)"
  echo "- Device: ${ADB_SERIAL:-none}"
  echo "- Sources analyzed: **${#ANALYSIS_TARGETS[@]}**"
  echo
  echo "## Source list"
  echo
  for row in "${ANALYSIS_TARGETS[@]}"; do
    label="${row%%|*}"
    src="${row#*|}"
    echo "- \`$label\`: \`$src\`"
  done
  echo
  echo "## Outputs"
  echo
  echo "- Per-source reports: \`$OUT_ROOT/<label>/IDE_REFLECTIVE_REPORT.md\`"
  echo "- Per-source matrix: \`$OUT_ROOT/<label>/LIBRARY_MATRIX.tsv\`"
  echo "- Per-library raw IDE artifacts: \`$OUT_ROOT/<label>/libs/*\`"
  if [[ -f "$OUT_ROOT/CROSS_SOURCE_IDE_COMPARISON.md" ]]; then
    echo "- Cross-source comparison: \`$OUT_ROOT/CROSS_SOURCE_IDE_COMPARISON.md\`"
  fi
  if [[ "${#FAILED_TARGETS[@]}" -gt 0 ]]; then
    echo "- Failed targets: \`${FAILED_TARGETS[*]}\`"
  fi
  echo
  echo "## Runtime capture correlation (latest deep_ide runs)"
  echo
  printf -- '- GameNative capture: `%s`\n' "${LATEST_GN:-missing}"
  printf -- '- GameHub capture: `%s`\n' "${LATEST_GH:-missing}"
  printf -- '- Ae.solator capture: `%s`\n' "${LATEST_AE:-missing}"
  echo "- Capture contract reports: \`$CONTRACT_DIR/*.md\`"
  echo "- Capture contract rc: \`$contract_rc\`"
  echo
  for d in "$LATEST_GN" "$LATEST_GH" "$LATEST_AE"; do
    [[ -n "$d" && -d "$d" ]] || continue
    bn="$(basename "$d")"
    if [[ -f "$d/metrics.env" ]]; then
      # shellcheck source=/dev/null
      . "$d/metrics.env"
      printf -- '- `%s`: wineserver=%s, wine=%s, auth_logcat=%s, auth_external=%s, x11_logcat=%s, x11_external=%s, net_logcat=%s, net_external=%s, container_setup_external=%s\n' \
        "$bn" \
        "${ps_wineserver_count:-0}" \
        "${ps_wine_count:-0}" \
        "${logcat_auth_count:-0}" \
        "${external_auth_count:-0}" \
        "${logcat_x11_count:-0}" \
        "${external_x11_count:-0}" \
        "${logcat_net_count:-0}" \
        "${external_net_count:-0}" \
        "${external_container_setup_count:-0}"
    else
      wineserver_count="$( (rg -n 'wineserver' "$d/ps_samples.txt" 2>/dev/null || true) | wc -l | tr -d ' ' )"
      wine_count="$( (rg -n '\bwine\b' "$d/ps_samples.txt" 2>/dev/null || true) | wc -l | tr -d ' ' )"
      auth_count="$( (rg -n -i 'auth|login|token|steam' "$d/logcat_threadtime.txt" "$d/external_logs" 2>/dev/null || true) | wc -l | tr -d ' ' )"
      x11_count="$( (rg -n -i 'X11Controller|Windows Changed: 0 x 0|BufferQueue has been abandoned|WineActivity|destroySurface|NO_SURFACE|setWindowStopped stopped:true|Starting up|startup' "$d/logcat_threadtime.txt" "$d/external_logs" 2>/dev/null || true) | wc -l | tr -d ' ' )"
      net_count="$( (rg -n -i 'SocketTimeout|SSLHandshake|UnknownHost|failed to connect|DNS|timeout' "$d/logcat_threadtime.txt" "$d/external_logs" 2>/dev/null || true) | wc -l | tr -d ' ' )"
      printf -- '- `%s`: wineserver=%s, wine=%s, auth_markers=%s, x11_markers=%s, net_markers=%s\n' \
        "$bn" "$wineserver_count" "$wine_count" "$auth_count" "$x11_count" "$net_count"
    fi
  done
  echo
  echo "## Constraint notes"
  echo
  echo "- Non-debuggable third-party app private data is not accessed directly."
  echo "- No authentication/account bypass is performed in this cycle."
} > "$REPORT"

log "Deep IDE report: $REPORT"
if [[ "$DEEP_FAIL_ON_CAPTURE_CONTRACT" == "1" && "$contract_rc" -ne 0 ]]; then
  exit 1
fi
