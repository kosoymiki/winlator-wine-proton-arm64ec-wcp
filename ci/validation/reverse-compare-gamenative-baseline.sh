#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

usage() {
  cat <<'EOF'
Usage:
  bash ci/validation/reverse-compare-gamenative-baseline.sh <target-wcp> <output-dir>

Env:
  WCP_GAMENATIVE_BASELINE_URL      URL to GameNative Proton 10.4 arm64ec WCP archive
  WCP_GAMENATIVE_BASELINE_SHA256   Optional SHA256 for downloaded baseline archive
  WCP_REVERSE_FULL_INVENTORY       1 enables full file inventory diff (default: 0 for CI speed)
  WCP_REVERSE_INVENTORY_PREFIXES   Space-separated prefixes for full inventory scope

Outputs:
  <output-dir>/gamenative-baseline-reverse.json
  <output-dir>/gamenative-baseline-reverse.md
EOF
}

fail() {
  printf '[reverse-compare][error] %s\n' "$*" >&2
  exit 1
}

log() {
  printf '[reverse-compare] %s\n' "$*"
}

sha256_file() {
  sha256sum "$1" | awk '{print $1}'
}

main() {
  local target_wcp="${1:-}"
  local output_dir="${2:-}"
  local baseline_url baseline_sha expected_sha actual_sha
  local baseline_path json_out md_out compare_input
  local -a reverse_args

  [[ -n "${target_wcp}" && -n "${output_dir}" ]] || { usage; fail "target-wcp and output-dir are required"; }
  [[ -f "${target_wcp}" || -d "${target_wcp}" ]] || fail "Target WCP path not found: ${target_wcp}"

  : "${WCP_GAMENATIVE_BASELINE_URL:=https://github.com/GameNative/proton-wine/releases/download/build-20260225-1/proton-wine-10.0-4-arm64ec.wcp.xz}"
  : "${WCP_GAMENATIVE_BASELINE_SHA256:=}"
  : "${WCP_REVERSE_FULL_INVENTORY:=0}"
  : "${WCP_REVERSE_INVENTORY_PREFIXES:=bin lib/wine/aarch64-unix lib/wine/aarch64-windows}"
  baseline_url="${WCP_GAMENATIVE_BASELINE_URL}"
  baseline_sha="${WCP_GAMENATIVE_BASELINE_SHA256}"

  mkdir -p "${output_dir}"
  TMP_GN_BASELINE_COMPARE_DIR="$(mktemp -d /tmp/gamenative_baseline_compare.XXXXXX)"
  trap 'rm -rf "${TMP_GN_BASELINE_COMPARE_DIR:-}"' EXIT

  baseline_path="${TMP_GN_BASELINE_COMPARE_DIR}/gamenative-proton10.4-arm64ec.wcp.xz"
  if [[ -f "${baseline_url}" ]]; then
    log "Using local baseline file: ${baseline_url}"
    cp -f "${baseline_url}" "${baseline_path}"
  else
    log "Downloading baseline: ${baseline_url}"
    curl -fL --retry 4 --retry-delay 2 --retry-connrefused -o "${baseline_path}" "${baseline_url}" || \
      fail "Failed to download baseline from ${baseline_url}"
  fi

  actual_sha="$(sha256_file "${baseline_path}")"
  if [[ -n "${baseline_sha}" ]]; then
    expected_sha="${baseline_sha,,}"
    if [[ "${actual_sha}" != "${expected_sha}" ]]; then
      fail "Baseline SHA mismatch: expected ${expected_sha}, got ${actual_sha}"
    fi
  fi

  json_out="${output_dir}/gamenative-baseline-reverse.json"
  md_out="${output_dir}/gamenative-baseline-reverse.md"
  compare_input="${target_wcp}"
  if [[ -f "${target_wcp}" ]]; then
    compare_input="${TMP_GN_BASELINE_COMPARE_DIR}/target.wcp"
    cp -f "${target_wcp}" "${compare_input}"
  fi
  reverse_args=(
    --input "${baseline_path}"
    --compare "${compare_input}"
    --output-json "${json_out}"
    --output-md "${md_out}"
  )
  if [[ "${WCP_REVERSE_FULL_INVENTORY}" == "1" ]]; then
    reverse_args+=(--full-inventory)
    for prefix in ${WCP_REVERSE_INVENTORY_PREFIXES}; do
      reverse_args+=(--inventory-prefix "${prefix}")
    done
  fi
  python3 ci/research/reverse-wcp-package.py "${reverse_args[@]}"

  log "Baseline SHA256: ${actual_sha}"
  log "Wrote ${json_out}"
  log "Wrote ${md_out}"
}

main "$@"
