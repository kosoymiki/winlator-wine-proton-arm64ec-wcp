#!/usr/bin/env bash
set -euo pipefail

log() { printf '[gh-health] %s\n' "$*"; }
fail() { printf '[gh-health][error] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
usage: ci/validation/gh-mainline-health.sh [branch] [since_hours]

Checks latest run state for the four critical workflows:
  - Build Wine 11 ARM64EC (WCP)
  - Build Proton GE10 ARM64EC (WCP)
  - Build ProtonWine10 GameNative ARM64EC (WCP)
  - Build Winlator ARM64EC (no-embedded-runtimes)

Examples:
  bash ci/validation/gh-mainline-health.sh
  bash ci/validation/gh-mainline-health.sh main 24

Env:
  WLT_REQUIRE_SUCCESS=1  # fail if any latest run is not success
  WLT_HEALTH_OUTPUT_PREFIX=/tmp/mainline-health  # optional .tsv/.json outputs
EOF
}

branch="${1:-main}"
since_hours="${2:-24}"
[[ -n "${branch}" ]] || { usage; fail "branch must be non-empty"; }
[[ "${since_hours}" =~ ^[0-9]+$ ]] || { usage; fail "since_hours must be numeric"; }
: "${WLT_REQUIRE_SUCCESS:=1}"
[[ "${WLT_REQUIRE_SUCCESS}" =~ ^[01]$ ]] || fail "WLT_REQUIRE_SUCCESS must be 0 or 1"
: "${WLT_HEALTH_OUTPUT_PREFIX:=}"

command -v gh >/dev/null 2>&1 || fail "gh is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"

runs_json="$(
  gh run list --limit 300 --branch "${branch}" \
    --json databaseId,workflowName,status,conclusion,createdAt,url
)"

report="$(
  RUNS_JSON="${runs_json}" python3 - "${since_hours}" <<'PY'
import json
import os
import sys
from datetime import datetime, timezone

since_hours = int(sys.argv[1])
now = datetime.now(timezone.utc)
runs = json.loads(os.environ.get("RUNS_JSON", "[]") or "[]")

targets = [
    "Build Wine 11 ARM64EC (WCP)",
    "Build Proton GE10 ARM64EC (WCP)",
    "Build ProtonWine10 GameNative ARM64EC (WCP)",
    "Build Winlator ARM64EC (no-embedded-runtimes)",
]

latest = {}
for row in runs:
    name = row.get("workflowName") or ""
    if name not in targets:
        continue
    created = row.get("createdAt") or ""
    if not created:
        continue
    prev = latest.get(name)
    if prev is None or created > (prev.get("createdAt") or ""):
        latest[name] = row

def age_hours(ts: str) -> float:
    dt = datetime.strptime(ts, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    return (now - dt).total_seconds() / 3600.0

for name in targets:
    row = latest.get(name)
    if not row:
        print("\t".join([name, "-", "-", "-", "-", "missing"]))
        continue
    created = row.get("createdAt") or "-"
    age = age_hours(created) if created != "-" else 9999.0
    conclusion = (row.get("conclusion") or "").lower() or "-"
    status = (row.get("status") or "").lower() or "-"
    rid = str(row.get("databaseId", "-"))
    freshness = "fresh" if age <= since_hours else "stale"
    print("\t".join([name, rid, status, conclusion, f"{age:.1f}", freshness]))
PY
)"

if [[ -n "${WLT_HEALTH_OUTPUT_PREFIX}" ]]; then
  tsv_path="${WLT_HEALTH_OUTPUT_PREFIX}.tsv"
  json_path="${WLT_HEALTH_OUTPUT_PREFIX}.json"
  mkdir -p "$(dirname -- "${tsv_path}")"
  {
    printf 'workflow\trun_id\tstatus\tconclusion\tage_h\tfreshness\n'
    printf '%s\n' "${report}"
  } > "${tsv_path}"
  REPORT_TSV="${report}" python3 - "${json_path}" <<'PY'
import json
import os
import sys

out = sys.argv[1]
rows = []
for line in os.environ.get("REPORT_TSV", "").splitlines():
    if not line.strip():
        continue
    wf, rid, status, conclusion, age_h, freshness = line.split("\t")
    rows.append({
        "workflow": wf,
        "run_id": rid,
        "status": status,
        "conclusion": conclusion,
        "age_h": age_h,
        "freshness": freshness,
    })
with open(out, "w", encoding="utf-8") as fh:
    json.dump({"rows": rows}, fh, indent=2, ensure_ascii=True)
    fh.write("\n")
PY
  log "wrote ${tsv_path}"
  log "wrote ${json_path}"
fi

printf '%s\n' "workflow | run_id | status | conclusion | age_h | freshness"
printf '%s\n' "---------|--------|--------|------------|-------|----------"
while IFS=$'\t' read -r wf rid status conclusion age freshness; do
  printf '%s | %s | %s | %s | %s | %s\n' "${wf}" "${rid}" "${status}" "${conclusion}" "${age}" "${freshness}"
done <<< "${report}"

if [[ "${WLT_REQUIRE_SUCCESS}" == "1" ]]; then
  bad="$(
    while IFS=$'\t' read -r _wf _rid _status conclusion _age freshness; do
      if [[ "${conclusion}" != "success" || "${freshness}" != "fresh" ]]; then
        echo 1
      fi
    done <<< "${report}" | wc -l | tr -d ' '
  )"
  if [[ "${bad}" != "0" ]]; then
    fail "mainline health check failed (${bad} workflow(s) are not fresh-success)"
  fi
fi

log "mainline health check passed"
