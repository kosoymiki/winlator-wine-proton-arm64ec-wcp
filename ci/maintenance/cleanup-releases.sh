#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO="${GITHUB_REPOSITORY:-$(git -C "${ROOT_DIR}" config --get remote.origin.url | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')}"
APPLY=0
KEEP_TAGS="v0.2b,wcp-v0.2b,winlator-latest,wcp-latest"

log() { printf '[release-cleanup] %s\n' "$*"; }
fail() { printf '[release-cleanup][error] %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<USAGE
Usage: bash ci/maintenance/cleanup-releases.sh [--apply] [--repo owner/repo] [--keep-tags csv]

Deletes GitHub releases not listed in --keep-tags (dry-run by default).
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --repo) REPO="$2"; shift ;;
    --keep-tags) KEEP_TAGS="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
  shift
done

command -v gh >/dev/null 2>&1 || fail "gh CLI is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
[[ -n "${REPO}" ]] || fail "Unable to determine repository"

json="$(gh api --paginate "/repos/${REPO}/releases?per_page=100" | python3 -c '
import json, sys
out = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    page = json.loads(line)
    if isinstance(page, list):
        out.extend(page)
    else:
        out.append(page)
print(json.dumps(out))
')"

mapfile -t rows < <(KEEP_TAGS="${KEEP_TAGS}" python3 - <<'PY' <<<"$json"
import json, os
keep = {t.strip() for t in os.environ.get('KEEP_TAGS','').split(',') if t.strip()}
releases = json.loads(input())
for r in releases:
    tag = r.get('tag_name') or ''
    if tag in keep:
        continue
    name = r.get('name') or ''
    draft = r.get('draft', False)
    pre = r.get('prerelease', False)
    created = (r.get('created_at') or '')[:19]
    print(f"{tag}\t{name}\tcreated={created}\tdraft={draft}\tprerelease={pre}")
PY
)

if [[ ${#rows[@]} -eq 0 ]]; then
  log "No releases matched for deletion."
  exit 0
fi

log "Matched ${#rows[@]} releases for deletion (keep: ${KEEP_TAGS}):"
printf '  %s\n' "${rows[@]}"

if [[ "${APPLY}" != "1" ]]; then
  log "Dry-run only. Re-run with --apply to delete matched releases."
  exit 0
fi

for row in "${rows[@]}"; do
  tag="${row%%$'\t'*}"
  log "Deleting release ${tag}"
  gh release delete "${tag}" --repo "${REPO}" --yes --cleanup-tag
  sleep 0.2
done

log "Release cleanup completed."
