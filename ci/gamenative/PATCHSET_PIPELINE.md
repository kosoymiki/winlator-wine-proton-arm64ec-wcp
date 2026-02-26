# GameNative Patchset Pipeline

This document defines the mainline patch pipeline contract for Wine/Proton builds.

## Single Source of Truth

- Patch ownership lives in:
  - `ci/gamenative/patchsets/28c3a06/manifest.tsv`
  - `ci/gamenative/apply-android-patchset.sh`
- Per-package scripts (`ci/ci-build.sh`, `ci/proton-ge10/*`, `ci/protonwine10/*`) only select mode and pass env.
- Do not duplicate file-level hotfixes in package-local scripts.

## Modes

- `full`: apply/verify/backport by manifest, then run post-normalization.
- `normalize-only`: skip manifest apply phase, run post-normalization only.
- `off`: skip all patchset actions.
- `auto` (default in patchset script):
  - `WCP_GN_PATCHSET_ENABLE=1` -> `full`
  - `WCP_GN_PATCHSET_ENABLE=0` -> `normalize-only`

## Normalization Phase (always for full/normalize-only)

- `programs/winebrowser/main.c`
  - enforce Android bridge safety casts for socket `send()` calls
  - normalize `WINE_OPEN_WITH_ANDROID_BROWSER` env key typo
- `dlls/winex11.drv/mouse.c`
  - guard `pXFixesHideCursor/ShowCursor` with `HAVE_X11_EXTENSIONS_XFIXES_H`
- `dlls/winex11.drv/window.c`
  - guard `xinput2_rawinput` usage with `HAVE_X11_EXTENSIONS_XINPUT2_H`

## Workflow Toggle Contract

`workflow_dispatch` exposes `gn_patchset_enable` (`0|1`) in all 3 WCP workflows:

- `.github/workflows/ci-arm64ec-wine.yml`
- `.github/workflows/ci-proton-ge10-wcp.yml`
- `.github/workflows/ci-protonwine10-wcp.yml`

Mainline default is `1`.

## Audit Tool

Run ownership audit:

```bash
python3 ci/gamenative/patchset-conflict-audit.py --output docs/PATCHSET_CONFLICT_REPORT.md
```

Use `--strict` in CI to fail if duplicate ownership appears.
