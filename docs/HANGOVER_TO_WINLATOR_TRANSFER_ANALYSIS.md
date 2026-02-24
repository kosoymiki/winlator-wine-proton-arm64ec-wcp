# Hangover to Winlator Transfer Analysis

## Summary

This document captures a reflective engineering analysis of `AndreRH/hangover` and maps the parts that are useful for `Winlator CMOD Aero.so`.

The core conclusion is straightforward: **Hangover helps us most as an architectural reference**, not as a direct code donor.

- Hangover optimizes by emulating only the application code path and breaking out at Wine/Unix call boundaries.
- It uses explicit emulator DLL selection (`HODLL`, `HODLL64`) and keeps emulator/runtime provenance clear.
- Our Winlator work can adopt the same discipline in runtime classification, launch decisions, and telemetry without copying desktop/Linux packaging assumptions.

## Observed Hangover Architecture (repo-level)

From the top-level repository and docs:

- `wine/`, `fex/`, `box64/` are submodules with explicit branches (`arm64ec`, `wow64`).
- `README.md` documents emulator selection via `HODLL` / `HODLL64`.
- `docs/COMPILE.md` shows separate build flows for Wine, FEX (arm64ec + wow64 PE DLLs), and Box64.
- `.packaging/*` provides reproducible distro/containerized build environments.

Practical implication: Hangover treats emulation/runtime selection as a **first-class, explicit runtime contract**, which matches the direction of our `RUNTIME_*` forensic events and runtime class markers.

## What Is Transferable to Winlator

### 1) Explicit runtime/emulator selection model

Transfer target in Winlator:

- `XServerDisplayActivity`
- `GuestProgramLauncherComponent`
- forensic events (`RUNTIME_*`, `LAUNCH_*`)

Value:

- Makes runtime selection observable and debuggable.
- Reduces “container-wide magic” by pushing decisions to launch-time context.

### 2) Runtime-class aware policy (bionic/native vs glibc-wrapped)

Transfer target in Winlator:

- launcher pre-exec normalization
- wrapper compatibility guards
- package/runtime provenance in WCP forensic manifests

Value:

- This is directly relevant to our `Wine 11` glibc-wrapped `signal_31` path.

### 3) Component provenance discipline

Transfer target in Winlator/WCP CI:

- `share/wcp-forensics/manifest.json`
- runtime bundle locks / version markers
- FEX/Box64/Wine source refs

Value:

- Supports reproducible comparisons across `Wine / GE / GameNative`.

## What Is Not Directly Transferable

### 1) Desktop/Linux packaging flow

Hangover’s `.packaging` and DEB-centric assumptions do not map directly to Android + Winlator packaging.

### 2) PE emulator DLL integration code paths (as-is)

Hangover’s PE DLL model and desktop runtime environment are useful as references, but not drop-in code for Winlator Android runtime.

### 3) Graphics stack assumptions (X11/Wayland desktop)

We can reuse policy ideas (driver suitability, fallback, explicit renderer decisions), but not desktop integration details verbatim.

## Current Winlator Alignment (already in progress)

The current patch stack already moves in a Hangover-compatible direction:

- runtime class separation (`glibc_wrapped` vs `bionic_or_native`)
- explicit forensic pre-exec telemetry
- container-owned upscale policy with runtime binding gate
- WCP runtime-bundle provenance and glibc bundle lock policy

This means the remaining work is not “adopt Hangover”; it is **tighten Winlator runtime control and telemetry using Hangover’s explicitness as the benchmark**.

## Recommended Transfer Work (next patches)

1. Strengthen launch-time runtime classification and wrapper telemetry (already started).
2. Keep upscaler/ScaleForce bound to graphics-eligible launches only (already started; continue validation).
3. Expand forensic evidence around pre-exec runtime path (`glibc`, preload guards, selected emulator/runtime).
4. Continue WCP runtime bundle locking (glibc + adjacent libs) to eliminate host drift.

## Risks / Caveats

- Over-copying Hangover concepts into Android-specific layers can create regressions if desktop assumptions leak into Winlator runtime.
- Emulator/runtime explicitness improves debugging but increases configuration complexity; telemetry and defaults must remain coherent.
- Provenance and lock enforcement must be staged to avoid breaking existing CI until pinned runtime artifacts are available.

## Reflective Conclusion

The most useful lesson from Hangover is not a specific code snippet; it is the engineering stance:

- **explicit runtime boundaries**
- **explicit emulator selection**
- **explicit provenance**
- **measurable behavior**

That aligns directly with the direction of our forensic-driven Winlator patch stack and should remain the baseline for future runtime/apscaler work.
