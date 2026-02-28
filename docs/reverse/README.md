# Reverse Index

Generated on 2026-02-27.

## GameHub tracks

- `gamehub-5.3.5/` - original reverse + forensic bundle.
- `gamehub-5.3.5-native-cycle/` - reproducible native reverse cycle outputs.

## GameNative tracks

- `gamenative-0.7.2-native-cycle/` - reproducible native reverse cycle outputs.

## Cross comparison

- `gamehub-vs-gamenative/CROSS_APK_NATIVE_COMPARISON.md`
- `gamehub-vs-gamenative/FULL_CYCLE_REPORT_2026-02-27.md`
- `gamehub-vs-gamenative/PATCH_RECONCILIATION_2026-02-27.md`
- `deep-ide/CROSS_SOURCE_IDE_COMPARISON.md`
- `deep-ide/DEEP_IDE_CYCLE_REPORT_2026-02-27.md`
- `deep-ide/PATCH_RECONCILIATION_DEEP_IDE_2026-02-27.md`

## Online intake (gh/git)

- `ONLINE_INTAKE_WORKFLOW.md`
- `online-intake/combined-matrix.md`
- `online-intake/combined-matrix.json`
- `online-intake/PATCH_TRANSFER_BACKLOG.md`
- `online-intake/PATCH_TRANSFER_BACKLOG.json`
- per-upstream snapshots under `online-intake/*.md` and `online-intake/*.json`
- intake defaults to `focused` scope (per-repo `focus_paths[]` first, tree fallback)

### Extended upstream lanes (default-enabled)

- Box/FEX ecosystem: `olegos2/mobox`, `Ilya114/Box64Droid`, `ahmad1abbadi/darkos`
- MiceWine/Horizon ecosystem: `KreitinnSoftware/MiceWine*`, `HorizonEmuTeam/Horizon-Emu`

## Tooling

- `ci/reverse/online-intake.sh`
- `ci/reverse/run-high-priority-cycle.sh`
- `ci/reverse/online_intake.py`
- `ci/reverse/check-online-backlog.py`
- `ci/reverse/online_intake_repos.json`
- `ci/reverse/apk_native_reflective_cycle.py`
- `ci/reverse/compare_apk_native_cycles.py`
- `ci/reverse/run_full_cycle.sh`
- `ci/reverse/elf_ide_reflective_cycle.py`
- `ci/reverse/compare_ide_cycles.py`
- `ci/reverse/run_deep_ide_cycle.sh`
- `ci/forensics/app_capture.sh`
- `ci/validation/check-app-capture-contract.py`
- `ci/validation/check-wcp-content-parity.py`
- `ci/validation/run-wcp-parity-suite.sh`
