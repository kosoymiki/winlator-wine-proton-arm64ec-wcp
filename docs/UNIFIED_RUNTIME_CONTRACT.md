# Unified Runtime Contract (URC)

## Scope

This contract defines the common behavior boundary for GameNative- and GameHub-derived improvements in Ae.solator mainline.

## Mainline Invariants

1. Runtime class target is `bionic-native`.
2. Mainline runtime payload is `external-only` for FEX/Box/WoWBox/Vulkan driver assets.
3. No bundled fallback payload may be introduced by migration patches.
4. Every fallback path must emit explicit telemetry reason codes.
5. Bionic donor sources (launcher + unix modules) must be pinned by SHA256 and validated in preflight before long builds.

## Required Runtime Fields

The package/runtime metadata must expose:

- `wrapperPolicyVersion`
- `policySource`
- `runtimeClassTarget`
- `runtimeClassDetected`
- `wineLauncherAbi`
- `wineserverLauncherAbi`
- `runtimeMismatchReason`
- `fexExpectationMode`
- `bionicLauncherSourceSha256`
- `bionicUnixSourceSha256`
- `bionicLauncherSourceResolvedSha256`
- `bionicUnixSourceResolvedSha256`
- `bionicDonorPreflightDone`

## Deterministic Fallback Chain

### Vulkan path

1. Try selected custom driver (validated metadata only).
2. On probe/symbol/init failure fallback to system Vulkan.
3. If system path fails, abort with explicit init error.

### Wrapper path

1. Resolve runtime profile and translator overlays (Box64/FEX).
2. Validate bionic donor contract preflight (archive integrity + ABI class).
3. Apply runtime env atomically.
4. Abort only on fatal preflight violations; warn on non-fatal mismatch.
5. CI must run strict artifact inspection (`inspect-wcp-runtime-contract.sh --strict-bionic`) before release upload.
6. Mainline workflows enforce strict launcher runpath contract (`WCP_STRICT_RUNPATH_CONTRACT=1`) with accepted runpath `/data/data/com.termux/files/usr/lib`.
7. Optional baseline compatibility check is available with `--strict-gamenative` (exports in `ntdll.dll`, `wow64.dll`, `win32u.dll`), used when comparing against GameNative Proton 10.4 reference behavior.

### Unix ABI forensic contract

1. Every WCP must include `share/wcp-forensics/unix-module-abi.tsv`.
2. Every WCP must include `share/wcp-forensics/bionic-source-entry.json` with source-map and resolved donor hashes.
3. In strict bionic mode, `lib/wine/aarch64-unix/ntdll.so` must be `bionic-unix`.
4. In strict bionic mode, any `glibc-unix` entry in `unix-module-abi.tsv` is a hard failure.

## Translator Overlay Migration Rules

1. Runtime profile remains the common policy layer; translator overlays remain mechanism layers.
2. Legacy preset defaults (`COMPATIBILITY` / `INTERMEDIATE`) are migrated to profile-matched overlays only when runtime profile is explicit (non-`AUTO`).
3. For `AUTO`, translator defaults stay deterministic: `XAW64_BASELINE` (Box64) and `DEVICE_MID_2026` (FEX).
4. Forensics must log requested and effective translator presets on launch.

## Conflict Arbitration (GN vs GH)

When signals diverge:

1. Runtime stability and deterministic launch wins.
2. Mainline policy compliance wins over convenience shortcuts.
3. Lower-regression path with better forensic observability wins.
4. Unproven behavior remains in research lane until validated.

## External Signal Bridge

See `docs/EXTERNAL_SIGNAL_CONTRACT.md` for source arbitration across GN/GH/Termux
lanes. Runtime launcher/export paths must preserve these markers when external
signals modify effective policy:

- `WINLATOR_SIGNAL_POLICY`
- `WINLATOR_SIGNAL_SOURCES`
- `WINLATOR_SIGNAL_DECISION_HASH`
- `WINLATOR_SIGNAL_DECISION_COUNT`

Launch precheck must also export signal input envelope:

- `WINLATOR_SIGNAL_INPUT_ROUTE`
- `WINLATOR_SIGNAL_INPUT_LAUNCH_KIND`
- `WINLATOR_SIGNAL_INPUT_TARGET_EXECUTABLE`
- `WINLATOR_SIGNAL_INPUT_PRECHECK_REASON`
- `WINLATOR_SIGNAL_INPUT_PRECHECK_FALLBACK`

## Runtime Env Marker Baseline

These markers are part of the runtime observability baseline and must stay
documented and deterministic across patch-base folds:

- `WINEDEBUG`
- `MESA_VK_WSI_PRESENT_MODE`
- `TU_DEBUG`
- `WINLATOR_VK_POLICY`
- `WINLATOR_VK_EFFECTIVE`
- `vulkanPolicy=force_latest` (default policy contract for new containers)
- `AERO_TURNIP_PROVIDER`
- `AERO_TURNIP_CHANNEL`
- `AERO_TURNIP_BIND_MODE`
- `AERO_TURNIP_BIND_VERDICT`
- `AERO_UPSCALE_PROFILE`
- `AERO_UPSCALE_MEM_POLICY`
- `AERO_UPSCALE_MEM_POLICY_EFFECTIVE`
- `AERO_UPSCALE_DX8_POLICY`
- `AERO_UPSCALE_MODULES_REQUESTED`
- `AERO_UPSCALE_MODULES_ACTIVE`
- `AERO_UPSCALE_VKBASALT_REQUESTED`
- `AERO_UPSCALE_SCREENFX_REQUESTED`
- `AERO_UPSCALE_SCALEFORCE_REQUESTED`
- `AERO_UPSCALE_VKBASALT_EFFECT`
- `AERO_UPSCALE_VKBASALT_REASON`
- `AERO_UPSCALE_SCREENFX_REASON`
- `AERO_UPSCALE_SCALEFORCE_REASON`
- `AERO_UPSCALE_PROTON_FSR_MODE`
- `AERO_UPSCALE_PROTON_FSR_REQUESTED`
- `AERO_UPSCALE_PROTON_FSR_STRENGTH`
- `AERO_UPSCALE_PROTON_FSR_REASON`
- `AERO_UPSCALE_DX8_ASSIST_REASON`
- `AERO_DXVK_VERSION_SELECTED`
- `AERO_DXVK_VERSION_REQUESTED`
- `AERO_DXVK_VERSION_EFFECTIVE`
- `AERO_DXVK_CAP_DX8_NATIVE`
- `AERO_DXVK_CAP_NVAPI`
- `AERO_DXVK_CAPS`
- `AERO_DXVK_ARTIFACT_ARCH`
- `AERO_DXVK_NVAPI_CONFIG`
- `AERO_DXVK_NVAPI_REQUESTED`
- `AERO_DXVK_NVAPI_EFFECTIVE`
- `AERO_DXVK_NVAPI_REASON`
- `AERO_DXVK_NVAPI_ARCH_GATE`
- `AERO_DXVK_NVAPI_ARCH_REASON`
- `AERO_VKD3D_VERSION_SELECTED`
- `AERO_VKD3D_VERSION_REQUESTED`
- `AERO_VKD3D_VERSION_EFFECTIVE`
- `AERO_D8VK_VERSION_SELECTED`
- `AERO_D8VK_VERSION_REQUESTED`
- `AERO_D8VK_VERSION_EFFECTIVE`
- `AERO_DDRAW_WRAPPER_SELECTED`
- `AERO_DDRAW_WRAPPER_REQUESTED`
- `AERO_DX_DIRECT_MAP`
- `AERO_DX_DIRECT_MAP_REQUESTED`
- `AERO_DX_DIRECT_MAP_EXTENDED`
- `AERO_RUNTIME_DISTRIBUTION`
- `AERO_RUNTIME_FLAVOR`
- `AERO_WINE_ARCH`
- `AERO_UPSCALE_LAYOUT_MODE`
- `AERO_UPSCALE_LAYOUT_REASON`
- `AERO_UPSCALE_LAYOUT_LIBS`
- `AERO_UPSCALE_LAYOUT_NVAPI`
- `AERO_UPSCALE_LAYOUT_FSR_COMPAT`
- `AERO_UPSCALE_LAYOUT_RUNTIME_FLAVOR`
- `AERO_UPSCALE_LAYOUT_WINEDLLOVERRIDES_SHA256`
- `AERO_LIBRARY_CONFLICTS`
- `AERO_LIBRARY_CONFLICT_COUNT`
- `AERO_LIBRARY_CONFLICT_SHA256`
- `AERO_LIBRARY_REPRO_ID`
- `AERO_RUNTIME_EMULATOR`
- `AERO_RUNTIME_TRANSLATOR_CHAIN`
- `AERO_RUNTIME_HODLL`
- `AERO_RUNTIME_SUBSYSTEMS`
- `AERO_RUNTIME_SUBSYSTEMS_SHA256`
- `AERO_LIBRARY_COMPONENT_STREAM`
- `AERO_LIBRARY_COMPONENT_STREAM_SHA256`
- `AERO_LIBRARY_FASTPATH`
- `AERO_RUNTIME_LOGGING_MODE`
- `AERO_RUNTIME_LOGGING_REQUIRED`
- `AERO_RUNTIME_LOGGING_COVERAGE`
- `AERO_RUNTIME_LOGGING_COVERAGE_SHA256`
- `AERO_DX_ROUTE_DX1`
- `AERO_DX_ROUTE_DX2`
- `AERO_DX_ROUTE_DX3`
- `AERO_DX_ROUTE_DX4`
- `AERO_DX_ROUTE_DX5`
- `AERO_DX_ROUTE_DX6`
- `AERO_DX_ROUTE_DX7`
- `AERO_DX_ROUTE_DX1_7`
- `AERO_DX_ROUTE_DX8`
- `AERO_DX_ROUTE_DX9`
- `AERO_DX_ROUTE_DX10`
- `AERO_DX_ROUTE_DX11`
- `AERO_DX_ROUTE_DX12`
- `AERO_DX_ROUTE_DX1_REQUESTED`
- `AERO_DX_ROUTE_DX2_REQUESTED`
- `AERO_DX_ROUTE_DX3_REQUESTED`
- `AERO_DX_ROUTE_DX4_REQUESTED`
- `AERO_DX_ROUTE_DX5_REQUESTED`
- `AERO_DX_ROUTE_DX6_REQUESTED`
- `AERO_DX_ROUTE_DX7_REQUESTED`
- `AERO_DX_ROUTE_DX8_REQUESTED`
- `AERO_DX_ROUTE_DX9_REQUESTED`
- `AERO_DX_ROUTE_DX10_REQUESTED`
- `AERO_DX_ROUTE_DX11_REQUESTED`
- `AERO_DX_ROUTE_DX12_REQUESTED`
- `AERO_DX8_ASSIST_REQUESTED`
- `AERO_DX8_ASSIST_EFFECTIVE`
- `AERO_DX8_D8VK_EXTRACTED`
- `AERO_DX_POLICY_STACK`
- `AERO_DX_POLICY_REASON`
- `AERO_DX_POLICY_ORDER`
- `AERO_DXVK_ARTIFACT_SOURCE`
- `AERO_VKD3D_ARTIFACT_SOURCE`
- `AERO_DDRAW_ARTIFACT_SOURCE`
- `AERO_LAUNCH_GRAPHICS_PACKET`
- `AERO_LAUNCH_GRAPHICS_PACKET_SHA256`
- `AERO_UPSCALE_RUNTIME_MATRIX`

Upscaler resolution must emit:

- `UPSCALE_PROFILE_RESOLVED`
- `UPSCALE_MEMORY_POLICY_APPLIED`
- `UPSCALE_MODULE_APPLIED`
- `UPSCALE_MODULE_SKIPPED`
- `DX_WRAPPER_GRAPH_RESOLVED`
- `DX_WRAPPER_ARTIFACTS_APPLIED`
- `LAUNCH_GRAPHICS_PACKET_READY`
- `DXVK_CAPS_RESOLVED`
- `PROTON_FSR_HACK_RESOLVED`
- `UPSCALE_RUNTIME_MATRIX_READY`
- `UPSCALE_LIBRARY_LAYOUT_APPLIED`
- `RUNTIME_LIBRARY_CONFLICT_SNAPSHOT`
- `RUNTIME_LIBRARY_CONFLICT_DETECTED`
- `RUNTIME_SUBSYSTEM_SNAPSHOT`
- `RUNTIME_LOGGING_CONTRACT_SNAPSHOT`
- `RUNTIME_LIBRARY_COMPONENT_SIGNAL`
- `RUNTIME_LIBRARY_COMPONENT_CONFLICT`

## Evidence Requirement

Each accepted change must be linked in `docs/REFLECTIVE_HARVARD_LEDGER.md` with:

- hypothesis
- evidence
- counter-evidence
- decision
- verification logs/tests

## ADB Contour Requirement

When collecting device evidence (`forensic-adb-runtime-contract.sh` or
`forensic-adb-harvard-suite.sh`), runtime logging contract coverage must be
captured as:

- per-scenario:
  - `logcat-runtime-conflict-contour.txt`
  - `runtime-conflict-contour.summary.txt`
- suite-level:
  - `runtime-conflict-contour.tsv`
  - `runtime-conflict-contour.md`
  - `runtime-conflict-contour.json`
  - `runtime-conflict-contour.summary.txt`

Conflict severity gating is controlled by
`WLT_FAIL_ON_CONFLICT_SEVERITY_AT_OR_ABOVE=off|info|low|medium|high`.
