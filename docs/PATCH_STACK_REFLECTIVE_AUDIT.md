# Winlator Patch Stack Reflective Audit

Generated: `2026-02-26T20:04:17Z`

## Snapshot

- Patch count: `62`
- Unique touched source files: `64`
- Diff volume across stack: `+16030 / -2915`
- Mean files touched per patch: `3.58`

## Numbering Contract

- Numbering contract is clean (`NNNN-` unique prefixes).

## High-Overlap Hotspots

- `app/src/main/res/values/strings.xml` touched by `21` patches
  - `0002-debug-no-embedded-runtime.patch`, `0003-wcphub-beta-turnip.patch`, `0005-aeroso-turnip-nightly-logs-branding-cleanup.patch`, `0008-contents-wcphub-overlay-single-track-wine-proton.patch`, `0014-adrenotools-driver-links-and-quick-info.patch`, `0015-adrenotools-driver-catalog-links-expand.patch`, `0016-adrenotools-dynamic-driver-catalog-themed-dialog.patch`, `0017-contents-arm64ec-switch-and-no-fake-wine-placeholders.patch` ...
- `app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java` touched by `20` patches
  - `0005-aeroso-turnip-nightly-logs-branding-cleanup.patch`, `0010-driver-probe-hardening-runtime-fallback-telemetry.patch`, `0011-xserver-session-exit-no-restart-on-guest-termination.patch`, `0021-default-enable-all-logs-and-full-wine-debug-channels.patch`, `0025-upscale-runtime-guardrails-and-swfg-contract.patch`, `0026-upscale-container-bridge-launch-normalization-and-ui.patch`, `0031-upscale-runtime-binding-gate-service-processes.patch`, `0036-upscale-binding-defer-shell-to-child-graphics.patch` ...
- `app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java` touched by `20` patches
  - `0001-winlator-arm64ec-runtime-and-fex.patch`, `0005-aeroso-turnip-nightly-logs-branding-cleanup.patch`, `0019-glibc-rseq-compat-for-wrapped-wine-launchers.patch`, `0020-glibc-wrapper-strip-bionic-ldpreload.patch`, `0021-default-enable-all-logs-and-full-wine-debug-channels.patch`, `0026-upscale-container-bridge-launch-normalization-and-ui.patch`, `0029-runtime-launcher-wrapper-preexec-forensics.patch`, `0040-runtime-common-profile-ui-and-launcher-integration.patch` ...
- `app/src/main/java/com/winlator/cmod/AdrenotoolsFragment.java` touched by `12` patches
  - `0003-wcphub-beta-turnip.patch`, `0005-aeroso-turnip-nightly-logs-branding-cleanup.patch`, `0014-adrenotools-driver-links-and-quick-info.patch`, `0016-adrenotools-dynamic-driver-catalog-themed-dialog.patch`, `0018-adrenotools-add-citron-yuzu-runtime-reference-links.patch`, `0023-adrenotools-hierarchical-driver-browser.patch`, `0024-adrenotools-remove-legacy-catalog-dead-code.patch`, `0028-adrenotools-native-gamenative-browser-polish-and-version-sorting.patch` ...
- `app/src/main/java/com/winlator/cmod/ContainerDetailFragment.java` touched by `12` patches
  - `0001-winlator-arm64ec-runtime-and-fex.patch`, `0017-contents-arm64ec-switch-and-no-fake-wine-placeholders.patch`, `0022-container-wine-picker-only-installed-artifacts.patch`, `0026-upscale-container-bridge-launch-normalization-and-ui.patch`, `0027-upscale-container-settings-own-config-and-env-migration.patch`, `0040-runtime-common-profile-ui-and-launcher-integration.patch`, `0042-external-runtime-placeholders-and-fex-resolution.patch`, `0043-runtime-profile-translator-preset-migration-and-defaults.patch` ...
- `app/src/main/java/com/winlator/cmod/container/Container.java` touched by `10` patches
  - `0001-winlator-arm64ec-runtime-and-fex.patch`, `0009-container-create-hardening-and-content-download-fixes.patch`, `0026-upscale-container-bridge-launch-normalization-and-ui.patch`, `0040-runtime-common-profile-ui-and-launcher-integration.patch`, `0042-external-runtime-placeholders-and-fex-resolution.patch`, `0043-runtime-profile-translator-preset-migration-and-defaults.patch`, `0049-upscale-eden-render-controls-and-runtime-contract.patch`, `0050-upscale-eden-advanced-renderer-runtime-controls.patch` ...
- `app/src/main/java/com/winlator/cmod/ContentsFragment.java` touched by `8` patches
  - `0003-wcphub-beta-turnip.patch`, `0005-aeroso-turnip-nightly-logs-branding-cleanup.patch`, `0008-contents-wcphub-overlay-single-track-wine-proton.patch`, `0009-container-create-hardening-and-content-download-fixes.patch`, `0012-contents-list-placeholder-and-actions-layout-polish.patch`, `0013-wcphub-arm64ec-channels-and-contents-switch-ux.patch`, `0017-contents-arm64ec-switch-and-no-fake-wine-placeholders.patch`, `0061-contents-wine-family-internal-type-labels.patch`
- `app/src/main/java/com/winlator/cmod/contents/ContentsManager.java` touched by `8` patches
  - `0003-wcphub-beta-turnip.patch`, `0005-aeroso-turnip-nightly-logs-branding-cleanup.patch`, `0008-contents-wcphub-overlay-single-track-wine-proton.patch`, `0013-wcphub-arm64ec-channels-and-contents-switch-ux.patch`, `0017-contents-arm64ec-switch-and-no-fake-wine-placeholders.patch`, `0042-external-runtime-placeholders-and-fex-resolution.patch`, `0054-contents-proton-type-aliases.patch`, `0060-contents-internal-type-canonicalization.patch`
- `app/src/main/res/layout/container_detail_fragment.xml` touched by `7` patches
  - `0026-upscale-container-bridge-launch-normalization-and-ui.patch`, `0040-runtime-common-profile-ui-and-launcher-integration.patch`, `0042-external-runtime-placeholders-and-fex-resolution.patch`, `0049-upscale-eden-render-controls-and-runtime-contract.patch`, `0050-upscale-eden-advanced-renderer-runtime-controls.patch`, `0051-upscale-eden-shader-debug-and-advanced-runtime-controls.patch`, `0052-upscale-eden-renderer-gpu-diagnostics-control-parity.patch`
- `app/src/main/res/layout/adrenotools_fragment.xml` touched by `6` patches
  - `0003-wcphub-beta-turnip.patch`, `0005-aeroso-turnip-nightly-logs-branding-cleanup.patch`, `0014-adrenotools-driver-links-and-quick-info.patch`, `0023-adrenotools-hierarchical-driver-browser.patch`, `0028-adrenotools-native-gamenative-browser-polish-and-version-sorting.patch`, `0035-adrenotools-fix-version-dialog-and-gamenative-native-browser-ux.patch`
- `app/src/main/java/com/winlator/cmod/SettingsFragment.java` touched by `5` patches
  - `0005-aeroso-turnip-nightly-logs-branding-cleanup.patch`, `0021-default-enable-all-logs-and-full-wine-debug-channels.patch`, `0040-runtime-common-profile-ui-and-launcher-integration.patch`, `0043-runtime-profile-translator-preset-migration-and-defaults.patch`, `0055-termux-x11-compat-contract-preflight-and-diagnostics.patch`
- `app/src/main/java/com/winlator/cmod/container/ContainerNormalizer.java` touched by `4` patches
  - `0006-forensics-diagnostics-contents-turnip-picker-and-repo-contents.patch`, `0040-runtime-common-profile-ui-and-launcher-integration.patch`, `0042-external-runtime-placeholders-and-fex-resolution.patch`, `0043-runtime-profile-translator-preset-migration-and-defaults.patch`
- `app/src/main/java/com/winlator/cmod/contentdialog/ContentInfoDialog.java` touched by `4` patches
  - `0006-forensics-diagnostics-contents-turnip-picker-and-repo-contents.patch`, `0008-contents-wcphub-overlay-single-track-wine-proton.patch`, `0017-contents-arm64ec-switch-and-no-fake-wine-placeholders.patch`, `0062-contents-info-dialog-wine-family-variant-and-meta-format.patch`
- `app/src/main/java/com/winlator/cmod/contents/AdrenotoolsManager.java` touched by `4` patches
  - `0005-aeroso-turnip-nightly-logs-branding-cleanup.patch`, `0010-driver-probe-hardening-runtime-fallback-telemetry.patch`, `0045-graphics-driver-fallback-chain-and-telemetry.patch`, `0047-driver-fallback-chain-ranking-and-telemetry.patch`
- `app/src/main/java/com/winlator/cmod/contents/ContentProfile.java` touched by `4` patches
  - `0006-forensics-diagnostics-contents-turnip-picker-and-repo-contents.patch`, `0008-contents-wcphub-overlay-single-track-wine-proton.patch`, `0054-contents-proton-type-aliases.patch`, `0060-contents-internal-type-canonicalization.patch`

## Risk Buckets

- `critical` (9 files):
  - `app/src/main/res/values/strings.xml` (21 patches)
  - `app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java` (20 patches)
  - `app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java` (20 patches)
  - `app/src/main/java/com/winlator/cmod/AdrenotoolsFragment.java` (12 patches)
  - `app/src/main/java/com/winlator/cmod/ContainerDetailFragment.java` (12 patches)
  - `app/src/main/java/com/winlator/cmod/container/Container.java` (10 patches)
  - `app/src/main/java/com/winlator/cmod/ContentsFragment.java` (8 patches)
  - `app/src/main/java/com/winlator/cmod/contents/ContentsManager.java` (8 patches)
- `high` (2 files):
  - `app/src/main/res/layout/container_detail_fragment.xml` (7 patches)
  - `app/src/main/res/layout/adrenotools_fragment.xml` (6 patches)
- `medium` (12 files):
  - `app/src/main/java/com/winlator/cmod/SettingsFragment.java` (5 patches)
  - `app/src/main/java/com/winlator/cmod/container/ContainerNormalizer.java` (4 patches)
  - `app/src/main/java/com/winlator/cmod/contentdialog/ContentInfoDialog.java` (4 patches)
  - `app/src/main/java/com/winlator/cmod/contents/ContentProfile.java` (4 patches)
  - `app/src/main/res/values/arrays.xml` (4 patches)
  - `app/build.gradle` (3 patches)
  - `app/src/main/java/com/winlator/cmod/container/ContainerManager.java` (3 patches)
  - `app/src/main/java/com/winlator/cmod/core/ForensicLogger.java` (3 patches)

## Key Runtime Integration Coverage

- `app/src/main/java/com/winlator/cmod/XServerDisplayActivity.java` -> touched: `yes` (20 patches)
- `app/src/main/java/com/winlator/cmod/xenvironment/components/GuestProgramLauncherComponent.java` -> touched: `yes` (20 patches)
- `app/src/main/java/com/winlator/cmod/container/Container.java` -> touched: `yes` (10 patches)
- `app/src/main/java/com/winlator/cmod/ContainerDetailFragment.java` -> touched: `yes` (12 patches)
- `app/src/main/java/com/winlator/cmod/ContentsFragment.java` -> touched: `yes` (8 patches)
- `app/src/main/java/com/winlator/cmod/contents/ContentsManager.java` -> touched: `yes` (8 patches)
- `app/src/main/java/com/winlator/cmod/AdrenotoolsFragment.java` -> touched: `yes` (12 patches)
- `app/src/main/java/com/winlator/cmod/contents/AdrenotoolsManager.java` -> touched: `yes` (4 patches)

## Action Rules

- Keep runtime launch flow changes in smallest possible follow-up patches.
- For files in `critical` bucket, run `ci/winlator/check-patch-stack.sh` before push.
- Any new patch touching `XServerDisplayActivity` or `GuestProgramLauncherComponent` must include forensic markers and fallback reason codes.

