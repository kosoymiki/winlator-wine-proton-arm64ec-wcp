#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

: "${WLT_HIGH_CYCLE_OUT_DIR:=docs/reverse/online-intake}"
: "${WLT_HIGH_CYCLE_FETCH:=1}"
: "${WLT_HIGH_CYCLE_TRANSPORT:=gh}"
: "${WLT_HIGH_CYCLE_PROFILE:=all}"
: "${WLT_HIGH_CYCLE_MODE:=code-only}"
: "${WLT_HIGH_CYCLE_SCOPE:=focused}"
: "${WLT_HIGH_CYCLE_LIMIT:=8}"
: "${WLT_HIGH_CYCLE_MAX_FOCUS_FILES:=6}"
: "${WLT_HIGH_CYCLE_ALL_REPOS:=0}"
: "${WLT_HIGH_CYCLE_ALIASES:=}"
: "${WLT_HIGH_CYCLE_GIT_DEPTH:=80}"
: "${WLT_HIGH_CYCLE_CMD_TIMEOUT_SEC:=120}"
: "${WLT_HIGH_CYCLE_GIT_FETCH_TIMEOUT_SEC:=420}"
: "${WLT_HIGH_CYCLE_BACKLOG_STRICT:=1}"
: "${WLT_HIGH_CYCLE_REQUIRED_HIGH_MARKERS:=x11drv_xinput2_enable,NtUserSendHardwareInput,SEND_HWMSG_NO_RAW,WRAPPER_VK_VERSION}"
: "${WLT_HIGH_CYCLE_REQUIRED_MEDIUM_MARKERS:=ContentProfile,REMOTE_PROFILES}"
: "${WLT_HIGH_CYCLE_REQUIRED_LOW_MARKERS:=DXVK,D8VK,VKD3D,PROOT_TMP_DIR,BOX64_LOG,WINEDEBUG,MESA_VK_WSI_PRESENT_MODE,TU_DEBUG,WINE_OPEN_WITH_ANDROID_BROWSER}"
: "${WLT_HIGH_CYCLE_REQUIRE_LOW_READY_VALIDATED:=1}"
: "${WLT_HIGH_CYCLE_RUN_GN_MANIFEST:=1}"
: "${WLT_HIGH_CYCLE_RUN_URC:=0}"
: "${WLT_HIGH_CYCLE_RUN_COMMIT_SCAN:=1}"
: "${WLT_HIGH_CYCLE_INCLUDE_COMMIT_SCAN:=}"
: "${WLT_HIGH_CYCLE_COMMIT_SCAN_PROFILE:=core}"
: "${WLT_HIGH_CYCLE_COMMIT_SCAN_COMMITS_PER_REPO:=12}"
: "${WLT_HIGH_CYCLE_COMMIT_SCAN_JSON:=}"
: "${WLT_HIGH_CYCLE_RUN_HARVEST:=0}"
: "${WLT_HIGH_CYCLE_HARVEST_PROFILE:=core}"
: "${WLT_HIGH_CYCLE_HARVEST_MAX_COMMITS_PER_REPO:=24}"
: "${WLT_HIGH_CYCLE_HARVEST_APPLY:=1}"
: "${WLT_HIGH_CYCLE_HARVEST_SKIP_NO_SYNC:=1}"
: "${WLT_HIGH_CYCLE_HARVEST_AUTO_FOCUS_SYNC:=1}"
: "${WLT_HIGH_CYCLE_HARVEST_INCLUDE_UNMAPPED:=1}"
: "${WLT_HIGH_CYCLE_SYNC_BRANCH_PINS:=1}"
: "${WLT_HIGH_CYCLE_HARVEST_FAIL_ON_REPO_ERRORS:=0}"
: "${WLT_HIGH_CYCLE_RUN_SNAPSHOT_AUDIT:=1}"
: "${WLT_HIGH_CYCLE_SNAPSHOT_AUDIT_STRICT:=1}"

log() { printf '[high-cycle] %s\n' "$*"; }
fail() { printf '[high-cycle][error] %s\n' "$*" >&2; exit 1; }

command -v bash >/dev/null 2>&1 || fail "bash is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
[[ "${WLT_HIGH_CYCLE_FETCH}" =~ ^[01]$ ]] || fail "WLT_HIGH_CYCLE_FETCH must be 0 or 1"
[[ "${WLT_HIGH_CYCLE_BACKLOG_STRICT}" =~ ^[01]$ ]] || fail "WLT_HIGH_CYCLE_BACKLOG_STRICT must be 0 or 1"
[[ "${WLT_HIGH_CYCLE_ALL_REPOS}" =~ ^[01]$ ]] || fail "WLT_HIGH_CYCLE_ALL_REPOS must be 0 or 1"
[[ "${WLT_HIGH_CYCLE_RUN_GN_MANIFEST}" =~ ^[01]$ ]] || fail "WLT_HIGH_CYCLE_RUN_GN_MANIFEST must be 0 or 1"
[[ "${WLT_HIGH_CYCLE_RUN_URC}" =~ ^[01]$ ]] || fail "WLT_HIGH_CYCLE_RUN_URC must be 0 or 1"
[[ "${WLT_HIGH_CYCLE_RUN_COMMIT_SCAN}" =~ ^[01]$ ]] || fail "WLT_HIGH_CYCLE_RUN_COMMIT_SCAN must be 0 or 1"
[[ "${WLT_HIGH_CYCLE_RUN_HARVEST}" =~ ^[01]$ ]] || fail "WLT_HIGH_CYCLE_RUN_HARVEST must be 0 or 1"
[[ "${WLT_HIGH_CYCLE_HARVEST_SKIP_NO_SYNC}" =~ ^[01]$ ]] || fail "WLT_HIGH_CYCLE_HARVEST_SKIP_NO_SYNC must be 0 or 1"
[[ "${WLT_HIGH_CYCLE_HARVEST_AUTO_FOCUS_SYNC}" =~ ^[01]$ ]] || fail "WLT_HIGH_CYCLE_HARVEST_AUTO_FOCUS_SYNC must be 0 or 1"
[[ "${WLT_HIGH_CYCLE_HARVEST_INCLUDE_UNMAPPED}" =~ ^[01]$ ]] || fail "WLT_HIGH_CYCLE_HARVEST_INCLUDE_UNMAPPED must be 0 or 1"
[[ "${WLT_HIGH_CYCLE_SYNC_BRANCH_PINS}" =~ ^[01]$ ]] || fail "WLT_HIGH_CYCLE_SYNC_BRANCH_PINS must be 0 or 1"
[[ "${WLT_HIGH_CYCLE_HARVEST_FAIL_ON_REPO_ERRORS}" =~ ^[01]$ ]] || fail "WLT_HIGH_CYCLE_HARVEST_FAIL_ON_REPO_ERRORS must be 0 or 1"
[[ "${WLT_HIGH_CYCLE_RUN_SNAPSHOT_AUDIT}" =~ ^[01]$ ]] || fail "WLT_HIGH_CYCLE_RUN_SNAPSHOT_AUDIT must be 0 or 1"
[[ "${WLT_HIGH_CYCLE_SNAPSHOT_AUDIT_STRICT}" =~ ^[01]$ ]] || fail "WLT_HIGH_CYCLE_SNAPSHOT_AUDIT_STRICT must be 0 or 1"
[[ "${WLT_HIGH_CYCLE_REQUIRE_LOW_READY_VALIDATED}" =~ ^[01]$ ]] || fail "WLT_HIGH_CYCLE_REQUIRE_LOW_READY_VALIDATED must be 0 or 1"
[[ "${WLT_HIGH_CYCLE_TRANSPORT}" =~ ^(git|gh)$ ]] || fail "WLT_HIGH_CYCLE_TRANSPORT must be git or gh"
[[ "${WLT_HIGH_CYCLE_MODE}" =~ ^(code-only|full)$ ]] || fail "WLT_HIGH_CYCLE_MODE must be code-only or full"
[[ "${WLT_HIGH_CYCLE_SCOPE}" =~ ^(focused|tree)$ ]] || fail "WLT_HIGH_CYCLE_SCOPE must be focused or tree"
[[ "${WLT_HIGH_CYCLE_PROFILE}" =~ ^(core|all|custom)$ ]] || fail "WLT_HIGH_CYCLE_PROFILE must be core, all or custom"
[[ "${WLT_HIGH_CYCLE_COMMIT_SCAN_PROFILE}" =~ ^(core|all|custom)$ ]] || fail "WLT_HIGH_CYCLE_COMMIT_SCAN_PROFILE must be core, all or custom"

if [[ "${WLT_HIGH_CYCLE_PROFILE}" == "core" && -z "${WLT_HIGH_CYCLE_ALIASES}" ]]; then
  WLT_HIGH_CYCLE_ALIASES="coffin_winlator,coffin_wine,gamenative_protonwine,froggingfamily_wine_tkg_git,utkarsh_gamenative,olegos2_mobox,ilya114_box64droid,ahmad1abbadi_darkos,christianhaitian_darkos,kreitinn_micewine_application,termux_x11"
fi

if [[ "${WLT_HIGH_CYCLE_PROFILE}" == "all" ]]; then
  WLT_HIGH_CYCLE_ALL_REPOS=1
  # Keep all-profile deterministic: ignore alias filters.
  WLT_HIGH_CYCLE_ALIASES=""
fi
if [[ "${WLT_HIGH_CYCLE_PROFILE}" == "custom" && -z "${WLT_HIGH_CYCLE_ALIASES}" ]]; then
  fail "WLT_HIGH_CYCLE_PROFILE=custom requires WLT_HIGH_CYCLE_ALIASES"
fi

if [[ -z "${WLT_HIGH_CYCLE_INCLUDE_COMMIT_SCAN}" ]]; then
  WLT_HIGH_CYCLE_INCLUDE_COMMIT_SCAN="${WLT_HIGH_CYCLE_RUN_COMMIT_SCAN}"
fi
[[ "${WLT_HIGH_CYCLE_INCLUDE_COMMIT_SCAN}" =~ ^[01]$ ]] || fail "WLT_HIGH_CYCLE_INCLUDE_COMMIT_SCAN must be 0 or 1"
commit_scan_json="${WLT_HIGH_CYCLE_COMMIT_SCAN_JSON:-${WLT_HIGH_CYCLE_OUT_DIR}/commit-scan.json}"
if [[ "${WLT_HIGH_CYCLE_INCLUDE_COMMIT_SCAN}" == "1" && "${WLT_HIGH_CYCLE_RUN_COMMIT_SCAN}" != "1" && ! -f "${commit_scan_json}" ]]; then
  log "commit-scan json missing (${commit_scan_json}); forcing online commit scan"
  WLT_HIGH_CYCLE_RUN_COMMIT_SCAN=1
fi
if [[ "${WLT_HIGH_CYCLE_RUN_COMMIT_SCAN}" == "1" ]]; then
  log "running online commit scan (profile=${WLT_HIGH_CYCLE_COMMIT_SCAN_PROFILE})"
  ONLINE_COMMIT_SCAN_PROFILE="${WLT_HIGH_CYCLE_COMMIT_SCAN_PROFILE}" \
  ONLINE_COMMIT_SCAN_COMMITS_PER_REPO="${WLT_HIGH_CYCLE_COMMIT_SCAN_COMMITS_PER_REPO}" \
  ONLINE_COMMIT_SCAN_ALIASES="${WLT_HIGH_CYCLE_ALIASES}" \
  ONLINE_COMMIT_SCAN_OUT_DIR="${WLT_HIGH_CYCLE_OUT_DIR}" \
  bash ci/reverse/online-commit-scan.sh
fi

if [[ "${WLT_HIGH_CYCLE_RUN_GN_MANIFEST}" == "1" ]]; then
  log "validating GN manifest contract"
  python3 ci/gamenative/check-manifest-contract.py
fi

log "running strict online intake cycle (profile=${WLT_HIGH_CYCLE_PROFILE}, scope=${WLT_HIGH_CYCLE_SCOPE}, aliases=${WLT_HIGH_CYCLE_ALIASES:-all-enabled})"
OUT_DIR="${WLT_HIGH_CYCLE_OUT_DIR}" \
ONLINE_INTAKE_FETCH="${WLT_HIGH_CYCLE_FETCH}" \
ONLINE_INTAKE_TRANSPORT="${WLT_HIGH_CYCLE_TRANSPORT}" \
ONLINE_INTAKE_MODE="${WLT_HIGH_CYCLE_MODE}" \
ONLINE_INTAKE_SCOPE="${WLT_HIGH_CYCLE_SCOPE}" \
LIMIT="${WLT_HIGH_CYCLE_LIMIT}" \
MAX_FOCUS_FILES="${WLT_HIGH_CYCLE_MAX_FOCUS_FILES}" \
INCLUDE_ALL_REPOS="${WLT_HIGH_CYCLE_ALL_REPOS}" \
ONLINE_INTAKE_ALIASES="${WLT_HIGH_CYCLE_ALIASES}" \
ONLINE_INTAKE_GIT_DEPTH="${WLT_HIGH_CYCLE_GIT_DEPTH}" \
ONLINE_INTAKE_CMD_TIMEOUT_SEC="${WLT_HIGH_CYCLE_CMD_TIMEOUT_SEC}" \
ONLINE_INTAKE_GIT_FETCH_TIMEOUT_SEC="${WLT_HIGH_CYCLE_GIT_FETCH_TIMEOUT_SEC}" \
ONLINE_BACKLOG_STRICT="${WLT_HIGH_CYCLE_BACKLOG_STRICT}" \
ONLINE_REQUIRED_HIGH_MARKERS="${WLT_HIGH_CYCLE_REQUIRED_HIGH_MARKERS}" \
ONLINE_REQUIRED_MEDIUM_MARKERS="${WLT_HIGH_CYCLE_REQUIRED_MEDIUM_MARKERS}" \
ONLINE_REQUIRED_LOW_MARKERS="${WLT_HIGH_CYCLE_REQUIRED_LOW_MARKERS}" \
ONLINE_REQUIRE_LOW_READY_VALIDATED="${WLT_HIGH_CYCLE_REQUIRE_LOW_READY_VALIDATED}" \
ONLINE_INCLUDE_COMMIT_SCAN="${WLT_HIGH_CYCLE_INCLUDE_COMMIT_SCAN}" \
ONLINE_COMMIT_SCAN_JSON="${commit_scan_json}" \
bash ci/reverse/online-intake.sh

if [[ "${WLT_HIGH_CYCLE_RUN_URC}" == "1" ]]; then
  log "running URC policy gate"
  bash ci/validation/check-urc-mainline-policy.sh
fi

if [[ "${WLT_HIGH_CYCLE_RUN_HARVEST}" == "1" ]]; then
  log "running targeted harvest transfer (profile=${WLT_HIGH_CYCLE_HARVEST_PROFILE}, apply=${WLT_HIGH_CYCLE_HARVEST_APPLY})"
  HARVEST_TRANSFER_PROFILE="${WLT_HIGH_CYCLE_HARVEST_PROFILE}" \
  HARVEST_TRANSFER_ALIASES="${WLT_HIGH_CYCLE_ALIASES}" \
  HARVEST_TRANSFER_ALL_REPOS="${WLT_HIGH_CYCLE_ALL_REPOS}" \
  HARVEST_TRANSFER_COMMIT_SCAN_JSON="${commit_scan_json}" \
  HARVEST_TRANSFER_OUT_DIR="${WLT_HIGH_CYCLE_OUT_DIR}/harvest" \
  HARVEST_TRANSFER_MAX_COMMITS_PER_REPO="${WLT_HIGH_CYCLE_HARVEST_MAX_COMMITS_PER_REPO}" \
  HARVEST_TRANSFER_APPLY="${WLT_HIGH_CYCLE_HARVEST_APPLY}" \
  HARVEST_TRANSFER_SKIP_NO_SYNC="${WLT_HIGH_CYCLE_HARVEST_SKIP_NO_SYNC}" \
  HARVEST_TRANSFER_AUTO_FOCUS_SYNC="${WLT_HIGH_CYCLE_HARVEST_AUTO_FOCUS_SYNC}" \
  HARVEST_TRANSFER_INCLUDE_UNMAPPED="${WLT_HIGH_CYCLE_HARVEST_INCLUDE_UNMAPPED}" \
  HARVEST_TRANSFER_FAIL_ON_REPO_ERRORS="${WLT_HIGH_CYCLE_HARVEST_FAIL_ON_REPO_ERRORS}" \
  bash ci/reverse/harvest-transfer.sh

  harvest_report="${WLT_HIGH_CYCLE_OUT_DIR}/harvest/transfer-report.json"
  if [[ -f "${harvest_report}" ]]; then
    python3 - "${harvest_report}" <<'PY'
import json
import sys
payload = json.load(open(sys.argv[1], encoding="utf-8"))
repos = payload.get("repos") or []
print(f"[high-cycle] harvest_repo_errors={int(payload.get('repo_errors') or 0)}")
print(f"[high-cycle] harvest_sync_changed={sum(int(r.get('sync_changed') or 0) for r in repos)}")
print(f"[high-cycle] harvest_sync_errors={sum(int(r.get('sync_errors') or 0) for r in repos)}")
PY
  fi

  if [[ "${WLT_HIGH_CYCLE_SYNC_BRANCH_PINS}" == "1" ]]; then
    log "syncing branch pins from harvest report"
    python3 ci/reverse/sync-repo-branches-from-harvest.py --write 1
  fi

  if [[ "${WLT_HIGH_CYCLE_RUN_SNAPSHOT_AUDIT}" == "1" ]]; then
    log "running snapshot contract audit (strict=${WLT_HIGH_CYCLE_SNAPSHOT_AUDIT_STRICT})"
    python3 ci/reverse/snapshot-contract-audit.py \
      --snapshot-root ci/reverse/upstream_snapshots \
      --output-md "${WLT_HIGH_CYCLE_OUT_DIR}/harvest/snapshot-contract-audit.md" \
      --output-json "${WLT_HIGH_CYCLE_OUT_DIR}/harvest/snapshot-contract-audit.json" \
      --strict "${WLT_HIGH_CYCLE_SNAPSHOT_AUDIT_STRICT}"
  fi
fi

BACKLOG_JSON="${WLT_HIGH_CYCLE_OUT_DIR}/PATCH_TRANSFER_BACKLOG.json"
[[ -f "${BACKLOG_JSON}" ]] || fail "missing backlog json: ${BACKLOG_JSON}"
python3 - "${BACKLOG_JSON}" <<'PY'
import json
import sys
from collections import Counter

path = sys.argv[1]
payload = json.load(open(path, encoding="utf-8"))
rows = payload.get("rows") or []
high = [r for r in rows if str(r.get("priority", "")).lower() == "high"]
medium = [r for r in rows if str(r.get("priority", "")).lower() == "medium"]
low = [r for r in rows if str(r.get("priority", "")).lower() == "low"]
status = Counter(r.get("status", "") for r in high)
medium_status = Counter(r.get("status", "") for r in medium)
low_status = Counter(r.get("status", "") for r in low)
print(f"[high-cycle] high_rows={len(high)}")
print(f"[high-cycle] high_status={dict(status)}")
print(f"[high-cycle] medium_rows={len(medium)}")
print(f"[high-cycle] medium_status={dict(medium_status)}")
print(f"[high-cycle] low_rows={len(low)}")
print(f"[high-cycle] low_status={dict(low_status)}")
for row in high:
    print(
        "[high-cycle] "
        f"marker={row.get('marker','')} status={row.get('status','')} target={row.get('target','')}"
    )
for row in medium:
    print(
        "[high-cycle] "
        f"medium_marker={row.get('marker','')} status={row.get('status','')} target={row.get('target','')}"
    )
for row in low:
    print(
        "[high-cycle] "
        f"low_marker={row.get('marker','')} status={row.get('status','')} target={row.get('target','')}"
    )
PY

log "done"
