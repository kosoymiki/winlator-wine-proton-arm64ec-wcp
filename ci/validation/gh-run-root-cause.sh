#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { printf '[gh-run-triage] %s\n' "$*"; }
fail() { printf '[gh-run-triage][error] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
usage: ci/validation/gh-run-root-cause.sh <run-id-or-url> [max_failed_jobs]

Collects failed jobs from a specific GitHub Actions run and produces
focused root-cause analysis files via extract-gh-job-failures.sh.

Examples:
  bash ci/validation/gh-run-root-cause.sh 22446750044
  bash ci/validation/gh-run-root-cause.sh https://github.com/org/repo/actions/runs/22446750044
  bash ci/validation/gh-run-root-cause.sh 22446750044 5

Env:
  WLT_RUN_TRIAGE_DIR=/tmp/gh-run-triage-22446750044
EOF
}

[[ $# -ge 1 ]] || { usage; exit 1; }
ref="$1"
max_jobs="${2:-10}"
[[ "${max_jobs}" =~ ^[0-9]+$ ]] || fail "max_failed_jobs must be numeric"

run_id=""
if [[ "${ref}" =~ ^[0-9]+$ ]]; then
  run_id="${ref}"
elif [[ "${ref}" =~ /actions/runs/([0-9]+) ]]; then
  run_id="${BASH_REMATCH[1]}"
else
  fail "Unable to parse run id from: ${ref}"
fi

: "${WLT_RUN_TRIAGE_DIR:=/tmp/gh-run-triage-${run_id}-$(date +%Y%m%d_%H%M%S)}"

command -v gh >/dev/null 2>&1 || fail "gh is required"
command -v python3 >/dev/null 2>&1 || fail "python3 is required"
[[ -x "${ROOT_DIR}/ci/validation/extract-gh-job-failures.sh" ]] || \
  fail "Missing parser: ci/validation/extract-gh-job-failures.sh"

mkdir -p "${WLT_RUN_TRIAGE_DIR}"

run_json="${WLT_RUN_TRIAGE_DIR}/run.json"
gh run view "${run_id}" --json databaseId,workflowName,displayTitle,status,conclusion,createdAt,url,jobs > "${run_json}" || \
  fail "Unable to fetch run metadata for run_id=${run_id}"

meta_file="${WLT_RUN_TRIAGE_DIR}/run.meta"
python3 - "${run_json}" "${meta_file}" <<'PY'
import json
import sys
from pathlib import Path

run_json = Path(sys.argv[1])
meta_file = Path(sys.argv[2])
payload = json.loads(run_json.read_text(encoding="utf-8"))
meta_file.write_text(
    "\n".join(
        [
            f"run_id={payload.get('databaseId', '-')}",
            f"workflow={payload.get('workflowName', '-')}",
            f"title={payload.get('displayTitle', '-')}",
            f"status={payload.get('status', '-')}",
            f"conclusion={payload.get('conclusion', '-')}",
            f"created_at={payload.get('createdAt', '-')}",
            f"url={payload.get('url', '-')}",
        ]
    )
    + "\n",
    encoding="utf-8",
)
PY

failed_tsv="${WLT_RUN_TRIAGE_DIR}/failed-jobs.tsv"
python3 - "${run_json}" "${failed_tsv}" "${max_jobs}" <<'PY'
import json
import sys
from pathlib import Path

run_json = Path(sys.argv[1])
failed_tsv = Path(sys.argv[2])
max_jobs = int(sys.argv[3])
payload = json.loads(run_json.read_text(encoding="utf-8"))
jobs = payload.get("jobs") or []

failed = []
for job in jobs:
    conclusion = (job.get("conclusion") or "").lower()
    if conclusion not in {"failure", "cancelled", "timed_out"}:
        continue
    failed.append(
        {
            "id": str(job.get("databaseId", "")),
            "name": job.get("name", ""),
            "status": job.get("status", ""),
            "conclusion": job.get("conclusion", ""),
            "started_at": job.get("startedAt", ""),
            "completed_at": job.get("completedAt", ""),
        }
    )

failed.sort(key=lambda x: x.get("started_at", ""), reverse=False)
failed = failed[:max_jobs]

lines = ["job_id\tjob_name\tstatus\tconclusion\tstarted_at\tcompleted_at"]
for row in failed:
    lines.append(
        "\t".join(
            [
                row["id"],
                row["name"].replace("\t", " "),
                row["status"],
                row["conclusion"],
                row["started_at"],
                row["completed_at"],
            ]
        )
    )
failed_tsv.write_text("\n".join(lines) + "\n", encoding="utf-8")
PY

line_count="$(wc -l < "${failed_tsv}" | tr -d ' ')"
summary_file="${WLT_RUN_TRIAGE_DIR}/root-cause-summary.tsv"
summary_json="${WLT_RUN_TRIAGE_DIR}/root-cause-summary.json"
printf 'job_id\tjob_name\tcategory\troot_cause\tfirst_hard_marker_line\n' > "${summary_file}"

if [[ "${line_count}" -le 1 ]]; then
  printf '{\n  "run_id": "%s",\n  "rows": []\n}\n' "${run_id}" > "${summary_json}"
  log "No failed jobs in run ${run_id}"
  log "Artifacts: ${WLT_RUN_TRIAGE_DIR}"
  exit 0
fi

log "Triaging run ${run_id} (failed jobs: $((line_count - 1)))"
while IFS=$'\t' read -r job_id job_name status conclusion started_at completed_at; do
  [[ "${job_id}" == "job_id" ]] && continue
  [[ -n "${job_id}" ]] || continue

  safe_job="$(printf '%s' "${job_name}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g' | sed -E 's/^-+|-+$//g')"
  [[ -n "${safe_job}" ]] || safe_job="job-${job_id}"
  log_file="${WLT_RUN_TRIAGE_DIR}/job-${job_id}-${safe_job}.log"
  analysis_file="${WLT_RUN_TRIAGE_DIR}/job-${job_id}-${safe_job}.analysis.txt"

  log "Fetch log: job_id=${job_id} name=${job_name}"
  if ! gh run view "${run_id}" --job "${job_id}" --log > "${log_file}" 2>"${log_file}.stderr"; then
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "${job_id}" "${job_name}" "workflow_infra" "log_fetch_failed" "log_fetch_failed" >> "${summary_file}"
    continue
  fi
  rm -f "${log_file}.stderr"

  bash "${ROOT_DIR}/ci/validation/extract-gh-job-failures.sh" "${log_file}" > "${analysis_file}" 2>&1 || true
  mapfile -t triage < <(python3 - "${analysis_file}" <<'PY'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8", errors="ignore")
lines = text.splitlines()

def first_line(patterns):
    for line in lines:
        for pat in patterns:
            if re.search(pat, line):
                return line
    return ""

compile_patterns = [
    r"/home/runner/.*error:",
    r"\bundefined reference\b",
    r"\bincompatible pointer types\b",
    r"\bundeclared function\b",
    r"make: \*\*\*",
]
runtime_contract_patterns = [
    r"contract validation failed",
    r"SDL2 runtime check failed",
    r"missing bionic ntdll marker",
    r"contains glibc-unix modules in strict bionic mode",
    r"runtime class mismatch",
    r"Strict gamenative check failed",
    r"Strict bionic check failed",
    r"Runpath contract failed",
    r"bionic-source-entry\.json contract violation",
    r"missing baseline symbols",
    r"mouse\.c WM_INPUT fix not applied",
    r"\[winlator-patch\]\[error\] Failed to apply .*\.patch",
    r"error: patch failed:",
    r"Rejected hunk #\d+",
    r"llvm-readobj(?:/readelf)? unavailable",
]
infra_patterns = [
    r"The operation was canceled",
    r"timed out",
    r"log_fetch_failed",
    r"Process completed with exit code",
    r"Unable to fetch log",
    r"Resource not accessible",
]
hard_marker_patterns = [
    r"##\[error\]",
    r"(?:^|\s)Error:",
    r"make: \*\*\*",
    r"Process completed with exit code",
    r"/home/runner/.*error:",
]

category = "unknown"
root = ""

compile_line = first_line(compile_patterns)
runtime_line = first_line(runtime_contract_patterns)
infra_line = first_line(infra_patterns)
hard_line = first_line(hard_marker_patterns)

if compile_line:
    category = "compile_error"
    root = compile_line
elif runtime_line:
    category = "runtime_contract"
    root = runtime_line
elif infra_line:
    category = "workflow_infra"
    root = infra_line
else:
    category = "unknown"
    root = "no_explicit_marker"

if not hard_line:
    hard_line = root

for value in (category, root, hard_line):
    value = re.sub(r"\s+", " ", value.strip())
    print(value)
PY
  )
  category="${triage[0]:-unknown}"
  root_cause="${triage[1]:-no_explicit_marker}"
  first_marker="${triage[2]:-${root_cause}}"
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "${job_id}" "${job_name}" "${category}" "${root_cause}" "${first_marker}" >> "${summary_file}"
done < "${failed_tsv}"

python3 - "${summary_file}" "${summary_json}" "${run_id}" <<'PY'
import csv
import json
import sys
from pathlib import Path

summary_tsv = Path(sys.argv[1])
summary_json = Path(sys.argv[2])
run_id = sys.argv[3]

rows = []
with summary_tsv.open("r", encoding="utf-8", newline="") as handle:
    reader = csv.DictReader(handle, delimiter="\t")
    for row in reader:
        rows.append(row)

summary_json.write_text(
    json.dumps({"run_id": run_id, "rows": rows}, indent=2, ensure_ascii=True) + "\n",
    encoding="utf-8",
)
PY

log "Summary:"
column -t -s $'\t' "${summary_file}" || cat "${summary_file}"
log "JSON: ${summary_json}"
log "Artifacts: ${WLT_RUN_TRIAGE_DIR}"
