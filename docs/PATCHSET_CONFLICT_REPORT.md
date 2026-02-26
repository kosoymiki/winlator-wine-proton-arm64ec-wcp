# GameNative Patchset Conflict Audit

Generated: `2026-02-26T16:14:01Z`

## Scope

- Manifest entries: `55`
- Unique owned source files: `57`
- Ownership contract: manifest + `apply-android-patchset.sh` is the single source of truth

## Action Distribution

### wine

- `apply`: 17
- `backport_include_winternl_fex`: 1
- `backport_wineboot_xstate`: 1
- `skip`: 20
- `verify`: 16

### protonge

- `apply`: 27
- `backport_protonge_hodll`: 1
- `backport_protonge_unix_server`: 1
- `backport_protonge_winex11`: 1
- `skip`: 7
- `verify`: 18

## Required Mapping Sanity

- No required/action mismatch detected in manifest.

## Potential Ownership Overlaps

- No overlapping ownership references detected outside allowed files.

## Next Actions

- Keep patch ownership centralized in `ci/gamenative/apply-android-patchset.sh`.
- Use workflow input `gn_patchset_enable` for full vs normalize-only operation.
- If overlap appears, remove ad-hoc patching from per-package scripts instead of duplicating fixes.

