# wine_11.1wcp

Сборка Wine ARM64EC в формате `.wcp` для Winlator/WOA сценария, с корректной схемой:

- Wine собирается как Unix-проект (без `--host=*-w64-*`).
- PE-часть включается через `--with-mingw=clang` и `--enable-archs=arm64ec,aarch64,i386`.
- FEX WoA DLL собираются отдельно и докладываются в `lib/wine/aarch64-windows/`:
  - `libarm64ecfex.dll`
  - `libwow64fex.dll`

## Что в репозитории

- `.github/workflows/ci-wine-11.1-wcp.yml` — GitHub Actions pipeline на `ubuntu-24.04-arm`.
- `ci/ci-build.sh` — основной build/pack-скрипт.
- `build.sh` — локальный wrapper вокруг `ci/ci-build.sh`.

## Важные требования

1. Раннер должен быть ARM64 (`aarch64`/`arm64`).
2. `prefixPack.txz` опционален: если файл лежит в корне репозитория, он будет добавлен в `.wcp`; если нет — сборка продолжится без него.
3. Для релиза Wine лучше фиксировать `WINE_REF` (tag/SHA), чтобы избежать дрейфа между snapshot-ами.

## Локальный запуск

```bash
./build.sh
```

Полезные переменные окружения:

- `WINE_REF` (по умолчанию `wine-11.1`)
- `LLVM_MINGW_TAG` (по умолчанию `20260210`)
- `WCP_NAME` (по умолчанию `Wine-11.1-arm64ec`)
- `WCP_COMPRESS` (`xz` или `zstd`, по умолчанию `zstd`)

Итоговый артефакт создаётся в `out/*.wcp`.
