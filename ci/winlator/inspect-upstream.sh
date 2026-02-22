#!/usr/bin/env bash
set -euo pipefail

WINLATOR_SRC_DIR="${1:-}"
OUT_DIR="${2:-}"

log() { printf '[winlator-inspect] %s\n' "$*"; }
fail() { printf '[winlator-inspect][error] %s\n' "$*" >&2; exit 1; }

[[ -n "${WINLATOR_SRC_DIR}" && -n "${OUT_DIR}" ]] || fail "usage: $0 <winlator-src-dir> <out-dir>"
[[ -d "${WINLATOR_SRC_DIR}/.git" ]] || fail "Not a git checkout: ${WINLATOR_SRC_DIR}"

mkdir -p "${OUT_DIR}"

: "${UPSTREAM_SINCE:=2 days ago}"
: "${UPSTREAM_LOG_LIMIT:=100}"
: "${UPSTREAM_STAT_LIMIT:=30}"

head_sha="$(git -C "${WINLATOR_SRC_DIR}" rev-parse HEAD)"
head_subject="$(git -C "${WINLATOR_SRC_DIR}" show -s --format='%s' HEAD)"

printf '%s\n' "${head_sha}" > "${OUT_DIR}/head-sha.txt"
printf '%s\n' "${head_subject}" > "${OUT_DIR}/head-subject.txt"

# Prefer same-day recency for reflective analysis; fallback to fixed commit count.
if git -C "${WINLATOR_SRC_DIR}" log --since="${UPSTREAM_SINCE}" --pretty=format:'%H|%ad|%an|%s' --date=iso-strict | grep -q .; then
  git -C "${WINLATOR_SRC_DIR}" log \
    --since="${UPSTREAM_SINCE}" \
    --pretty=format:'%H|%ad|%an|%s' \
    --date=iso-strict > "${OUT_DIR}/commits.tsv"
else
  git -C "${WINLATOR_SRC_DIR}" log \
    -n "${UPSTREAM_LOG_LIMIT}" \
    --pretty=format:'%H|%ad|%an|%s' \
    --date=iso-strict > "${OUT_DIR}/commits.tsv"
fi

git -C "${WINLATOR_SRC_DIR}" log -n "${UPSTREAM_STAT_LIMIT}" --stat > "${OUT_DIR}/diffstat.log"
git -C "${WINLATOR_SRC_DIR}" show --name-status --format=fuller -n 1 HEAD > "${OUT_DIR}/head-commit-detail.log"
git -C "${WINLATOR_SRC_DIR}" status --short > "${OUT_DIR}/working-tree-status.log"

log "Upstream inspection complete (head=${head_sha})"
