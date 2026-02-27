# Docs Index

This repository keeps docs in two buckets:

- **Active Ops**: build/runbook docs used by current CI and release process.
- **Research Archive**: deep analysis logs kept for traceability; not authoritative for current mainline behavior.

## Active Ops

- `docs/CI_FAILURE_PLAYBOOK.md` - triage path for failed Wine/Proton workflows.
- `ci/validation/extract-gh-job-failures.sh` - raw GH job log parser to isolate first hard failures.
- `ci/validation/gh-latest-failures.sh` - fetch + parse active failed workflows (latest-run failure only) in one command, with optional TSV/meta export and optional auto run-level triage.
- `ci/validation/gh-mainline-health.sh` - checks latest health state of critical mainline workflows (`fresh + success`) and can export TSV/JSON snapshots.
- `ci/validation/gh-run-root-cause.sh` - run-scoped triage: fetch failed jobs for one run and produce root-cause summaries/artifacts.
- `ci/validation/reverse-compare-gamenative-baseline.sh` - compares built WCP artifact against pinned GameNative Proton 10.4 baseline via reverse contract report.
- `ci/validation/collect-mainline-forensic-snapshot.sh` - one-shot collection of mainline health + active failures + URC check logs/metadata (optional per-run triage).
- `ci/winlator/forensic-adb-runtime-contract.sh` - adb runtime forensic orchestrator for wine/proton scenario matrix.
- `ci/winlator/forensic-adb-harvard-suite.sh` - full device forensic orchestrator (seed/artifacts/matrix/mismatch/per-scenario bundles).
- `ci/winlator/adb-container-seed-matrix.sh` - deterministic `xuser-*` clone + `.container` normalization for test matrices.
- `ci/winlator/adb-ensure-artifacts-latest.sh` - refresh/install latest WCP artifacts into app-private contents via `run-as`.
- `ci/winlator/artifact-source-map.json` - pinned source map used by artifact refresh automation.
- `ci/winlator/forensic-runtime-mismatch-matrix.py` - baseline mismatch TSV/MD/JSON generator with status/severity/severity-rank/patch-hint routing.
- `ci/winlator/selftest-runtime-mismatch-matrix.sh` - local selftest for mismatch classifier/exit-code contract.
- `docs/ADB_HARVARD_DEVICE_FORENSICS.md` - runbook for end-to-end device forensic suite.
- `ci/research/reverse-wcp-package.py` - reverse-inspects reference WCP archives (ELF/PE/exports/runtime-class) and can emit full per-file inventory via `--full-inventory`.
- `ci/research/run-gamenative-proton104-reverse.sh` - one-shot wrapper: compares GameNative Proton 10.4 against device Wine 11 or a local path/archive via `WCP_COMPARE_SOURCE`; auto-falls back to common local archive paths when `WCP_SOURCE` is unavailable.
- `docs/GAMENATIVE_PROTON104_WCP_REVERSE.md` - latest reverse report for GameNative Proton 10.4 WCP vs local Wine 11 package.
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
- `docs/GAMENATIVE_PROTON_10_4_WCP_BASELINE_ANALYSIS.md`
- `docs/GAMENATIVE_PROTON104_WCP_REVERSE.json`

When an archived finding becomes actionable, migrate the result into an Active Ops doc and keep archive files immutable.
