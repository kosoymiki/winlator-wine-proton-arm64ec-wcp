#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${WINLATOR_OUTPUT_DIR:-${ROOT_DIR}/out/winlator}"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work/winlator-ludashi}"
SRC_DIR="${WORK_DIR}/src"
LOG_DIR="${OUT_DIR}/logs"
INSPECT_DIR="${LOG_DIR}/inspect-upstream"
DOC_REPORT="${WINLATOR_ANALYSIS_REPORT:-${ROOT_DIR}/docs/WINLATOR_LUDASHI_REFLECTIVE_ANALYSIS.md}"
PATCH_AUDIT_REPORT="${WINLATOR_PATCH_AUDIT_REPORT:-${ROOT_DIR}/docs/PATCH_STACK_REFLECTIVE_AUDIT.md}"
RUNTIME_CONTRACT_AUDIT_REPORT="${WINLATOR_RUNTIME_CONTRACT_AUDIT_REPORT:-${ROOT_DIR}/docs/PATCH_STACK_RUNTIME_CONTRACT_AUDIT.md}"

: "${WINLATOR_LUDASHI_REPO:=https://github.com/StevenMXZ/Winlator-Ludashi.git}"
: "${WINLATOR_LUDASHI_REF:=winlator_bionic}"
: "${WINLATOR_GRADLE_TASK:=assembleDebug}"
: "${WINLATOR_APK_BASENAME:=by.aero.so.benchmark-debug}"

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
  # Ensure binary assets/submodules (adrenotools, pngs) are present.
  if command -v git-lfs >/dev/null 2>&1; then
    git -C "${SRC_DIR}" lfs install --local || true
    git -C "${SRC_DIR}" lfs pull || true
  fi
  git -C "${SRC_DIR}" submodule update --init --recursive || true
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
  bash "${ROOT_DIR}/ci/winlator/run-reflective-audits.sh" \
    "${ROOT_DIR}/ci/winlator/patches" \
    "${PATCH_AUDIT_REPORT}" \
    "${RUNTIME_CONTRACT_AUDIT_REPORT}"
  bash "${ROOT_DIR}/ci/winlator/assets-fixes/remove-broken-anim.sh" "${SRC_DIR}"
  git -C "${SRC_DIR}" diff --stat > "${LOG_DIR}/patch-diffstat.log"
  git -C "${SRC_DIR}" diff > "${LOG_DIR}/patch.diff"
  cp -f "${PATCH_AUDIT_REPORT}" "${LOG_DIR}/patch-stack-reflective-audit.md"
  cp -f "${RUNTIME_CONTRACT_AUDIT_REPORT}" "${LOG_DIR}/patch-stack-runtime-contract-audit.md"
}

build_apk() {
  local apk_path upstream_sha out_apk

  chmod +x "${SRC_DIR}/gradlew"
  pushd "${SRC_DIR}" >/dev/null
  ./gradlew --no-daemon "${WINLATOR_GRADLE_TASK}"
  popd >/dev/null

  apk_path="$(find "${SRC_DIR}/app/build/outputs/apk" -type f -name '*.apk' | sort | head -n1)"
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
  build_apk
}

main "$@"
