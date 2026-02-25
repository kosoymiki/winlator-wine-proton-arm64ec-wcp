# GameNative Android Patchset Integration

This folder stores the curated Android patchset imported from:

- `GameNative/proton-wine` commit `28c3a06ba773f6d29b9f3ed23b9297f94af4771c`
- plus follow-up deltas from:
  - `7b1c9dd7d5dbb8d82bd669cb7beb84e6ffcc1646` (winemenubuilder shortcut patch)
  - `906c4d6a54bcf219b6bd4341a981a8c23c992007` (ARM64EC test-bylaws updates)

The integration model is manifest-driven:

- `patchsets/28c3a06/android/patches/` — source patch files
- `patchsets/28c3a06/android/android_sysvshm/sys/shm.h` — Android sysvshm shim header injected into non-GameNative trees when needed
- `patchsets/28c3a06/manifest.tsv` — per-patch action matrix for `wine` and `proton-ge`
- `apply-android-patchset.sh` — applies/validates/backports according to the manifest

Supported per-target actions:

- `apply` — apply patch if needed
- `verify` — verify patch content is already present upstream
- `verify` with `WCP_GN_PATCHSET_VERIFY_AUTOFIX=1` will auto-apply clean missing patches
- `skip` — do nothing for this target
- `backport_wineboot_xstate` — targeted xstate backport
- `backport_protonge_hodll` — targeted `HODLL` override backport for wow64
- `backport_protonge_winex11` — targeted Android class hints/window integration backport
