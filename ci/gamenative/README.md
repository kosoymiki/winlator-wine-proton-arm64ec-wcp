# GameNative Android Patchset Integration

This folder stores the curated Android patchset imported from:

- `GameNative/proton-wine` commit `28c3a06ba773f6d29b9f3ed23b9297f94af4771c`

The integration model is manifest-driven:

- `patchsets/28c3a06/android/patches/` — source patch files
- `patchsets/28c3a06/manifest.tsv` — per-patch action matrix for `wine` and `proton-ge`
- `apply-android-patchset.sh` — applies/validates/backports according to the manifest

Supported per-target actions:

- `apply` — apply patch if needed
- `verify` — verify patch content is already present upstream
- `skip` — do nothing for this target
- `backport_wineboot_xstate` — targeted xstate backport
- `backport_protonge_hodll` — targeted `HODLL` override backport for wow64
- `backport_protonge_winex11` — targeted Android class hints/window integration backport
