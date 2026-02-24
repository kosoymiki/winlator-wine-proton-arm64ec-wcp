# Runtime Library Patching Protocol (Reflexive)

This protocol defines how we update/patch the glibc runtime bundle (`wcp-glibc-runtime`) without losing causality.

## Scope

Applies to:
- `glibc` loader/runtime (`ld-linux-aarch64.so.1`, `libc.so.6`)
- adjacent bundled runtime libs:
  - `libstdc++.so.6`
  - `libgcc_s.so.1`
  - `libz.so.1`
  - `libnss_*`
  - `libresolv.so.2`
  - `libutil.so.1`
  - `libnsl.so.1`
  - `libSDL2-2.0.so.0` (if bundled)

## Rules

1. **One variable at a time**
   - First compare `host` vs `pinned-source` glibc runtime.
   - Do not patch glibc source and change wrapper logic in the same cycle.

2. **Bundle-level reasoning**
   - Treat glibc + adjacent libs as one runtime bundle.
   - Record provenance and version markers for the whole bundle.

3. **Patch through explicit hooks**
   - Use `WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR` and/or `WCP_GLIBC_RUNTIME_PATCH_SCRIPT`.
   - Never patch silently after packaging.

4. **Forensic-first validation**
   - Compare the same device, same container, same driver, same ScaleForce settings.
   - Require `RUNTIME_WINE_WRAPPER_SELECTED`, `RUNTIME_PRE_EXEC_STAGE`, `LAUNCH_EXEC_*`, `SESSION_EXIT_*`.

5. **Lock before enforce**
   - Start with runtime lock audit (`WCP_RUNTIME_BUNDLE_ENFORCE_LOCK=0`).
   - Move to enforce mode only after pinned bundle fingerprints are stable.

## Reflexive workflow per library patch cycle

### Before
- State the exact symptom/signature (`exit_status`, `signal`, missing runtime logs, etc.).
- State the single intended variable change (e.g. `glibc 2.39 -> 2.43`).
- Freeze unrelated layers (launcher/UI/contents/adrenotools).

### During
- Build all three WCPs with the same runtime bundle policy:
  - `wine`
  - `proton-ge`
  - `protonwine-gamenative`
- Capture WCP forensics:
  - `glibc-runtime-libs.tsv`
  - `glibc-runtime-version-markers.tsv`
  - `manifest.json`
- Run device ADB-only forensic scenarios on the same containers.

### After
- Classify differences:
  - `causal`
  - `supporting`
  - `noise`
- If signature is unchanged, do not stack more random env workarounds.
- Either:
  - patch glibc source minimally (with proof), or
  - move to next library line (`FEX`, `Box64`, Vulkan headers) as separate cycle.

## Current target lock

- Lock ID: `glibc-2.43-bundle-v1`
- Default WCP builder mode in repo: **`pinned-source` target `glibc 2.43`**
- Lock mode in repo defaults to: **audit** (auto-enforced for `pinned-source` during WCP validation)
- Enforce mode should be enabled only for pinned-source runtime bundles after fingerprinting.
