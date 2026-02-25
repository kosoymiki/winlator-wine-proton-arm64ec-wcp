# Magnum Opus Bundle Mapping

Source bundle: `/home/mikhail/winlator_impl_bundle_20260225_162243.tar.gz`

## Integration Rule

- Mainline remains **bionic-native + external-only runtime**.
- Bundle content is used as behavior/reference input; no direct asset-first import.

## File-Level Mapping

| Bundle path | Intent in bundle | Target in this repo | Action |
| --- | --- | --- | --- |
| `IMPLEMENTATION_DIFF.patch` | Vulkan loader hardening + fallback telemetry | `ci/winlator/patches/0043+` | Re-split into incremental Winlator patches with CI gate checks |
| `files/app/src/main/cpp/winlator/vulkan.c` | Custom -> system Vulkan deterministic fallback | `ci/winlator/patches/0043+` + forensic checks | Port behavior only, keep external driver policy |
| `files/app/src/main/java/com/winlator/cmod/runtime/*` | Launch plan, preflight, trace events | `ci/winlator/patches/0044+` | Introduce contract-level classes via patch stack |
| `files/app/src/main/java/com/winlator/cmod/graphics/*` | Driver probe normalization and graphics profile | `ci/winlator/patches/0045+` | Merge with existing `0025/0031/0040` logic |
| `files/app/src/main/java/com/winlator/cmod/compat/*` | App-specific compatibility overrides | `ci/winlator/patches/0046+` | Port guarded rules only, with explicit telemetry |
| `files/app/src/main/java/com/winlator/cmod/contents/AdrenotoolsManager.java` | Driver probing and source orchestration | `ci/winlator/patches/0047+` | Integrate trust-score + fallback-chain |
| `files/docs/ARCHITECTURE.md` | Runtime architecture notes | `docs/UNIFIED_RUNTIME_CONTRACT.md` | Normalize into Aero.so contract docs |
| `files/docs/TEST_PLAN.md` | Functional/perf matrix | `docs/CONTENTS_QA_CHECKLIST.md` + CI scripts | Promote mandatory matrix cases |
| `files/docs/VULKAN_ADRENOTOOLS_HYBRID.md` | Hybrid probe policy | `docs/UNIFIED_RUNTIME_CONTRACT.md` | Embed as Vulkan contract section |
| `files/tools/reverse_gamehub/*` | Reverse pipeline support | `ci/research/*` + docs-only guidance | Keep as research-only; no proprietary payload import |

## Anti-Conflict Notes (GameNative vs GameHub)

1. Any imported behavior must be expressed through a shared runtime contract first.
2. GameHub-derived logic cannot bypass GameNative-derived preflight/telemetry contracts.
3. Conflicts are resolved by deterministic policy order:
   - runtime stability
   - policy compliance (external-only)
   - compatibility
   - performance
