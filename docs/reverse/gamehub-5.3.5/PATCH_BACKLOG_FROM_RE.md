# Patch Backlog From GameHub 5.3.5 Reverse

Status: active backlog generated from reverse + device forensics on February 27, 2026.

## P0 - Launch survival and lifecycle integrity

### P0.1 Activity/surface survival guardrails
- **Goal:** prevent immediate `WineActivity` teardown when runtime has already spawned healthy Wine process tree.
- **Target areas (our tree):**
  - `ci/winlator/patches/0011-xserver-session-exit-no-restart-on-guest-termination.patch`
  - `ci/winlator/patches/0044-runtime-launch-precheck-and-forensic-guardrails.patch`
  - `ci/winlator/patches/0053-graphics-lib-integrity-self-heal-and-forensics.patch`
- **Implementation intent:**
  - defer destructive session close if wineserver + explorer/rpcss remain alive,
  - add explicit lifecycle forensic marker before teardown decision.
- **Acceptance:**
  - `WineActivity` remains active for >=60s in Proton and Wine scenarios under identical input.
- **Current implementation (mainline patch stack):**
  - `ci/winlator/patches/0065-xserver-guest-exit-deferral-and-x11-zero-window-recovery.patch`
  - deferred guest-exit shutdown while Wine process tree is still active, with bounded recheck loop and forensic markers.

### P0.2 X11 window-zero handshake handling
- **Goal:** treat transient `X11Controller: Windows Changed: 0 x 0` as recoverable during early activity transitions.
- **Target areas:**
  - runtime launch and X server integration patches (`0011`, `0029`, `0058`).
- **Acceptance:**
  - no immediate window destroy path solely due to first zero-window callback.
- **Current implementation (mainline patch stack):**
  - `ci/winlator/patches/0065-xserver-guest-exit-deferral-and-x11-zero-window-recovery.patch`
  - marks transient zero mapped app-window state as recoverable while Wine tree is alive (`X11_ZERO_APP_WINDOWS_RECOVERABLE`).

## P1 - Runtime diagnostics and parity contracts

### P1.1 Device forensic bundle parity with GameHub signals
- **Goal:** collect the same high-value signals that exposed failure in GameHub (`activity visibility`, `X11 window`, `BufferQueue`, process churn).
- **Target areas:**
  - `ci/winlator/forensic-adb-harvard-suite.sh`
  - new `ci/forensics/gamehub_capture.sh` (added in this cycle)
- **Acceptance:**
  - one archive per scenario with key events extraction and process timeline.

### P1.2 GN patchset parity gate
- **Goal:** ensure GN-like Android patch assumptions (notably no-XInput2 path) are explicit and validated.
- **Target areas:**
  - `ci/gamenative/apply-android-patchset.sh`
  - `ci/validation/check-gamenative-patch-contract.sh`
- **Acceptance:**
  - contract check fails on missing key GN backports; CI no longer silently drifts.

## P2 - Config translation and defaults coherence

### P2.1 Translator default consistency (Box64/FEX)
- **Goal:** avoid null/default translator state at container selection time.
- **Evidence:** GameHub log shows translator config parse/default issues around container selection.
- **Target areas:**
  - `ci/winlator/patches/0030-fexcore-upstream-config-vars-and-inline-help.patch`
  - `ci/winlator/patches/0037-fex-box-preset-switch-semantics-and-box-descriptions.patch`
  - `ci/winlator/patches/0039-box64-wowbox64-envvars-and-device-tier-presets.patch`
- **Acceptance:**
  - new and migrated containers always resolve non-null translator profile values.

### P2.2 Package identity as compatibility variable (not optimization claim)
- **Goal:** keep package-id related behavior testable and explicit.
- **Evidence:** mod package runs as `com.miHoYo.GenshinImpact`; OEM behavior may differ by identity.
- **Target areas:**
  - docs/test matrix only; no hardcoded product behavior assumptions in runtime logic.
- **Acceptance:**
  - CI/device matrix includes identity-sensitive scenario notes without coupling core runtime correctness to spoofed id.

## Rollout Order

1. P0.1 -> P0.2
2. P1.1 -> P1.2
3. P2.1 -> P2.2

## Regressions To Watch

- false-positive session survival causing zombie windows,
- delayed teardown leaking surfaces,
- increased startup latency due extra guardrails,
- contract gate overfitting to one upstream patchset version.
