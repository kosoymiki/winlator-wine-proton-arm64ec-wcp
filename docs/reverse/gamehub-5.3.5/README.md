# GameHub 5.3.5 Reverse Bundle

This directory contains the implementation artifacts for the reverse/forensics plan:

- `REVERSE_LEDGER.md` - reflective before/during/after analysis.
- `LIBRARY_MATRIX.tsv` - full native library inventory and classification.
- `PROCESS_LAUNCH_TIMELINE.md` - launch/process timeline for Proton/Wine scenarios.
- `PATCH_BACKLOG_FROM_RE.md` - prioritized backlog derived from findings.
- `FORENSIC_RUNS_2026-02-27.md` - executed capture runs and interpretation.

Capture automation script:

- `ci/forensics/gamehub_capture.sh`

Example usage:

```bash
ADB_SERIAL=edb0acd0 GH_PKG=com.miHoYo.GenshinImpact \
  ci/forensics/gamehub_capture.sh proton_container

ADB_SERIAL=edb0acd0 GH_PKG=com.miHoYo.GenshinImpact \
  ci/forensics/gamehub_capture.sh wine_container
```

For strict process-level Proton/Wine comparison, use interactive mode:

```bash
ADB_SERIAL=edb0acd0 GH_PKG=com.miHoYo.GenshinImpact GH_START_APP=0 GH_DURATION=90 \
  ci/forensics/gamehub_capture.sh proton_container_live
```
