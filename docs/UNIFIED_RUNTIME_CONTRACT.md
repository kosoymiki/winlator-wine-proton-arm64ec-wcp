# Unified Runtime Contract (URC)

## Scope

This contract defines the common behavior boundary for GameNative- and GameHub-derived improvements in Winlator CMOD Aero.so mainline.

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

## Evidence Requirement

Each accepted change must be linked in `docs/REFLECTIVE_HARVARD_LEDGER.md` with:

- hypothesis
- evidence
- counter-evidence
- decision
- verification logs/tests
