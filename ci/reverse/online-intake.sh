#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

OUT_DIR="${OUT_DIR:-docs/reverse/online-intake}"
LIMIT="${LIMIT:-8}"
MAX_FOCUS_FILES="${MAX_FOCUS_FILES:-6}"
GH_RETRIES="${GH_RETRIES:-4}"
GH_RETRY_DELAY_SEC="${GH_RETRY_DELAY_SEC:-1.5}"
ONLINE_INTAKE_MODE="${ONLINE_INTAKE_MODE:-code-only}"
ONLINE_INTAKE_SCOPE="${ONLINE_INTAKE_SCOPE:-focused}"
ONLINE_INTAKE_TRANSPORT="${ONLINE_INTAKE_TRANSPORT:-gh}"
ONLINE_INTAKE_GIT_WORKDIR="${ONLINE_INTAKE_GIT_WORKDIR:-${OUT_DIR}/_git-cache}"
ONLINE_INTAKE_GIT_DEPTH="${ONLINE_INTAKE_GIT_DEPTH:-80}"
ONLINE_INTAKE_CMD_TIMEOUT_SEC="${ONLINE_INTAKE_CMD_TIMEOUT_SEC:-120}"
ONLINE_INTAKE_GIT_FETCH_TIMEOUT_SEC="${ONLINE_INTAKE_GIT_FETCH_TIMEOUT_SEC:-420}"
REPO_FILE="${REPO_FILE:-ci/reverse/online_intake_repos.json}"
INCLUDE_ALL_REPOS="${INCLUDE_ALL_REPOS:-0}"
ONLINE_INTAKE_ALIASES="${ONLINE_INTAKE_ALIASES:-}"
ONLINE_INTAKE_FETCH="${ONLINE_INTAKE_FETCH:-1}"
ONLINE_BACKLOG_STRICT="${ONLINE_BACKLOG_STRICT:-0}"
ONLINE_REQUIRED_HIGH_MARKERS="${ONLINE_REQUIRED_HIGH_MARKERS:-x11drv_xinput2_enable,NtUserSendHardwareInput,SEND_HWMSG_NO_RAW,WRAPPER_VK_VERSION}"
ONLINE_REQUIRED_MEDIUM_MARKERS="${ONLINE_REQUIRED_MEDIUM_MARKERS:-ContentProfile,REMOTE_PROFILES}"
ONLINE_REQUIRED_LOW_MARKERS="${ONLINE_REQUIRED_LOW_MARKERS:-DXVK,D8VK,VKD3D,PROOT_TMP_DIR,BOX64_LOG,WINEDEBUG,MESA_VK_WSI_PRESENT_MODE,TU_DEBUG,WINE_OPEN_WITH_ANDROID_BROWSER}"
ONLINE_REQUIRE_LOW_READY_VALIDATED="${ONLINE_REQUIRE_LOW_READY_VALIDATED:-1}"
ONLINE_INCLUDE_COMMIT_SCAN="${ONLINE_INCLUDE_COMMIT_SCAN:-1}"
ONLINE_COMMIT_SCAN_AUTO="${ONLINE_COMMIT_SCAN_AUTO:-1}"
ONLINE_COMMIT_SCAN_PROFILE="${ONLINE_COMMIT_SCAN_PROFILE:-}"
ONLINE_COMMIT_SCAN_COMMITS_PER_REPO="${ONLINE_COMMIT_SCAN_COMMITS_PER_REPO:-12}"
ONLINE_COMMIT_SCAN_JSON="${ONLINE_COMMIT_SCAN_JSON:-${OUT_DIR}/commit-scan.json}"
ONLINE_RUN_HARVEST="${ONLINE_RUN_HARVEST:-0}"
ONLINE_HARVEST_PROFILE="${ONLINE_HARVEST_PROFILE:-}"
ONLINE_HARVEST_MAX_COMMITS_PER_REPO="${ONLINE_HARVEST_MAX_COMMITS_PER_REPO:-24}"
ONLINE_HARVEST_APPLY="${ONLINE_HARVEST_APPLY:-1}"
ONLINE_HARVEST_SKIP_NO_SYNC="${ONLINE_HARVEST_SKIP_NO_SYNC:-1}"
ONLINE_HARVEST_AUTO_FOCUS_SYNC="${ONLINE_HARVEST_AUTO_FOCUS_SYNC:-1}"
ONLINE_HARVEST_INCLUDE_UNMAPPED="${ONLINE_HARVEST_INCLUDE_UNMAPPED:-1}"
ONLINE_HARVEST_FAIL_ON_REPO_ERRORS="${ONLINE_HARVEST_FAIL_ON_REPO_ERRORS:-0}"
ONLINE_HARVEST_OUT_DIR="${ONLINE_HARVEST_OUT_DIR:-${OUT_DIR}/harvest}"
ONLINE_SYNC_BRANCH_PINS="${ONLINE_SYNC_BRANCH_PINS:-1}"
ONLINE_RUN_SNAPSHOT_AUDIT="${ONLINE_RUN_SNAPSHOT_AUDIT:-1}"
ONLINE_SNAPSHOT_AUDIT_STRICT="${ONLINE_SNAPSHOT_AUDIT_STRICT:-1}"
[[ "${ONLINE_REQUIRE_LOW_READY_VALIDATED}" =~ ^[01]$ ]] || { echo "[online-intake][error] ONLINE_REQUIRE_LOW_READY_VALIDATED must be 0 or 1" >&2; exit 1; }
[[ "${ONLINE_INCLUDE_COMMIT_SCAN}" =~ ^[01]$ ]] || { echo "[online-intake][error] ONLINE_INCLUDE_COMMIT_SCAN must be 0 or 1" >&2; exit 1; }
[[ "${ONLINE_COMMIT_SCAN_AUTO}" =~ ^[01]$ ]] || { echo "[online-intake][error] ONLINE_COMMIT_SCAN_AUTO must be 0 or 1" >&2; exit 1; }
[[ "${ONLINE_RUN_HARVEST}" =~ ^[01]$ ]] || { echo "[online-intake][error] ONLINE_RUN_HARVEST must be 0 or 1" >&2; exit 1; }
[[ "${ONLINE_HARVEST_APPLY}" =~ ^[01]$ ]] || { echo "[online-intake][error] ONLINE_HARVEST_APPLY must be 0 or 1" >&2; exit 1; }
[[ "${ONLINE_HARVEST_SKIP_NO_SYNC}" =~ ^[01]$ ]] || { echo "[online-intake][error] ONLINE_HARVEST_SKIP_NO_SYNC must be 0 or 1" >&2; exit 1; }
[[ "${ONLINE_HARVEST_AUTO_FOCUS_SYNC}" =~ ^[01]$ ]] || { echo "[online-intake][error] ONLINE_HARVEST_AUTO_FOCUS_SYNC must be 0 or 1" >&2; exit 1; }
[[ "${ONLINE_HARVEST_INCLUDE_UNMAPPED}" =~ ^[01]$ ]] || { echo "[online-intake][error] ONLINE_HARVEST_INCLUDE_UNMAPPED must be 0 or 1" >&2; exit 1; }
[[ "${ONLINE_HARVEST_FAIL_ON_REPO_ERRORS}" =~ ^[01]$ ]] || { echo "[online-intake][error] ONLINE_HARVEST_FAIL_ON_REPO_ERRORS must be 0 or 1" >&2; exit 1; }
[[ "${ONLINE_SYNC_BRANCH_PINS}" =~ ^[01]$ ]] || { echo "[online-intake][error] ONLINE_SYNC_BRANCH_PINS must be 0 or 1" >&2; exit 1; }
[[ "${ONLINE_RUN_SNAPSHOT_AUDIT}" =~ ^[01]$ ]] || { echo "[online-intake][error] ONLINE_RUN_SNAPSHOT_AUDIT must be 0 or 1" >&2; exit 1; }
[[ "${ONLINE_SNAPSHOT_AUDIT_STRICT}" =~ ^[01]$ ]] || { echo "[online-intake][error] ONLINE_SNAPSHOT_AUDIT_STRICT must be 0 or 1" >&2; exit 1; }
[[ "${ONLINE_HARVEST_MAX_COMMITS_PER_REPO}" =~ ^[0-9]+$ ]] || { echo "[online-intake][error] ONLINE_HARVEST_MAX_COMMITS_PER_REPO must be numeric" >&2; exit 1; }
[[ "${ONLINE_COMMIT_SCAN_COMMITS_PER_REPO}" =~ ^[0-9]+$ ]] || { echo "[online-intake][error] ONLINE_COMMIT_SCAN_COMMITS_PER_REPO must be numeric" >&2; exit 1; }
[[ "${ONLINE_INTAKE_SCOPE}" =~ ^(focused|tree)$ ]] || { echo "[online-intake][error] ONLINE_INTAKE_SCOPE must be focused or tree" >&2; exit 1; }
if [[ -z "${ONLINE_COMMIT_SCAN_PROFILE}" ]]; then
  if [[ "${INCLUDE_ALL_REPOS}" == "1" ]]; then
    ONLINE_COMMIT_SCAN_PROFILE="all"
  elif [[ -n "${ONLINE_INTAKE_ALIASES}" ]]; then
    ONLINE_COMMIT_SCAN_PROFILE="custom"
  else
    ONLINE_COMMIT_SCAN_PROFILE="core"
  fi
fi
if [[ -z "${ONLINE_HARVEST_PROFILE}" ]]; then
  if [[ "${INCLUDE_ALL_REPOS}" == "1" ]]; then
    ONLINE_HARVEST_PROFILE="all"
  elif [[ -n "${ONLINE_INTAKE_ALIASES}" ]]; then
    ONLINE_HARVEST_PROFILE="custom"
  else
    ONLINE_HARVEST_PROFILE="core"
  fi
fi
[[ "${ONLINE_COMMIT_SCAN_PROFILE}" =~ ^(core|all|custom)$ ]] || { echo "[online-intake][error] ONLINE_COMMIT_SCAN_PROFILE must be core, all or custom" >&2; exit 1; }
[[ "${ONLINE_HARVEST_PROFILE}" =~ ^(core|all|custom)$ ]] || { echo "[online-intake][error] ONLINE_HARVEST_PROFILE must be core, all or custom" >&2; exit 1; }
if [[ "${ONLINE_COMMIT_SCAN_PROFILE}" == "custom" && -z "${ONLINE_INTAKE_ALIASES}" ]]; then
  echo "[online-intake][error] ONLINE_COMMIT_SCAN_PROFILE=custom requires ONLINE_INTAKE_ALIASES" >&2
  exit 1
fi
if [[ "${ONLINE_HARVEST_PROFILE}" == "custom" && -z "${ONLINE_INTAKE_ALIASES}" ]]; then
  echo "[online-intake][error] ONLINE_HARVEST_PROFILE=custom requires ONLINE_INTAKE_ALIASES" >&2
  exit 1
fi

command -v python3 >/dev/null 2>&1 || { echo "[online-intake][error] python3 is required" >&2; exit 1; }
if [[ "${ONLINE_INTAKE_TRANSPORT}" == "gh" ]]; then
  command -v gh >/dev/null 2>&1 || { echo "[online-intake][error] gh is required for ONLINE_INTAKE_TRANSPORT=gh" >&2; exit 1; }
elif [[ "${ONLINE_INTAKE_TRANSPORT}" == "git" ]]; then
  command -v git >/dev/null 2>&1 || { echo "[online-intake][error] git is required for ONLINE_INTAKE_TRANSPORT=git" >&2; exit 1; }
else
  echo "[online-intake][error] unsupported ONLINE_INTAKE_TRANSPORT=${ONLINE_INTAKE_TRANSPORT}" >&2
  exit 1
fi

extra_args=()
if [[ "${INCLUDE_ALL_REPOS}" == "1" ]]; then
  extra_args+=(--all-repos)
fi
if [[ -n "${ONLINE_INTAKE_ALIASES}" ]]; then
  extra_args+=(--aliases "${ONLINE_INTAKE_ALIASES}")
fi
backlog_args=()
commit_scan_args=()
if [[ "${ONLINE_BACKLOG_STRICT}" == "1" ]]; then
  backlog_args+=(--fail-on-needs-review)
  backlog_args+=(--fail-on-intake-errors)
  if [[ "${ONLINE_INCLUDE_COMMIT_SCAN}" == "1" ]]; then
    backlog_args+=(--fail-on-commit-scan-errors)
  fi
  backlog_args+=(--require-ready-validated)
  backlog_args+=(--require-medium-ready-validated)
  if [[ "${ONLINE_REQUIRE_LOW_READY_VALIDATED}" == "1" ]]; then
    backlog_args+=(--require-low-ready-validated)
  fi
  if [[ -n "${ONLINE_REQUIRED_HIGH_MARKERS}" ]]; then
    backlog_args+=(--require-high-markers "${ONLINE_REQUIRED_HIGH_MARKERS}")
  fi
  if [[ -n "${ONLINE_REQUIRED_MEDIUM_MARKERS}" ]]; then
    backlog_args+=(--require-medium-markers "${ONLINE_REQUIRED_MEDIUM_MARKERS}")
  fi
  if [[ -n "${ONLINE_REQUIRED_LOW_MARKERS}" ]]; then
    backlog_args+=(--require-low-markers "${ONLINE_REQUIRED_LOW_MARKERS}")
  fi
fi
if [[ "${ONLINE_INCLUDE_COMMIT_SCAN}" == "1" ]]; then
  if [[ "${ONLINE_COMMIT_SCAN_AUTO}" == "1" ]]; then
    run_commit_scan=0
    if [[ "${ONLINE_INTAKE_FETCH}" == "1" || ! -f "${ONLINE_COMMIT_SCAN_JSON}" ]]; then
      run_commit_scan=1
    fi
    if [[ "${run_commit_scan}" == "1" ]]; then
      command -v gh >/dev/null 2>&1 || { echo "[online-intake][error] gh is required for ONLINE_COMMIT_SCAN_AUTO=1" >&2; exit 1; }
      commit_scan_out_dir="$(dirname -- "${ONLINE_COMMIT_SCAN_JSON}")"
      mkdir -p "${commit_scan_out_dir}"
      echo "[online-intake] running online commit scan (profile=${ONLINE_COMMIT_SCAN_PROFILE}, commits_per_repo=${ONLINE_COMMIT_SCAN_COMMITS_PER_REPO})"
      ONLINE_COMMIT_SCAN_PROFILE="${ONLINE_COMMIT_SCAN_PROFILE}" \
      ONLINE_COMMIT_SCAN_ALIASES="${ONLINE_INTAKE_ALIASES}" \
      ONLINE_COMMIT_SCAN_COMMITS_PER_REPO="${ONLINE_COMMIT_SCAN_COMMITS_PER_REPO}" \
      ONLINE_COMMIT_SCAN_OUT_DIR="${commit_scan_out_dir}" \
      ONLINE_COMMIT_SCAN_REPO_FILE="${REPO_FILE}" \
      ONLINE_COMMIT_SCAN_RETRIES="${GH_RETRIES}" \
      ONLINE_COMMIT_SCAN_RETRY_DELAY_SEC="${GH_RETRY_DELAY_SEC}" \
      bash ci/reverse/online-commit-scan.sh
      generated_commit_scan_json="${commit_scan_out_dir}/commit-scan.json"
      if [[ "${generated_commit_scan_json}" != "${ONLINE_COMMIT_SCAN_JSON}" && -f "${generated_commit_scan_json}" ]]; then
        cp "${generated_commit_scan_json}" "${ONLINE_COMMIT_SCAN_JSON}"
      fi
    fi
  fi
  commit_scan_args+=(--commit-scan-json "${ONLINE_COMMIT_SCAN_JSON}")
fi

if [[ "${ONLINE_INTAKE_FETCH}" == "1" ]]; then
  echo "[online-intake] running intake (transport=${ONLINE_INTAKE_TRANSPORT}, mode=${ONLINE_INTAKE_MODE}, scope=${ONLINE_INTAKE_SCOPE}, limit=${LIMIT}, max_focus_files=${MAX_FOCUS_FILES}, all_repos=${INCLUDE_ALL_REPOS})"
  python3 ci/reverse/online_intake.py \
    --out-dir "${OUT_DIR}" \
    --limit "${LIMIT}" \
    --max-focus-files "${MAX_FOCUS_FILES}" \
    --mode "${ONLINE_INTAKE_MODE}" \
    --scope "${ONLINE_INTAKE_SCOPE}" \
    --transport "${ONLINE_INTAKE_TRANSPORT}" \
    --git-workdir "${ONLINE_INTAKE_GIT_WORKDIR}" \
    --git-depth "${ONLINE_INTAKE_GIT_DEPTH}" \
    --cmd-timeout-sec "${ONLINE_INTAKE_CMD_TIMEOUT_SEC}" \
    --git-fetch-timeout-sec "${ONLINE_INTAKE_GIT_FETCH_TIMEOUT_SEC}" \
    --gh-retries "${GH_RETRIES}" \
    --gh-retry-delay-sec "${GH_RETRY_DELAY_SEC}" \
    --repo-file "${REPO_FILE}" \
    "${extra_args[@]}"
else
  echo "[online-intake] fetch skipped (ONLINE_INTAKE_FETCH=0), using existing combined matrix"
  if [[ ! -f "${OUT_DIR}/combined-matrix.json" ]]; then
    fallback_combined="docs/reverse/online-intake/combined-matrix.json"
    fallback_combined_md="docs/reverse/online-intake/combined-matrix.md"
    if [[ -f "${fallback_combined}" ]]; then
      mkdir -p "${OUT_DIR}"
      cp "${fallback_combined}" "${OUT_DIR}/combined-matrix.json"
      if [[ -f "${fallback_combined_md}" ]]; then
        cp "${fallback_combined_md}" "${OUT_DIR}/combined-matrix.md"
      fi
      echo "[online-intake] seeded ${OUT_DIR}/combined-matrix.json from ${fallback_combined}"
    else
      echo "[online-intake][error] ONLINE_INTAKE_FETCH=0 but ${OUT_DIR}/combined-matrix.json is missing" >&2
      exit 1
    fi
  fi
fi
python3 ci/reverse/generate-online-backlog.py \
  --combined-json "${OUT_DIR}/combined-matrix.json" \
  "${commit_scan_args[@]}" \
  --out-md "${OUT_DIR}/PATCH_TRANSFER_BACKLOG.md" \
  --out-json "${OUT_DIR}/PATCH_TRANSFER_BACKLOG.json" \
  --repo-root "${ROOT_DIR}"
python3 ci/reverse/check-online-backlog.py \
  --backlog-json "${OUT_DIR}/PATCH_TRANSFER_BACKLOG.json" \
  "${backlog_args[@]}"
if [[ "${ONLINE_RUN_HARVEST}" == "1" ]]; then
  echo "[online-intake] running harvest transfer (profile=${ONLINE_HARVEST_PROFILE}, apply=${ONLINE_HARVEST_APPLY})"
  HARVEST_TRANSFER_PROFILE="${ONLINE_HARVEST_PROFILE}" \
  HARVEST_TRANSFER_REPO_FILE="${REPO_FILE}" \
  HARVEST_TRANSFER_ALIASES="${ONLINE_INTAKE_ALIASES}" \
  HARVEST_TRANSFER_ALL_REPOS="${INCLUDE_ALL_REPOS}" \
  HARVEST_TRANSFER_COMMIT_SCAN_JSON="${ONLINE_COMMIT_SCAN_JSON}" \
  HARVEST_TRANSFER_OUT_DIR="${ONLINE_HARVEST_OUT_DIR}" \
  HARVEST_TRANSFER_MAX_COMMITS_PER_REPO="${ONLINE_HARVEST_MAX_COMMITS_PER_REPO}" \
  HARVEST_TRANSFER_APPLY="${ONLINE_HARVEST_APPLY}" \
  HARVEST_TRANSFER_SKIP_NO_SYNC="${ONLINE_HARVEST_SKIP_NO_SYNC}" \
  HARVEST_TRANSFER_AUTO_FOCUS_SYNC="${ONLINE_HARVEST_AUTO_FOCUS_SYNC}" \
  HARVEST_TRANSFER_INCLUDE_UNMAPPED="${ONLINE_HARVEST_INCLUDE_UNMAPPED}" \
  HARVEST_TRANSFER_FAIL_ON_REPO_ERRORS="${ONLINE_HARVEST_FAIL_ON_REPO_ERRORS}" \
  bash ci/reverse/harvest-transfer.sh
  harvest_report="${ONLINE_HARVEST_OUT_DIR}/transfer-report.json"
  if [[ -f "${harvest_report}" ]]; then
    python3 - "${harvest_report}" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
repos = payload.get("repos") or []
print(f"[online-intake] harvest_repo_errors={int(payload.get('repo_errors') or 0)}")
print(f"[online-intake] harvest_sync_changed={sum(int(r.get('sync_changed') or 0) for r in repos)}")
print(f"[online-intake] harvest_sync_errors={sum(int(r.get('sync_errors') or 0) for r in repos)}")
PY
  fi
  if [[ "${ONLINE_SYNC_BRANCH_PINS}" == "1" ]]; then
    echo "[online-intake] syncing branch pins from harvest report"
    python3 ci/reverse/sync-repo-branches-from-harvest.py --write 1
  fi
  if [[ "${ONLINE_RUN_SNAPSHOT_AUDIT}" == "1" ]]; then
    echo "[online-intake] running snapshot contract audit (strict=${ONLINE_SNAPSHOT_AUDIT_STRICT})"
    python3 ci/reverse/snapshot-contract-audit.py \
      --snapshot-root ci/reverse/upstream_snapshots \
      --output-md "${ONLINE_HARVEST_OUT_DIR}/snapshot-contract-audit.md" \
      --output-json "${ONLINE_HARVEST_OUT_DIR}/snapshot-contract-audit.json" \
      --strict "${ONLINE_SNAPSHOT_AUDIT_STRICT}"
  fi
fi
echo "[online-intake] done: ${OUT_DIR}"
