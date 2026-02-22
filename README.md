# Winlator Proton ARM64EC WCP

Recommended canonical project name: `winlator-proton-arm64ec-wcp`.

This repository builds Winlator-compatible `.wcp` packages for ARM64EC scenarios, with focus on Proton 10.

## RU: Обзор

Репозиторий содержит два направления:

1. `Wine 11.1 ARM64EC` (legacy/auxiliary flow).
2. `Proton 10 ARM64EC` (основной flow для Winlator bionic).

### Что важно сейчас

- Основная цель: стабильный `proton-10-arm64ec.wcp`.
- Для ветки Proton CI не запускает параллельную сборку Wine 11.1.
- Для Winlator bionic профиль сборки считает внешними пакетами:
  - FEX
  - DXVK
  - VKD3D
  - Vulkan-driver payload

### Структура

- `ci/proton10/ci-build-proton10-wcp.sh` — основной Proton build+pack.
- `ci/proton10/smoke-check-wcp.sh` — smoke checks готового WCP.
- `docs/PROTON10_WCP.md` — подробности по Proton pipeline.
- `docs/winlator-container-hang-debug.md` — triage зависания `Starting up...`.
- `.github/workflows/ci-proton10-wcp.yml` — CI Proton.
- `.github/workflows/release-proton10-wcp.yml` — tag release Proton.
- `.github/workflows/ci-arm64ec-wine.yml` — Wine 11.1 pipeline (legacy/support).
- `ci/maintenance/cleanup-branches.sh` — safe cleanup branch script (dry-run by default).

### Proton runtime policy (bionic)

- `WCP_TARGET_RUNTIME=winlator-bionic`
- `WCP_PRUNE_EXTERNAL_COMPONENTS=1`
- `WCP_ENABLE_SDL2_RUNTIME=1`

Pipeline:

1. Проверяет SDL2 toolchain/runtime.
2. При упаковке удаляет внешние payload-компоненты (FEX/DXVK/VKD3D/Vulkan layers).
3. Пишет diagnostics в `out/logs/runtime-report.*`.

### Локальный запуск Proton

```bash
LLVM_MINGW_TAG=20260210 \
PROTON_GE_REF=GE-Proton10-32 \
WCP_COMPRESS=xz \
WCP_TARGET_RUNTIME=winlator-bionic \
WCP_PRUNE_EXTERNAL_COMPONENTS=1 \
WCP_ENABLE_SDL2_RUNTIME=1 \
bash ci/proton10/ci-build-proton10-wcp.sh
```

### Branch cleanup (safe mode)

Dry-run:

```bash
bash ci/maintenance/cleanup-branches.sh
```

Apply local cleanup:

```bash
bash ci/maintenance/cleanup-branches.sh --apply
```

Apply local + remote cleanup (merged branches only):

```bash
bash ci/maintenance/cleanup-branches.sh --apply --remote
```

## EN: Overview

This repo builds ARM64EC WCP packages for Winlator, with Proton 10 as the primary target.

### Current direction

- Proton 10 ARM64EC is the primary production track.
- Wine 11.1 flow remains as legacy/support.
- Proton branch avoids parallel Wine 11.1 CI builds.

### Runtime packaging policy

For Winlator bionic runtime profile:

- external components are expected from host-installed WCPs:
  - FEX
  - DXVK
  - VKD3D
  - Vulkan driver/layer payloads
- package keeps Wine/Proton core runtime only.
- SDL2 linkage is treated as mandatory and validated during build.

### CI/Release behavior

- `ci-proton10-wcp.yml` builds Proton artifacts and attaches them to unified pre-release `wcp-latest`.
- `ci-arm64ec-wine.yml` also attaches artifacts to `wcp-latest` (without removing existing artifacts).
- `release-proton10-wcp.yml` produces tag-based Proton releases (`proton10-wcp-*`).

### Troubleshooting

If Winlator hangs on `Starting up...`:

1. Verify container uses ARM64EC Wine build.
2. Ensure emulator selection is `FEXCore` for ARM64EC container path.
3. Collect logs with `docs/winlator-container-hang-debug.md`.
