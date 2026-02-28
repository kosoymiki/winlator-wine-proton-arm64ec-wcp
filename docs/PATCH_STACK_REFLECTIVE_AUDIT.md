# Winlator Patch Stack Reflective Audit

Generated: `2026-02-28T16:45:13Z`

## Snapshot

- Patch count: `10`
- Unique touched source files: `279`
- Diff volume across stack: `+10801 / -1991`
- Mean files touched per patch: `30.50`

## Numbering Contract

- Numbering contract is clean (`NNNN-` unique prefixes).

## High-Overlap Hotspots

- `app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java` touched by `9` patches
  - `0001-mainline-full-stack-consolidated.patch`, `0003-aeturnip-runtime-bind-and-forensics.patch`, `0004-upscaler-adrenotools-control-plane-x11-bind.patch`, `0005-upscaler-dxvk-proton-fsr-x11-turnip-runtime-matrix.patch`, `0006-upscaler-x11-turnip-dx-all-directs-memory-policy.patch`, `0007-upscaler-module-forensics-dx8assist-contract.patch`, `0008-upscaler-dx-policy-order-and-artifact-sources.patch`, `0009-launch-graphics-packet-dx-upscaler-x11-turnip-bundle.patch` ...
- `app/src/main/res/values/strings.xml` touched by `7` patches
  - `0001-mainline-full-stack-consolidated.patch`, `0002-turnip-lane-global-adrenotools-restructure.patch`, `0003-aeturnip-runtime-bind-and-forensics.patch`, `0004-upscaler-adrenotools-control-plane-x11-bind.patch`, `0005-upscaler-dxvk-proton-fsr-x11-turnip-runtime-matrix.patch`, `0006-upscaler-x11-turnip-dx-all-directs-memory-policy.patch`, `0010-dxvk-capability-envelope-proton-fsr-gate-upscaler-matrix.patch`
- `app/src/main/java/com/winlator/cmod/AdrenotoolsFragment.java` touched by `6` patches
  - `0001-mainline-full-stack-consolidated.patch`, `0002-turnip-lane-global-adrenotools-restructure.patch`, `0003-aeturnip-runtime-bind-and-forensics.patch`, `0004-upscaler-adrenotools-control-plane-x11-bind.patch`, `0005-upscaler-dxvk-proton-fsr-x11-turnip-runtime-matrix.patch`, `0006-upscaler-x11-turnip-dx-all-directs-memory-policy.patch`
- `app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java` touched by `3` patches
  - `0001-mainline-full-stack-consolidated.patch`, `0009-launch-graphics-packet-dx-upscaler-x11-turnip-bundle.patch`, `0010-dxvk-capability-envelope-proton-fsr-gate-upscaler-matrix.patch`
- `app/src/main/res/layout/adrenotools_fragment.xml` touched by `3` patches
  - `0001-mainline-full-stack-consolidated.patch`, `0002-turnip-lane-global-adrenotools-restructure.patch`, `0004-upscaler-adrenotools-control-plane-x11-bind.patch`
- `app/src/main/java/com/winlator/cmod/container/Container.java` touched by `2` patches
  - `0001-mainline-full-stack-consolidated.patch`, `0010-dxvk-capability-envelope-proton-fsr-gate-upscaler-matrix.patch`
- `app/src/main/java/com/winlator/cmod/contentdialog/DXVKConfigDialog.java` touched by `2` patches
  - `0005-upscaler-dxvk-proton-fsr-x11-turnip-runtime-matrix.patch`, `0010-dxvk-capability-envelope-proton-fsr-gate-upscaler-matrix.patch`
- `app/src/main/java/com/winlator/cmod/contents/AdrenotoolsManager.java` touched by `2` patches
  - `0001-mainline-full-stack-consolidated.patch`, `0003-aeturnip-runtime-bind-and-forensics.patch`
- `app/build.gradle` touched by `1` patches
  - `0001-mainline-full-stack-consolidated.patch`
- `app/src/main/AndroidManifest.xml` touched by `1` patches
  - `0001-mainline-full-stack-consolidated.patch`
- `app/src/main/assets/box64_env_vars.json` touched by `1` patches
  - `0001-mainline-full-stack-consolidated.patch`
- `app/src/main/assets/fexcore_env_vars.json` touched by `1` patches
  - `0001-mainline-full-stack-consolidated.patch`
- `app/src/main/assets/wowbox64_env_vars.json` touched by `1` patches
  - `0001-mainline-full-stack-consolidated.patch`
- `app/src/main/java/com/winlator/cmod/ContainerDetailFragment.java` touched by `1` patches
  - `0001-mainline-full-stack-consolidated.patch`
- `app/src/main/java/com/winlator/cmod/ContentsFragment.java` touched by `1` patches
  - `0001-mainline-full-stack-consolidated.patch`

## Risk Buckets

- `critical` (2 files):
  - `app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java` (9 patches)
  - `app/src/main/java/com/winlator/cmod/AdrenotoolsFragment.java` (6 patches)
- `high` (1 files):
  - `app/src/main/res/values/strings.xml` (7 patches)
- `medium` (2 files):
  - `app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java` (3 patches)
  - `app/src/main/res/layout/adrenotools_fragment.xml` (3 patches)

## Key Runtime Integration Coverage

- `app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java` -> touched: `yes` (9 patches)
- `app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java` -> touched: `yes` (3 patches)
- `app/src/main/java/com/winlator/cmod/container/Container.java` -> touched: `yes` (2 patches)
- `app/src/main/java/com/winlator/cmod/ContainerDetailFragment.java` -> touched: `yes` (1 patches)
- `app/src/main/java/com/winlator/cmod/ContentsFragment.java` -> touched: `yes` (1 patches)
- `app/src/main/java/com/winlator/cmod/contents/ContentsManager.java` -> touched: `yes` (1 patches)
- `app/src/main/java/com/winlator/cmod/AdrenotoolsFragment.java` -> touched: `yes` (6 patches)
- `app/src/main/java/com/winlator/cmod/contents/AdrenotoolsManager.java` -> touched: `yes` (2 patches)

## Action Rules

- Keep runtime launch flow changes in smallest possible follow-up patches.
- For files in `critical` bucket, run `ci/winlator/check-patch-stack.sh` before push.
- Any new patch touching `XServerDisplayActivity` or `GuestProgramLauncherComponent` must include forensic markers and fallback reason codes.

