# Winlator Fork Integration

Этот pipeline собирает APK форка `Winlator CMOD Aero.so` (на базе upstream `Winlator-Ludashi`) с вшитыми ARM64EC runtime из нашего релиза (`wcp-latest`), без ручного импорта WCP в интерфейсе приложения.

## Что делает сборка

1. Клонирует upstream `StevenMXZ/Winlator-Ludashi` на pinned ref.
2. Генерирует upstream-обзор и рефлексивный отчёт:
   - `out/winlator/logs/inspect-upstream/*`
   - `docs/WINLATOR_LUDASHI_REFLECTIVE_ANALYSIS.md`
3. Применяет локальные патчи из `ci/winlator/patches/*.patch` (включая branding/logging/Turnip/nightly правки Aero.so).
4. Подготавливает встроенные runtime assets:
   - `wine-11-arm64ec.txz`
   - `proton-ge10-arm64ec.txz`
   - `protonwine10-gamenative-arm64ec.txz`
5. Собирает APK (Gradle task через `WINLATOR_GRADLE_TASK`, по умолчанию `assembleDebug`) и публикует артефакт (package ID `by.aero.so.benchmark`).

## Ключевые фиксы в патче

- Надёжный парсинг runtime identifier в `WineInfo` для имён вида `proton-ge10-arm64ec` и `protonwine10-gamenative-arm64ec`.
- Корректный выбор runner-а для ARM64EC (FEX по умолчанию).
- Расширенные `LD_LIBRARY_PATH`, `WINEDLLPATH` и `PATH` для runtime из `/opt/<runtime>`.
- Защита от падения при неполной runtime-структуре при создании контейнера.

## Workflow

- `.github/workflows/ci-winlator.yml`
- script entrypoint: `ci/winlator/ci-build-winlator-ludashi.sh`
