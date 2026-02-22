#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${WCP_OUTPUT_DIR:-${ROOT_DIR}/out/protonwine10}"
LOG_DIR="${OUT_DIR}/logs/protonwine10/inspect-upstreams"
WINE_SRC_DIR="${WINE_SRC_DIR:-${ROOT_DIR}/work/protonwine10/wine-src}"
SELECTED_FILE="${LOG_DIR}/android-support-selected-commits.txt"

: "${ANDROID_SUPPORT_REPO:=https://github.com/sidaodomorro/proton-wine.git}"
: "${ANDROID_SUPPORT_REF:=47e79a66652afae9fd0e521b03736d1e6536ac5a}"
: "${PROTONWINE_UPSTREAM_FIX_COMMITS:=}"

log() { printf '[protonwine10][apply-upstream] %s\n' "$*"; }
fail() { printf '[protonwine10][apply-upstream][error] %s\n' "$*" >&2; exit 1; }

skip_empty_cherry_pick_if_needed() {
  git rev-parse -q --verify CHERRY_PICK_HEAD >/dev/null 2>&1 || return 1
  if git diff --quiet && git diff --cached --quiet; then
    git cherry-pick --skip >/dev/null 2>&1 || return 1
    return 0
  fi
  return 1
}

main() {
  local commits_file apply_log conflict_dir hash

  [[ -d "${WINE_SRC_DIR}/.git" ]] || fail "WINE_SRC_DIR is not a git tree: ${WINE_SRC_DIR}"
  mkdir -p "${LOG_DIR}"

  commits_file="$(mktemp)"
  trap 'rm -f "${commits_file:-}"' EXIT

  if [[ -n "${PROTONWINE_UPSTREAM_FIX_COMMITS}" ]]; then
    printf '%s\n' "${PROTONWINE_UPSTREAM_FIX_COMMITS}" | tr ', ' '\n\n' | sed '/^$/d' > "${commits_file}"
  else
    if [[ -s "${SELECTED_FILE}" ]]; then
      cp -f "${SELECTED_FILE}" "${commits_file}"
    else
      log "No MUST/SHOULD upstream commits selected; skipping cherry-pick stage"
      return 0
    fi
  fi

  apply_log="${LOG_DIR}/apply-upstream.log"
  : > "${apply_log}"

  pushd "${WINE_SRC_DIR}" >/dev/null
  if git remote get-url android_support >/dev/null 2>&1; then
    git remote set-url android_support "${ANDROID_SUPPORT_REPO}"
  else
    git remote add android_support "${ANDROID_SUPPORT_REPO}"
  fi
  git fetch --no-tags android_support "${ANDROID_SUPPORT_REF}"
  git config user.name "protonwine10-ci"
  git config user.email "protonwine10-ci@users.noreply.github.com"

  while IFS= read -r hash; do
    [[ -n "${hash}" ]] || continue

    if git merge-base --is-ancestor "${hash}" HEAD >/dev/null 2>&1; then
      log "Commit already present, skipping: ${hash}"
      continue
    fi

    log "Cherry-picking ${hash}"
    if ! git cherry-pick -x "${hash}" >>"${apply_log}" 2>&1; then
      if skip_empty_cherry_pick_if_needed; then
        log "Skipped empty cherry-pick for ${hash}"
        continue
      fi
      conflict_dir="${LOG_DIR}/conflict-${hash}"
      mkdir -p "${conflict_dir}"
      git status --porcelain=v1 > "${conflict_dir}/status.txt" || true
      git diff > "${conflict_dir}/diff.txt" || true
      git diff --name-only --diff-filter=U > "${conflict_dir}/conflicts.txt" || true
      git cherry-pick --abort || true
      fail "Cherry-pick conflict for ${hash}; see ${conflict_dir}"
    fi
  done < "${commits_file}"

  popd >/dev/null
  log "Upstream cherry-picks applied successfully"
}

main "$@"
