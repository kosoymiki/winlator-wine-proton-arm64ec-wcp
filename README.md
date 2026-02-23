# winlator-wine-proton-arm64ec-wcp

Репозиторий собирает ARM64EC-стек для Winlator и публикует артефакты в GitHub Releases.

## Что находится в этом репозитории

1. WCP runtime-пакеты:
- `wine-11-arm64ec.wcp`
- `proton-ge10-arm64ec.wcp`
- `protonwine10-gamenative-arm64ec.wcp`

2. APK форк Winlator Ludashi:
- `by.aero.so-benchmark-debug-<upstream_sha>.apk`
- Публикуется в релиз `winlator-latest`

3. CI-инфраструктура:
- сборка runtime-пакетов,
- сборка Winlator APK,
- публикация артефактов и checksum-файлов,
- проверка upstream-изменений и reflective-анализ.

## Цели и ограничения

- Цель: стабильная поставка ARM64EC runtime + совместимый Winlator APK.
- Сборки приоритетно проверяются на корректность слоёв Wine и упаковки WCP.
- Для Winlator форка применяются патчи из `ci/winlator/patches`.

## Структура репозитория

- `.github/workflows/`
  - CI-пайплайны сборки и публикации.
- `ci/lib/`
  - общие shell-библиотеки (toolchain/runtime/WCP-помощники).
- `ci/winlator/`
  - скрипты клонирования upstream Winlator, применения патчей, сборки APK.
- `ci/winlator/patches/`
  - патчи форка Winlator.
- `ci/proton-ge10/`, `ci/protonwine10/`, `ci/`
  - сборка соответствующих runtime-пакетов.
- `docs/`
  - технические заметки, debug-инструкции, отчёты.

## Патчи Winlator (важно)

Патчи применяются строго по порядку:

1. `0001-winlator-arm64ec-runtime-and-fex.patch`
- ARM64EC/FEX интеграция и runtime-правки.

2. `0002-debug-no-embedded-runtime.patch`
- режим сборки APK без вшитых runtime.

3. `0003-wcphub-beta-turnip.patch`
- улучшенная работа `ContentsFragment`:
  - корректная загрузка remote-профилей,
  - динамический список типов контента,
  - отображение контент-пакетов по факту доступности,
  - beta/nightly toggle,
  - безопасная установка загруженных WCP.
- улучшенная работа `AdrenotoolsFragment`:
  - интерактивный выбор Turnip-драйвера из GitHub Releases,
  - выбор конкретного zip-ассета,
  - более устойчивые проверки и обработка ошибок.
- исправленные layout-позиции кнопок (без “плавающего” поведения на узких экранах).

4. `0004-theme-darkgreen-daynight.patch`
- выравнивание светлой/тёмной палитры,
- единая типографика (`sans-serif`) в теме,
- курсивный акцент для элементов управления/заголовков.

## Основные workflow

- `ci-arm64ec-wine.yml`
  - сборка `wine-11-arm64ec.wcp`
- `ci-proton-ge10-wcp.yml`
  - сборка `proton-ge10-arm64ec.wcp`
- `ci-protonwine10-wcp.yml`
  - сборка `protonwine10-gamenative-arm64ec.wcp`
- `ci-winlator.yml`
  - сборка Winlator APK (ветка upstream `winlator_bionic`)

## Релизы

- `wcp-latest`
  - актуальные `.wcp` + checksum/log assets.
- `winlator-latest`
  - актуальный APK + checksum + reflective analysis.

## Локальный запуск

Примеры:

```bash
# Wine 11 ARM64EC
bash ci/ci-build.sh
```

```bash
# Proton GE10 ARM64EC
bash ci/proton-ge10/ci-build-proton-ge10-wcp.sh
```

```bash
# ProtonWine10 GameNative ARM64EC
bash ci/protonwine10/ci-build-protonwine10-wcp.sh
```

```bash
# Winlator APK
bash ci/winlator/ci-build-winlator-ludashi.sh
```

## Техническая диагностика

- Зависание контейнера Winlator:
  - `docs/winlator-container-hang-debug.md`
- Android-support review pipeline:
  - `docs/PROTONWINE_ANDROID_SUPPORT_REVIEW.md`
- Интеграция форка Winlator:
  - `docs/winlator-fork-integration.md`

## Правила сопровождения

- Перед изменением логики форка Winlator сначала проверять последний failed workflow лог.
- Любое исправление в патчах обязательно перепроверять на чистом upstream checkout:
  - `ci/winlator/apply-repo-patches.sh`
- После фикса: commit -> push `main` -> запуск workflow -> проверка логов.

## Текущее состояние очистки

- Лишние ветки: отсутствуют (удалённая ветка только `main`).
- Лишние релизы: удалены устаревшие ассеты `wine-11.1-*` из `wcp-latest`.
