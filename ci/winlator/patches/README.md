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
- `0025-0030` - upscale transfer (control plane -> guardrails -> execution contract -> container UI)

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
