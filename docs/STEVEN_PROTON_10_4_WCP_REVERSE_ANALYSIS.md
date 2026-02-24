# Steven Proton 10.4 WCP Reverse Analysis

## Scope

Reference artifact analyzed:

- `/home/mikhail/Загрузки/proton-10-4-arm64ec.wcp.xz`

Goal: identify structural/runtime differences versus our WCP line (`Wine 11`, `Proton GE`, `ProtonWine GameNative`) that explain why Steven's package is a stable runtime baseline.

## Key Findings (facts)

### 1) Package shape is minimal and clean

Archive top-level contents:

- `bin/`
- `lib/`
- `share/`
- `prefixPack.txz`
- `profile.json`

No extra runtime bundle folders (e.g. no `wcp-glibc-runtime`) and no bundled FEX payloads were found in the tar listing.

### 2) Runtime class is bionic/native, not glibc-wrapped

Extracted binaries:

- `bin/wine` (ELF PIE, aarch64)
- `bin/wineserver` (ELF PIE, aarch64)
- `bin/wine-preloader` (static ELF, aarch64)

Both `bin/wine` and `bin/wineserver` request Android linker:

- interpreter: `/system/bin/linker64`

This is the critical difference from our problematic `Wine 11` path where `bin/wine` is a shell wrapper launching `wine.glibc-real` via bundled glibc runtime.

### 3) `profile.json` is intentionally simple (and `versionCode=0`)

Observed `profile.json`:

- `type: "Wine"` (parser-compatible)
- `versionName: "10.4-arm64ec"`
- `versionCode: 0`
- `description: "Proton 10-4 from gamenative repository"`
- `wine.binPath/libPath/prefixPack`

This confirms two things:

1. `versionCode=0` is valid in the wild and must be rendered gracefully (we already patched UI fallback/placeholder behavior).
2. Steven package does not depend on extra metadata fields for runtime success.

### 4) No bundled FEX in WCP (supports our new policy)

Tar listing scan did **not** show:

- `libarm64ecfex.dll`
- `libwow64fex.dll`

This matches the new repo policy introduced in CI:

- `WCP_INCLUDE_FEX_DLLS=0` (default)
- `WCP_FEX_EXPECTATION_MODE=external`

## Comparative Interpretation (causal)

### Why Steven's package is a useful baseline

- It avoids the glibc-wrapped launcher class entirely.
- It keeps WCP payload focused on Wine/Proton content.
- It relies on external runtime components (FEX, DXVK, VKD3D, drivers) rather than bundling everything into one WCP.

### What our line was missing (and is being fixed)

1. **Runtime-class separation clarity**
   - We now log `wine_runtime_class` and pre-exec state.
2. **FEX separation**
   - Implemented in CI (`external` by default).
3. **glibc runtime reproducibility**
   - Pinned `glibc 2.43` lane + staged reports + lock modes implemented.

## Reverse-analysis hashes (extracted files)

- `bin/wine`: `bbb474f5fe8d61e189203c7ad4ede0ed1d4cd06bc496a71d867936a89881a3c8`
- `bin/wineserver`: `60e2b085f0d48884e9467d1589fc31ad578b7eaf4eaed844e73d22e791d6c13a`
- `bin/wine-preloader`: `e92dc5b98eb6dfe1545c1131006b1166385ba8ae918e348723b92c2e78f95081`
- `profile.json`: `e83f267d9c083664b323123ddf1a3b93576d6ff58f5c98e2897cdc8d9fd8a1c0`

## Next engineering implication

The remaining `Wine 11` failure (`signal_31`) should be treated as a **glibc runtime-class issue**, not as a Wine payload metadata or Turnip issue. Steven 10.4 remains the bionic/native baseline for runtime behavioral comparison.

## Baseline policy extracted from this reference

Use Steven 10.4 as the structural target for default WCP builds:

- **runtime class:** `bionic/native`
- **glibc bundle:** absent by default
- **FEX payload:** external (not bundled in WCP)

This is now the intended default policy for our `Wine / Proton GE / ProtonWine GameNative`
builders, while `glibc-wrapped` remains an explicit compat/experimental mode.
