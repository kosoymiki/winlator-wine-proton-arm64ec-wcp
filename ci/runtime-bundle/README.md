# Runtime Bundle (glibc group)

This directory tracks the reproducible runtime bundle policy for the optional
`glibc-wrapped` Wine/Proton launcher mode (`lib/wine/wcp-glibc-runtime`).

Default WCP builds now target `bionic/native` runtime class and do not bundle
`wcp-glibc-runtime` unless `WCP_RUNTIME_CLASS_TARGET=glibc-wrapped`.

## What is covered

- `glibc` loader/runtime (`ld-linux-aarch64.so.1`, `libc.so.6`)
- adjacent runtime libs copied into the same bundle (`libstdc++`, `libgcc_s`,
  `libz`, `nss/resolv`, `libutil`, `libnsl`, optional `SDL2`)

## Lock files

- `locks/glibc-2.43-bundle-v1.env` — regex-based audit/enforce expectations for
  runtime-bundle version markers.

## Source build helper

- `build-glibc-runtime-from-source.sh` — builds a reusable glibc runtime tree
  from a pinned glibc source tarball and supplements adjacent runtime libs.
  This is used automatically in `pinned-source` mode when no prebuilt runtime
  dir/archive is provided.

## CI variables (all WCP builders)

- `WCP_GLIBC_SOURCE_MODE=host|pinned-source`
- `WCP_GLIBC_RUNTIME_DIR`
- `WCP_GLIBC_RUNTIME_ARCHIVE`
- `WCP_GLIBC_RUNTIME_SUBDIR`
- `WCP_GLIBC_RUNTIME_PATCH_OVERLAY_DIR`
- `WCP_GLIBC_RUNTIME_PATCH_SCRIPT`
- `WCP_RUNTIME_BUNDLE_LOCK_ID`
- `WCP_RUNTIME_BUNDLE_LOCK_FILE`
- `WCP_RUNTIME_BUNDLE_ENFORCE_LOCK=0|1`

## Validation

WCP forensics emits:
- `share/wcp-forensics/glibc-runtime-libs.tsv`
- `share/wcp-forensics/glibc-runtime-version-markers.tsv`

Lock verification runs during `validate_wcp_tree_arm64ec()` in audit mode by
default and auto-switches to enforce mode for `pinned-source` runtime builds.

Current `glibc-wrapped` lane targets:
- `WCP_GLIBC_SOURCE_MODE=pinned-source`
- `WCP_GLIBC_VERSION=2.43`

Default builder runtime policy:
- `WCP_RUNTIME_CLASS_TARGET=bionic-native`
- `WCP_INCLUDE_FEX_DLLS=0`
- `WCP_FEX_EXPECTATION_MODE=external`
- `WCP_MAINLINE_FEX_EXTERNAL_ONLY=1` (forbid bundled FEX/Box/WoWBox runtime payload in WCP)
