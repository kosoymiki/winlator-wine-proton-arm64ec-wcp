# Proton 10 ARM64EC WCP Pipeline

Этот pipeline собирает отдельный WCP артефакт `proton-10-arm64ec.wcp` для Winlator:

1. База `ValveSoftware/wine` на pinned commit `986bda11d3e569813ec0f86e56ef94d7c384da04`.
2. Применение ARM64EC серии из `AndreRH/wine:arm64ec` через `git cherry-pick -x`.
3. Применение Proton GE patch-system (`protonprep-valve-staging.sh`) на подготовленное дерево.
4. Сборка Wine + упаковка WCP + smoke-check.

## Ключевые env vars

- `LLVM_MINGW_TAG` (default `20260210`)
- `WCP_COMPRESS` (`xz` или `zst`, default `xz`)
- `PROTON_GE_REF` (default `GE-Proton10-32`)
- `TARGET_HOST` (default `aarch64-linux-gnu`)
- `WCP_NAME` (default `proton-10-arm64ec`)

## Локальный запуск

```bash
LLVM_MINGW_TAG=20260210 \
WCP_COMPRESS=xz \
PROTON_GE_REF=GE-Proton10-32 \
TARGET_HOST=aarch64-linux-gnu \
bash ci/proton10/ci-build-proton10-wcp.sh
```

## Артефакты

- `out/proton-10-arm64ec.wcp`
- `out/SHA256SUMS`
- `out/patchlog.txt`
- `docs/ARM64EC_PATCH_REVIEW.md`
- `out/logs/**`
