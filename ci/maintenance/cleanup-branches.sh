#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

REMOTE="${REMOTE:-origin}"
MODE="dry-run"
DELETE_REMOTE=0
BASE_BRANCH=""
KEEP_LIST="${KEEP_LIST:-main,master,pr-27,feature/proton10-wcp-valvebase}"

log() { printf '[branch-cleanup] %s\n' "$*"; }
die() { printf '[branch-cleanup][error] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage:
  bash ci/maintenance/cleanup-branches.sh [--apply] [--remote] [--base <branch>] [--keep <csv>] [--origin <name>]

Default mode is dry-run.

Options:
  --apply          Delete candidate branches (local and optionally remote).
  --remote         Also process remote branches (origin/*) that are already merged.
  --base BRANCH    Base branch used to check if a branch is merged (default: main, fallback: master).
  --keep CSV       Comma-separated protected branch names.
  --origin NAME    Git remote name (default: origin).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      MODE="apply"
      ;;
    --remote)
      DELETE_REMOTE=1
      ;;
    --base)
      shift
      [[ $# -gt 0 ]] || die "--base requires a value"
      BASE_BRANCH="$1"
      ;;
    --keep)
      shift
      [[ $# -gt 0 ]] || die "--keep requires a value"
      KEEP_LIST="$1"
      ;;
    --origin)
      shift
      [[ $# -gt 0 ]] || die "--origin requires a value"
      REMOTE="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
  shift
done

cd "${ROOT_DIR}"
git rev-parse --git-dir >/dev/null 2>&1 || die "Not a git repository: ${ROOT_DIR}"

if [[ -z "${BASE_BRANCH}" ]]; then
  if git show-ref --verify --quiet refs/heads/main || git show-ref --verify --quiet refs/remotes/${REMOTE}/main; then
    BASE_BRANCH="main"
  elif git show-ref --verify --quiet refs/heads/master || git show-ref --verify --quiet refs/remotes/${REMOTE}/master; then
    BASE_BRANCH="master"
  else
    die "Cannot determine base branch. Use --base <branch>."
  fi
fi

IFS=',' read -r -a KEEP_BRANCHES <<< "${KEEP_LIST}"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
BASE_REF_LOCAL="${BASE_BRANCH}"
BASE_REF_REMOTE="${REMOTE}/${BASE_BRANCH}"

log "mode=${MODE}, remote=${REMOTE}, base=${BASE_BRANCH}, delete_remote=${DELETE_REMOTE}"
log "keep branches: ${KEEP_LIST}"
log "current branch: ${CURRENT_BRANCH}"

git fetch --prune "${REMOTE}" >/dev/null 2>&1 || log "warning: unable to fetch ${REMOTE}; proceeding with local refs"

if ! git show-ref --verify --quiet "refs/heads/${BASE_BRANCH}"; then
  if git show-ref --verify --quiet "refs/remotes/${BASE_REF_REMOTE}"; then
    BASE_REF_LOCAL="${BASE_REF_REMOTE}"
  else
    die "Base branch not found locally or on ${REMOTE}: ${BASE_BRANCH}"
  fi
fi

is_protected() {
  local branch="$1" keep
  if [[ "${branch}" == "${CURRENT_BRANCH}" ]]; then
    return 0
  fi
  for keep in "${KEEP_BRANCHES[@]}"; do
    if [[ "${branch}" == "${keep}" ]]; then
      return 0
    fi
  done
  return 1
}

local_candidates=()
while IFS= read -r branch; do
  [[ -n "${branch}" ]] || continue
  if is_protected "${branch}"; then
    continue
  fi
  if git merge-base --is-ancestor "${branch}" "${BASE_REF_LOCAL}"; then
    local_candidates+=("${branch}")
  fi
done < <(git for-each-ref refs/heads --format='%(refname:short)')

log "local merged candidates (${#local_candidates[@]}):"
for b in "${local_candidates[@]}"; do
  echo "  - ${b}"
done

if [[ "${MODE}" == "apply" ]]; then
  for b in "${local_candidates[@]}"; do
    git branch -d "${b}"
  done
fi

if [[ "${DELETE_REMOTE}" == "1" ]]; then
  remote_candidates=()
  while IFS= read -r ref; do
    [[ -n "${ref}" ]] || continue
    branch="${ref#${REMOTE}/}"
    [[ "${branch}" == "HEAD" ]] && continue
    if is_protected "${branch}"; then
      continue
    fi
    if git merge-base --is-ancestor "${ref}" "${BASE_REF_REMOTE}" 2>/dev/null; then
      remote_candidates+=("${branch}")
    fi
  done < <(git for-each-ref "refs/remotes/${REMOTE}" --format='%(refname:short)')

  log "remote merged candidates (${#remote_candidates[@]}):"
  for b in "${remote_candidates[@]}"; do
    echo "  - ${b}"
  done

  if [[ "${MODE}" == "apply" ]]; then
    for b in "${remote_candidates[@]}"; do
      git push "${REMOTE}" --delete "${b}"
    done
  fi
fi

if [[ "${MODE}" == "dry-run" ]]; then
  log "Dry-run complete. Re-run with --apply to delete listed branches."
else
  log "Branch cleanup completed."
fi
