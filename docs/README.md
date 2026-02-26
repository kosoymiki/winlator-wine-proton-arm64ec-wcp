# Docs Index

This repository keeps docs in two buckets:

- **Active Ops**: build/runbook docs used by current CI and release process.
- **Research Archive**: deep analysis logs kept for traceability; not authoritative for current mainline behavior.

## Active Ops

- `docs/CI_FAILURE_PLAYBOOK.md` - triage path for failed Wine/Proton workflows.
- `docs/PATCHSET_CONFLICT_REPORT.md` - generated ownership/conflict report for GN patchset.
- `docs/UNIFIED_RUNTIME_CONTRACT.md` - runtime contract for WCP packaging.
- `docs/CONTENT_PACKAGES_ARCHITECTURE.md` - content package model used by Winlator UI.
- `docs/CONTENTS_QA_CHECKLIST.md` - QA checklist for contents/adrenotools paths.

## Patch Pipeline Docs

- `ci/gamenative/README.md` - GN patchset structure and actions.
- `ci/gamenative/PATCHSET_PIPELINE.md` - mode semantics (`full`, `normalize-only`, `off`).
- `ci/gamenative/patchset-conflict-audit.py` - report generator used to detect duplicate ownership.

## Research Archive (reference only)

The files below are preserved as historical analysis and can be used for forensic comparison:

- `docs/REFLECTIVE_HARVARD_LEDGER.md`
- `docs/AEROSO_IMPLEMENTATION_REFLECTIVE_LOG.md`
- `docs/UPSCALER_TRANSFER_REFLECTIVE_LOG.md`
- `docs/GAMEHUB_PROVENANCE_REPORT.md`
- `docs/GAMENATIVE_BRANCH_AUDIT_LOG.md`
- `docs/STEVEN_PROTON_10_4_WCP_REVERSE_ANALYSIS.md`

When an archived finding becomes actionable, migrate the result into an Active Ops doc and keep archive files immutable.
