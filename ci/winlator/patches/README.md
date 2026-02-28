# Winlator Patch Stack Notes

This directory contains the ordered patch stack applied to the upstream Winlator
source checkout by `ci/winlator/apply-repo-patches.sh`.

## Ordering rule

Patches are applied lexicographically (`0001` -> `NNNN`). Do not renumber in the
middle of the stack.

## Current thematic ranges

The patch base currently uses a consolidated mainline plus active review
slices:

- `0001-mainline-full-stack-consolidated.patch`
  - base fork/runtime/FEX contract
  - branding + versioning
  - contents/WCPHub routing and UI changes
  - Adrenotools browser/control-plane work
  - runtime profiles, FEX/Box/WoWBox surface, and launch contracts
  - forensic logging, diagnostics, network hardening, and Vulkan policy
  - upscale/render controls and container/runtime glue
- `0002-turnip-lane-global-adrenotools-restructure.patch`
  - Turnip multi-source lane orchestration (Steven + mirror repos)
  - policy-driven source/channel/limit controls in Adrenotools
  - restructured Adrenotools screen for turnip + install/catalog flow
- `0003-aeturnip-runtime-bind-and-forensics.patch`
  - integrated `aeturnip` provider lane with trust-ranked mirror ingestion
  - persisted driver origin metadata (`provider/channel/source`) for runtime bind
  - strict runtime bind verdict + forensic markers (`TURNIP_RUNTIME_BOUND`, source/install events)
- `0004-upscaler-adrenotools-control-plane-x11-bind.patch`
  - Adrenotools upscaler policy panel (profile/memory/DX8/vkBasalt/ScreenFX/ScaleForce)
  - runtime merge path keeps shortcut override compatibility while promoting Adrenotools policy
  - X11 launch env markers + forensic integration (`AERO_UPSCALE_*`, `UPSCALE_PROFILE_RESOLVED`)
- `0005-upscaler-dxvk-proton-fsr-x11-turnip-runtime-matrix.patch`
  - extends upscaler policy with Proton FSR hack mode/strength and runtime env export
  - adds DX wrapper matrix markers for all DirectX paths (`AERO_DX_DIRECT_MAP`, DXVK/VKD3D/DDRAW selected versions)
  - forces DX8->d8vk route when policy demands it, without dropping older DXVK version choices in config UI
- `0006-upscaler-x11-turnip-dx-all-directs-memory-policy.patch`
  - expands DX route matrix to per-DirectX contracts (`dx1..dx12`) with explicit route markers
  - adds memory-policy runtime application (`aggressive|balanced|lowmem|auto`) for X11+Turnip launch path
  - extends upscaler policy surface with additional vkBasalt effects (NIS/FSR) and richer pipeline summary (ScreenFX/ScaleForce/Proton FSR)
- `0007-upscaler-module-forensics-dx8assist-contract.patch`
  - adds per-module upscaler forensic trace events (`UPSCALE_MODULE_APPLIED` / `UPSCALE_MODULE_SKIPPED`) with reasoned state
  - tightens DX8 assist contract so `shortcut_only` activates only under shortcut override
  - exports explicit DX8 assist request/effective markers and selected D8VK version for X11+Turnip runtime diagnostics
- `0008-upscaler-dx-policy-order-and-artifact-sources.patch`
  - adds requested vs effective DX stack markers (`DXVK/VKD3D/DDraw`) to preserve full selection provenance
  - enforces deterministic DX policy order marker (`ddraw->dx8assist->dxvk->vkd3d`) with stack/reason telemetry
  - logs wrapper artifact sources (`profile|asset|system`) via `DX_WRAPPER_ARTIFACTS_APPLIED` for audit-safe runtime debugging
- `0009-launch-graphics-packet-dx-upscaler-x11-turnip-bundle.patch`
  - builds a deterministic launch graphics packet (`AERO_LAUNCH_GRAPHICS_PACKET*`) covering X11 stack, Turnip bind verdict, DX requested/effective map, and upscaler modules
  - expands DX route contracts to explicit requested/effective markers for each DirectX lane (`dx1..dx12`) plus effective D8VK version
  - propagates the packet into launcher submit for end-to-end forensic correlation (`LAUNCH_GRAPHICS_PACKET_READY`, `LAUNCH_EXEC_SUBMIT`)
- `0010-dxvk-capability-envelope-proton-fsr-gate-upscaler-matrix.patch`
  - adds DXVK capability envelope (`AERO_DXVK_CAPS`) with version-aware flags (`dx8_native`, `nvapi`) and NVAPI requested/effective telemetry
  - adds ARM64EC-aware NVAPI capability gates (`AERO_DXVK_NVAPI_ARCH_*`) so unsupported paths fail closed without hiding DXVK usage
  - gates Proton FSR hack by effective DX policy stack (`dxvk_stack`) to avoid invalid apply on non-DXVK paths
  - exports unified upscaler runtime matrix and forwards it to launcher submit forensic payload
  - exports runtime flavor/distribution/layout markers (`AERO_RUNTIME_FLAVOR`, `AERO_RUNTIME_DISTRIBUTION=ae.solator`, `AERO_UPSCALE_LAYOUT_*`) for Wine/Proton parity diagnostics
  - emits reproducible runtime library conflict snapshots (`AERO_LIBRARY_CONFLICT_*`, `RUNTIME_LIBRARY_CONFLICT_*`) to surface loader/layout conflicts with deterministic SHA fingerprints
  - emits strict runtime subsystem logging envelope (`AERO_RUNTIME_SUBSYSTEMS*`, `AERO_LIBRARY_COMPONENT_STREAM*`, `AERO_RUNTIME_LOGGING_*`) for X11/Turnip/DXVK/VKD3D/FEX/Box/loader coverage with conflict-grade forensic events

Historical incremental patches (`0001`..`0064`) were folded into `0001` after
equivalence checks (`EQUIV_DIFFS 0`). During active patch-base work, targeted
`0002+` slices are allowed and later folded back.

## Patch-base rule

- Mainline stays consolidated by default (`0001`).
- New work can land as `0002+` slices when isolated review/debug windows are
  needed.
- Once a slice is stable, fold it back into
  `0001-mainline-full-stack-consolidated.patch` and restore the one-patch
  baseline.

## Phase map

`ci/winlator/patch-batch-plan.tsv` maps phases to active patch windows (`0001`
and optional `0002+` slices) so batch tooling stays deterministic during patch
base expansion.

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
bash ci/winlator/validate-patch-sequence.sh
bash ci/winlator/run-reflective-audits.sh
bash ci/winlator/check-patch-stack.sh /path/to/upstream/winlator/checkout
```

This creates a clean temporary clone, applies the full stack, and reports file
overlaps touched by multiple patches.

For Winlator CI mainline, keep `WINLATOR_PATCH_PREFLIGHT=1` so the same
apply-check runs before Gradle. This turns patch drift into an early patch-stack
failure instead of a late APK build failure.

`ci/winlator/apply-repo-patches.sh` also contains a narrow reject-heal path for
the contents-branding block inside `0001-mainline-full-stack-consolidated.patch`.
It only applies when upstream drifts in
`app/src/main/res/values/strings.xml`; do not generalize this pattern without
adding an explicit bounded self-heal condition.

## Fast local patch-base flow

When the goal is to keep moving through the patch base instead of running the
full audit loop every time, use the lighter batch runner:

```bash
bash ci/winlator/check-patch-batches.sh /path/to/upstream/winlator/checkout
```

Useful modes:

- `WINLATOR_PATCH_BATCH_SIZE=5` - apply in blocks of 5 patches (default)
- `WINLATOR_PATCH_BATCH_SIZE=7` - apply in blocks of 7 patches
- `WINLATOR_PATCH_BATCH_MODE=single` - apply strictly one patch at a time
- `WINLATOR_PATCH_BATCH_PROFILE=standard|wide|single` - convenience aliases for 5, 7 or 1 patch windows
- `WINLATOR_PATCH_BATCH_FIRST=1 WINLATOR_PATCH_BATCH_LAST=1` - focus only the
  current consolidated mainline window

`ci/winlator/apply-repo-patches.sh` supports the same selective window via
`WINLATOR_PATCH_FROM=NNNN` and `WINLATOR_PATCH_TO=NNNN`.

The heavier full audit can also be scoped to a contiguous window:

```bash
WINLATOR_PATCH_FROM=0001 WINLATOR_PATCH_TO=0001 \
  bash ci/winlator/check-patch-stack.sh /path/to/upstream/winlator/checkout

WINLATOR_PATCH_PHASE=runtime_policy \
  bash ci/winlator/check-patch-stack.sh /path/to/upstream/winlator/checkout
```

For multi-window patch-base work, use the phase runner:

```bash
bash ci/winlator/run-patch-base-cycle.sh /path/to/upstream/winlator/checkout
WINLATOR_PATCH_BASE_PROFILE=wide bash ci/winlator/run-patch-base-cycle.sh /path/to/upstream/winlator/checkout
WINLATOR_PATCH_BASE_PHASE=runtime_policy bash ci/winlator/run-patch-base-cycle.sh /path/to/upstream/winlator/checkout
```

To inspect the exact local 5/7/1 windows before running anything:

```bash
bash ci/winlator/list-patch-batches.sh
WINLATOR_PATCH_BATCH_PROFILE=wide bash ci/winlator/list-patch-batches.sh
WINLATOR_PATCH_BATCH_FIRST=1 WINLATOR_PATCH_BATCH_LAST=1 bash ci/winlator/list-patch-batches.sh
WINLATOR_PATCH_BATCH_PHASE=runtime_policy bash ci/winlator/list-patch-batches.sh
```

To inspect the named phases themselves:

```bash
bash ci/winlator/list-patch-phases.sh
bash ci/winlator/resolve-patch-phase.sh runtime_policy
```

To reserve the next patch number safely:

```bash
bash ci/winlator/next-patch-number.sh
bash ci/winlator/next-patch-number.sh ci/winlator/patches my-new-patch-slug
```

To create a temporary `0002+` slice patch from a modified Winlator source tree
relative to the current consolidated base:

```bash
bash ci/winlator/create-slice-patch.sh /path/to/upstream/winlator/checkout my-slice
```

To step through the next local batch window deterministically:

```bash
bash ci/winlator/next-patch-batch.sh
WINLATOR_PATCH_BATCH_CURSOR=1 bash ci/winlator/next-patch-batch.sh
WINLATOR_PATCH_BATCH_PHASE=runtime_policy bash ci/winlator/next-patch-batch.sh
```

## Ae.solator asset overlay import

To import a `res/*` overlay zip (safezone/allskins pack), generate a slice, and
fold it back into consolidated mainline:

```bash
bash ci/winlator/import-aesolator-assets.sh \
  "/path/to/res_custom_AE_SOLATOR_mipmap_safezone_allskins.zip" \
  "/path/to/winlator-src-git"
```

Useful modes:

- `WINLATOR_ASSET_IMPORT_MODE=slice` - keep a temporary `0002-...` review slice
- `WINLATOR_ASSET_IMPORT_MODE=fold` - default, folds back into `0001` baseline
- `WINLATOR_ASSET_VALIDATE_ONLY=1` - inspect zip metadata without mutating source

## Folding slices back into mainline

When temporary slice patches (`0002+`) are done, fold them back into the
single-patch base:

```bash
bash ci/winlator/fold-into-mainline.sh /path/to/upstream/winlator/checkout
```

By default it drops folded `0002+` patch files and keeps only
`0001-mainline-full-stack-consolidated.patch`.
