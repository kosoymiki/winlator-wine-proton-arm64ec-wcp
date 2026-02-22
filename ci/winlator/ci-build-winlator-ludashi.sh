#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${WINLATOR_OUTPUT_DIR:-${ROOT_DIR}/out/winlator}"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work/winlator-ludashi}"
SRC_DIR="${WORK_DIR}/src"
LOG_DIR="${OUT_DIR}/logs"
INSPECT_DIR="${LOG_DIR}/inspect-upstream"
RUNTIME_ASSET_WORK_DIR="${WORK_DIR}/runtime-assets"
DOC_REPORT="${WINLATOR_ANALYSIS_REPORT:-${ROOT_DIR}/docs/WINLATOR_LUDASHI_REFLECTIVE_ANALYSIS.md}"

: "${WINLATOR_LUDASHI_REPO:=https://github.com/StevenMXZ/Winlator-Ludashi.git}"
: "${WINLATOR_LUDASHI_REF:=winlator_bionic}"
: "${WINLATOR_GRADLE_TASK:=assembleRelease}"
: "${WINLATOR_APK_BASENAME:=winlator-ludashi-arm64ec-fork}"

log() { printf '[winlator-ci] %s\n' "$*"; }
fail() { printf '[winlator-ci][error] %s\n' "$*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }

prepare_layout() {
  rm -rf "${WORK_DIR}"
  mkdir -p "${OUT_DIR}" "${LOG_DIR}" "${WORK_DIR}"
}

clone_upstream() {
  log "Cloning ${WINLATOR_LUDASHI_REPO} (${WINLATOR_LUDASHI_REF})"
  git clone --filter=blob:none "${WINLATOR_LUDASHI_REPO}" "${SRC_DIR}"
  git -C "${SRC_DIR}" fetch --tags --force
  git -C "${SRC_DIR}" checkout "${WINLATOR_LUDASHI_REF}"
  git -C "${SRC_DIR}" rev-parse HEAD > "${LOG_DIR}/upstream-head.txt"
}

inspect_upstream() {
  bash "${ROOT_DIR}/ci/winlator/inspect-upstream.sh" "${SRC_DIR}" "${INSPECT_DIR}"
  bash "${ROOT_DIR}/ci/winlator/generate-reflective-analysis.sh" \
    "${INSPECT_DIR}/commits.tsv" \
    "${DOC_REPORT}" \
    "${WINLATOR_LUDASHI_REPO}"
}

apply_patches() {
  bash "${ROOT_DIR}/ci/winlator/apply-repo-patches.sh" "${SRC_DIR}" "${ROOT_DIR}/ci/winlator/patches"
  git -C "${SRC_DIR}" diff --stat > "${LOG_DIR}/patch-diffstat.log"
  git -C "${SRC_DIR}" diff > "${LOG_DIR}/patch.diff"
}

prepare_runtime_assets() {
  bash "${ROOT_DIR}/ci/winlator/materialize-runtime-assets.sh" "${SRC_DIR}/app/src/main/assets" "${RUNTIME_ASSET_WORK_DIR}"
  cp -f "${SRC_DIR}/app/src/main/assets/embedded-runtime-SHA256SUMS" "${LOG_DIR}/embedded-runtime-SHA256SUMS"
}

build_apk() {
  local apk_path upstream_sha out_apk

  chmod +x "${SRC_DIR}/gradlew"
  pushd "${SRC_DIR}" >/dev/null
  ./gradlew --no-daemon "${WINLATOR_GRADLE_TASK}"
  popd >/dev/null

  apk_path="$(find "${SRC_DIR}/app/build/outputs/apk" -type f \( -name '*release*.apk' -o -name '*-unsigned.apk' \) | sort | head -n1)"
  [[ -n "${apk_path}" ]] || fail "Unable to locate built APK under app/build/outputs/apk"

  upstream_sha="$(git -C "${SRC_DIR}" rev-parse --short HEAD)"
  out_apk="${OUT_DIR}/${WINLATOR_APK_BASENAME}-${upstream_sha}.apk"
  cp -f "${apk_path}" "${out_apk}"

  (
    cd "${OUT_DIR}"
    sha256sum "$(basename -- "${out_apk}")" > SHA256SUMS
  )

  log "Built APK: ${out_apk}"
}

main() {
  require_cmd bash
  require_cmd git
  require_cmd curl
  require_cmd tar
  require_cmd python3
  require_cmd sha256sum

  prepare_layout
  clone_upstream
  inspect_upstream
  apply_patches
  prepare_runtime_assets
  build_apk
}

main "$@"
