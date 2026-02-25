# Winlator Patch Stack Notes

This directory contains the ordered patch stack applied to the upstream Winlator
source checkout by `ci/winlator/apply-repo-patches.sh`.

## Ordering rule

Patches are applied lexicographically (`0001` -> `NNNN`). Do not renumber in the
middle of the stack.

## Current thematic ranges

- `0001-0005` - base fork, runtime/FEX, branding, CI compatibility
- `0006-0012` - forensics, diagnostics, contents/turnip, launch-exit fixes, UI cleanup
- `0013-0024` - WCPHub/contents UX, Adrenotools browser refactors and cleanup
- `0025-0027` - upscale transfer (runtime guardrails + container-owned config path)
- `0028+` - Adrenotools native source adapters (GameNative), browser UX polish/sorting, runtime forensic instrumentation follow-ups, FEX/Box preset editor surface expansion,
  upscale runtime binding gates, forensic log sink reliability fixes, common runtime profile system, launch precheck contract guardrails, and follow-up driver browser UI/source pruning fixes

## Upscale patch consolidation note

The original incremental upscale bring-up (`0025`..`0030`) was intentionally
split during implementation for safe iteration. After validation, it was
consolidated into:

- `0025-upscale-runtime-guardrails-and-swfg-contract.patch`
  - historical steps: old `0025`, `0026`, `0027`
- `0026-upscale-container-bridge-launch-normalization-and-ui.patch`
  - historical steps: old `0028`, `0029`, `0030`
- `0027-upscale-container-settings-own-config-and-env-migration.patch`
  - moves upscale config ownership to container settings UI and strips legacy raw env overrides from generic env editor
- `0029-runtime-launcher-wrapper-preexec-forensics.patch`
  - adds launcher wrapper artifact telemetry and final pre-exec env markers for glibc/bionic runtime triage
- `0030-fexcore-upstream-config-vars-and-inline-help.patch`
  - expands FEX preset env-var editor to track upstream FEX config options and uses inline help text parsed from the source config descriptions
- `0031-upscale-runtime-binding-gate-service-processes.patch`
  - binds ScaleForce/SWFG activation to graphics-eligible shortcut launches (Vulkan/OpenGL) and disables it for container shell/service processes with forensic reasons
- `0032-forensicslogger-fallback-to-app-private-jsonl-sink.patch`
  - falls back from `/sdcard/Winlator/logs/forensics` to app-private `files/Winlator/logs/forensics` when external storage writes fail (EACCES), and logs sink switches
- `0033-adrenotools-driver-browser-version-list-ui-polish.patch`
  - makes the driver-version picker rows look and behave closer to `Contents` (icon + structured metadata rows + recommended badge)
- `0034-adrenotools-contents-style-version-rows-and-disable-dead-xforyoux.patch`
  - temporarily removes dead `XForYouX` release source entries (404) from the in-app driver browser pending a valid upstream source
- `0035-adrenotools-fix-version-dialog-and-gamenative-native-browser-ux.patch`
  - fixes OEM AlertDialog list/message collision in version picker (source hint moved into custom clickable header), improves GameNative native parsing/filter labels, and hardens driver row readability in themed dialogs
- `0036-upscale-binding-defer-shell-to-child-graphics.patch`
  - defers ScaleForce/SWFG binding decisions at container-shell/service launches so child graphics launches can apply upscale policy later instead of being preemptively downgraded
- `0037-fex-box-preset-switch-semantics-and-box-descriptions.patch`
  - hardens FEX/Box preset JSON boolean parsing (`true`/`false`/`1`/`0`), supports explicit toggle on/off values and labels, and upgrades Box preset help to use inline JSON descriptions
- `0038-contents-list-title-layout-for-long-package-names.patch`
  - improves `Contents` list rows for long package names (2-line title, ellipsis, tighter action spacing) to avoid truncated/awkward package labels
- `0039-box64-wowbox64-envvars-and-device-tier-presets.patch`
  - imports a fuller Box64/WoWBox64 env-var surface with typed toggle metadata and extends FEX/Box preset managers with 2026 device-tier profiles (including S8+G1 performance-focused presets)
- `0040-runtime-common-profile-ui-and-launcher-integration.patch`
  - adds a runtime-common profile layer (independent from FEX/Box presets), persists it in container/settings UI, bridges it into launcher env overlays, and emits forensic telemetry for applied common profile selection
- `0042-external-runtime-placeholders-and-fex-resolution.patch`
  - switches Box/WoWBox/FEX version pickers to installed-only lists with neutral `—` placeholder when external runtime packages are absent, sanitizes placeholder tokens from persisted container/shortcut data, resolves FEX/WoWBox runtime payload from installed Contents profiles (no embedded tar fallback for ARM64EC path), and applies non-crashing HODLL fallback selection during launch
- `0043-runtime-profile-translator-preset-migration-and-defaults.patch`
  - binds common runtime profile policy to translator preset defaults/migration (legacy `COMPATIBILITY`/`INTERMEDIATE` values map to profile-matched overlays for non-`AUTO` mode), unifies default Box64/FEX presets in container/settings/normalizer, and logs requested vs effective preset resolution in launcher forensics
- `0044-runtime-launch-precheck-and-forensic-guardrails.patch`
  - introduces a launch precheck contract between `XServerDisplayActivity` and `GuestProgramLauncherComponent` (route/kind/target/reason/shell-fallback markers), hardens missing-shortcut or empty-command launches with deterministic shell fallback, and adds reason-coded forensic telemetry for launch acceptance and runtime preset migration guards
- `0045-graphics-driver-fallback-chain-and-telemetry.patch`
  - adds deterministic graphics driver probe fallback chain (`requested -> fallback candidate -> system`), exports probe-chain env telemetry for runtime triage, and refines graphics suitability fallback severity when a usable non-system fallback driver is selected

## Known high-overlap files (intentional)

These files appear in multiple patches and require extra review when adding new
patches to avoid accidental regressions:

- `XServerDisplayActivity.java` (runtime integration point)
- `GuestProgramLauncherComponent.java` (launch submit/final env normalization)
- `Container.java` / `ContainerDetailFragment.java` (schema + UI persistence)
- `ContentsFragment.java` / `ContentsManager.java` (source routing and display policy)
- `AdrenotoolsFragment.java` / `AdrenotoolsManager.java` (driver browser and install flow)

## Audit workflow

Before pushing a new patch touching high-overlap files:

```bash
bash ci/winlator/check-patch-stack.sh /path/to/upstream/winlator/checkout
```

This creates a clean temporary clone, applies the full stack, and reports file
overlaps touched by multiple patches.
