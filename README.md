# wine_11.1wcp

Скрипты в репозитории автоматизируют сборку Wine 11.1 (ветка `arm64ec`) в формате WCP для Winlator.

## Что реализовано

- Двухэтапная сборка Wine:
  - `build-tools`: нативные host-утилиты (`winebuild`, `widl`, `wrc` и т.д.).
  - `build-arm64ec`: кросс-сборка с `--enable-archs=arm64ec,aarch64,i386`.
- Поддержка toolchain-комбинации:
  - `llvm-mingw` (CRT/headers для MinGW/ARM64EC);
  - `LLVM 22.1.0-rc3` (clang/lld/llvm-*).
- Формирование WCP-структуры (`bin`, `lib`, `share`, `info`) и слоя `winetools`:
  - `bin/winetools` (list/run/info);
  - `share/winetools/manifest.txt`;
  - `share/winetools/linking-report.txt`.
- Совместимость с новым WoW64-подходом Wine 11.1:
  - основной бинарник `bin/wine`;
  - при необходимости создаётся `bin/wine64 -> wine`.
- Упаковка `prefixPack.txz` и `profile.json` в итоговый `.wcp` при наличии файлов.

## Локальная сборка

```bash
./build.sh
```

Ключевые переменные окружения:

- `WCP_NAME` (по умолчанию `wine-11.1-arm64ec`)
- `WCP_OUTPUT_DIR` (по умолчанию `./dist`)
- `WINE_SRC_DIR`, `WINE_GIT_REF`
- `PREFIX_PACK_PATH`, `PROFILE_PATH`
- `SKIP_FEX_BUILD` (сейчас FEX-шаг отключён по умолчанию; интеграция внешних DLL возможна отдельным этапом)

## GitHub Actions

Workflow: `.github/workflows/ci-arm64ec-wine.yml`

Сценарий CI (`scripts/ci-build.sh`):

1. Ставит зависимости на `ubuntu-24.04`.
2. Запускает `./build.sh`.
3. Публикует `dist/*.wcp` как артефакт.
