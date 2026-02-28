#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"
EXTRA_ARGS=("$@")

: "${HARVEST_TRANSFER_REPO_FILE:=ci/reverse/online_intake_repos.json}"
: "${HARVEST_TRANSFER_MAP_FILE:=ci/reverse/transfer_map.json}"
: "${HARVEST_TRANSFER_COMMIT_SCAN_JSON:=docs/reverse/online-intake/commit-scan.json}"
: "${HARVEST_TRANSFER_GIT_WORKDIR:=docs/reverse/online-intake/_git-cache}"
: "${HARVEST_TRANSFER_OUT_DIR:=docs/reverse/online-intake/harvest}"
: "${HARVEST_TRANSFER_PROFILE:=core}"
: "${HARVEST_TRANSFER_ALIASES:=}"
: "${HARVEST_TRANSFER_ALL_REPOS:=0}"
: "${HARVEST_TRANSFER_MAX_COMMITS_PER_REPO:=24}"
: "${HARVEST_TRANSFER_GIT_DEPTH:=120}"
: "${HARVEST_TRANSFER_APPLY:=1}"
: "${HARVEST_TRANSFER_SKIP_NO_SYNC:=1}"
: "${HARVEST_TRANSFER_AUTO_FOCUS_SYNC:=1}"
: "${HARVEST_TRANSFER_INCLUDE_UNMAPPED:=1}"
: "${HARVEST_TRANSFER_FAIL_ON_REPO_ERRORS:=0}"

log() { printf '[harvest-transfer] %s\n' "$*"; }
fail() { printf '[harvest-transfer][error] %s\n' "$*" >&2; exit 1; }

[[ "${HARVEST_TRANSFER_PROFILE}" =~ ^(core|all|custom)$ ]] || fail "HARVEST_TRANSFER_PROFILE must be core, all or custom"
[[ "${HARVEST_TRANSFER_ALL_REPOS}" =~ ^[01]$ ]] || fail "HARVEST_TRANSFER_ALL_REPOS must be 0 or 1"
[[ "${HARVEST_TRANSFER_APPLY}" =~ ^[01]$ ]] || fail "HARVEST_TRANSFER_APPLY must be 0 or 1"
[[ "${HARVEST_TRANSFER_SKIP_NO_SYNC}" =~ ^[01]$ ]] || fail "HARVEST_TRANSFER_SKIP_NO_SYNC must be 0 or 1"
[[ "${HARVEST_TRANSFER_AUTO_FOCUS_SYNC}" =~ ^[01]$ ]] || fail "HARVEST_TRANSFER_AUTO_FOCUS_SYNC must be 0 or 1"
[[ "${HARVEST_TRANSFER_INCLUDE_UNMAPPED}" =~ ^[01]$ ]] || fail "HARVEST_TRANSFER_INCLUDE_UNMAPPED must be 0 or 1"
[[ "${HARVEST_TRANSFER_FAIL_ON_REPO_ERRORS}" =~ ^[01]$ ]] || fail "HARVEST_TRANSFER_FAIL_ON_REPO_ERRORS must be 0 or 1"
[[ "${HARVEST_TRANSFER_MAX_COMMITS_PER_REPO}" =~ ^[0-9]+$ ]] || fail "HARVEST_TRANSFER_MAX_COMMITS_PER_REPO must be numeric"
[[ "${HARVEST_TRANSFER_GIT_DEPTH}" =~ ^[0-9]+$ ]] || fail "HARVEST_TRANSFER_GIT_DEPTH must be numeric"

if [[ "${HARVEST_TRANSFER_PROFILE}" == "core" && -z "${HARVEST_TRANSFER_ALIASES}" ]]; then
  HARVEST_TRANSFER_ALIASES="gamenative_protonwine,coffin_wine,coffin_winlator"
fi
if [[ "${HARVEST_TRANSFER_PROFILE}" == "all" ]]; then
  HARVEST_TRANSFER_ALL_REPOS=1
  HARVEST_TRANSFER_ALIASES=""
fi
if [[ "${HARVEST_TRANSFER_PROFILE}" == "custom" && -z "${HARVEST_TRANSFER_ALIASES}" ]]; then
  fail "HARVEST_TRANSFER_PROFILE=custom requires HARVEST_TRANSFER_ALIASES"
fi

args=()
if [[ "${HARVEST_TRANSFER_ALL_REPOS}" == "1" ]]; then
  args+=(--all-repos)
fi
if [[ -n "${HARVEST_TRANSFER_ALIASES}" ]]; then
  args+=(--aliases "${HARVEST_TRANSFER_ALIASES}")
fi

log "running transfer harvest (profile=${HARVEST_TRANSFER_PROFILE}, apply=${HARVEST_TRANSFER_APPLY})"
python3 ci/reverse/harvest_transfer.py \
  --repo-file "${HARVEST_TRANSFER_REPO_FILE}" \
  --map-file "${HARVEST_TRANSFER_MAP_FILE}" \
  --commit-scan-json "${HARVEST_TRANSFER_COMMIT_SCAN_JSON}" \
  --git-workdir "${HARVEST_TRANSFER_GIT_WORKDIR}" \
  --out-dir "${HARVEST_TRANSFER_OUT_DIR}" \
  --max-commits-per-repo "${HARVEST_TRANSFER_MAX_COMMITS_PER_REPO}" \
  --git-depth "${HARVEST_TRANSFER_GIT_DEPTH}" \
  --apply "${HARVEST_TRANSFER_APPLY}" \
  --skip-no-sync "${HARVEST_TRANSFER_SKIP_NO_SYNC}" \
  --auto-focus-sync "${HARVEST_TRANSFER_AUTO_FOCUS_SYNC}" \
  --include-unmapped "${HARVEST_TRANSFER_INCLUDE_UNMAPPED}" \
  --fail-on-repo-errors "${HARVEST_TRANSFER_FAIL_ON_REPO_ERRORS}" \
  "${args[@]}" \
  "${EXTRA_ARGS[@]}"

log "done: ${HARVEST_TRANSFER_OUT_DIR}"
