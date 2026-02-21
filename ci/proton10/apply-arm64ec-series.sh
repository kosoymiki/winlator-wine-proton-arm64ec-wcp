#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="${WORK_DIR:-${ROOT_DIR}/work/proton10}"
OUT_DIR="${WCP_OUTPUT_DIR:-${ROOT_DIR}/out}"
LOG_DIR="${OUT_DIR}/logs"
SERIES_FILE="${ARM64EC_SERIES_FILE:-${OUT_DIR}/arm64ec-series.txt}"
WINE_VALVE_DIR="${WORK_DIR}/wine-valve"
WINE_SRC_DIR="${WORK_DIR}/wine-src"

: "${VALVE_WINE_REPO:=https://github.com/ValveSoftware/wine.git}"
: "${VALVE_WINE_REF:=986bda11d3e569813ec0f86e56ef94d7c384da04}"
: "${ANDRE_WINE_REPO:=https://github.com/AndreRH/wine.git}"
: "${ANDRE_ARM64EC_REF:=arm64ec}"
: "${ARM64EC_CHERRY_PICK_STRATEGY:=theirs}"

log() { printf '[proton10][cherry-pick] %s\n' "$*"; }
fail() { printf '[proton10][cherry-pick][error] %s\n' "$*" >&2; exit 1; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"; }

resolve_conflicts_with_theirs() {
  local conflict_files path unresolved

  conflict_files="$(git diff --name-only --diff-filter=U || true)"
  [[ -n "${conflict_files}" ]] || return 1

  while IFS= read -r path; do
    [[ -n "${path}" ]] || continue
    if git cat-file -e ":3:${path}" 2>/dev/null; then
      git checkout --theirs -- "${path}" || return 1
      git add -- "${path}" || return 1
    else
      git rm -f -- "${path}" >/dev/null 2>&1 || git rm --cached -f -- "${path}" >/dev/null 2>&1 || true
      git add -u -- "${path}" || true
    fi
  done <<< "${conflict_files}"

  unresolved="$(git diff --name-only --diff-filter=U || true)"
  [[ -z "${unresolved}" ]] || return 1

  git cherry-pick --continue >/dev/null 2>&1 || return 1
  return 0
}

main() {
  local hash conflict_dir applied_files conflict_files failure_reason resolved_file
  local -a cherry_pick_args

  require_cmd git
  [[ -f "${SERIES_FILE}" ]] || fail "Series file not found: ${SERIES_FILE}"
  [[ -s "${SERIES_FILE}" ]] || fail "Series file is empty: ${SERIES_FILE}"

  mkdir -p "${WORK_DIR}" "${LOG_DIR}"
  rm -rf "${WINE_VALVE_DIR}" "${WINE_SRC_DIR}"

  log "Cloning Valve wine repository"
  git clone --filter=blob:none "${VALVE_WINE_REPO}" "${WINE_VALVE_DIR}"
  git -C "${WINE_VALVE_DIR}" checkout "${VALVE_WINE_REF}"
  git -C "${WINE_VALVE_DIR}" worktree add --detach "${WINE_SRC_DIR}" "${VALVE_WINE_REF}"

  pushd "${WINE_SRC_DIR}" >/dev/null
  if git remote get-url andre >/dev/null 2>&1; then
    git remote set-url andre "${ANDRE_WINE_REPO}"
  else
    git remote add andre "${ANDRE_WINE_REPO}"
  fi
  git fetch --force --no-tags andre "${ANDRE_ARM64EC_REF}"
  git config user.name "proton10-ci"
  git config user.email "proton10-ci@users.noreply.github.com"

  cherry_pick_args=(-x)
  case "${ARM64EC_CHERRY_PICK_STRATEGY}" in
    theirs)
      cherry_pick_args+=(-X theirs)
      ;;
    default)
      ;;
    *)
      fail "ARM64EC_CHERRY_PICK_STRATEGY must be 'theirs' or 'default'"
      ;;
  esac

  resolved_file="${LOG_DIR}/cherry-pick-autoresolved.txt"
  : > "${resolved_file}"

  while IFS= read -r hash; do
    [[ -n "${hash}" ]] || continue
    log "Applying commit ${hash}"
    if ! git cherry-pick "${cherry_pick_args[@]}" "${hash}"; then
      if [[ "${ARM64EC_CHERRY_PICK_STRATEGY}" == "theirs" ]] && resolve_conflicts_with_theirs; then
        log "Resolved conflicts for ${hash} via theirs-preferred fallback"
        printf '%s\n' "${hash}" >> "${resolved_file}"
        continue
      fi

      conflict_dir="${LOG_DIR}/cherry-pick-conflict/${hash}"
      mkdir -p "${conflict_dir}"
      git status --porcelain=v1 > "${conflict_dir}/status.txt" || true
      git diff > "${conflict_dir}/diff.txt" || true
      conflict_files="$(git diff --name-only --diff-filter=U || true)"
      printf '%s\n' "${conflict_files}" > "${conflict_dir}/conflicts.txt"
      if [[ -n "${conflict_files}" ]]; then
        failure_reason="conflict"
      else
        failure_reason="non-conflict error"
      fi
      git cherry-pick --abort || true
      fail "Cherry-pick ${failure_reason} while applying ${hash}; details in ${conflict_dir}"
    fi
  done < "${SERIES_FILE}"

  applied_files="${LOG_DIR}/arm64ec-applied-files.txt"
  git diff --name-only "${VALVE_WINE_REF}..HEAD" > "${applied_files}"
  if ! grep -E '^(loader/|dlls/ntdll/|dlls/wow64|server/|tools/)' "${applied_files}" >/dev/null 2>&1; then
    fail "Sanity check failed: expected ARM64EC/WoW64 core paths were not touched"
  fi

  git rev-parse HEAD > "${LOG_DIR}/wine-src-head.txt"
  git --no-pager log --oneline -n 50 > "${LOG_DIR}/wine-src-commits.txt"
  popd >/dev/null

  log "ARM64EC series applied successfully into ${WINE_SRC_DIR}"
}

main "$@"
