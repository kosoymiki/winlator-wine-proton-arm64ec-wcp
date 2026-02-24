# Runtime Library Actualization Analysis (Reflexive)

## Scope

This document tracks which runtime libraries in the WCP packaging pipeline should be updated, rebuilt, or patched, and why. It is focused on reproducibility and early-launch stability on Android (`Winlator` + `Wine/Proton/GE/GameNative` ARM64EC).

## Ground truth (current state)

- `wcp-glibc-runtime` is currently bundled from the **build host** via `ci/lib/winlator-runtime.sh` (`winlator_resolve_host_lib`), not from a pinned source release.
- On the current host, `glibc` is `2.39`.
- Glibc-wrapped runtimes (e.g. `Wine 11`) still show early `signal_31` (`SIGSYS`) in some device scenarios, despite wrapper mitigations:
  - `unset LD_PRELOAD`
  - `GLIBC_TUNABLES=glibc.pthread.rseq=0`

## Reflexive analysis

### 1) glibc is the highest-priority update target

**Why**
- It is the runtime class boundary for glibc-wrapped `wine`/`wineserver`.
- It is currently host-derived and therefore non-reproducible.
- The observed failure mode (`signal_31`) is consistent with seccomp-sensitive early runtime initialization paths.

**Conclusion**
- First step is a **pinned glibc source/runtime lane** (experiment with `2.43`) before considering glibc source patching.
- If `2.43` still reproduces the same signal, patching glibc may be required, but only after telemetry comparison.

### 2) glibc-adjacent libs should be treated as one bundle, not individually

These libraries are copied transitively into `wcp-glibc-runtime` and are part of the same ABI/runtime surface:
- `libstdc++.so.6`
- `libgcc_s.so.1`
- `libz.so.1`
- `libnss_files.so.2`, `libnss_dns.so.2`
- `libresolv.so.2`
- `libutil.so.1`
- `libnsl.so.1`
- `libSDL2-2.0.so.0` (when enabled)

**Why this matters**
- Updating glibc without controlling these can leave hidden host drift.
- Forensics and reproducibility require provenance for the whole runtime bundle.

**Conclusion**
- Version/provenance for these libs must be recorded in WCP forensics.
- They should be updated/rebuilt in lockstep with a pinned glibc runtime line.

### 3) SDL2 is important, but second-order for current `signal_31`

**Why**
- SDL2 is bundled into the same glibc runtime bundle path in some configurations and can affect `winebus` behavior.
- However, current failures occur before a stable guest runtime phase and are not primarily SDL2 signatures.

**Conclusion**
- Keep SDL2 in the glibc runtime inventory and validate provenance.
- Do not treat SDL2 as the first root-cause target for `signal_31`.

### 4) FEX / Box64 / WOWBox64 should be version-pinned and logged, but not mixed into glibc root-cause fix

**Why**
- They change runtime execution behavior and compatibility.
- They are external inputs with potential drift.
- But the present evidence localizes the issue earlier to glibc-wrapped launcher/runtime path.

**Conclusion**
- Add provenance rigor and update policy, but keep them as separate follow-up lines.

### 5) Vulkan headers (`vk.xml`) and `winevulkan` bootstrap are reproducibility concerns, not current root cause

**Why**
- `wcp_try_bootstrap_winevulkan()` can use host/system registry paths for `vk.xml`.
- This affects determinism of generated `winevulkan` artifacts.

**Conclusion**
- Pin Vulkan-Headers source/version in CI and record it in forensics.
- Do not mix into glibc signal_31 fix cycle.

## Decision-ready priority order

### P0 (immediate)
1. Add pinned glibc runtime lane (`host` vs `pinned-source`).
2. Add glibc runtime provenance + inventory to WCP forensics.
3. Compare device forensic logs (`host 2.39` vs `glibc 2.43`) on the same containers.

### P1 (next)
4. Align bundled runtime adjacents (`libstdc++`, `libgcc_s`, `libz`, `nss/resolv`, `SDL2`).
5. If needed, prepare minimal glibc patchset (only after proof from logs).

### P2 (separate update lines)
6. FEX provenance pin / refresh policy
7. Box64/WOWBox64 update matrix and telemetry validation
8. Vulkan-Headers pin for `winevulkan` bootstrap

## Practical rule for patching

Do not patch glibc source until the following comparison exists and is archived:
- same device
- same container(s)
- same driver
- same ScaleForce settings
- same Winlator build
- only glibc runtime line changed (`2.39 host` vs `2.43 pinned-source`)

