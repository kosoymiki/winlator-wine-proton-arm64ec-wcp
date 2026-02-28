# GameNative Patchset Conflict Audit

Generated: `2026-02-27T14:32:21Z`

## Scope

- Manifest entries: `57`
- Unique owned source files: `57`
- Ownership contract: manifest + `apply-android-patchset.sh` is the single source of truth

## Action Distribution

### wine

- `apply`: 17
- `backport_include_winternl_fex`: 1
- `backport_ntdll_spec_ntuserpfn`: 1
- `backport_wineboot_xstate`: 1
- `backport_winex11_mouse_wm_input`: 1
- `skip`: 20
- `verify`: 16

### protonge

- `apply`: 27
- `backport_ntdll_spec_ntuserpfn`: 1
- `backport_protonge_hodll`: 1
- `backport_protonge_unix_server`: 1
- `backport_protonge_winex11`: 1
- `backport_winex11_mouse_wm_input`: 1
- `skip`: 7
- `verify`: 18

## Required Mapping Sanity

- No required/action mismatch detected in manifest.

## Potential Ownership Overlaps

The files below are owned by GN patchset and are also referenced elsewhere in CI scripts:

- `dlls/winex11.drv/mouse.c` -> `ci/gamenative/selftest-normalizers.sh`
- `include/winnt.h` -> `ci/gamenative/selftest-normalizers.sh`
- `programs/winebrowser/main.c` -> `ci/gamenative/selftest-normalizers.sh`

## Next Actions

- Keep patch ownership centralized in `ci/gamenative/apply-android-patchset.sh`.
- Use workflow input `gn_patchset_enable` for full vs normalize-only operation.
- If overlap appears, remove ad-hoc patching from per-package scripts instead of duplicating fixes.

