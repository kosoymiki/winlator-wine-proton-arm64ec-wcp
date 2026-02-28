#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${WLT_SNAPSHOT_DIR:=/tmp/mainline-forensic-snapshot-$(date +%Y%m%d_%H%M%S)}"
: "${WLT_SNAPSHOT_FAIL_MODE:=strict}"
: "${WLT_BRANCH:=main}"
: "${WLT_SINCE_HOURS:=24}"
: "${WLT_FAILURE_LIMIT:=20}"
: "${WLT_TRIAGE_ACTIVE_RUNS:=0}"
: "${WLT_TRIAGE_MAX_RUNS:=3}"
: "${WLT_TRIAGE_MAX_JOBS:=3}"
: "${WLT_CAPTURE_ONLINE_INTAKE:=1}"
: "${WLT_ONLINE_INTAKE_REQUIRED:=0}"
: "${WLT_CAPTURE_CONTENTS_QA:=1}"
: "${WLT_CONTENTS_QA_REQUIRED:=0}"
: "${WLT_CAPTURE_WCP_PARITY:=1}"
: "${WLT_WCP_PARITY_REQUIRED:=0}"
: "${WLT_WCP_PARITY_REQUIRE_ANY:=0}"
: "${WLT_WCP_PARITY_FAIL_ON_MISSING:=0}"
: "${WLT_WCP_PARITY_PAIRS_FILE:=${ROOT_DIR}/ci/validation/wcp-parity-pairs.tsv}"
: "${WLT_WCP_PARITY_LABELS:=}"
: "${WLT_CAPTURE_RELEASE_PREP:=0}"
: "${WLT_RELEASE_PREP_REQUIRED:=0}"
: "${WLT_RELEASE_PREP_REQUIRE_SOURCE:=0}"
: "${WLT_ONLINE_INTAKE_USE_HIGH_CYCLE:=1}"
: "${WLT_ONLINE_INTAKE_PROFILE:=all}"
: "${WLT_ONLINE_INTAKE_LIMIT:=8}"
: "${WLT_ONLINE_INTAKE_MAX_FOCUS_FILES:=6}"
: "${WLT_ONLINE_INTAKE_ALL_REPOS:=0}"
: "${WLT_ONLINE_INTAKE_ALIASES:=}"
: "${WLT_ONLINE_INTAKE_FETCH:=1}"
: "${WLT_ONLINE_INTAKE_MODE:=code-only}"
: "${WLT_ONLINE_INTAKE_SCOPE:=focused}"
: "${WLT_ONLINE_INTAKE_TRANSPORT:=gh}"
: "${WLT_ONLINE_INTAKE_GIT_DEPTH:=80}"
: "${WLT_ONLINE_INTAKE_CMD_TIMEOUT_SEC:=120}"
: "${WLT_ONLINE_INTAKE_GIT_FETCH_TIMEOUT_SEC:=420}"
: "${WLT_ONLINE_INTAKE_RUN_HARVEST:=1}"
: "${WLT_ONLINE_INTAKE_HARVEST_PROFILE:=core}"
: "${WLT_ONLINE_INTAKE_HARVEST_MAX_COMMITS_PER_REPO:=24}"
: "${WLT_ONLINE_INTAKE_HARVEST_APPLY:=1}"
: "${WLT_ONLINE_INTAKE_HARVEST_SKIP_NO_SYNC:=1}"
: "${WLT_ONLINE_INTAKE_HARVEST_AUTO_FOCUS_SYNC:=1}"
: "${WLT_ONLINE_INTAKE_HARVEST_INCLUDE_UNMAPPED:=1}"
: "${WLT_ONLINE_INTAKE_SYNC_BRANCH_PINS:=1}"
: "${WLT_ONLINE_INTAKE_HARVEST_FAIL_ON_REPO_ERRORS:=0}"
: "${WLT_ONLINE_BACKLOG_STRICT:=0}"
: "${WLT_ONLINE_REQUIRED_HIGH_MARKERS:=x11drv_xinput2_enable,NtUserSendHardwareInput,SEND_HWMSG_NO_RAW,WRAPPER_VK_VERSION}"
: "${WLT_ONLINE_REQUIRED_MEDIUM_MARKERS:=ContentProfile,REMOTE_PROFILES}"
: "${WLT_ONLINE_REQUIRED_LOW_MARKERS:=DXVK,D8VK,VKD3D,PROOT_TMP_DIR,BOX64_LOG,WINEDEBUG,MESA_VK_WSI_PRESENT_MODE,TU_DEBUG,WINE_OPEN_WITH_ANDROID_BROWSER}"
: "${WLT_ONLINE_REQUIRE_LOW_READY_VALIDATED:=1}"
: "${WLT_CAPTURE_COMMIT_SCAN:=1}"
: "${WLT_COMMIT_SCAN_REQUIRED:=0}"
: "${WLT_COMMIT_SCAN_PROFILE:=core}"
: "${WLT_COMMIT_SCAN_COMMITS_PER_REPO:=12}"

log() { printf '[mainline-snapshot] %s\n' "$*"; }
fail() { printf '[mainline-snapshot][error] %s\n' "$*" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || fail "gh is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
[[ "${WLT_SNAPSHOT_FAIL_MODE}" =~ ^(strict|capture-only)$ ]] || fail "WLT_SNAPSHOT_FAIL_MODE must be strict or capture-only"
[[ "${WLT_TRIAGE_ACTIVE_RUNS}" =~ ^[01]$ ]] || fail "WLT_TRIAGE_ACTIVE_RUNS must be 0 or 1"
[[ "${WLT_TRIAGE_MAX_RUNS}" =~ ^[0-9]+$ ]] || fail "WLT_TRIAGE_MAX_RUNS must be numeric"
[[ "${WLT_TRIAGE_MAX_JOBS}" =~ ^[0-9]+$ ]] || fail "WLT_TRIAGE_MAX_JOBS must be numeric"
[[ "${WLT_CAPTURE_ONLINE_INTAKE}" =~ ^[01]$ ]] || fail "WLT_CAPTURE_ONLINE_INTAKE must be 0 or 1"
[[ "${WLT_ONLINE_INTAKE_REQUIRED}" =~ ^[01]$ ]] || fail "WLT_ONLINE_INTAKE_REQUIRED must be 0 or 1"
[[ "${WLT_CAPTURE_CONTENTS_QA}" =~ ^[01]$ ]] || fail "WLT_CAPTURE_CONTENTS_QA must be 0 or 1"
[[ "${WLT_CONTENTS_QA_REQUIRED}" =~ ^[01]$ ]] || fail "WLT_CONTENTS_QA_REQUIRED must be 0 or 1"
[[ "${WLT_CAPTURE_WCP_PARITY}" =~ ^[01]$ ]] || fail "WLT_CAPTURE_WCP_PARITY must be 0 or 1"
[[ "${WLT_WCP_PARITY_REQUIRED}" =~ ^[01]$ ]] || fail "WLT_WCP_PARITY_REQUIRED must be 0 or 1"
[[ "${WLT_WCP_PARITY_REQUIRE_ANY}" =~ ^[01]$ ]] || fail "WLT_WCP_PARITY_REQUIRE_ANY must be 0 or 1"
[[ "${WLT_WCP_PARITY_FAIL_ON_MISSING}" =~ ^[01]$ ]] || fail "WLT_WCP_PARITY_FAIL_ON_MISSING must be 0 or 1"
[[ "${WLT_CAPTURE_RELEASE_PREP}" =~ ^[01]$ ]] || fail "WLT_CAPTURE_RELEASE_PREP must be 0 or 1"
[[ "${WLT_RELEASE_PREP_REQUIRED}" =~ ^[01]$ ]] || fail "WLT_RELEASE_PREP_REQUIRED must be 0 or 1"
[[ "${WLT_RELEASE_PREP_REQUIRE_SOURCE}" =~ ^[01]$ ]] || fail "WLT_RELEASE_PREP_REQUIRE_SOURCE must be 0 or 1"
[[ "${WLT_ONLINE_INTAKE_USE_HIGH_CYCLE}" =~ ^[01]$ ]] || fail "WLT_ONLINE_INTAKE_USE_HIGH_CYCLE must be 0 or 1"
[[ "${WLT_ONLINE_INTAKE_PROFILE}" =~ ^(core|all|custom)$ ]] || fail "WLT_ONLINE_INTAKE_PROFILE must be core, all or custom"
[[ "${WLT_ONLINE_INTAKE_LIMIT}" =~ ^[0-9]+$ ]] || fail "WLT_ONLINE_INTAKE_LIMIT must be numeric"
[[ "${WLT_ONLINE_INTAKE_MAX_FOCUS_FILES}" =~ ^[0-9]+$ ]] || fail "WLT_ONLINE_INTAKE_MAX_FOCUS_FILES must be numeric"
[[ "${WLT_ONLINE_INTAKE_ALL_REPOS}" =~ ^[01]$ ]] || fail "WLT_ONLINE_INTAKE_ALL_REPOS must be 0 or 1"
[[ "${WLT_ONLINE_INTAKE_FETCH}" =~ ^[01]$ ]] || fail "WLT_ONLINE_INTAKE_FETCH must be 0 or 1"
[[ "${WLT_ONLINE_INTAKE_MODE}" =~ ^(code-only|full)$ ]] || fail "WLT_ONLINE_INTAKE_MODE must be code-only or full"
[[ "${WLT_ONLINE_INTAKE_SCOPE}" =~ ^(focused|tree)$ ]] || fail "WLT_ONLINE_INTAKE_SCOPE must be focused or tree"
[[ "${WLT_ONLINE_INTAKE_TRANSPORT}" =~ ^(git|gh)$ ]] || fail "WLT_ONLINE_INTAKE_TRANSPORT must be git or gh"
[[ "${WLT_ONLINE_INTAKE_GIT_DEPTH}" =~ ^[0-9]+$ ]] || fail "WLT_ONLINE_INTAKE_GIT_DEPTH must be numeric"
[[ "${WLT_ONLINE_INTAKE_CMD_TIMEOUT_SEC}" =~ ^[0-9]+([.][0-9]+)?$ ]] || fail "WLT_ONLINE_INTAKE_CMD_TIMEOUT_SEC must be numeric"
[[ "${WLT_ONLINE_INTAKE_GIT_FETCH_TIMEOUT_SEC}" =~ ^[0-9]+([.][0-9]+)?$ ]] || fail "WLT_ONLINE_INTAKE_GIT_FETCH_TIMEOUT_SEC must be numeric"
[[ "${WLT_ONLINE_INTAKE_RUN_HARVEST}" =~ ^[01]$ ]] || fail "WLT_ONLINE_INTAKE_RUN_HARVEST must be 0 or 1"
[[ "${WLT_ONLINE_INTAKE_HARVEST_SKIP_NO_SYNC}" =~ ^[01]$ ]] || fail "WLT_ONLINE_INTAKE_HARVEST_SKIP_NO_SYNC must be 0 or 1"
[[ "${WLT_ONLINE_INTAKE_HARVEST_AUTO_FOCUS_SYNC}" =~ ^[01]$ ]] || fail "WLT_ONLINE_INTAKE_HARVEST_AUTO_FOCUS_SYNC must be 0 or 1"
[[ "${WLT_ONLINE_INTAKE_HARVEST_INCLUDE_UNMAPPED}" =~ ^[01]$ ]] || fail "WLT_ONLINE_INTAKE_HARVEST_INCLUDE_UNMAPPED must be 0 or 1"
[[ "${WLT_ONLINE_INTAKE_SYNC_BRANCH_PINS}" =~ ^[01]$ ]] || fail "WLT_ONLINE_INTAKE_SYNC_BRANCH_PINS must be 0 or 1"
[[ "${WLT_ONLINE_INTAKE_HARVEST_FAIL_ON_REPO_ERRORS}" =~ ^[01]$ ]] || fail "WLT_ONLINE_INTAKE_HARVEST_FAIL_ON_REPO_ERRORS must be 0 or 1"
[[ "${WLT_ONLINE_BACKLOG_STRICT}" =~ ^[01]$ ]] || fail "WLT_ONLINE_BACKLOG_STRICT must be 0 or 1"
[[ "${WLT_ONLINE_REQUIRE_LOW_READY_VALIDATED}" =~ ^[01]$ ]] || fail "WLT_ONLINE_REQUIRE_LOW_READY_VALIDATED must be 0 or 1"
[[ "${WLT_CAPTURE_COMMIT_SCAN}" =~ ^[01]$ ]] || fail "WLT_CAPTURE_COMMIT_SCAN must be 0 or 1"
[[ "${WLT_COMMIT_SCAN_REQUIRED}" =~ ^[01]$ ]] || fail "WLT_COMMIT_SCAN_REQUIRED must be 0 or 1"
[[ "${WLT_COMMIT_SCAN_PROFILE}" =~ ^(core|all|custom)$ ]] || fail "WLT_COMMIT_SCAN_PROFILE must be core, all or custom"
[[ "${WLT_COMMIT_SCAN_COMMITS_PER_REPO}" =~ ^[0-9]+$ ]] || fail "WLT_COMMIT_SCAN_COMMITS_PER_REPO must be numeric"

if [[ "${WLT_ONLINE_INTAKE_PROFILE}" == "core" && -z "${WLT_ONLINE_INTAKE_ALIASES}" ]]; then
  WLT_ONLINE_INTAKE_ALIASES="coffin_winlator,coffin_wine,gamenative_protonwine,utkarsh_gamenative,olegos2_mobox,ilya114_box64droid,ahmad1abbadi_darkos,christianhaitian_darkos,kreitinn_micewine_application,termux_x11"
fi
if [[ "${WLT_ONLINE_INTAKE_PROFILE}" == "all" ]]; then
  WLT_ONLINE_INTAKE_ALL_REPOS=1
  WLT_ONLINE_INTAKE_ALIASES=""
fi
if [[ "${WLT_ONLINE_INTAKE_PROFILE}" == "custom" && -z "${WLT_ONLINE_INTAKE_ALIASES}" ]]; then
  fail "WLT_ONLINE_INTAKE_PROFILE=custom requires WLT_ONLINE_INTAKE_ALIASES"
fi

mkdir -p "${WLT_SNAPSHOT_DIR}"

run_capture() {
  local name="$1"; shift
  local out="${WLT_SNAPSHOT_DIR}/${name}.log"
  if "$@" >"${out}" 2>&1; then
    printf '0\n'
  else
    rc=$?
    printf '%s\n' "${rc}"
  fi
}

printf 'time_utc=%s\nbranch=%s\nsince_hours=%s\nfailure_limit=%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${WLT_BRANCH}" "${WLT_SINCE_HOURS}" "${WLT_FAILURE_LIMIT}" \
  > "${WLT_SNAPSHOT_DIR}/snapshot.meta"
git -C "${ROOT_DIR}" rev-parse HEAD > "${WLT_SNAPSHOT_DIR}/git-head.txt"
git -C "${ROOT_DIR}" status --short > "${WLT_SNAPSHOT_DIR}/git-status.txt"
git -C "${ROOT_DIR}" rev-list --count origin/main..main > "${WLT_SNAPSHOT_DIR}/ahead-count.txt" 2>/dev/null || true

health_rc="$(run_capture "health" env WLT_HEALTH_OUTPUT_PREFIX="${WLT_SNAPSHOT_DIR}/mainline-health" \
  bash "${ROOT_DIR}/ci/validation/gh-mainline-health.sh" "${WLT_BRANCH}" "${WLT_SINCE_HOURS}")"
failures_rc="$(run_capture "active-failures" env WLT_FAILURES_OUTPUT_PREFIX="${WLT_SNAPSHOT_DIR}/active-failures" \
  bash "${ROOT_DIR}/ci/validation/gh-latest-failures.sh" "${WLT_FAILURE_LIMIT}" "${WLT_BRANCH}" "${WLT_SINCE_HOURS}")"
contents_qa_rc=0
if [[ "${WLT_CAPTURE_CONTENTS_QA}" == "1" ]]; then
  contents_qa_rc="$(run_capture "contents-qa" \
    python3 "${ROOT_DIR}/ci/validation/check-contents-qa-contract.py" \
      --root "${ROOT_DIR}" \
      --output "${WLT_SNAPSHOT_DIR}/contents-qa.md")"
fi
wcp_parity_rc=0
if [[ "${WLT_CAPTURE_WCP_PARITY}" == "1" ]]; then
  wcp_parity_rc="$(run_capture "wcp-parity" env \
    WLT_WCP_PARITY_OUT_DIR="${WLT_SNAPSHOT_DIR}/wcp-parity" \
    WLT_WCP_PARITY_PAIRS_FILE="${WLT_WCP_PARITY_PAIRS_FILE}" \
    WLT_WCP_PARITY_REQUIRE_ANY="${WLT_WCP_PARITY_REQUIRE_ANY}" \
    WLT_WCP_PARITY_FAIL_ON_MISSING="${WLT_WCP_PARITY_FAIL_ON_MISSING}" \
    WLT_WCP_PARITY_LABELS="${WLT_WCP_PARITY_LABELS}" \
    bash "${ROOT_DIR}/ci/validation/run-wcp-parity-suite.sh")"
fi
triage_rc=0
online_intake_rc=0
release_prep_rc=0
commit_scan_rc=0
online_high_rows=-1
online_high_not_validated=-1
online_medium_rows=-1
online_medium_not_validated=-1
online_low_rows=-1
online_low_not_validated=-1
commit_scan_json="${WLT_SNAPSHOT_DIR}/online-intake/commit-scan.json"

if [[ "${WLT_CAPTURE_RELEASE_PREP}" == "1" ]]; then
  release_prep_rc="$(run_capture "release-patch-base" env \
    WLT_RELEASE_PREP_OUT_DIR="${WLT_SNAPSHOT_DIR}/release-patch-base" \
    WLT_RELEASE_PREP_REQUIRE_SOURCE="${WLT_RELEASE_PREP_REQUIRE_SOURCE}" \
    bash "${ROOT_DIR}/ci/validation/prepare-release-patch-base.sh")"
fi

if [[ "${WLT_CAPTURE_COMMIT_SCAN}" == "1" ]]; then
  commit_scan_dir="$(dirname "${commit_scan_json}")"
  commit_scan_rc="$(run_capture "commit-scan" env \
    ONLINE_COMMIT_SCAN_OUT_DIR="${commit_scan_dir}" \
    ONLINE_COMMIT_SCAN_PROFILE="${WLT_COMMIT_SCAN_PROFILE}" \
    ONLINE_COMMIT_SCAN_COMMITS_PER_REPO="${WLT_COMMIT_SCAN_COMMITS_PER_REPO}" \
    ONLINE_COMMIT_SCAN_ALIASES="${WLT_ONLINE_INTAKE_ALIASES}" \
    bash "${ROOT_DIR}/ci/reverse/online-commit-scan.sh")"
fi

if [[ "${WLT_CAPTURE_ONLINE_INTAKE}" == "1" ]]; then
  online_dir="${WLT_SNAPSHOT_DIR}/online-intake"
  if [[ "${WLT_ONLINE_INTAKE_USE_HIGH_CYCLE}" == "1" ]]; then
    online_intake_rc="$(run_capture "online-intake" env \
      WLT_HIGH_CYCLE_OUT_DIR="${online_dir}" \
      WLT_HIGH_CYCLE_FETCH="${WLT_ONLINE_INTAKE_FETCH}" \
      WLT_HIGH_CYCLE_TRANSPORT="${WLT_ONLINE_INTAKE_TRANSPORT}" \
      WLT_HIGH_CYCLE_PROFILE="${WLT_ONLINE_INTAKE_PROFILE}" \
      WLT_HIGH_CYCLE_MODE="${WLT_ONLINE_INTAKE_MODE}" \
      WLT_HIGH_CYCLE_SCOPE="${WLT_ONLINE_INTAKE_SCOPE}" \
      WLT_HIGH_CYCLE_LIMIT="${WLT_ONLINE_INTAKE_LIMIT}" \
      WLT_HIGH_CYCLE_MAX_FOCUS_FILES="${WLT_ONLINE_INTAKE_MAX_FOCUS_FILES}" \
      WLT_HIGH_CYCLE_ALL_REPOS="${WLT_ONLINE_INTAKE_ALL_REPOS}" \
      WLT_HIGH_CYCLE_ALIASES="${WLT_ONLINE_INTAKE_ALIASES}" \
      WLT_HIGH_CYCLE_GIT_DEPTH="${WLT_ONLINE_INTAKE_GIT_DEPTH}" \
      WLT_HIGH_CYCLE_CMD_TIMEOUT_SEC="${WLT_ONLINE_INTAKE_CMD_TIMEOUT_SEC}" \
      WLT_HIGH_CYCLE_GIT_FETCH_TIMEOUT_SEC="${WLT_ONLINE_INTAKE_GIT_FETCH_TIMEOUT_SEC}" \
      WLT_HIGH_CYCLE_BACKLOG_STRICT="${WLT_ONLINE_BACKLOG_STRICT}" \
      WLT_HIGH_CYCLE_REQUIRED_HIGH_MARKERS="${WLT_ONLINE_REQUIRED_HIGH_MARKERS}" \
      WLT_HIGH_CYCLE_REQUIRED_MEDIUM_MARKERS="${WLT_ONLINE_REQUIRED_MEDIUM_MARKERS}" \
      WLT_HIGH_CYCLE_REQUIRED_LOW_MARKERS="${WLT_ONLINE_REQUIRED_LOW_MARKERS}" \
      WLT_HIGH_CYCLE_REQUIRE_LOW_READY_VALIDATED="${WLT_ONLINE_REQUIRE_LOW_READY_VALIDATED}" \
      WLT_HIGH_CYCLE_RUN_COMMIT_SCAN=0 \
      WLT_HIGH_CYCLE_INCLUDE_COMMIT_SCAN="${WLT_CAPTURE_COMMIT_SCAN}" \
      WLT_HIGH_CYCLE_COMMIT_SCAN_JSON="${commit_scan_json}" \
      WLT_HIGH_CYCLE_COMMIT_SCAN_PROFILE="${WLT_COMMIT_SCAN_PROFILE}" \
      WLT_HIGH_CYCLE_COMMIT_SCAN_COMMITS_PER_REPO="${WLT_COMMIT_SCAN_COMMITS_PER_REPO}" \
      WLT_HIGH_CYCLE_RUN_HARVEST="${WLT_ONLINE_INTAKE_RUN_HARVEST}" \
      WLT_HIGH_CYCLE_HARVEST_PROFILE="${WLT_ONLINE_INTAKE_HARVEST_PROFILE}" \
      WLT_HIGH_CYCLE_HARVEST_MAX_COMMITS_PER_REPO="${WLT_ONLINE_INTAKE_HARVEST_MAX_COMMITS_PER_REPO}" \
      WLT_HIGH_CYCLE_HARVEST_APPLY="${WLT_ONLINE_INTAKE_HARVEST_APPLY}" \
      WLT_HIGH_CYCLE_HARVEST_SKIP_NO_SYNC="${WLT_ONLINE_INTAKE_HARVEST_SKIP_NO_SYNC}" \
      WLT_HIGH_CYCLE_HARVEST_AUTO_FOCUS_SYNC="${WLT_ONLINE_INTAKE_HARVEST_AUTO_FOCUS_SYNC}" \
      WLT_HIGH_CYCLE_HARVEST_INCLUDE_UNMAPPED="${WLT_ONLINE_INTAKE_HARVEST_INCLUDE_UNMAPPED}" \
      WLT_HIGH_CYCLE_SYNC_BRANCH_PINS="${WLT_ONLINE_INTAKE_SYNC_BRANCH_PINS}" \
      WLT_HIGH_CYCLE_HARVEST_FAIL_ON_REPO_ERRORS="${WLT_ONLINE_INTAKE_HARVEST_FAIL_ON_REPO_ERRORS}" \
      WLT_HIGH_CYCLE_RUN_GN_MANIFEST=1 \
      "${ROOT_DIR}/ci/reverse/run-high-priority-cycle.sh")"
  else
    online_intake_rc="$(run_capture "online-intake" env \
      OUT_DIR="${online_dir}" \
      LIMIT="${WLT_ONLINE_INTAKE_LIMIT}" \
      MAX_FOCUS_FILES="${WLT_ONLINE_INTAKE_MAX_FOCUS_FILES}" \
      INCLUDE_ALL_REPOS="${WLT_ONLINE_INTAKE_ALL_REPOS}" \
      ONLINE_INTAKE_ALIASES="${WLT_ONLINE_INTAKE_ALIASES}" \
      ONLINE_INTAKE_FETCH="${WLT_ONLINE_INTAKE_FETCH}" \
      ONLINE_INTAKE_MODE="${WLT_ONLINE_INTAKE_MODE}" \
      ONLINE_INTAKE_SCOPE="${WLT_ONLINE_INTAKE_SCOPE}" \
      ONLINE_INTAKE_TRANSPORT="${WLT_ONLINE_INTAKE_TRANSPORT}" \
      ONLINE_INTAKE_GIT_DEPTH="${WLT_ONLINE_INTAKE_GIT_DEPTH}" \
      ONLINE_INTAKE_CMD_TIMEOUT_SEC="${WLT_ONLINE_INTAKE_CMD_TIMEOUT_SEC}" \
      ONLINE_INTAKE_GIT_FETCH_TIMEOUT_SEC="${WLT_ONLINE_INTAKE_GIT_FETCH_TIMEOUT_SEC}" \
      ONLINE_BACKLOG_STRICT="${WLT_ONLINE_BACKLOG_STRICT}" \
      ONLINE_REQUIRED_HIGH_MARKERS="${WLT_ONLINE_REQUIRED_HIGH_MARKERS}" \
      ONLINE_REQUIRED_MEDIUM_MARKERS="${WLT_ONLINE_REQUIRED_MEDIUM_MARKERS}" \
      ONLINE_REQUIRED_LOW_MARKERS="${WLT_ONLINE_REQUIRED_LOW_MARKERS}" \
      ONLINE_REQUIRE_LOW_READY_VALIDATED="${WLT_ONLINE_REQUIRE_LOW_READY_VALIDATED}" \
      ONLINE_INCLUDE_COMMIT_SCAN="${WLT_CAPTURE_COMMIT_SCAN}" \
      ONLINE_COMMIT_SCAN_AUTO=0 \
      ONLINE_COMMIT_SCAN_PROFILE="${WLT_COMMIT_SCAN_PROFILE}" \
      ONLINE_COMMIT_SCAN_COMMITS_PER_REPO="${WLT_COMMIT_SCAN_COMMITS_PER_REPO}" \
      ONLINE_COMMIT_SCAN_JSON="${commit_scan_json}" \
      ONLINE_RUN_HARVEST="${WLT_ONLINE_INTAKE_RUN_HARVEST}" \
      ONLINE_HARVEST_PROFILE="${WLT_ONLINE_INTAKE_HARVEST_PROFILE}" \
      ONLINE_HARVEST_MAX_COMMITS_PER_REPO="${WLT_ONLINE_INTAKE_HARVEST_MAX_COMMITS_PER_REPO}" \
      ONLINE_HARVEST_APPLY="${WLT_ONLINE_INTAKE_HARVEST_APPLY}" \
      ONLINE_HARVEST_SKIP_NO_SYNC="${WLT_ONLINE_INTAKE_HARVEST_SKIP_NO_SYNC}" \
      ONLINE_HARVEST_AUTO_FOCUS_SYNC="${WLT_ONLINE_INTAKE_HARVEST_AUTO_FOCUS_SYNC}" \
      ONLINE_HARVEST_INCLUDE_UNMAPPED="${WLT_ONLINE_INTAKE_HARVEST_INCLUDE_UNMAPPED}" \
      ONLINE_HARVEST_FAIL_ON_REPO_ERRORS="${WLT_ONLINE_INTAKE_HARVEST_FAIL_ON_REPO_ERRORS}" \
      ONLINE_SYNC_BRANCH_PINS="${WLT_ONLINE_INTAKE_SYNC_BRANCH_PINS}" \
      ONLINE_RUN_SNAPSHOT_AUDIT=1 \
      ONLINE_SNAPSHOT_AUDIT_STRICT=1 \
      bash "${ROOT_DIR}/ci/reverse/online-intake.sh")"
  fi

  backlog_json="${online_dir}/PATCH_TRANSFER_BACKLOG.json"
  if [[ -f "${backlog_json}" ]]; then
    read -r online_high_rows online_high_not_validated online_medium_rows online_medium_not_validated online_low_rows online_low_not_validated < <(python3 - "${backlog_json}" <<'PY'
import json
import sys
rows = (json.load(open(sys.argv[1], encoding="utf-8")).get("rows") or [])
high = [r for r in rows if str(r.get("priority", "")).lower() == "high"]
medium = [r for r in rows if str(r.get("priority", "")).lower() == "medium"]
low = [r for r in rows if str(r.get("priority", "")).lower() == "low"]
not_validated = [r for r in high if r.get("status") != "ready_validated"]
medium_not_validated = [r for r in medium if r.get("status") != "ready_validated"]
low_not_validated = [r for r in low if r.get("status") != "ready_validated"]
print(f"{len(high)} {len(not_validated)} {len(medium)} {len(medium_not_validated)} {len(low)} {len(low_not_validated)}")
PY
)
  fi
fi

if [[ "${WLT_TRIAGE_ACTIVE_RUNS}" == "1" && "${failures_rc}" == "0" ]]; then
  active_tsv="${WLT_SNAPSHOT_DIR}/active-failures.tsv"
  if [[ -f "${active_tsv}" ]]; then
    mapfile -t active_run_ids < <(tail -n +2 "${active_tsv}" | cut -f1 | sed '/^$/d' | head -n "${WLT_TRIAGE_MAX_RUNS}")
    if [[ "${#active_run_ids[@]}" -gt 0 ]]; then
      triage_dir="${WLT_SNAPSHOT_DIR}/run-triage"
      mkdir -p "${triage_dir}"
      for run_id in "${active_run_ids[@]}"; do
        log "triage run ${run_id}"
        if ! WLT_RUN_TRIAGE_DIR="${triage_dir}/run-${run_id}" \
          bash "${ROOT_DIR}/ci/validation/gh-run-root-cause.sh" "${run_id}" "${WLT_TRIAGE_MAX_JOBS}" \
          > "${triage_dir}/run-${run_id}.log" 2>&1; then
          triage_rc=1
        fi
      done
    fi
  fi
fi

{
  printf 'fail_mode=%s\n' "${WLT_SNAPSHOT_FAIL_MODE}"
  printf 'health_rc=%s\n' "${health_rc}"
  printf 'active_failures_rc=%s\n' "${failures_rc}"
  printf 'contents_qa_rc=%s\n' "${contents_qa_rc}"
  printf 'capture_contents_qa=%s\n' "${WLT_CAPTURE_CONTENTS_QA}"
  printf 'contents_qa_required=%s\n' "${WLT_CONTENTS_QA_REQUIRED}"
  printf 'wcp_parity_rc=%s\n' "${wcp_parity_rc}"
  printf 'capture_wcp_parity=%s\n' "${WLT_CAPTURE_WCP_PARITY}"
  printf 'wcp_parity_required=%s\n' "${WLT_WCP_PARITY_REQUIRED}"
  printf 'wcp_parity_require_any=%s\n' "${WLT_WCP_PARITY_REQUIRE_ANY}"
  printf 'wcp_parity_fail_on_missing=%s\n' "${WLT_WCP_PARITY_FAIL_ON_MISSING}"
  printf 'wcp_parity_pairs_file=%s\n' "${WLT_WCP_PARITY_PAIRS_FILE}"
  printf 'wcp_parity_labels=%s\n' "${WLT_WCP_PARITY_LABELS}"
  printf 'triage_rc=%s\n' "${triage_rc}"
  printf 'online_intake_rc=%s\n' "${online_intake_rc}"
  printf 'online_intake_scope=%s\n' "${WLT_ONLINE_INTAKE_SCOPE}"
  printf 'online_intake_run_harvest=%s\n' "${WLT_ONLINE_INTAKE_RUN_HARVEST}"
  printf 'online_intake_harvest_profile=%s\n' "${WLT_ONLINE_INTAKE_HARVEST_PROFILE}"
  printf 'online_intake_harvest_commits_per_repo=%s\n' "${WLT_ONLINE_INTAKE_HARVEST_MAX_COMMITS_PER_REPO}"
  printf 'online_intake_harvest_apply=%s\n' "${WLT_ONLINE_INTAKE_HARVEST_APPLY}"
  printf 'online_intake_harvest_skip_no_sync=%s\n' "${WLT_ONLINE_INTAKE_HARVEST_SKIP_NO_SYNC}"
  printf 'online_intake_harvest_auto_focus_sync=%s\n' "${WLT_ONLINE_INTAKE_HARVEST_AUTO_FOCUS_SYNC}"
  printf 'online_intake_harvest_include_unmapped=%s\n' "${WLT_ONLINE_INTAKE_HARVEST_INCLUDE_UNMAPPED}"
  printf 'online_intake_sync_branch_pins=%s\n' "${WLT_ONLINE_INTAKE_SYNC_BRANCH_PINS}"
  printf 'online_intake_harvest_fail_on_repo_errors=%s\n' "${WLT_ONLINE_INTAKE_HARVEST_FAIL_ON_REPO_ERRORS}"
  printf 'release_prep_rc=%s\n' "${release_prep_rc}"
  printf 'commit_scan_rc=%s\n' "${commit_scan_rc}"
  printf 'commit_scan_profile=%s\n' "${WLT_COMMIT_SCAN_PROFILE}"
  printf 'commit_scan_commits_per_repo=%s\n' "${WLT_COMMIT_SCAN_COMMITS_PER_REPO}"
  printf 'online_high_rows=%s\n' "${online_high_rows}"
  printf 'online_high_not_ready_validated=%s\n' "${online_high_not_validated}"
  printf 'online_medium_rows=%s\n' "${online_medium_rows}"
  printf 'online_medium_not_ready_validated=%s\n' "${online_medium_not_validated}"
  printf 'online_low_rows=%s\n' "${online_low_rows}"
  printf 'online_low_not_ready_validated=%s\n' "${online_low_not_validated}"
} > "${WLT_SNAPSHOT_DIR}/status.meta"

if [[ "${WLT_SNAPSHOT_FAIL_MODE}" == "strict" ]]; then
  if [[ "${WLT_CONTENTS_QA_REQUIRED}" == "1" && "${contents_qa_rc}" != "0" ]]; then
    log "snapshot captured with contents QA failure: ${WLT_SNAPSHOT_DIR}"
    fail "contents QA failed (contents_qa=${contents_qa_rc})"
  fi

  if [[ "${WLT_WCP_PARITY_REQUIRED}" == "1" && "${wcp_parity_rc}" != "0" ]]; then
    log "snapshot captured with WCP parity failure: ${WLT_SNAPSHOT_DIR}"
    fail "wcp parity failed (wcp_parity=${wcp_parity_rc})"
  fi

  if [[ "${WLT_RELEASE_PREP_REQUIRED}" == "1" && "${release_prep_rc}" != "0" ]]; then
    log "snapshot captured with release patch-base failure: ${WLT_SNAPSHOT_DIR}"
    fail "release patch-base failed (release_prep=${release_prep_rc})"
  fi

  if [[ "${WLT_ONLINE_INTAKE_REQUIRED}" == "1" && "${online_intake_rc}" != "0" ]]; then
    log "snapshot captured with online-intake failure: ${WLT_SNAPSHOT_DIR}"
    fail "online intake failed (online_intake=${online_intake_rc})"
  fi

  if [[ "${WLT_COMMIT_SCAN_REQUIRED}" == "1" && "${commit_scan_rc}" != "0" ]]; then
    log "snapshot captured with online commit-scan failure: ${WLT_SNAPSHOT_DIR}"
    fail "online commit-scan failed (commit_scan=${commit_scan_rc})"
  fi

  if [[ "${health_rc}" != "0" || "${failures_rc}" != "0" || "${contents_qa_rc}" != "0" || "${wcp_parity_rc}" != "0" || "${triage_rc}" != "0" ]]; then
    log "snapshot captured with failures: ${WLT_SNAPSHOT_DIR}"
    fail "one or more checks failed (health=${health_rc}, active_failures=${failures_rc}, contents_qa=${contents_qa_rc}, wcp_parity=${wcp_parity_rc}, triage=${triage_rc})"
  fi
else
  log "capture-only mode: not failing on check return codes"
fi

log "snapshot captured: ${WLT_SNAPSHOT_DIR}"
