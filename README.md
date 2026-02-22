# winlator-wine-proton-arm64ec-wcp

Сборочная база для `.wcp` пакетов под Winlator:

- `Wine ARM64EC` пакет
- `Proton 10 ARM64EC` пакет

Репозиторий ориентирован на практическую задачу: получить **рабочие пакеты для Winlator на Android/ARM64**, где контейнеры запускают Windows-приложения через Wine/Proton с ARM64EC/WoW64-сценарием.

## 1. Что решает проект

Winlator строит runtime из нескольких слоёв:

1. Linux userspace в контейнере
2. Wine runtime (unix+windows dll/so)
3. Эмуляторный слой (`FEXCore` или `Box64`, в зависимости от пути запуска)
4. Графический/DirectX слой (часто отдельными контент-пакетами)

Этот репозиторий делает предсказуемую и воспроизводимую сборку именно слоя Wine/Proton в формате `WCP`.

## 2. Как это работает в Winlator (коротко)

### ARM64EC путь

1. Winlator запускает wine-бинарь из контейнера
2. Для WoW64 маршрута выбирается DLL-эмулятор (обычно через `HODLL`)
3. При `FEXCore` ожидается `libwow64fex.dll`
4. При `Box64` используется `wowbox64.dll`

### Почему это важно

Если контейнер с ARM64EC runtime настроен не на тот emulator path, можно получить вечный `Starting up...` без явного краша.

## 3. Структура репозитория

- `ci/ci-build.sh` — сборка Wine ARM64EC WCP
- `ci/proton10/ci-build-proton10-wcp.sh` — сборка Proton 10 ARM64EC WCP
- `ci/proton10/smoke-check-wcp.sh` — smoke-проверка готового Proton WCP
- `ci/maintenance/cleanup-branches.sh` — безопасная очистка веток
- `.github/workflows/ci-arm64ec-wine.yml` — основной CI Wine ARM64EC
- `.github/workflows/ci-proton10-wcp.yml` — CI Proton 10 ARM64EC
- `.github/workflows/release-proton10-wcp.yml` — tag-релиз Proton
- `.github/workflows/ci-wine-11.1-wcp.yml` — ручной legacy workflow Wine 11.1
- `docs/winlator-container-hang-debug.md` — runbook по зависаниям контейнера
- `docs/PROTON10_WCP.md` — детали Proton pipeline

## 4. Политика пакетов (текущая)

### Wine ARM64EC

- Сборка проверяет SDL2 runtime path (`winebus.sys.so`)
- В CI принудительно включен `WCP_ENABLE_SDL2_RUNTIME=1`

### Proton 10 ARM64EC

Профиль: `winlator-bionic`

- `WCP_TARGET_RUNTIME=winlator-bionic`
- `WCP_PRUNE_EXTERNAL_COMPONENTS=1`
- `WCP_ENABLE_SDL2_RUNTIME=1`

Это означает:

1. SDL2 в runtime обязателен
2. Host-managed payload (FEX/DXVK/VKD3D/Vulkan layers) не дублируется в WCP
3. Пишутся diagnostics:
   - `out/logs/runtime-report.txt`
   - `out/logs/runtime-report.json`
   - `out/logs/pruned-components.txt`

## 5. CI/CD и релизы

### Автоматические ветки/события

- `ci-arm64ec-wine.yml` запускается на `push main` и `pull_request`
- `ci-proton10-wcp.yml` запускается на `push feature/proton10-wcp-valvebase` и `workflow_dispatch`

### Unified prerelease

Оба пайплайна могут публиковать артефакты в `wcp-latest` (GitHub prerelease), без удаления существующих артефактов при апдейте.

### Что обычно попадает в релиз

- `wine-11.1-arm64ec.wcp`
- `proton-10-arm64ec.wcp`
- checksums/diagnostics (в зависимости от workflow)

## 6. Локальный запуск

### Wine ARM64EC

```bash
LLVM_MINGW_TAG=20260210 \
WCP_NAME=wine-11.1-arm64ec \
WCP_COMPRESS=xz \
WCP_ENABLE_SDL2_RUNTIME=1 \
bash ci/ci-build.sh
```

### Proton 10 ARM64EC

```bash
LLVM_MINGW_TAG=20260210 \
PROTON_GE_REF=GE-Proton10-32 \
WCP_COMPRESS=xz \
WCP_NAME=proton-10-arm64ec \
WCP_TARGET_RUNTIME=winlator-bionic \
WCP_PRUNE_EXTERNAL_COMPONENTS=1 \
WCP_ENABLE_SDL2_RUNTIME=1 \
bash ci/proton10/ci-build-proton10-wcp.sh
```

## 7. Контракт по переменным окружения

### Общие

- `LLVM_MINGW_TAG` — версия llvm-mingw
- `WCP_NAME` — имя итогового пакета
- `WCP_COMPRESS` — `xz`/`zstd` (или `xz`/`zst` в proton script)

### Wine

- `WINE_REF` — ref в `AndreRH/wine`
- `WCP_ENABLE_SDL2_RUNTIME` — `1`/`0`

### Proton

- `VALVE_WINE_REF`
- `PROTON_GE_REF`
- `WCP_TARGET_RUNTIME`
- `WCP_PRUNE_EXTERNAL_COMPONENTS`
- `WCP_ENABLE_SDL2_RUNTIME`

## 8. Диагностика и troubleshooting

### Симптом: контейнер висит на `Starting up...`

Порядок проверки:

1. Wine build в контейнере действительно ARM64EC
2. Для ARM64EC выбран корректный emulator path (`FEXCore` при ожидаемом FEX-маршруте)
3. Снять лог-пакет по `docs/winlator-container-hang-debug.md`
4. Сверить `HODLL` путь в логах старта

### Симптом: CI собрался, но runtime нестабилен

1. Проверить `runtime-report.txt/json`
2. Проверить что не удалены критичные runtime-файлы при pruning
3. Проверить совместимость Winlator version / container presets

## 9. Управление ветками

Скрипт безопасной очистки:

```bash
bash ci/maintenance/cleanup-branches.sh
```

Применить очистку:

```bash
bash ci/maintenance/cleanup-branches.sh --apply
```

С удалением merged remote веток:

```bash
bash ci/maintenance/cleanup-branches.sh --apply --remote
```

## 10. Практические принципы проекта

1. Воспроизводимость важнее «магии»
2. Любая сборка должна оставлять читаемую диагностику
3. Runtime-контракт с Winlator должен быть явным и проверяемым
4. Никаких скрытых зависимостей от локальной машины
