# Proton GE10 ARM64EC WCP

Сборка `proton-ge10-arm64ec.wcp` для Winlator (bionic runtime), на базе:

- Valve Wine pinned commit.
- ARM64EC cherry-pick серии.
- Proton GE patch pipeline.

## Build flow

1. `ci/proton10/arm64ec-commit-review.sh` — отбор совместимой ARM64EC серии.
2. `ci/proton10/apply-arm64ec-series.sh` — replay коммитов в рабочее дерево.
3. `protonprep-valve-staging.sh` — применение Proton GE патчей.
4. Сборка Wine (`--enable-archs=arm64ec,aarch64,i386`).
5. Формирование WCP + smoke checks + diagnostics.

## Runtime profile (важно)

Pipeline ориентирован на Winlator bionic профиль:

- FEX/DXVK/VKD3D/Vulkan-driver считаются внешними пакетами Winlator.
- В WCP остаётся ядро Wine/Proton runtime.
- SDL2 runtime проверяется как обязательный для этого профиля.

## Ключевые env vars

- `LLVM_MINGW_TAG` (default `20260210`)
- `WCP_COMPRESS` (`xz` или `zst`, default `xz`)
- `PROTON_GE_REF` (default `GE-Proton10-32`)
- `TARGET_HOST` (default `aarch64-linux-gnu`)
- `WCP_NAME` (default `proton-ge10-arm64ec`)
- `WCP_TARGET_RUNTIME` (default `winlator-bionic`)
- `WCP_PRUNE_EXTERNAL_COMPONENTS` (`1`/`0`, default `1`)
- `WCP_ENABLE_SDL2_RUNTIME` (`1`/`0`, default `1`)

## Артефакты

- `out/proton-ge10/proton-ge10-arm64ec.wcp`
- `out/proton-ge10/SHA256SUMS`
- `out/proton-ge10/patchlog.txt`
- `out/proton-ge10/logs/*`
- `docs/ARM64EC_PATCH_REVIEW.md`

## Локальный запуск

```bash
LLVM_MINGW_TAG=20260210 \
WCP_COMPRESS=xz \
PROTON_GE_REF=GE-Proton10-32 \
TARGET_HOST=aarch64-linux-gnu \
WCP_NAME=proton-ge10-arm64ec \
WCP_OUTPUT_DIR=out/proton-ge10 \
WCP_TARGET_RUNTIME=winlator-bionic \
WCP_PRUNE_EXTERNAL_COMPONENTS=1 \
WCP_ENABLE_SDL2_RUNTIME=1 \
bash ci/proton-ge10/ci-build-proton-ge10-wcp.sh
```

## Диагностика container startup

Если контейнер зависает на `Starting up...`:

1. Убедитесь, что container Wine — именно ARM64EC build.
2. Для ARM64EC выберите `FEXCore` как emulator (не `Box64`).
3. Снимите логи по гайду: `docs/winlator-container-hang-debug.md`.
