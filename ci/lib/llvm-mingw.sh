#!/usr/bin/env bash

llvm_log() {
  if declare -F log >/dev/null 2>&1; then
    log "$@"
  else
    printf '[llvm-mingw] %s\n' "$*"
  fi
}

llvm_fail() {
  if declare -F fail >/dev/null 2>&1; then
    fail "$@"
  else
    printf '[llvm-mingw][error] %s\n' "$*" >&2
    exit 1
  fi
}

download_release_asset() {
  local repo="$1"
  local tag="$2"
  local regex="$3"
  local output_file="$4"
  local api_url
  local asset_url

  api_url="https://api.github.com/repos/${repo}/releases/tags/${tag}"
  llvm_log "Resolving asset from ${repo}@${tag} (${regex})"

  asset_url="$({
    curl -fsSL "${api_url}" | python3 -c '
import json, re, sys
pattern = re.compile(sys.argv[1])
release = json.load(sys.stdin)
for asset in release.get("assets", []):
    name = asset.get("name", "")
    if pattern.search(name):
        print(asset["browser_download_url"])
        raise SystemExit(0)
raise SystemExit("no matching release asset")
' "${regex}"
  })" || llvm_fail "Unable to resolve release asset URL for ${repo}@${tag}"

  curl -fL --retry 5 --retry-delay 2 -o "${output_file}" "${asset_url}" \
    || llvm_fail "Failed downloading ${asset_url}"
}

ensure_llvm_mingw() {
  : "${LLVM_MINGW_TAG:=${LLVM_MINGW_VER:-20260210}}"
  : "${CACHE_DIR:=${PWD}/.cache}"
  : "${TOOLCHAIN_DIR:=${CACHE_DIR}/toolchain/llvm-mingw-${LLVM_MINGW_TAG}}"

  local tmp_archive extracted cfg_count wrapper_count

  mkdir -p "${CACHE_DIR}" "${CACHE_DIR}/toolchain"
  tmp_archive="${CACHE_DIR}/llvm-mingw-${LLVM_MINGW_TAG}.tar.xz"

  if [[ -x "${TOOLCHAIN_DIR}/bin/clang" ]]; then
    llvm_log "Using cached llvm-mingw at ${TOOLCHAIN_DIR}"
  else
    download_release_asset \
      "mstorsjo/llvm-mingw" \
      "${LLVM_MINGW_TAG}" \
      "llvm-mingw-.*-ucrt-ubuntu-.*-(aarch64|arm64)\\.tar\\.xz$" \
      "${tmp_archive}"

    tar -xJf "${tmp_archive}" -C "${CACHE_DIR}/toolchain" \
      || llvm_fail "Unable to extract ${tmp_archive}"
    extracted="$(find "${CACHE_DIR}/toolchain" -maxdepth 1 -mindepth 1 -type d -name 'llvm-mingw-*-ucrt-ubuntu-*' | sort | tail -n 1)"
    [[ -n "${extracted}" ]] || llvm_fail "Unable to locate extracted llvm-mingw directory"

    rm -rf "${TOOLCHAIN_DIR}"
    mv "${extracted}" "${TOOLCHAIN_DIR}"
  fi

  export TOOLCHAIN_DIR
  export LLVM_MINGW_DIR="${TOOLCHAIN_DIR}"
  export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"

  llvm_log "Toolchain clang: $(command -v clang)"
  clang --version | sed -n '1,2p'

  if command -v ld.lld >/dev/null 2>&1; then
    llvm_log "Toolchain lld: $(command -v ld.lld)"
    ld.lld --version | sed -n '1,2p'
  elif command -v lld >/dev/null 2>&1; then
    llvm_log "Toolchain lld: $(command -v lld)"
    lld --version | sed -n '1,2p'
  else
    llvm_fail "lld/ld.lld not found in llvm-mingw toolchain"
  fi

  llvm_log "Checking triplet cfg files:"
  find "${TOOLCHAIN_DIR}" -type f -name '*-w64-mingw32.cfg' | sed "s#^# - #"
  cfg_count="$(find "${TOOLCHAIN_DIR}" -type f -name '*-w64-mingw32.cfg' | wc -l | tr -d '[:space:]')"
  if [[ "${cfg_count}" == "0" ]]; then
    # Some llvm-mingw builds do not ship standalone *.cfg files.
    llvm_log "No triplet cfg files found; checking triplet wrapper binaries instead:"
    find "${TOOLCHAIN_DIR}/bin" -maxdepth 1 -type f \
      \( -name '*-w64-mingw32-clang' -o -name '*-w64-mingw32-clang++' \) \
      | sed "s#^# - #"
    wrapper_count="$(find "${TOOLCHAIN_DIR}/bin" -maxdepth 1 -type f \
      \( -name '*-w64-mingw32-clang' -o -name '*-w64-mingw32-clang++' \) \
      | wc -l | tr -d '[:space:]')"
    if [[ "${wrapper_count}" == "0" ]]; then
      llvm_log "No triplet wrapper binaries found either; printing available mingw markers:"
      find "${TOOLCHAIN_DIR}" -maxdepth 3 -type d -name '*-w64-mingw32*' | sed "s#^# - #"
      find "${TOOLCHAIN_DIR}/bin" -maxdepth 1 -type f | grep -E 'mingw|w64|ucrt' | sed "s#^# - #" || true
      llvm_log "Proceeding without cfg/wrapper hard requirement (toolchain may still be valid)."
    fi
  fi
}
