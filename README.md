<p align="center">
  <img src="docs/assets/winlator-cmod-aeroso-logo.png" alt="Winlator CMOD Aero.so" width="680">
</p>

# Winlator CMOD Aero.so (ARM64EC WCP Toolkit)

`Winlator CMOD Aero.so` — наш форк Winlator (через upstream `Winlator-Ludashi`) с фокусом на `ARM64EC + FEXCore`, расширенную диагностику, аккуратную работу `Contents` и сборку/дистрибуцию WCP-пакетов.

## Что находится в репозитории

- WCP runtime-пакеты:
  - `wine-11-arm64ec.wcp`
  - `proton-ge10-arm64ec.wcp`
  - `protonwine10-gamenative-arm64ec.wcp`
- APK форка Winlator:
  - `by.aero.so.benchmark` (debug/release artifacts через CI)
- CI-инфраструктура:
  - сборка WCP-пакетов и Winlator APK,
  - публикация rolling/stable релизов,
  - reflective/forensic tooling и диагностические артефакты.

## Почему package ID заканчивается на `.benchmark`

APK использует package ID `by.aero.so.benchmark` **намеренно**.
Это не опечатка: на части устройств/OEM game-mode профилировщиков имя пакета в стиле benchmark-приложений может влиять на поведение режимов производительности.

## Что меняет этот форк

- ARM64EC/FEX-ориентированная логика runtime/launcher
- `Contents` для `Wine/Proton` из релизов **этого** репозитория
- разделение каналов `stable / beta / nightly`
- улучшенный `Turnip / Adrenotools` (выбор версий: latest + history)
- forensic/diagnostics слой (parser hardening, launch trace, JSONL logs)
- ребрендинг `Winlator CMOD Aero.so`

## Winlator patch stack (порядок применения)

1. `0001-winlator-arm64ec-runtime-and-fex.patch` — ARM64EC/FEX/runtime fixes
2. `0002-debug-no-embedded-runtime.patch` — режим APK без обязательных embedded runtime
3. `0003-wcphub-beta-turnip.patch` — базовые правки `Contents`/Turnip/beta-nightly
4. `0004-theme-darkgreen-daynight.patch` — тема/палитра
5. `0005-aeroso-turnip-nightly-logs-branding-cleanup.patch` — Aero.so branding/logging/UI cleanup
6. `0006-forensics-diagnostics-contents-turnip-picker-and-repo-contents.patch` — forensic + diagnostics + repo-backed contents + Turnip picker
7. `0007-aeroso-version-0.2b.patch` — версия Winlator `0.2b`

## Contents / Content Packages

- Источник списка пакетов: `contents/contents.json`
- Источник загрузки `Wine/Proton`: GitHub Releases этого репозитория
- Каналы:
  - `stable` → `wcp-v0.2b`
  - `nightly` → `wcp-latest`
- В UI Winlator тип отображается как `Wine/Proton` (внутренний тип совместимости остаётся `Wine`)

См. также:
- `docs/CONTENT_PACKAGES_ARCHITECTURE.md`
- `docs/CONTENTS_QA_CHECKLIST.md`

## Releases (0.2b line)

- **Winlator app**:
  - rolling prerelease: `winlator-latest`
  - stable: `v0.2b`
- **WCP bundle** (`wine-11`, `proton-ge10`, `protonwine10-gamenative`):
  - rolling prerelease: `wcp-latest`
  - stable: `wcp-v0.2b`

## Основные workflows

- `ci-arm64ec-wine.yml` — сборка `wine-11-arm64ec.wcp`
- `ci-proton-ge10-wcp.yml` — сборка `proton-ge10-arm64ec.wcp`
- `ci-protonwine10-wcp.yml` — сборка `protonwine10-gamenative-arm64ec.wcp`
- `ci-winlator.yml` — сборка Winlator APK на основе upstream `winlator_bionic`

## Быстрый старт (локальная сборка)

### WCP пакеты

```bash
bash ci/ci-build.sh
bash ci/proton-ge10/ci-build-proton-ge10-wcp.sh
bash ci/protonwine10/ci-build-protonwine10-wcp.sh
```

### Winlator APK

```bash
bash ci/winlator/ci-build-winlator-ludashi.sh
```

По умолчанию APK-артефакт именуется в стиле `by.aero.so.benchmark-debug-<upstream_sha>.apk`.

## Структура репозитория

- `ci/` — pipeline-скрипты сборки/publish/maintenance
- `ci/lib/` — общие WCP/runtime helper-функции
- `ci/winlator/patches/` — patch stack форка Winlator
- `.github/workflows/` — GitHub Actions entrypoints
- `contents/` — repo-backed index для Winlator `Contents`
- `docs/` — архитектура, QA, reflective/forensic заметки
- `work/`, `out/` — локальные рабочие/выходные директории (игнорируются)

## Техническая диагностика

- forensic/reflective журнал реализации: `docs/AEROSO_IMPLEMENTATION_REFLECTIVE_LOG.md`
- интеграция форка Winlator: `docs/winlator-fork-integration.md`
- локальные regression helpers:
  - `ci/winlator/forensic-regression-local.sh`
  - `ci/winlator/forensic-adb-matrix.sh` (ADB запуск — отдельно, после фиксов)

## Правила сопровождения (практика)

- Изменения Winlator вносятся через patch stack (`ci/winlator/patches/*`)
- Перед публикацией проверять применимость патчей на чистом `winlator_bionic`
- Для `Contents`/WCP обязательно валидировать `contents/contents.json`
- Rolling и stable релизы поддерживаются отдельно (`*-latest` и `v0.2b` / `wcp-v0.2b`)

## Credits and Thanks

- **Original Winlator** — [brunodev85](https://github.com/brunodev85/winlator)
- **Winlator Bionic** — [Pipetto-crypto](https://github.com/Pipetto-crypto/winlator)
- **Winlator Ludashi / upstream base for this fork** — [StevenMXZ](https://github.com/StevenMXZ)
- **Ludashi backup** — [StevenMX-backup](https://github.com/StevenMX-backup/Ludashi-Backup)
- **Winlator (coffincolors fork)** — [coffincolors](https://github.com/coffincolors/winlator)
- **Box86/Box64** — [ptitSeb](https://github.com/ptitSeb)
- **FEX-Emu** — [FEX-Emu](https://github.com/FEX-Emu/FEX)
- **Mesa / Turnip / Zink / VirGL** — [mesa3d.org](https://www.mesa3d.org)
- **Wine** — [winehq.org](https://www.winehq.org/)
- **DXVK** — [doitsujin/dxvk](https://github.com/doitsujin/dxvk)
- **VKD3D** — [winehq GitLab](https://gitlab.winehq.org/wine/vkd3d)
- **D8VK** — [AlpyneDreams/d8vk](https://github.com/AlpyneDreams/d8vk)
- **CNC DDraw** — [FunkyFr3sh/cnc-ddraw](https://github.com/FunkyFr3sh/cnc-ddraw)
- **PRoot** — [proot-me.github.io](https://proot-me.github.io)
- **Ubuntu RootFs (Bionic Beaver)** — [releases.ubuntu.com/bionic](https://releases.ubuntu.com/bionic/)

Отдельная благодарность Ludashi-ветке за базу, графику README и практические идеи по package naming / benchmark-режимам.
