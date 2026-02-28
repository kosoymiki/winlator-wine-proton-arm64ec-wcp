#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${WLT_FINAL_STAGE_OUT_DIR:=/tmp/final-stage-gates-$(date +%Y%m%d_%H%M%S)}"
: "${WLT_FINAL_STAGE_FAIL_MODE:=strict}"
: "${WLT_FINAL_STAGE_FETCH:=0}"
: "${WLT_FINAL_STAGE_SCOPE:=focused}"
: "${WLT_FINAL_STAGE_RUN_CONTENTS_QA:=1}"
: "${WLT_FINAL_STAGE_RUN_PATCH_BASE:=1}"
: "${WLT_FINAL_STAGE_PATCH_BASE_REQUIRED:=0}"
: "${WLT_FINAL_STAGE_PATCH_BASE_SOURCE_DIRS:=${ROOT_DIR}/work/winlator-ludashi/src,/tmp/winlator-ludashi-src}"
: "${WLT_FINAL_STAGE_PATCH_BASE_PROFILE:=standard}"
: "${WLT_FINAL_STAGE_PATCH_BASE_PHASE:=harvard_followup}"
: "${WLT_FINAL_STAGE_RUN_WCP_PARITY:=1}"
: "${WLT_FINAL_STAGE_WCP_PARITY_REQUIRE_ANY:=0}"
: "${WLT_FINAL_STAGE_WCP_PARITY_FAIL_ON_MISSING:=0}"
: "${WLT_FINAL_STAGE_WCP_PARITY_PAIRS_FILE:=${ROOT_DIR}/ci/validation/wcp-parity-pairs.tsv}"
: "${WLT_FINAL_STAGE_WCP_PARITY_LABELS:=}"
: "${WLT_FINAL_STAGE_RUN_HARVEST:=1}"
: "${WLT_FINAL_STAGE_HARVEST_PROFILE:=core}"
: "${WLT_FINAL_STAGE_HARVEST_MAX_COMMITS_PER_REPO:=24}"
: "${WLT_FINAL_STAGE_HARVEST_APPLY:=1}"
: "${WLT_FINAL_STAGE_HARVEST_SKIP_NO_SYNC:=1}"
: "${WLT_FINAL_STAGE_HARVEST_AUTO_FOCUS_SYNC:=1}"
: "${WLT_FINAL_STAGE_HARVEST_INCLUDE_UNMAPPED:=1}"
: "${WLT_FINAL_STAGE_SYNC_BRANCH_PINS:=1}"
: "${WLT_FINAL_STAGE_HARVEST_FAIL_ON_REPO_ERRORS:=0}"
: "${WLT_FINAL_STAGE_RUN_RELEASE_PREP:=1}"
: "${WLT_FINAL_STAGE_RUN_SNAPSHOT:=1}"
: "${WLT_FINAL_STAGE_RELEASE_PREP_RUN_PATCH_BASE:=0}"
: "${WLT_FINAL_STAGE_RELEASE_PREP_REQUIRE_SOURCE:=0}"
: "${WLT_FINAL_STAGE_RELEASE_PREP_RUN_CONTENTS_QA:=1}"
: "${WLT_FINAL_STAGE_RELEASE_PREP_RUN_WCP_PARITY:=1}"
: "${WLT_FINAL_STAGE_RELEASE_PREP_WCP_PARITY_REQUIRE_ANY:=0}"
: "${WLT_FINAL_STAGE_RELEASE_PREP_WCP_PARITY_FAIL_ON_MISSING:=0}"
: "${WLT_FINAL_STAGE_RELEASE_PREP_WCP_PARITY_PAIRS_FILE:=${ROOT_DIR}/ci/validation/wcp-parity-pairs.tsv}"
: "${WLT_FINAL_STAGE_RELEASE_PREP_WCP_PARITY_LABELS:=}"
: "${WLT_FINAL_STAGE_SNAPSHOT_FAIL_MODE:=capture-only}"
: "${WLT_FINAL_STAGE_SNAPSHOT_CAPTURE_CONTENTS_QA:=1}"
: "${WLT_FINAL_STAGE_SNAPSHOT_CONTENTS_QA_REQUIRED:=0}"
: "${WLT_FINAL_STAGE_SNAPSHOT_CAPTURE_WCP_PARITY:=1}"
: "${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_REQUIRED:=0}"
: "${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_REQUIRE_ANY:=0}"
: "${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_FAIL_ON_MISSING:=0}"
: "${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_PAIRS_FILE:=${ROOT_DIR}/ci/validation/wcp-parity-pairs.tsv}"
: "${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_LABELS:=}"
: "${WLT_FINAL_STAGE_RUN_COMMIT_SCAN:=1}"
: "${WLT_FINAL_STAGE_COMMIT_SCAN_PROFILE:=core}"
: "${WLT_FINAL_STAGE_COMMIT_SCAN_COMMITS_PER_REPO:=12}"

: "${WLT_FINAL_STAGE_REQUIRED_HIGH_MARKERS:=x11drv_xinput2_enable,NtUserSendHardwareInput,SEND_HWMSG_NO_RAW,WRAPPER_VK_VERSION}"
: "${WLT_FINAL_STAGE_REQUIRED_MEDIUM_MARKERS:=ContentProfile,REMOTE_PROFILES}"
: "${WLT_FINAL_STAGE_REQUIRED_LOW_MARKERS:=DXVK,D8VK,VKD3D,PROOT_TMP_DIR,BOX64_LOG,WINEDEBUG,MESA_VK_WSI_PRESENT_MODE,TU_DEBUG,WINE_OPEN_WITH_ANDROID_BROWSER}"

log() { printf '[final-stage] %s\n' "$*" >&2; }
fail() { printf '[final-stage][error] %s\n' "$*" >&2; exit 1; }

[[ "${WLT_FINAL_STAGE_FAIL_MODE}" =~ ^(strict|capture-only)$ ]] || fail "WLT_FINAL_STAGE_FAIL_MODE must be strict or capture-only"
[[ "${WLT_FINAL_STAGE_FETCH}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_FETCH must be 0 or 1"
[[ "${WLT_FINAL_STAGE_SCOPE}" =~ ^(focused|tree)$ ]] || fail "WLT_FINAL_STAGE_SCOPE must be focused or tree"
[[ "${WLT_FINAL_STAGE_RUN_CONTENTS_QA}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_RUN_CONTENTS_QA must be 0 or 1"
[[ "${WLT_FINAL_STAGE_RUN_PATCH_BASE}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_RUN_PATCH_BASE must be 0 or 1"
[[ "${WLT_FINAL_STAGE_PATCH_BASE_REQUIRED}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_PATCH_BASE_REQUIRED must be 0 or 1"
[[ "${WLT_FINAL_STAGE_PATCH_BASE_PROFILE}" =~ ^(standard|wide|single)$ ]] || fail "WLT_FINAL_STAGE_PATCH_BASE_PROFILE must be standard, wide or single"
[[ "${WLT_FINAL_STAGE_RUN_WCP_PARITY}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_RUN_WCP_PARITY must be 0 or 1"
[[ "${WLT_FINAL_STAGE_WCP_PARITY_REQUIRE_ANY}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_WCP_PARITY_REQUIRE_ANY must be 0 or 1"
[[ "${WLT_FINAL_STAGE_WCP_PARITY_FAIL_ON_MISSING}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_WCP_PARITY_FAIL_ON_MISSING must be 0 or 1"
[[ "${WLT_FINAL_STAGE_RUN_HARVEST}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_RUN_HARVEST must be 0 or 1"
[[ "${WLT_FINAL_STAGE_HARVEST_SKIP_NO_SYNC}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_HARVEST_SKIP_NO_SYNC must be 0 or 1"
[[ "${WLT_FINAL_STAGE_HARVEST_AUTO_FOCUS_SYNC}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_HARVEST_AUTO_FOCUS_SYNC must be 0 or 1"
[[ "${WLT_FINAL_STAGE_HARVEST_INCLUDE_UNMAPPED}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_HARVEST_INCLUDE_UNMAPPED must be 0 or 1"
[[ "${WLT_FINAL_STAGE_SYNC_BRANCH_PINS}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_SYNC_BRANCH_PINS must be 0 or 1"
[[ "${WLT_FINAL_STAGE_HARVEST_FAIL_ON_REPO_ERRORS}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_HARVEST_FAIL_ON_REPO_ERRORS must be 0 or 1"
[[ "${WLT_FINAL_STAGE_RUN_RELEASE_PREP}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_RUN_RELEASE_PREP must be 0 or 1"
[[ "${WLT_FINAL_STAGE_RUN_SNAPSHOT}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_RUN_SNAPSHOT must be 0 or 1"
[[ "${WLT_FINAL_STAGE_RELEASE_PREP_RUN_PATCH_BASE}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_RELEASE_PREP_RUN_PATCH_BASE must be 0 or 1"
[[ "${WLT_FINAL_STAGE_RELEASE_PREP_REQUIRE_SOURCE}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_RELEASE_PREP_REQUIRE_SOURCE must be 0 or 1"
[[ "${WLT_FINAL_STAGE_RELEASE_PREP_RUN_CONTENTS_QA}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_RELEASE_PREP_RUN_CONTENTS_QA must be 0 or 1"
[[ "${WLT_FINAL_STAGE_RELEASE_PREP_RUN_WCP_PARITY}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_RELEASE_PREP_RUN_WCP_PARITY must be 0 or 1"
[[ "${WLT_FINAL_STAGE_RELEASE_PREP_WCP_PARITY_REQUIRE_ANY}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_RELEASE_PREP_WCP_PARITY_REQUIRE_ANY must be 0 or 1"
[[ "${WLT_FINAL_STAGE_RELEASE_PREP_WCP_PARITY_FAIL_ON_MISSING}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_RELEASE_PREP_WCP_PARITY_FAIL_ON_MISSING must be 0 or 1"
[[ "${WLT_FINAL_STAGE_SNAPSHOT_FAIL_MODE}" =~ ^(strict|capture-only)$ ]] || fail "WLT_FINAL_STAGE_SNAPSHOT_FAIL_MODE must be strict or capture-only"
[[ "${WLT_FINAL_STAGE_SNAPSHOT_CAPTURE_CONTENTS_QA}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_SNAPSHOT_CAPTURE_CONTENTS_QA must be 0 or 1"
[[ "${WLT_FINAL_STAGE_SNAPSHOT_CONTENTS_QA_REQUIRED}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_SNAPSHOT_CONTENTS_QA_REQUIRED must be 0 or 1"
[[ "${WLT_FINAL_STAGE_SNAPSHOT_CAPTURE_WCP_PARITY}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_SNAPSHOT_CAPTURE_WCP_PARITY must be 0 or 1"
[[ "${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_REQUIRED}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_REQUIRED must be 0 or 1"
[[ "${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_REQUIRE_ANY}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_REQUIRE_ANY must be 0 or 1"
[[ "${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_FAIL_ON_MISSING}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_FAIL_ON_MISSING must be 0 or 1"
[[ "${WLT_FINAL_STAGE_RUN_COMMIT_SCAN}" =~ ^[01]$ ]] || fail "WLT_FINAL_STAGE_RUN_COMMIT_SCAN must be 0 or 1"
[[ "${WLT_FINAL_STAGE_COMMIT_SCAN_PROFILE}" =~ ^(core|all|custom)$ ]] || fail "WLT_FINAL_STAGE_COMMIT_SCAN_PROFILE must be core, all or custom"
[[ "${WLT_FINAL_STAGE_COMMIT_SCAN_COMMITS_PER_REPO}" =~ ^[0-9]+$ ]] || fail "WLT_FINAL_STAGE_COMMIT_SCAN_COMMITS_PER_REPO must be numeric"

mkdir -p "${WLT_FINAL_STAGE_OUT_DIR}"
commit_scan_json="${ROOT_DIR}/docs/reverse/online-intake/commit-scan.json"
combined_matrix_json="${ROOT_DIR}/docs/reverse/online-intake/combined-matrix.json"

conflict_marker_repo_total=0
conflict_marker_repos=0
conflict_marker_total_hits=0
conflict_marker_hits=-

run_capture() {
  local name="$1"; shift
  local out="${WLT_FINAL_STAGE_OUT_DIR}/${name}.log"
  log "running ${name}"
  if "$@" >"${out}" 2>&1; then
    log "ok: ${name}"
    printf '0\n'
  else
    local rc=$?
    tail -n 120 "${out}" >&2 || true
    log "failed: ${name} (rc=${rc})"
    printf '%s\n' "${rc}"
  fi
}

reflective_rc="$(run_capture reflective-audits \
  bash "${ROOT_DIR}/ci/winlator/run-reflective-audits.sh")"

manifest_rc="$(run_capture gn-manifest \
  python3 "${ROOT_DIR}/ci/gamenative/check-manifest-contract.py")"

contents_qa_rc=0
if [[ "${WLT_FINAL_STAGE_RUN_CONTENTS_QA}" == "1" ]]; then
  contents_qa_rc="$(run_capture contents-qa \
    python3 "${ROOT_DIR}/ci/validation/check-contents-qa-contract.py" \
      --root "${ROOT_DIR}" \
      --output "${WLT_FINAL_STAGE_OUT_DIR}/contents-qa.md")"
fi

patch_base_rc=0
if [[ "${WLT_FINAL_STAGE_RUN_PATCH_BASE}" == "1" ]]; then
  patch_base_rc="$(run_capture patch-base-contract \
    env \
      WLT_PATCH_BASE_CONTRACT_OUT_DIR="${WLT_FINAL_STAGE_OUT_DIR}/patch-base-contract" \
      WLT_PATCH_BASE_CONTRACT_SOURCE_DIRS="${WLT_FINAL_STAGE_PATCH_BASE_SOURCE_DIRS}" \
      WLT_PATCH_BASE_CONTRACT_REQUIRED="${WLT_FINAL_STAGE_PATCH_BASE_REQUIRED}" \
      WLT_PATCH_BASE_CONTRACT_PROFILE="${WLT_FINAL_STAGE_PATCH_BASE_PROFILE}" \
      WLT_PATCH_BASE_CONTRACT_PHASE="${WLT_FINAL_STAGE_PATCH_BASE_PHASE}" \
      bash "${ROOT_DIR}/ci/validation/check-patch-base-contract.sh")"
fi

wcp_parity_rc=0
if [[ "${WLT_FINAL_STAGE_RUN_WCP_PARITY}" == "1" ]]; then
  wcp_parity_rc="$(run_capture wcp-parity \
    env \
      WLT_WCP_PARITY_OUT_DIR="${WLT_FINAL_STAGE_OUT_DIR}/wcp-parity" \
      WLT_WCP_PARITY_PAIRS_FILE="${WLT_FINAL_STAGE_WCP_PARITY_PAIRS_FILE}" \
      WLT_WCP_PARITY_REQUIRE_ANY="${WLT_FINAL_STAGE_WCP_PARITY_REQUIRE_ANY}" \
      WLT_WCP_PARITY_FAIL_ON_MISSING="${WLT_FINAL_STAGE_WCP_PARITY_FAIL_ON_MISSING}" \
      WLT_WCP_PARITY_LABELS="${WLT_FINAL_STAGE_WCP_PARITY_LABELS}" \
      bash "${ROOT_DIR}/ci/validation/run-wcp-parity-suite.sh")"
fi

commit_scan_rc=0
if [[ "${WLT_FINAL_STAGE_RUN_COMMIT_SCAN}" == "1" ]]; then
  commit_scan_rc="$(run_capture commit-scan \
    env \
      ONLINE_COMMIT_SCAN_OUT_DIR="${ROOT_DIR}/docs/reverse/online-intake" \
      ONLINE_COMMIT_SCAN_PROFILE="${WLT_FINAL_STAGE_COMMIT_SCAN_PROFILE}" \
      ONLINE_COMMIT_SCAN_COMMITS_PER_REPO="${WLT_FINAL_STAGE_COMMIT_SCAN_COMMITS_PER_REPO}" \
      bash "${ROOT_DIR}/ci/reverse/online-commit-scan.sh")"
fi

intake_rc="$(run_capture online-intake-strict \
  env \
    OUT_DIR="${ROOT_DIR}/docs/reverse/online-intake" \
    ONLINE_INTAKE_FETCH="${WLT_FINAL_STAGE_FETCH}" \
    ONLINE_INTAKE_SCOPE="${WLT_FINAL_STAGE_SCOPE}" \
    ONLINE_BACKLOG_STRICT=1 \
    ONLINE_REQUIRED_HIGH_MARKERS="${WLT_FINAL_STAGE_REQUIRED_HIGH_MARKERS}" \
    ONLINE_REQUIRED_MEDIUM_MARKERS="${WLT_FINAL_STAGE_REQUIRED_MEDIUM_MARKERS}" \
    ONLINE_REQUIRED_LOW_MARKERS="${WLT_FINAL_STAGE_REQUIRED_LOW_MARKERS}" \
    ONLINE_REQUIRE_LOW_READY_VALIDATED=1 \
    ONLINE_INCLUDE_COMMIT_SCAN="${WLT_FINAL_STAGE_RUN_COMMIT_SCAN}" \
    ONLINE_COMMIT_SCAN_AUTO=0 \
    ONLINE_COMMIT_SCAN_PROFILE="${WLT_FINAL_STAGE_COMMIT_SCAN_PROFILE}" \
    ONLINE_COMMIT_SCAN_COMMITS_PER_REPO="${WLT_FINAL_STAGE_COMMIT_SCAN_COMMITS_PER_REPO}" \
    ONLINE_COMMIT_SCAN_JSON="${commit_scan_json}" \
    ONLINE_RUN_HARVEST=0 \
    bash "${ROOT_DIR}/ci/reverse/online-intake.sh")"

high_cycle_rc="$(run_capture high-cycle-strict \
  env \
    WLT_HIGH_CYCLE_OUT_DIR="${ROOT_DIR}/docs/reverse/online-intake" \
    WLT_HIGH_CYCLE_FETCH="${WLT_FINAL_STAGE_FETCH}" \
    WLT_HIGH_CYCLE_SCOPE="${WLT_FINAL_STAGE_SCOPE}" \
    WLT_HIGH_CYCLE_BACKLOG_STRICT=1 \
    WLT_HIGH_CYCLE_REQUIRED_HIGH_MARKERS="${WLT_FINAL_STAGE_REQUIRED_HIGH_MARKERS}" \
    WLT_HIGH_CYCLE_REQUIRED_MEDIUM_MARKERS="${WLT_FINAL_STAGE_REQUIRED_MEDIUM_MARKERS}" \
    WLT_HIGH_CYCLE_REQUIRED_LOW_MARKERS="${WLT_FINAL_STAGE_REQUIRED_LOW_MARKERS}" \
    WLT_HIGH_CYCLE_REQUIRE_LOW_READY_VALIDATED=1 \
    WLT_HIGH_CYCLE_RUN_COMMIT_SCAN=0 \
    WLT_HIGH_CYCLE_INCLUDE_COMMIT_SCAN="${WLT_FINAL_STAGE_RUN_COMMIT_SCAN}" \
    WLT_HIGH_CYCLE_COMMIT_SCAN_JSON="${commit_scan_json}" \
    WLT_HIGH_CYCLE_COMMIT_SCAN_PROFILE="${WLT_FINAL_STAGE_COMMIT_SCAN_PROFILE}" \
    WLT_HIGH_CYCLE_COMMIT_SCAN_COMMITS_PER_REPO="${WLT_FINAL_STAGE_COMMIT_SCAN_COMMITS_PER_REPO}" \
    WLT_HIGH_CYCLE_RUN_HARVEST="${WLT_FINAL_STAGE_RUN_HARVEST}" \
    WLT_HIGH_CYCLE_HARVEST_PROFILE="${WLT_FINAL_STAGE_HARVEST_PROFILE}" \
    WLT_HIGH_CYCLE_HARVEST_MAX_COMMITS_PER_REPO="${WLT_FINAL_STAGE_HARVEST_MAX_COMMITS_PER_REPO}" \
    WLT_HIGH_CYCLE_HARVEST_APPLY="${WLT_FINAL_STAGE_HARVEST_APPLY}" \
    WLT_HIGH_CYCLE_HARVEST_SKIP_NO_SYNC="${WLT_FINAL_STAGE_HARVEST_SKIP_NO_SYNC}" \
    WLT_HIGH_CYCLE_HARVEST_AUTO_FOCUS_SYNC="${WLT_FINAL_STAGE_HARVEST_AUTO_FOCUS_SYNC}" \
    WLT_HIGH_CYCLE_HARVEST_INCLUDE_UNMAPPED="${WLT_FINAL_STAGE_HARVEST_INCLUDE_UNMAPPED}" \
    WLT_HIGH_CYCLE_SYNC_BRANCH_PINS="${WLT_FINAL_STAGE_SYNC_BRANCH_PINS}" \
    WLT_HIGH_CYCLE_HARVEST_FAIL_ON_REPO_ERRORS="${WLT_FINAL_STAGE_HARVEST_FAIL_ON_REPO_ERRORS}" \
    bash "${ROOT_DIR}/ci/reverse/run-high-priority-cycle.sh")"

release_prep_rc=0
if [[ "${WLT_FINAL_STAGE_RUN_RELEASE_PREP}" == "1" ]]; then
  release_prep_rc="$(run_capture release-prep \
    env \
      WLT_RELEASE_PREP_OUT_DIR="${WLT_FINAL_STAGE_OUT_DIR}/release-prep" \
      WLT_RELEASE_PREP_REQUIRE_SOURCE="${WLT_FINAL_STAGE_RELEASE_PREP_REQUIRE_SOURCE}" \
      WLT_RELEASE_PREP_RUN_PATCH_BASE="${WLT_FINAL_STAGE_RELEASE_PREP_RUN_PATCH_BASE}" \
      WLT_RELEASE_PREP_RUN_CONTENTS_QA="${WLT_FINAL_STAGE_RELEASE_PREP_RUN_CONTENTS_QA}" \
      WLT_RELEASE_PREP_RUN_WCP_PARITY="${WLT_FINAL_STAGE_RELEASE_PREP_RUN_WCP_PARITY}" \
      WLT_RELEASE_PREP_WCP_PARITY_REQUIRE_ANY="${WLT_FINAL_STAGE_RELEASE_PREP_WCP_PARITY_REQUIRE_ANY}" \
      WLT_RELEASE_PREP_WCP_PARITY_FAIL_ON_MISSING="${WLT_FINAL_STAGE_RELEASE_PREP_WCP_PARITY_FAIL_ON_MISSING}" \
      WLT_RELEASE_PREP_WCP_PARITY_PAIRS_FILE="${WLT_FINAL_STAGE_RELEASE_PREP_WCP_PARITY_PAIRS_FILE}" \
      WLT_RELEASE_PREP_WCP_PARITY_LABELS="${WLT_FINAL_STAGE_RELEASE_PREP_WCP_PARITY_LABELS}" \
      WLT_RELEASE_PREP_INTAKE_SCOPE="${WLT_FINAL_STAGE_SCOPE}" \
      WLT_RELEASE_PREP_REQUIRED_LOW_MARKERS="${WLT_FINAL_STAGE_REQUIRED_LOW_MARKERS}" \
      WLT_RELEASE_PREP_RUN_COMMIT_SCAN="${WLT_FINAL_STAGE_RUN_COMMIT_SCAN}" \
      WLT_RELEASE_PREP_COMMIT_SCAN_PROFILE="${WLT_FINAL_STAGE_COMMIT_SCAN_PROFILE}" \
      WLT_RELEASE_PREP_COMMIT_SCAN_COMMITS_PER_REPO="${WLT_FINAL_STAGE_COMMIT_SCAN_COMMITS_PER_REPO}" \
      WLT_RELEASE_PREP_RUN_HARVEST="${WLT_FINAL_STAGE_RUN_HARVEST}" \
      WLT_RELEASE_PREP_HARVEST_PROFILE="${WLT_FINAL_STAGE_HARVEST_PROFILE}" \
      WLT_RELEASE_PREP_HARVEST_MAX_COMMITS_PER_REPO="${WLT_FINAL_STAGE_HARVEST_MAX_COMMITS_PER_REPO}" \
      WLT_RELEASE_PREP_HARVEST_APPLY="${WLT_FINAL_STAGE_HARVEST_APPLY}" \
      WLT_RELEASE_PREP_HARVEST_SKIP_NO_SYNC="${WLT_FINAL_STAGE_HARVEST_SKIP_NO_SYNC}" \
      WLT_RELEASE_PREP_HARVEST_AUTO_FOCUS_SYNC="${WLT_FINAL_STAGE_HARVEST_AUTO_FOCUS_SYNC}" \
      WLT_RELEASE_PREP_HARVEST_INCLUDE_UNMAPPED="${WLT_FINAL_STAGE_HARVEST_INCLUDE_UNMAPPED}" \
      WLT_RELEASE_PREP_SYNC_BRANCH_PINS="${WLT_FINAL_STAGE_SYNC_BRANCH_PINS}" \
      WLT_RELEASE_PREP_HARVEST_FAIL_ON_REPO_ERRORS="${WLT_FINAL_STAGE_HARVEST_FAIL_ON_REPO_ERRORS}" \
      bash "${ROOT_DIR}/ci/validation/prepare-release-patch-base.sh")"
fi

snapshot_rc=0
if [[ "${WLT_FINAL_STAGE_RUN_SNAPSHOT}" == "1" ]]; then
  snapshot_rc="$(run_capture snapshot \
    env \
      WLT_SNAPSHOT_DIR="${WLT_FINAL_STAGE_OUT_DIR}/snapshot" \
      WLT_SNAPSHOT_FAIL_MODE="${WLT_FINAL_STAGE_SNAPSHOT_FAIL_MODE}" \
      WLT_CAPTURE_ONLINE_INTAKE=1 \
      WLT_CAPTURE_CONTENTS_QA="${WLT_FINAL_STAGE_SNAPSHOT_CAPTURE_CONTENTS_QA}" \
      WLT_CONTENTS_QA_REQUIRED="${WLT_FINAL_STAGE_SNAPSHOT_CONTENTS_QA_REQUIRED}" \
      WLT_CAPTURE_WCP_PARITY="${WLT_FINAL_STAGE_SNAPSHOT_CAPTURE_WCP_PARITY}" \
      WLT_WCP_PARITY_REQUIRED="${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_REQUIRED}" \
      WLT_WCP_PARITY_REQUIRE_ANY="${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_REQUIRE_ANY}" \
      WLT_WCP_PARITY_FAIL_ON_MISSING="${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_FAIL_ON_MISSING}" \
      WLT_WCP_PARITY_PAIRS_FILE="${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_PAIRS_FILE}" \
      WLT_WCP_PARITY_LABELS="${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_LABELS}" \
      WLT_ONLINE_INTAKE_REQUIRED=0 \
      WLT_ONLINE_INTAKE_USE_HIGH_CYCLE=1 \
      WLT_ONLINE_INTAKE_FETCH="${WLT_FINAL_STAGE_FETCH}" \
      WLT_ONLINE_INTAKE_SCOPE="${WLT_FINAL_STAGE_SCOPE}" \
      WLT_ONLINE_BACKLOG_STRICT=1 \
      WLT_ONLINE_REQUIRED_HIGH_MARKERS="${WLT_FINAL_STAGE_REQUIRED_HIGH_MARKERS}" \
      WLT_ONLINE_REQUIRED_MEDIUM_MARKERS="${WLT_FINAL_STAGE_REQUIRED_MEDIUM_MARKERS}" \
      WLT_ONLINE_REQUIRED_LOW_MARKERS="${WLT_FINAL_STAGE_REQUIRED_LOW_MARKERS}" \
      WLT_ONLINE_REQUIRE_LOW_READY_VALIDATED=1 \
      WLT_CAPTURE_COMMIT_SCAN="${WLT_FINAL_STAGE_RUN_COMMIT_SCAN}" \
      WLT_COMMIT_SCAN_REQUIRED=0 \
      WLT_COMMIT_SCAN_PROFILE="${WLT_FINAL_STAGE_COMMIT_SCAN_PROFILE}" \
      WLT_COMMIT_SCAN_COMMITS_PER_REPO="${WLT_FINAL_STAGE_COMMIT_SCAN_COMMITS_PER_REPO}" \
      WLT_CAPTURE_RELEASE_PREP=0 \
      bash "${ROOT_DIR}/ci/validation/collect-mainline-forensic-snapshot.sh")"
fi

if [[ -f "${combined_matrix_json}" ]]; then
  while IFS= read -r line; do
    key="${line%%=*}"
    value="${line#*=}"
    case "${key}" in
      conflict_marker_repo_total) conflict_marker_repo_total="${value}" ;;
      conflict_marker_repos) conflict_marker_repos="${value}" ;;
      conflict_marker_total_hits) conflict_marker_total_hits="${value}" ;;
      conflict_marker_hits) conflict_marker_hits="${value}" ;;
    esac
  done < <(python3 - "${combined_matrix_json}" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
payload = json.loads(path.read_text(encoding="utf-8"))
reports = payload.get("reports", {}) if isinstance(payload, dict) else {}
markers = [
    "AERO_LIBRARY_CONFLICTS",
    "AERO_LIBRARY_CONFLICT_COUNT",
    "AERO_LIBRARY_CONFLICT_SHA256",
    "AERO_LIBRARY_REPRO_ID",
    "RUNTIME_LIBRARY_CONFLICT_SNAPSHOT",
    "RUNTIME_LIBRARY_CONFLICT_DETECTED",
]
hits = {m: 0 for m in markers}
repos_with_hits = 0

for report in reports.values():
    repo_seen = False
    for row in report.get("focus_files", []):
        for marker in row.get("markers") or []:
            if marker in hits:
                hits[marker] += 1
                repo_seen = True
    if repo_seen:
        repos_with_hits += 1

print(f"conflict_marker_repo_total={len(reports)}")
print(f"conflict_marker_repos={repos_with_hits}")
print(f"conflict_marker_total_hits={sum(hits.values())}")
print("conflict_marker_hits=" + ",".join(f"{m}:{hits[m]}" for m in markers))
PY
)
fi

{
  printf 'time_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'fail_mode=%s\n' "${WLT_FINAL_STAGE_FAIL_MODE}"
  printf 'fetch=%s\n' "${WLT_FINAL_STAGE_FETCH}"
  printf 'scope=%s\n' "${WLT_FINAL_STAGE_SCOPE}"
  printf 'run_contents_qa=%s\n' "${WLT_FINAL_STAGE_RUN_CONTENTS_QA}"
  printf 'run_patch_base=%s\n' "${WLT_FINAL_STAGE_RUN_PATCH_BASE}"
  printf 'patch_base_required=%s\n' "${WLT_FINAL_STAGE_PATCH_BASE_REQUIRED}"
  printf 'patch_base_source_dirs=%s\n' "${WLT_FINAL_STAGE_PATCH_BASE_SOURCE_DIRS}"
  printf 'patch_base_profile=%s\n' "${WLT_FINAL_STAGE_PATCH_BASE_PROFILE}"
  printf 'patch_base_phase=%s\n' "${WLT_FINAL_STAGE_PATCH_BASE_PHASE}"
  printf 'run_wcp_parity=%s\n' "${WLT_FINAL_STAGE_RUN_WCP_PARITY}"
  printf 'wcp_parity_require_any=%s\n' "${WLT_FINAL_STAGE_WCP_PARITY_REQUIRE_ANY}"
  printf 'wcp_parity_fail_on_missing=%s\n' "${WLT_FINAL_STAGE_WCP_PARITY_FAIL_ON_MISSING}"
  printf 'wcp_parity_pairs_file=%s\n' "${WLT_FINAL_STAGE_WCP_PARITY_PAIRS_FILE}"
  printf 'wcp_parity_labels=%s\n' "${WLT_FINAL_STAGE_WCP_PARITY_LABELS}"
  printf 'run_harvest=%s\n' "${WLT_FINAL_STAGE_RUN_HARVEST}"
  printf 'harvest_profile=%s\n' "${WLT_FINAL_STAGE_HARVEST_PROFILE}"
  printf 'harvest_commits_per_repo=%s\n' "${WLT_FINAL_STAGE_HARVEST_MAX_COMMITS_PER_REPO}"
  printf 'harvest_apply=%s\n' "${WLT_FINAL_STAGE_HARVEST_APPLY}"
  printf 'harvest_skip_no_sync=%s\n' "${WLT_FINAL_STAGE_HARVEST_SKIP_NO_SYNC}"
  printf 'harvest_auto_focus_sync=%s\n' "${WLT_FINAL_STAGE_HARVEST_AUTO_FOCUS_SYNC}"
  printf 'harvest_include_unmapped=%s\n' "${WLT_FINAL_STAGE_HARVEST_INCLUDE_UNMAPPED}"
  printf 'sync_branch_pins=%s\n' "${WLT_FINAL_STAGE_SYNC_BRANCH_PINS}"
  printf 'harvest_fail_on_repo_errors=%s\n' "${WLT_FINAL_STAGE_HARVEST_FAIL_ON_REPO_ERRORS}"
  printf 'reflective_rc=%s\n' "${reflective_rc}"
  printf 'manifest_rc=%s\n' "${manifest_rc}"
  printf 'contents_qa_rc=%s\n' "${contents_qa_rc}"
  printf 'patch_base_rc=%s\n' "${patch_base_rc}"
  printf 'wcp_parity_rc=%s\n' "${wcp_parity_rc}"
  printf 'intake_rc=%s\n' "${intake_rc}"
  printf 'high_cycle_rc=%s\n' "${high_cycle_rc}"
  printf 'commit_scan_rc=%s\n' "${commit_scan_rc}"
  printf 'release_prep_rc=%s\n' "${release_prep_rc}"
  printf 'snapshot_rc=%s\n' "${snapshot_rc}"
  printf 'run_release_prep=%s\n' "${WLT_FINAL_STAGE_RUN_RELEASE_PREP}"
  printf 'release_prep_run_contents_qa=%s\n' "${WLT_FINAL_STAGE_RELEASE_PREP_RUN_CONTENTS_QA}"
  printf 'release_prep_run_wcp_parity=%s\n' "${WLT_FINAL_STAGE_RELEASE_PREP_RUN_WCP_PARITY}"
  printf 'release_prep_wcp_parity_require_any=%s\n' "${WLT_FINAL_STAGE_RELEASE_PREP_WCP_PARITY_REQUIRE_ANY}"
  printf 'release_prep_wcp_parity_fail_on_missing=%s\n' "${WLT_FINAL_STAGE_RELEASE_PREP_WCP_PARITY_FAIL_ON_MISSING}"
  printf 'release_prep_wcp_parity_pairs_file=%s\n' "${WLT_FINAL_STAGE_RELEASE_PREP_WCP_PARITY_PAIRS_FILE}"
  printf 'release_prep_wcp_parity_labels=%s\n' "${WLT_FINAL_STAGE_RELEASE_PREP_WCP_PARITY_LABELS}"
  printf 'snapshot_capture_contents_qa=%s\n' "${WLT_FINAL_STAGE_SNAPSHOT_CAPTURE_CONTENTS_QA}"
  printf 'snapshot_contents_qa_required=%s\n' "${WLT_FINAL_STAGE_SNAPSHOT_CONTENTS_QA_REQUIRED}"
  printf 'snapshot_capture_wcp_parity=%s\n' "${WLT_FINAL_STAGE_SNAPSHOT_CAPTURE_WCP_PARITY}"
  printf 'snapshot_wcp_parity_required=%s\n' "${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_REQUIRED}"
  printf 'snapshot_wcp_parity_require_any=%s\n' "${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_REQUIRE_ANY}"
  printf 'snapshot_wcp_parity_fail_on_missing=%s\n' "${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_FAIL_ON_MISSING}"
  printf 'snapshot_wcp_parity_pairs_file=%s\n' "${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_PAIRS_FILE}"
  printf 'snapshot_wcp_parity_labels=%s\n' "${WLT_FINAL_STAGE_SNAPSHOT_WCP_PARITY_LABELS}"
  printf 'run_snapshot=%s\n' "${WLT_FINAL_STAGE_RUN_SNAPSHOT}"
  printf 'run_commit_scan=%s\n' "${WLT_FINAL_STAGE_RUN_COMMIT_SCAN}"
  printf 'commit_scan_profile=%s\n' "${WLT_FINAL_STAGE_COMMIT_SCAN_PROFILE}"
  printf 'commit_scan_commits_per_repo=%s\n' "${WLT_FINAL_STAGE_COMMIT_SCAN_COMMITS_PER_REPO}"
  printf 'conflict_marker_repo_total=%s\n' "${conflict_marker_repo_total}"
  printf 'conflict_marker_repos=%s\n' "${conflict_marker_repos}"
  printf 'conflict_marker_total_hits=%s\n' "${conflict_marker_total_hits}"
  printf 'conflict_marker_hits=%s\n' "${conflict_marker_hits}"
} > "${WLT_FINAL_STAGE_OUT_DIR}/summary.meta"

if [[ "${WLT_FINAL_STAGE_FAIL_MODE}" == "strict" ]]; then
  if [[ "${reflective_rc}" != "0" || "${manifest_rc}" != "0" || "${contents_qa_rc}" != "0" || "${patch_base_rc}" != "0" || "${wcp_parity_rc}" != "0" || "${intake_rc}" != "0" || "${high_cycle_rc}" != "0" || "${commit_scan_rc}" != "0" || "${release_prep_rc}" != "0" || "${snapshot_rc}" != "0" ]]; then
    fail "one or more gates failed (summary: ${WLT_FINAL_STAGE_OUT_DIR}/summary.meta)"
  fi
fi

log "final stage gates captured: ${WLT_FINAL_STAGE_OUT_DIR}"
