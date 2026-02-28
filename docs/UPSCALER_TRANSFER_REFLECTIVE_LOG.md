# Upscaler Transfer Reflective Log

This log tracks the upscale transfer work from Eden/Yuzu/Citron into Winlator and
captures the reasoning for each patch-level step.

Note: the implementation was developed incrementally as `0025..0030`, then
consolidated in the patch stack to reduce maintenance overhead:

- current `0025` = historical `0025+0026+0027`
- current `0026` = historical `0028+0029+0030`

## Historical Patch `0025` - Control Plane Baseline

### Before
- Missing structured upscale control plane in Winlator runtime.
- Risk: ad-hoc env tweaks without deterministic policy or telemetry.

### During
- Added `ScaleForceProfile`, `PerfPresetResolver`, `FrameGenerationConfig`.
- Integrated only at one runtime point (`XServerDisplayActivity`) to keep blast radius small.

### After
- Established base preset resolution + SWFG env contract.
- Created stable foundation for guardrails and execution-plane work.

## Historical Patch `0026` - Graphics Suitability Guardrails

### Before
- `0025` could enable aggressive presets without validating driver suitability.
- Risk: unstable or misleading upscale behavior on weak/unsupported driver paths.

### During
- Introduced `GraphicsSuitability` and guard-aware preset downgrade logic.
- Avoided UI/schema changes to isolate runtime causality.

### After
- Runtime can downgrade presets with explicit reasons.
- Forensic events now explain *why* a preset changes.

## Historical Patch `0027` - SWFG Execution Contract Completion

### Before
- Control-plane existed but effective SWFG config lacked full normalization/conflict logging.
- Risk: silent override conflicts and inconsistent runtime env.

### During
- Normalized mode/multiplier/latency/artifact guard.
- Added guard-vs-override conflict handling and telemetry.

### After
- Effective SWFG config is deterministic and observable in logs.
- Guard actions no longer look like unexplained behavior changes.

## Historical Patch `0028` - Container Schema Bridge

### Before
- Upscale controls existed only as env overrides; no container-level source of truth.

### During
- Added normalized `upscale*` keys to container extraData.
- Bridged container/shortcut values into runtime env.

### After
- Container config now participates directly in upscale policy resolution.
- Forensic logs can attribute runtime config to container settings.

## Historical Patch `0029` - Launcher Final Normalization

### Before
- Runtime could still receive malformed/conflicting `WINLATOR_SWFG_*` values before submit.

### During
- Added final env normalization in `GuestProgramLauncherComponent`.
- Logged runtime class (`glibc_wrapped` vs `bionic_or_native`) for parity analysis.

### After
- Launch step acts as final safety gate for upscale env.
- Cross-package comparison (Wine/GE/GameNative) is easier and less noisy.

## Historical Patch `0030` - Container UI Controls

### Before
- Control plane and schema existed, but no stable UI for per-container configuration.

### During
- Added Advanced-tab UI controls and persistence for preset/SWFG options.
- Kept changes isolated from runtime logic to preserve patch auditability.

### After
- End-to-end path exists: UI -> `.container` -> runtime env -> resolver -> telemetry.
- This is the first version suitable for real ADB validation of user-facing upscale control.

## Patch Interaction Audit (historical split `0025..0030`)

### Intentional overlap zones
- `XServerDisplayActivity.java`: `0025`, `0026`, `0027`, `0028`
  - Reason: single runtime integration point for probe/suitability/preset/env bridge.
- `graphics/PerfPresetResolver.java`: `0025`, `0026`, `0027`
  - Reason: layered policy (base preset -> suitability guard -> SWFG effective config).
- `Container.java`: `0028`, `0030`
  - Reason: schema normalization and UI-backed persistence use the same extraData keys.
- `GuestProgramLauncherComponent.java`: `0029` (isolated final-gate)

### Conflict prevention rules used
- UI/schema and runtime/launcher changes are kept in separate patches.
- Final env normalization exists only in launcher (`0029`) to avoid duplicate logic spread.
- Guard decisions are logged at runtime (`0026`, `0027`) instead of hidden in UI.

## Consolidation Step (patch stack cleanup)

### Before
- Patch stack contained six upscale patches (`0025..0030`) with intentional overlap.
- This was safe for iteration, but expensive to maintain and review long-term.

### During
- Rebuilt consolidated patch artifacts from the validated export baseline:
  - `a273fc8..da1465b` -> new patch stack `0025`
  - `da1465b..2b07678` -> new patch stack `0026`
- Removed old patch files `0027..0030` from `ci/winlator/patches`.
- Kept implementation code unchanged (artifact-level consolidation only).

### After
- Patch stack is shorter and easier to review (`0025..0026` for upscale).
- Functional behavior remains identical to validated historical split patches.
- Audit tooling confirms stack applies end-to-end.

## Next Work

- `0031+`: runtime upscale validation / deeper renderer behavior parity work
- Runtime validation against:
  - `container n2` (Steven reference)
  - problematic Wine/GE/GameNative containers
- Citron/Eden source-path comparison for deeper renderer/apscaler execution behavior

## Patch `0049` - Eden Render Control Expansion

### Before
- Upscale stack controlled preset/SWFG, but lacked Eden-style render knobs in container settings.
- Missing parity keys for resolution/filter/FSR sharpness/frame pacing/vsync/anisotropy/Vulkan-call logging.

### During
- Extended container schema/UI with new structured upscale fields.
- Added env bridge aliases (`RENDERER_*`, `FRAME_PACING_MODE`, `MAX_ANISOTROPY`, `GPU_LOG_VULKAN_CALLS`) plus Winlator-prefixed contract keys.
- Added runtime render-policy resolution and launcher final normalization/telemetry for the expanded key set.

### After
- Container settings remain the single source of truth, now including Eden-aligned render controls.
- Upscale runtime/launcher path gains deterministic normalization and forensic visibility for render knobs.

## Patch `0050` - Eden Advanced Renderer Controls (backend/shaders/speed policy)

### Before
- `0049` covered core render knobs but not deeper Eden-style renderer policy controls.
- Missing structured UI/schema/runtime path for backend selection, shader-cache behavior, and speed-limit policy.

### During
- Extended container upscale UI with advanced controls: backend, async shaders, disk shader cache, use-speed-limit, speed limit, turbo speed limit, force max clock.
- Added `Container` extraData keys with normalization, legacy env migration path, and env-editor strip-list ownership.
- Bridged the new keys into runtime env aliases (`RENDERER_BACKEND`, `RENDERER_ASYNCHRONOUS_SHADERS`, `RENDERER_USE_DISK_SHADER_CACHE`, `RENDERER_USE_SPEED_LIMIT`, `RENDERER_SPEED_LIMIT`, `RENDERER_TURBO_SPEED_LIMIT`, `RENDERER_FORCE_MAX_CLOCK`) and launcher final normalization.

### After
- Container settings now own an extended Eden-compatible renderer policy surface end-to-end.
- Runtime and launcher emit forensic fields for advanced renderer policy resolution, reducing opaque behavior during crash/perf triage.

## Patch `0051` - Eden Shader/Debug Renderer Controls Expansion

### Before
- `0050` covered backend/cache/speed policy, but several Eden renderer flags were still outside structured container-owned config.
- Missing parity for shader-debug and low-level renderer toggles (`GPU_LOG_SHADER_DUMPS`, `IR3_SHADER_DEBUG`, `RENDERER_DESCRIPTOR_INDEXING`, etc.) plus `RENDERER_SLOW_SPEED_LIMIT`.

### During
- Extended `Container` extraData schema and normalizers with advanced Eden flags:
  - shader/debug telemetry toggles
  - descriptor/dynamic/reactive/provoking/sample/spirv toggles
  - legacy QCOM patching + NVDEC emulation
  - slow speed limit
- Expanded Advanced tab UI with dedicated controls for these fields.
- Bridged all keys into launcher/runtime contracts:
  - `WINLATOR_UPSCALE_*` normalized keys
  - Eden aliases (`RENDERER_*`, `GPU_LOG_SHADER_DUMPS`, etc.)
  - enriched forensic fields in `XServerDisplayActivity` and `GuestProgramLauncherComponent`.

### After
- Upscale transfer reaches broader Eden renderer parity without relying on raw env hacks.
- Container settings remain the canonical source, while launcher/runtime still normalize and mirror values for deterministic behavior and forensic analysis.

## Patch `0052` - Eden Renderer/GPU Diagnostics Control Parity

### Before
- `0051` still left a gap for several Eden renderer/GPU diagnostics controls (`RENDERER_ACCURACY`, ASTC policy tokens, GPU logging/unswizzle controls, VRAM usage mode, GPU model/time tokens, Mesa debug).
- These keys could still appear only as ad-hoc raw env values, outside container-owned schema and migration logic.

### During
- Extended container schema/UI and legacy-env migration with a structured set of renderer/GPU diagnostic controls:
  - renderer quality/policy tokens (accuracy/AA/aspect/ASTC/screen-layout/VRAM mode)
  - low-level GPU diagnostics (logging master/driver-debug/level/memory/ring-buffer)
  - unswizzle controls (enabled/chunk/stream/texture size)
  - GPU model/time + Mesa debug token fields
- Added normalization + env-editor strip ownership so these controls stay container-owned.
- Bridged normalized values in both runtime and launcher paths into:
  - `WINLATOR_UPSCALE_*` keys
  - Eden-compatible aliases (`RENDERER_*`, `GPU_*`, `MESA_DEBUG`)
  - expanded forensic submit fields.

### After
- Eden renderer/upscaler transfer reaches near-complete env-contract coverage without fallback to unmanaged raw env hacks.
- Runtime and launcher now converge on the same normalized diagnostics policy surface, improving reproducibility for crash/perf forensics.

## Patch `0027` - Container Settings Own Upscale Config (UI + migration guard)

### Before
- Upscale UI controls existed, but raw `WINLATOR_SWFG_*` / `WINLATOR_PERF_PRESET` values could still live in the generic Env Vars editor.
- This created duplicate sources of truth (container upscale UI vs manual env string) and made behavior harder to reason about.

### During
- Kept the runtime path unchanged and focused only on `ContainerDetailFragment`.
- Added legacy env fallback import for old containers (reads old `WINLATOR_*` values into upscale UI when structured `extraData` is missing).
- Stripped upscale/runtime telemetry vars from the generic env editor and from saved env string so container settings own the config path.
- Added simple UI state guard (`SWFG policy = off` disables detail controls) to reduce invalid combinations.

### After
- Container settings are the canonical UI/config source for upscale behavior.
- Legacy containers still open with sensible values (migrated from raw env at edit time).
- Generic Env Vars tab no longer silently conflicts with upscale container settings.

## Repo-Level Audit Step (post-`0030`)

### Before
- Patch stack had grown to `0001..0030`; manual reasoning alone was no longer enough.
- User requirement: keep patches conflict-free and audit interactions continuously.

### During
- Added `ci/winlator/check-patch-stack.sh` for clean-clone apply-check + overlap report.
- Added ADB upscale validation helper `ci/winlator/forensic-adb-upscale-matrix.sh`.
- Ran full apply-check on `/tmp/winlator-ludashi-src` baseline for `0001..0030`.

### After
- No apply-order conflicts found across `0001..0030` (stack applies end-to-end).
- High-overlap files confirmed and documented (`XServerDisplayActivity`, `GuestProgramLauncherComponent`, `Container*`, `Contents*`).
- Only non-fatal hygiene warning observed: cached diff whitespace warning on CRLF XML lines in `container_detail_fragment.xml` touched by `0030`.

## Harvard Slice Era (`0004..0010`) - X11/DXVK/Turnip/Upscaler Matrix

### Before
- Историческая линия `0025..0052` закрывала перенос SWFG/Eden-контролов, но не давала полного X11-first DX matrix контракта с единым packet-submit path.
- Не хватало строгой связки:
  - requested/effective DX stack для всех DirectX путей,
  - policy-order маркера для DX chain,
  - NVAPI capability + ARM64EC gate,
  - Proton FSR hack gate по фактическому DXVK stack.

### During
- В рабочем слое `0004..0010` переведена логика на модульный control plane в Adrenotools:
  - `vkbasalt` (включая FSR/NIS/CAS),
  - `screenfx`,
  - `scaleforce`,
  - `dx8 assist` policy (`auto|shortcut_only|force_d8vk`).
- Добавлены runtime/launcher инварианты:
  - `AERO_DX_DIRECT_MAP` и по-путевые requested/effective markers (`dx1..dx12`),
  - `AERO_DX_POLICY_ORDER=ddraw->dx8assist->dxvk->vkd3d`,
  - `AERO_DXVK_CAPS` + `AERO_DXVK_NVAPI_REQUESTED/EFFECTIVE`,
  - ARM64EC capability markers (`AERO_DXVK_NVAPI_ARCH_*`),
  - `AERO_UPSCALE_RUNTIME_MATRIX`,
  - `AERO_LAUNCH_GRAPHICS_PACKET*` с пробросом в `LAUNCH_EXEC_SUBMIT`.
- Усилен distro/runtime контур:
  - `AERO_RUNTIME_FLAVOR` (wine/proton family),
  - `AERO_RUNTIME_DISTRIBUTION=ae.solator`,
  - upscaler layout bridge через `WINEDLLOVERRIDES` с forensic-метками layout state.

### After
- Апскейлер-стек работает как часть единого X11-first графического пакета запуска, а не как набор разрозненных env-флагов.
- Wine/Proton launch path получает одинаковую детерминированную схему:
  - profile -> module state -> DX policy -> capability gate -> launch packet.
- Регрессионный риск снижен за счет контрактных проверок:
  - `validate-patch-sequence`,
  - `check-patch-stack (0001..0010)`,
  - `run-reflective-audits`,
  - `check-urc-mainline-policy`,
  - `run-final-stage-gates` (strict/no-fetch paths).
