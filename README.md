<p align="center">
  <img src="docs/assets/winlator-cmod-aeroso-logo.png" alt="Winlator CMOD Aero.so" width="680">
</p>

# Winlator CMOD Aero.so

**RU:** Витринный форк Winlator/Ludashi для ARM64EC + FEXCore + WCP-потока, с форензикой и воспроизводимым CI.

**EN:** Showcase Winlator/Ludashi fork for ARM64EC + FEXCore + WCP workflow, with forensic tooling and reproducible CI.

- **App package / Пакет приложения:** `by.aero.so.benchmark`
- **Main branch / Основная ветка:** `main`
- **Current line / Текущая линейка:** `0.9b`

---

## Artifacts & Releases / Артефакты и релизы

| Component | Artifact | Rolling Tag | Stable Line |
|---|---|---|---|
| Winlator APK | `by.aero.so.benchmark-*.apk` | `winlator-latest` | `v0.9b` |
| Wine 11 ARM64EC | `wine-11-arm64ec.wcp` | `wine-11-arm64ec-latest` | `wcp-stable` |
| Proton GE10 ARM64EC | `proton-ge10-arm64ec.wcp` | `proton-ge10-arm64ec-latest` | `wcp-stable` |
| ProtonWine10 GameNative ARM64EC | `protonwine10-gamenative-arm64ec.wcp` | `protonwine10-gamenative-arm64ec-latest` | `wcp-stable` |

**RU:** Rolling-теги обновляются последним успешным артефактом без дублей.  
**EN:** Rolling tags are updated with the latest successful artifact without duplicates.

---

## Quick Start / Быстрый старт

### Build WCP packages / Сборка WCP-пакетов

```bash
bash ci/ci-build.sh
bash ci/proton-ge10/ci-build-proton-ge10-wcp.sh
bash ci/protonwine10/ci-build-protonwine10-wcp.sh
```

### Build Winlator APK / Сборка Winlator APK

```bash
bash ci/winlator/ci-build-winlator-ludashi.sh
```

**RU:** Результаты сборки лежат в `out/`.  
**EN:** Build outputs are written to `out/`.

---

## Runtime & Contents Model / Модель runtime и contents

- **RU:** Для Wine/Proton контента используется этот репозиторий (GitHub Releases).
- **EN:** Wine/Proton content is sourced from this repository (GitHub Releases).
- **RU:** В UI Winlator они отображаются в совместимой группе `Wine/Proton`.
- **EN:** In Winlator UI they are displayed in a compatible `Wine/Proton` group.
- **RU:** Пустые значения показываются честным placeholder `—`.
- **EN:** Empty values are represented by the honest placeholder `—`.

См./See:
- `docs/CONTENT_PACKAGES_ARCHITECTURE.md`
- `docs/CONTENTS_QA_CHECKLIST.md`

---

## Diagnostics & Forensics / Диагностика и форензика

- `ci/winlator/forensic-adb-matrix.sh`
- `ci/winlator/forensic-regression-local.sh`
- `ci/winlator/adb-logcat-winlator.sh`
- `ci/validation/inspect-wcp-runtime-contract.sh`
- `share/wcp-forensics/unix-module-abi.tsv` (inside built `.wcp`)

**RU:** Используйте форензик-логи для проверки FEX/Vulkan/Turnip/Box64 и причин падений контейнеров.  
**EN:** Use forensic logs to validate FEX/Vulkan/Turnip/Box64 behavior and container crash root causes.

---

## Release Policy (Detailed) / Политика релизов (детально)

### Rolling releases

- `winlator-latest`
- `wine-11-arm64ec-latest`
- `proton-ge10-arm64ec-latest`
- `protonwine10-gamenative-arm64ec-latest`

### Stable line

- Winlator app line: `v0.9b`
- WCP bundle line: `wcp-stable`

**RU:** Каждый артефакт имеет собственный тег и SHA256; новый успешный артефакт заменяет старый в рамках того же тега.  
**EN:** Each artifact has its own tag and SHA256; a new successful artifact replaces the previous one under the same tag.

---

## Repository Map / Карта репозитория

- `ci/` — build/release automation scripts
- `ci/lib/` — shared runtime and packaging helpers
- `ci/winlator/patches/` — Winlator fork patch stack
- `.github/workflows/` — CI/CD workflows
- `contents/` — Winlator contents index
- `docs/` — architecture, QA, forensic reports
- `out/`, `work/` — local/generated build artifacts

---

## Credits / Благодарности

- **Original Winlator** — [brunodev85](https://github.com/brunodev85/winlator)
- **Winlator Bionic** — [Pipetto-crypto](https://github.com/Pipetto-crypto/winlator)
- **Winlator Ludashi base** — [StevenMXZ](https://github.com/StevenMXZ)
- **Ludashi backup** — [StevenMX-backup](https://github.com/StevenMX-backup/Ludashi-Backup)
- **coffincolors fork** — [coffincolors/winlator](https://github.com/coffincolors/winlator)
- **Box64** — [ptitSeb/box64](https://github.com/ptitSeb/box64)
- **FEX-Emu** — [FEX-Emu/FEX](https://github.com/FEX-Emu/FEX)
- **Mesa / Turnip / Zink / VirGL** — [mesa3d.org](https://www.mesa3d.org)
- **Wine** — [winehq.org](https://www.winehq.org/)
- **DXVK** — [doitsujin/dxvk](https://github.com/doitsujin/dxvk)
- **VKD3D** — [winehq GitLab / vkd3d](https://gitlab.winehq.org/wine/vkd3d)
- **D8VK** — [AlpyneDreams/d8vk](https://github.com/AlpyneDreams/d8vk)
- **CNC DDraw** — [FunkyFr3sh/cnc-ddraw](https://github.com/FunkyFr3sh/cnc-ddraw)
- **PRoot** — [proot-me.github.io](https://proot-me.github.io)

**RU:** Отдельная благодарность Ludashi-ветке за практическую основу и UX-направление форка.  
**EN:** Special thanks to the Ludashi branch for the practical base and UX direction of this fork.
