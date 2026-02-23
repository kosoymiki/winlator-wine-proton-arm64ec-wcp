# winlator-wine-proton-arm64ec-wcp

Репозиторий собирает **три независимых ARM64EC WCP-пакета** для Winlator и отдельный **fork Winlator Ludashi APK** с вшитыми runtime:

1. `wine-11-arm64ec`
2. `proton-ge10-arm64ec`
3. `protonwine10-gamenative-arm64ec`
4. `winlator-ludashi-arm64ec-fork-<sha>.apk` (встроенные runtime, без ручного импорта WCP в приложении)

Все пайплайны ориентированы на Android/Winlator runtime и строго держат мульти-арх слой Wine:

- `--with-mingw=clang`
- `--enable-archs=arm64ec,aarch64,i386`

Если ARM64EC слой не собрался — сборка должна падать.

## Пакеты

| Пакет | WCP_NAME | OUT_DIR | Build Script |
|---|---|---|---|
| Wine 11 ARM64EC | `wine-11-arm64ec` | `out/wine` | `ci/ci-build.sh` |
| Proton GE10 ARM64EC | `proton-ge10-arm64ec` | `out/proton-ge10` | `ci/proton-ge10/ci-build-proton-ge10-wcp.sh` |
| ProtonWine10 GameNative ARM64EC | `protonwine10-gamenative-arm64ec` | `out/protonwine10` | `ci/protonwine10/ci-build-protonwine10-wcp.sh` |

| Android APK | Артефакт | OUT_DIR | Build Script |
|---|---|---|---|
| Winlator Ludashi Fork | `winlator-ludashi-arm64ec-fork-<upstream_sha>.apk` | `out/winlator` | `ci/winlator/ci-build-winlator-ludashi.sh` |

## Ключевые требования WCP

- Формат: `.wcp` (tar-архив)
- Компрессия: `xz` или `zst` (`WCP_COMPRESS`, default `xz`)
- В корне WCP обязательно:
  - `prefixPack.txz` (авто-скачивается из `GameNative/bionic-prefix-files` `main/prefixPack-arm64ec.txz`, можно переопределить `PREFIX_PACK_URL`)
  - `profile.json`
- Обязательные слои внутри `lib/wine/`:
  - `aarch64-unix/`
  - `aarch64-windows/`
  - `i386-windows/`
- Для Android/bionic профиля включён wrapper glibc-launcher через `ci/lib/winlator-runtime.sh`. Локальный `prefixPack.txz` в репо больше не хранится: используется релиз GameNative/bionic-prefix-files.

## Общие переменные окружения

- `LLVM_MINGW_TAG` (default `20260210`)
- `TARGET_HOST` (default `aarch64-linux-gnu`)
- `WCP_COMPRESS` (`xz`/`zst`)
- `WCP_TARGET_RUNTIME` (обычно `winlator-bionic`)

## Локальный запуск

### Wine 11 ARM64EC

```bash
LLVM_MINGW_TAG=20260210 \
TARGET_HOST=aarch64-linux-gnu \
WCP_NAME=wine-11-arm64ec \
WCP_OUTPUT_DIR=out/wine \
WCP_COMPRESS=xz \
WCP_ENABLE_SDL2_RUNTIME=1 \
bash ci/ci-build.sh
```

### Proton GE10 ARM64EC

```bash
LLVM_MINGW_TAG=20260210 \
TARGET_HOST=aarch64-linux-gnu \
PROTON_GE_REF=GE-Proton10-32 \
WCP_NAME=proton-ge10-arm64ec \
WCP_OUTPUT_DIR=out/proton-ge10 \
WCP_COMPRESS=xz \
WCP_TARGET_RUNTIME=winlator-bionic \
WCP_PRUNE_EXTERNAL_COMPONENTS=1 \
WCP_ENABLE_SDL2_RUNTIME=1 \
bash ci/proton-ge10/ci-build-proton-ge10-wcp.sh
```

### ProtonWine10 GameNative ARM64EC

```bash
LLVM_MINGW_TAG=20260210 \
TARGET_HOST=aarch64-linux-gnu \
PROTONWINE_REF=e7dbb4a10b85c1e8d505068d36249127d8b7fe79 \
ANDROID_SUPPORT_REF=47e79a66652afae9fd0e521b03736d1e6536ac5a \
WCP_NAME=protonwine10-gamenative-arm64ec \
WCP_OUTPUT_DIR=out/protonwine10 \
WCP_COMPRESS=xz \
WCP_TARGET_RUNTIME=winlator-bionic \
WCP_PRUNE_EXTERNAL_COMPONENTS=1 \
WCP_ENABLE_SDL2_RUNTIME=1 \
bash ci/protonwine10/ci-build-protonwine10-wcp.sh
```

### Winlator Ludashi Fork APK (embedded runtime)

```bash
WINLATOR_LUDASHI_REF=winlator_bionic \
RUNTIME_RELEASE_REPO=kosoymiki/winlator-wine-proton-arm64ec-wcp \
RUNTIME_RELEASE_TAG=wcp-latest \
WINLATOR_OUTPUT_DIR=out/winlator \
bash ci/winlator/ci-build-winlator-ludashi.sh
```

Скрипт:
- подтягивает актуальный upstream Winlator Ludashi,
- делает рефлексивный отчет по upstream-коммитам в `docs/WINLATOR_LUDASHI_REFLECTIVE_ANALYSIS.md`,
- применяет наши патчи (`ci/winlator/patches/*.patch`),
- преобразует наши runtime-артефакты в `app/src/main/assets/*.txz`,
- собирает APK.

## CI Workflows

- `/.github/workflows/ci-arm64ec-wine.yml`
  - Build Wine 11 ARM64EC WCP
- `/.github/workflows/ci-proton-ge10-wcp.yml`
  - Build Proton GE10 ARM64EC WCP
- `/.github/workflows/ci-protonwine10-wcp.yml`
  - Build ProtonWine10 GameNative ARM64EC WCP
- `/.github/workflows/ci-winlator.yml`
  - Build Winlator Ludashi ARM64EC fork APK (embedded runtime)
- `/.github/workflows/ci-proton10-wcp.yml`
  - Legacy compatibility entrypoint (manual)

Каждый основной workflow публикует:

- `${OUT_DIR}/${WCP_NAME}.wcp`
- `${OUT_DIR}/SHA256SUMS`
- диагностические логи (включая review/inspect для protonwine10)

и добавляет артефакт в общий релиз `wcp-latest`.

## ProtonWine10 Android-support pipeline

Скрипты:

- `ci/protonwine10/inspect-upstreams.sh`
- `ci/protonwine10/android-support-review.sh`
- `ci/protonwine10/apply-upstream-fixes.sh`
- `ci/protonwine10/apply-our-fixes.sh`

Review-файл: `docs/PROTONWINE_ANDROID_SUPPORT_REVIEW.md`

## Структура CI-библиотек

- `ci/lib/llvm-mingw.sh` — toolchain download/validate
- `ci/lib/winlator-runtime.sh` — bionic/glibc launcher wrapper + runtime libs
- `ci/lib/wcp_common.sh` — общие функции сборки/валидации/упаковки WCP

## Диагностика Winlator контейнера

Если контейнер зависает на `Starting up...`:

1. Проверить, что выбран ARM64EC пакет.
2. Для ARM64EC в Winlator выбирать `FEXCore` в emulator runner.
3. Снять логи по `docs/winlator-container-hang-debug.md`.
4. Проверить runtime-слои в WCP (`aarch64-unix`, `aarch64-windows`, `i386-windows`).

Для live-логов с устройства через adb:

```bash
bash ci/winlator/adb-logcat-winlator.sh 192.168.0.144:5555
```
