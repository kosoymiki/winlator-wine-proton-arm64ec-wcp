#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO="${GITHUB_REPOSITORY:-$(git -C "${ROOT_DIR}" config --get remote.origin.url | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##') }"
APPLY=0
LIMIT=200
KEEP_BRANCHES=""

log() { printf '[workflow-cleanup] %s\n' "$*"; }
fail() { printf '[workflow-cleanup][error] %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<USAGE
Usage: bash ci/maintenance/cleanup-workflow-runs.sh [--apply] [--limit N] [--repo owner/repo] [--keep-branches csv]

Deletes failed/cancelled GitHub Actions workflow runs (dry-run by default).
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --limit) LIMIT="$2"; shift ;;
    --repo) REPO="$2"; shift ;;
    --keep-branches) KEEP_BRANCHES="$2"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
  shift
done

command -v gh >/dev/null 2>&1 || fail "gh CLI is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
[[ -n "${REPO}" ]] || fail "Unable to determine repository"

log "Repository: ${REPO}"
log "Fetching up to ${LIMIT} workflow runs"

json="$(gh api --paginate "/repos/${REPO}/actions/runs?per_page=100" | python3 - "${LIMIT}" <<'PY'
import json, sys
limit = int(sys.argv[1])
out = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    page = json.loads(line)
    for run in page.get('workflow_runs', []):
        out.append(run)
        if len(out) >= limit:
            print(json.dumps(out))
            raise SystemExit(0)
print(json.dumps(out[:limit]))
PY
)"

mapfile -t rows < <(python3 - <<'PY' <<<"$json"
import json, os
runs = json.loads(input())
keep_branches = {b.strip() for b in os.environ.get('KEEP_BRANCHES', '').split(',') if b.strip()}
for r in runs:
    conclusion = (r.get('conclusion') or '').lower()
    status = (r.get('status') or '').lower()
    if conclusion not in {'failure', 'cancelled'}:
        continue
    if keep_branches and (r.get('head_branch') or '') in keep_branches:
        continue
    rid = r['id']
    created = (r.get('created_at') or '')[:19]
    name = r.get('name') or r.get('display_title') or '(no name)'
    wf = r.get('path') or ''
    branch = r.get('head_branch') or ''
    print(f"{rid}\t{status}\t{conclusion}\t{branch}\t{created}\t{name}\t{wf}")
PY
)

if [[ ${#rows[@]} -eq 0 ]]; then
  log "No failed/cancelled runs matched the filter."
  exit 0
fi

log "Matched ${#rows[@]} runs for deletion:"
printf '  %s\n' "${rows[@]}"

if [[ "${APPLY}" != "1" ]]; then
  log "Dry-run only. Re-run with --apply to delete matched runs."
  exit 0
fi

for row in "${rows[@]}"; do
  run_id="${row%%$'\t'*}"
  log "Deleting run ${run_id}"
  gh run delete "${run_id}" --repo "${REPO}" --yes
  sleep 0.2
done

log "Workflow run cleanup completed."
