# Upstream Research Artifacts

This directory stores generated evidence from reproducible upstream audits.

## Generators

- `ci/research/gamenative_forensic_audit.py`
  - Produces `docs/GAMENATIVE_BRANCH_AUDIT_LOG.md`
  - Produces `docs/research/gamenative_branch_audit_raw.json`
  - Produces per-branch details in `docs/research/gamenative-branch-reports/`
- `ci/research/gamehub_provenance_audit.py`
  - Produces `docs/GAMEHUB_PROVENANCE_REPORT.md`
  - Produces `docs/research/gamehub_provenance_raw.json`

## Run

```bash
bash ci/research/run_upstream_audits.sh
```

Notes:
- Scripts use `gh api`; ensure `gh auth status` is valid before running.
- Reports are triage inputs for patch planning, not auto-merge instructions.
