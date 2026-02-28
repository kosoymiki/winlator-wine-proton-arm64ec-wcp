# Patch Reconciliation (Deep IDE Binary Cycle)

Date: 2026-02-27

## Inputs

- `docs/reverse/deep-ide/CROSS_SOURCE_IDE_COMPARISON.md`
- `docs/reverse/deep-ide/RUNTIME_CAPTURE_SYNTHESIS_2026-02-27.md`
- Existing patch stack `ci/winlator/patches/0063..0065`

## What was corrected in logic during this cycle

1. Deep scanner upgraded from ELF-only to ELF+PE:
   - `ci/reverse/elf_ide_reflective_cycle.py`
   - reason: WCP payloads are mostly PE (`.dll/.exe`) and were undercounted previously.
2. Deep cycle orchestration hardened:
   - `ci/reverse/run_deep_ide_cycle.sh`
   - added `SKIP_ANALYSIS=1` mode for fast report refresh and runtime-capture correlation section.
3. Multi-source comparator updated for binary-level totals:
   - `ci/reverse/compare_ide_cycles.py`
   - shows `binary_count`, `elf_count`, `pe_count` per source.

## Deterministic observations to apply in runtime/package policy

1. `proton-10-4-arm64ec.wcp.xz` and device `proton-10.0-4-arm64ec.wcp` are binary-identical in core payload shape:
   - 1596 binaries (`elf=34`, `pe=1562`) in both scans.
2. `protonwine10-gamenative-arm64ec.wcp` diverges from proton10.4 baseline:
   - 1607 binaries (`elf=47`, `pe=1560`), with extra tool/runtime surface.
3. Installed Ae.solator contents include additional binaries vs archive baselines:
   - `10.0-4-arm64ec-1`: 1604 binaries
   - `11-arm64ec-1`: 1701 binaries
   This confirms in-app post-install mutation layer and needs explicit validation rules.

## Patch-level recommendations mapped to current stack

1. Add package integrity contract checker (next block):
   - compare source WCP vs installed contents for critical binaries (`bin/wine`, `bin/wineserver`, unix loaders, core dll sets).
   - fail only on critical missing paths, warn on additive mutation.
2. Keep `0065-xserver-guest-exit-deferral-and-x11-zero-window-recovery.patch` and add launch-window process assertion:
   - enforce runtime evidence (`wine` + `wineserver`) in forensic gating for selected container profiles.
3. Keep `0063-network-vpn-download-hardening.patch` and split historical external logs from real-time launch markers:
   - prevents false-positive spike in marker counters from persisted GameHub logs.

## Constraint boundary

- No bypass of account/auth gates.
- No direct read of non-debuggable third-party private app data without root.
