# GameNative 0.7.2 Reverse Ledger

Date: 2026-02-27
APK: `/home/mikhail/gamenative-v0.7.2.apk`
Installed package: `app.gamenative`

## Scope

This ledger captures the full reproducible cycle performed for GameNative in this repository:
- static native reverse (`readelf`/`nm`/`strings` based matrix),
- live startup forensics on device,
- patch-relevance mapping to current Winlator patch stack.

## Static reverse outputs

- `LIBRARY_MATRIX.tsv`
- `SUMMARY.json`
- `REVERSE_SUMMARY.md`

Observed result in this cycle:
- 35 native libraries total,
- major Winlator-oriented modules present (`libwinlator.so`, `libwinlator_11.so`, `libdummyvk.so`, `libvortekrenderer.so`, `libextras.so`),
- no `libwinemu.so` / `libxserver.so` pair in this APK.

## Runtime forensics outputs

- `out/app-forensics/*gamenative_startup_live*`
- package process remained alive (`app.gamenative`), but no Wine process tree (`wineserver` / `wine`) during startup capture window.
- high amount of auth/login/token markers in logs, consistent with gated flow before container launch.

## Reflective conclusions

1. GameNative 0.7.2 and GameHub 5.3.5 mod are not binary-equivalent runtime shells.
2. Transfer should be done at logic/contract level, not by binary swapping.
3. Auth-gated flow is an external dependency; not bypassed in this cycle.

## Constraint note

This cycle does not bypass third-party account/authentication controls.
Any emulator/container path behind account gating is logged as a constraint and handled through forensic capture.
