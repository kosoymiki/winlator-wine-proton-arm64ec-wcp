# Docs Index

This repository keeps docs in two buckets:

- **Active Ops**: build/runbook docs used by current CI and release process.
- **Research Archive**: deep analysis logs kept for traceability; not authoritative for current mainline behavior.

## Active Ops

- `docs/CI_FAILURE_PLAYBOOK.md` - triage path for failed Wine/Proton workflows.
- `ci/validation/extract-gh-job-failures.sh` - raw GH job log parser to isolate first hard failures.
- `ci/validation/gh-latest-failures.sh` - fetch + parse active failed workflows (latest-run failure only) in one command, with optional TSV/meta export.
- `ci/validation/gh-mainline-health.sh` - checks latest health state of critical mainline workflows (`fresh + success`) and can export TSV/JSON snapshots.
- `ci/validation/collect-mainline-forensic-snapshot.sh` - one-shot collection of mainline health + active failures + URC check logs/metadata.
- `ci/winlator/forensic-adb-runtime-contract.sh` - adb runtime forensic orchestrator for wine/proton scenario matrix.
- `ci/winlator/forensic-runtime-mismatch-matrix.py` - baseline mismatch TSV/MD/JSON generator with status/severity/patch-hint routing.
- `ci/winlator/selftest-runtime-mismatch-matrix.sh` - local selftest for mismatch classifier/exit-code contract.
- `docs/PATCHSET_CONFLICT_REPORT.md` - generated ownership/conflict report for GN patchset.
- `docs/PATCH_STACK_REFLECTIVE_AUDIT.md` - generated overlap/risk report for Winlator patch stack hot files.
- `docs/PATCH_STACK_RUNTIME_CONTRACT_AUDIT.md` - generated runtime-forensics contract report for XServer/Launcher patch coverage.
- `ci/winlator/validate-patch-sequence.sh` - enforces contiguous `NNNN-` patch numbering before audits/build.
- `docs/UNIFIED_RUNTIME_CONTRACT.md` - runtime contract for WCP packaging.
- `docs/EXTERNAL_SIGNAL_CONTRACT.md` - arbitration contract for external runtime signal sources (GN/GH/Termux lanes).
- `docs/X11_TERMUX_COMPAT_CONTRACT.md` - optional `termux_compat` backend contract (preflight/env/forensics).
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
