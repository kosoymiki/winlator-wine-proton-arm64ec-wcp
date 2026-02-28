#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${WLT_RELEASE_PREP_OUT_DIR:=/tmp/release-patch-base-$(date +%Y%m%d_%H%M%S)}"
: "${WLT_RELEASE_PREP_SOURCE_DIR:=${ROOT_DIR}/work/winlator-ludashi/src}"
: "${WLT_RELEASE_PREP_REQUIRE_SOURCE:=0}"
: "${WLT_RELEASE_PREP_RUN_PATCH_BASE:=0}"
: "${WLT_RELEASE_PREP_PATCH_BASE_PROFILE:=standard}"
: "${WLT_RELEASE_PREP_PATCH_BASE_PHASE:=all}"
: "${WLT_RELEASE_PREP_RUN_CONTENTS_QA:=1}"
: "${WLT_RELEASE_PREP_RUN_WCP_PARITY:=1}"
: "${WLT_RELEASE_PREP_WCP_PARITY_REQUIRE_ANY:=0}"
: "${WLT_RELEASE_PREP_WCP_PARITY_FAIL_ON_MISSING:=0}"
: "${WLT_RELEASE_PREP_WCP_PARITY_PAIRS_FILE:=${ROOT_DIR}/ci/validation/wcp-parity-pairs.tsv}"
: "${WLT_RELEASE_PREP_WCP_PARITY_LABELS:=}"
: "${WLT_RELEASE_PREP_REQUIRED_LOW_MARKERS:=DXVK,D8VK,VKD3D,PROOT_TMP_DIR,BOX64_LOG,WINEDEBUG,MESA_VK_WSI_PRESENT_MODE,TU_DEBUG,WINE_OPEN_WITH_ANDROID_BROWSER}"
: "${WLT_RELEASE_PREP_REQUIRE_LOW_READY_VALIDATED:=1}"
: "${WLT_RELEASE_PREP_INTAKE_SCOPE:=focused}"
: "${WLT_RELEASE_PREP_RUN_COMMIT_SCAN:=1}"
: "${WLT_RELEASE_PREP_COMMIT_SCAN_PROFILE:=core}"
: "${WLT_RELEASE_PREP_COMMIT_SCAN_COMMITS_PER_REPO:=12}"
: "${WLT_RELEASE_PREP_RUN_HARVEST:=1}"
: "${WLT_RELEASE_PREP_HARVEST_PROFILE:=core}"
: "${WLT_RELEASE_PREP_HARVEST_MAX_COMMITS_PER_REPO:=24}"
: "${WLT_RELEASE_PREP_HARVEST_APPLY:=1}"
: "${WLT_RELEASE_PREP_HARVEST_SKIP_NO_SYNC:=1}"
: "${WLT_RELEASE_PREP_HARVEST_AUTO_FOCUS_SYNC:=1}"
: "${WLT_RELEASE_PREP_HARVEST_INCLUDE_UNMAPPED:=1}"
: "${WLT_RELEASE_PREP_SYNC_BRANCH_PINS:=1}"
: "${WLT_RELEASE_PREP_HARVEST_FAIL_ON_REPO_ERRORS:=0}"

log() { printf '[release-patch-base] %s\n' "$*"; }
fail() { printf '[release-patch-base][error] %s\n' "$*" >&2; exit 1; }

[[ "${WLT_RELEASE_PREP_REQUIRE_SOURCE}" =~ ^[01]$ ]] || fail "WLT_RELEASE_PREP_REQUIRE_SOURCE must be 0 or 1"
[[ "${WLT_RELEASE_PREP_RUN_PATCH_BASE}" =~ ^[01]$ ]] || fail "WLT_RELEASE_PREP_RUN_PATCH_BASE must be 0 or 1"
[[ "${WLT_RELEASE_PREP_PATCH_BASE_PROFILE}" =~ ^(standard|wide|single)$ ]] || fail "WLT_RELEASE_PREP_PATCH_BASE_PROFILE must be standard, wide or single"
[[ "${WLT_RELEASE_PREP_RUN_CONTENTS_QA}" =~ ^[01]$ ]] || fail "WLT_RELEASE_PREP_RUN_CONTENTS_QA must be 0 or 1"
[[ "${WLT_RELEASE_PREP_RUN_WCP_PARITY}" =~ ^[01]$ ]] || fail "WLT_RELEASE_PREP_RUN_WCP_PARITY must be 0 or 1"
[[ "${WLT_RELEASE_PREP_WCP_PARITY_REQUIRE_ANY}" =~ ^[01]$ ]] || fail "WLT_RELEASE_PREP_WCP_PARITY_REQUIRE_ANY must be 0 or 1"
[[ "${WLT_RELEASE_PREP_WCP_PARITY_FAIL_ON_MISSING}" =~ ^[01]$ ]] || fail "WLT_RELEASE_PREP_WCP_PARITY_FAIL_ON_MISSING must be 0 or 1"
[[ "${WLT_RELEASE_PREP_REQUIRE_LOW_READY_VALIDATED}" =~ ^[01]$ ]] || fail "WLT_RELEASE_PREP_REQUIRE_LOW_READY_VALIDATED must be 0 or 1"
[[ "${WLT_RELEASE_PREP_INTAKE_SCOPE}" =~ ^(focused|tree)$ ]] || fail "WLT_RELEASE_PREP_INTAKE_SCOPE must be focused or tree"
[[ "${WLT_RELEASE_PREP_RUN_COMMIT_SCAN}" =~ ^[01]$ ]] || fail "WLT_RELEASE_PREP_RUN_COMMIT_SCAN must be 0 or 1"
[[ "${WLT_RELEASE_PREP_COMMIT_SCAN_PROFILE}" =~ ^(core|all|custom)$ ]] || fail "WLT_RELEASE_PREP_COMMIT_SCAN_PROFILE must be core, all or custom"
[[ "${WLT_RELEASE_PREP_COMMIT_SCAN_COMMITS_PER_REPO}" =~ ^[0-9]+$ ]] || fail "WLT_RELEASE_PREP_COMMIT_SCAN_COMMITS_PER_REPO must be numeric"
[[ "${WLT_RELEASE_PREP_RUN_HARVEST}" =~ ^[01]$ ]] || fail "WLT_RELEASE_PREP_RUN_HARVEST must be 0 or 1"
[[ "${WLT_RELEASE_PREP_HARVEST_SKIP_NO_SYNC}" =~ ^[01]$ ]] || fail "WLT_RELEASE_PREP_HARVEST_SKIP_NO_SYNC must be 0 or 1"
[[ "${WLT_RELEASE_PREP_HARVEST_AUTO_FOCUS_SYNC}" =~ ^[01]$ ]] || fail "WLT_RELEASE_PREP_HARVEST_AUTO_FOCUS_SYNC must be 0 or 1"
[[ "${WLT_RELEASE_PREP_HARVEST_INCLUDE_UNMAPPED}" =~ ^[01]$ ]] || fail "WLT_RELEASE_PREP_HARVEST_INCLUDE_UNMAPPED must be 0 or 1"
[[ "${WLT_RELEASE_PREP_SYNC_BRANCH_PINS}" =~ ^[01]$ ]] || fail "WLT_RELEASE_PREP_SYNC_BRANCH_PINS must be 0 or 1"
[[ "${WLT_RELEASE_PREP_HARVEST_FAIL_ON_REPO_ERRORS}" =~ ^[01]$ ]] || fail "WLT_RELEASE_PREP_HARVEST_FAIL_ON_REPO_ERRORS must be 0 or 1"

mkdir -p "${WLT_RELEASE_PREP_OUT_DIR}"

run_capture() {
  local name="$1"; shift
  local out="${WLT_RELEASE_PREP_OUT_DIR}/${name}.log"
  log "running ${name}"
  if "$@" >"${out}" 2>&1; then
    log "ok: ${name}"
  else
    tail -n 120 "${out}" >&2 || true
    fail "${name} failed (see ${out})"
  fi
}

main() {
  local commit_scan_json
  commit_scan_json="${WLT_RELEASE_PREP_OUT_DIR}/online-intake/commit-scan.json"

  if [[ "${WLT_RELEASE_PREP_RUN_COMMIT_SCAN}" == "1" ]]; then
    run_capture commit-scan \
      env \
        ONLINE_COMMIT_SCAN_OUT_DIR="${WLT_RELEASE_PREP_OUT_DIR}/online-intake" \
        ONLINE_COMMIT_SCAN_PROFILE="${WLT_RELEASE_PREP_COMMIT_SCAN_PROFILE}" \
        ONLINE_COMMIT_SCAN_COMMITS_PER_REPO="${WLT_RELEASE_PREP_COMMIT_SCAN_COMMITS_PER_REPO}" \
        bash "${ROOT_DIR}/ci/reverse/online-commit-scan.sh"
  fi

  run_capture reflective-audits \
    bash "${ROOT_DIR}/ci/winlator/run-reflective-audits.sh"

  if [[ "${WLT_RELEASE_PREP_RUN_CONTENTS_QA}" == "1" ]]; then
    run_capture contents-qa \
      python3 "${ROOT_DIR}/ci/validation/check-contents-qa-contract.py" \
        --root "${ROOT_DIR}" \
        --output "${WLT_RELEASE_PREP_OUT_DIR}/contents-qa.md"
  else
    log "skip: contents-qa (WLT_RELEASE_PREP_RUN_CONTENTS_QA=0)"
  fi

  if [[ "${WLT_RELEASE_PREP_RUN_WCP_PARITY}" == "1" ]]; then
    run_capture wcp-parity \
      env \
        WLT_WCP_PARITY_OUT_DIR="${WLT_RELEASE_PREP_OUT_DIR}/wcp-parity" \
        WLT_WCP_PARITY_PAIRS_FILE="${WLT_RELEASE_PREP_WCP_PARITY_PAIRS_FILE}" \
        WLT_WCP_PARITY_REQUIRE_ANY="${WLT_RELEASE_PREP_WCP_PARITY_REQUIRE_ANY}" \
        WLT_WCP_PARITY_FAIL_ON_MISSING="${WLT_RELEASE_PREP_WCP_PARITY_FAIL_ON_MISSING}" \
        WLT_WCP_PARITY_LABELS="${WLT_RELEASE_PREP_WCP_PARITY_LABELS}" \
        bash "${ROOT_DIR}/ci/validation/run-wcp-parity-suite.sh"
  else
    log "skip: wcp-parity (WLT_RELEASE_PREP_RUN_WCP_PARITY=0)"
  fi

  run_capture online-intake-strict \
    env \
      OUT_DIR="${WLT_RELEASE_PREP_OUT_DIR}/online-intake" \
      ONLINE_INTAKE_FETCH=0 \
      ONLINE_INTAKE_TRANSPORT=gh \
      ONLINE_INTAKE_MODE=code-only \
      ONLINE_INTAKE_SCOPE="${WLT_RELEASE_PREP_INTAKE_SCOPE}" \
      ONLINE_BACKLOG_STRICT=1 \
      ONLINE_REQUIRED_HIGH_MARKERS=x11drv_xinput2_enable,NtUserSendHardwareInput,SEND_HWMSG_NO_RAW,WRAPPER_VK_VERSION \
      ONLINE_REQUIRED_MEDIUM_MARKERS=ContentProfile,REMOTE_PROFILES \
      ONLINE_REQUIRED_LOW_MARKERS="${WLT_RELEASE_PREP_REQUIRED_LOW_MARKERS}" \
      ONLINE_REQUIRE_LOW_READY_VALIDATED="${WLT_RELEASE_PREP_REQUIRE_LOW_READY_VALIDATED}" \
      ONLINE_INCLUDE_COMMIT_SCAN="${WLT_RELEASE_PREP_RUN_COMMIT_SCAN}" \
      ONLINE_COMMIT_SCAN_AUTO=0 \
      ONLINE_COMMIT_SCAN_PROFILE="${WLT_RELEASE_PREP_COMMIT_SCAN_PROFILE}" \
      ONLINE_COMMIT_SCAN_COMMITS_PER_REPO="${WLT_RELEASE_PREP_COMMIT_SCAN_COMMITS_PER_REPO}" \
      ONLINE_COMMIT_SCAN_JSON="${commit_scan_json}" \
      ONLINE_RUN_HARVEST=0 \
      bash "${ROOT_DIR}/ci/reverse/online-intake.sh"

  run_capture high-cycle-all \
    env \
      WLT_HIGH_CYCLE_OUT_DIR="${WLT_RELEASE_PREP_OUT_DIR}/high-cycle" \
      WLT_HIGH_CYCLE_FETCH=0 \
      WLT_HIGH_CYCLE_PROFILE=all \
      WLT_HIGH_CYCLE_TRANSPORT=gh \
      WLT_HIGH_CYCLE_SCOPE="${WLT_RELEASE_PREP_INTAKE_SCOPE}" \
      WLT_HIGH_CYCLE_REQUIRED_HIGH_MARKERS=x11drv_xinput2_enable,NtUserSendHardwareInput,SEND_HWMSG_NO_RAW,WRAPPER_VK_VERSION \
      WLT_HIGH_CYCLE_REQUIRED_MEDIUM_MARKERS=ContentProfile,REMOTE_PROFILES \
      WLT_HIGH_CYCLE_REQUIRED_LOW_MARKERS="${WLT_RELEASE_PREP_REQUIRED_LOW_MARKERS}" \
      WLT_HIGH_CYCLE_REQUIRE_LOW_READY_VALIDATED="${WLT_RELEASE_PREP_REQUIRE_LOW_READY_VALIDATED}" \
      WLT_HIGH_CYCLE_RUN_COMMIT_SCAN="${WLT_RELEASE_PREP_RUN_COMMIT_SCAN}" \
      WLT_HIGH_CYCLE_INCLUDE_COMMIT_SCAN="${WLT_RELEASE_PREP_RUN_COMMIT_SCAN}" \
      WLT_HIGH_CYCLE_COMMIT_SCAN_JSON="${commit_scan_json}" \
      WLT_HIGH_CYCLE_COMMIT_SCAN_PROFILE="${WLT_RELEASE_PREP_COMMIT_SCAN_PROFILE}" \
      WLT_HIGH_CYCLE_COMMIT_SCAN_COMMITS_PER_REPO="${WLT_RELEASE_PREP_COMMIT_SCAN_COMMITS_PER_REPO}" \
      WLT_HIGH_CYCLE_RUN_HARVEST="${WLT_RELEASE_PREP_RUN_HARVEST}" \
      WLT_HIGH_CYCLE_HARVEST_PROFILE="${WLT_RELEASE_PREP_HARVEST_PROFILE}" \
      WLT_HIGH_CYCLE_HARVEST_MAX_COMMITS_PER_REPO="${WLT_RELEASE_PREP_HARVEST_MAX_COMMITS_PER_REPO}" \
      WLT_HIGH_CYCLE_HARVEST_APPLY="${WLT_RELEASE_PREP_HARVEST_APPLY}" \
      WLT_HIGH_CYCLE_HARVEST_SKIP_NO_SYNC="${WLT_RELEASE_PREP_HARVEST_SKIP_NO_SYNC}" \
      WLT_HIGH_CYCLE_HARVEST_AUTO_FOCUS_SYNC="${WLT_RELEASE_PREP_HARVEST_AUTO_FOCUS_SYNC}" \
      WLT_HIGH_CYCLE_HARVEST_INCLUDE_UNMAPPED="${WLT_RELEASE_PREP_HARVEST_INCLUDE_UNMAPPED}" \
      WLT_HIGH_CYCLE_SYNC_BRANCH_PINS="${WLT_RELEASE_PREP_SYNC_BRANCH_PINS}" \
      WLT_HIGH_CYCLE_HARVEST_FAIL_ON_REPO_ERRORS="${WLT_RELEASE_PREP_HARVEST_FAIL_ON_REPO_ERRORS}" \
      bash "${ROOT_DIR}/ci/reverse/run-high-priority-cycle.sh"

  if [[ "${WLT_RELEASE_PREP_RUN_PATCH_BASE}" == "1" ]]; then
    run_capture patch-base-cycle \
      env \
        WINLATOR_PATCH_BASE_OUT_DIR="${WLT_RELEASE_PREP_OUT_DIR}/patch-base-cycle" \
        WINLATOR_PATCH_BASE_PROFILE="${WLT_RELEASE_PREP_PATCH_BASE_PROFILE}" \
        WINLATOR_PATCH_BASE_PHASE="${WLT_RELEASE_PREP_PATCH_BASE_PHASE}" \
        bash "${ROOT_DIR}/ci/winlator/run-patch-base-cycle.sh" "${WLT_RELEASE_PREP_SOURCE_DIR}"
  fi

  if [[ -d "${WLT_RELEASE_PREP_SOURCE_DIR}/.git" ]]; then
    run_capture winlator-patch-stack \
      bash "${ROOT_DIR}/ci/winlator/check-patch-stack.sh" "${WLT_RELEASE_PREP_SOURCE_DIR}"
  elif [[ "${WLT_RELEASE_PREP_REQUIRE_SOURCE}" == "1" ]]; then
    fail "Winlator source dir not found: ${WLT_RELEASE_PREP_SOURCE_DIR}"
  else
    log "skip: winlator-patch-stack (source dir missing: ${WLT_RELEASE_PREP_SOURCE_DIR})"
  fi

  {
    printf 'time_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'out_dir=%s\n' "${WLT_RELEASE_PREP_OUT_DIR}"
    printf 'source_dir=%s\n' "${WLT_RELEASE_PREP_SOURCE_DIR}"
    printf 'source_required=%s\n' "${WLT_RELEASE_PREP_REQUIRE_SOURCE}"
    printf 'run_patch_base=%s\n' "${WLT_RELEASE_PREP_RUN_PATCH_BASE}"
    printf 'patch_base_profile=%s\n' "${WLT_RELEASE_PREP_PATCH_BASE_PROFILE}"
    printf 'patch_base_phase=%s\n' "${WLT_RELEASE_PREP_PATCH_BASE_PHASE}"
    printf 'run_contents_qa=%s\n' "${WLT_RELEASE_PREP_RUN_CONTENTS_QA}"
    printf 'run_wcp_parity=%s\n' "${WLT_RELEASE_PREP_RUN_WCP_PARITY}"
    printf 'wcp_parity_require_any=%s\n' "${WLT_RELEASE_PREP_WCP_PARITY_REQUIRE_ANY}"
    printf 'wcp_parity_fail_on_missing=%s\n' "${WLT_RELEASE_PREP_WCP_PARITY_FAIL_ON_MISSING}"
    printf 'wcp_parity_pairs_file=%s\n' "${WLT_RELEASE_PREP_WCP_PARITY_PAIRS_FILE}"
    printf 'wcp_parity_labels=%s\n' "${WLT_RELEASE_PREP_WCP_PARITY_LABELS}"
    printf 'required_low_markers=%s\n' "${WLT_RELEASE_PREP_REQUIRED_LOW_MARKERS}"
    printf 'require_low_ready_validated=%s\n' "${WLT_RELEASE_PREP_REQUIRE_LOW_READY_VALIDATED}"
    printf 'intake_scope=%s\n' "${WLT_RELEASE_PREP_INTAKE_SCOPE}"
    printf 'run_commit_scan=%s\n' "${WLT_RELEASE_PREP_RUN_COMMIT_SCAN}"
    printf 'commit_scan_profile=%s\n' "${WLT_RELEASE_PREP_COMMIT_SCAN_PROFILE}"
    printf 'commit_scan_commits_per_repo=%s\n' "${WLT_RELEASE_PREP_COMMIT_SCAN_COMMITS_PER_REPO}"
    printf 'run_harvest=%s\n' "${WLT_RELEASE_PREP_RUN_HARVEST}"
    printf 'harvest_profile=%s\n' "${WLT_RELEASE_PREP_HARVEST_PROFILE}"
    printf 'harvest_commits_per_repo=%s\n' "${WLT_RELEASE_PREP_HARVEST_MAX_COMMITS_PER_REPO}"
    printf 'harvest_apply=%s\n' "${WLT_RELEASE_PREP_HARVEST_APPLY}"
    printf 'harvest_skip_no_sync=%s\n' "${WLT_RELEASE_PREP_HARVEST_SKIP_NO_SYNC}"
    printf 'harvest_auto_focus_sync=%s\n' "${WLT_RELEASE_PREP_HARVEST_AUTO_FOCUS_SYNC}"
    printf 'harvest_include_unmapped=%s\n' "${WLT_RELEASE_PREP_HARVEST_INCLUDE_UNMAPPED}"
    printf 'sync_branch_pins=%s\n' "${WLT_RELEASE_PREP_SYNC_BRANCH_PINS}"
    printf 'harvest_fail_on_repo_errors=%s\n' "${WLT_RELEASE_PREP_HARVEST_FAIL_ON_REPO_ERRORS}"
  } > "${WLT_RELEASE_PREP_OUT_DIR}/summary.meta"

  log "release patch-base ready: ${WLT_RELEASE_PREP_OUT_DIR}"
}

main "$@"
