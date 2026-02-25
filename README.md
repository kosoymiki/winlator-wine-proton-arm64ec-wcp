<p align="center">
  <img src="docs/assets/winlator-cmod-aeroso-logo.png" alt="Winlator CMOD Aero.so" width="680">
</p>

# **Winlator CMOD Aero.so** *(ARM64EC / FEX / WCP Toolkit)*

**Winlator CMOD Aero.so** — форк Winlator (через базу *Winlator Ludashi*), ориентированный на **ARM64EC + FEXCore**, аккуратную работу с **WCP-пакетами**, расширенную **forensic-диагностику** и воспроизводимую CI-сборку.

> Пакет приложения: **`by.aero.so.benchmark`** *(суффикс `.benchmark` оставлен намеренно для поведения некоторых OEM game-mode профилей).*

---

## **Что здесь есть**

- **Winlator APK** (CI-сборка форка, без embedded runtime по умолчанию)
- **WCP пакеты**:
  - `wine-11-arm64ec.wcp`
  - `proton-ge10-arm64ec.wcp`
  - `protonwine10-gamenative-arm64ec.wcp`
- **Patch stack Winlator** (`ci/winlator/patches/*.patch`)
- **Contents index** (`contents/contents.json`) для overlay `Wine/Proton`
- **Forensic / ADB tooling** для runtime-диагностики

---

## **Release Policy (без каши и дублей)**

### **Rolling releases (по одному пакету на релиз)**

Каждый пакет имеет **свой rolling release** и **свою SHA256**:

- **Winlator APK:** `winlator-latest`
- **Wine 11 ARM64EC:** `wine-11-arm64ec-latest`
- **Proton GE10 ARM64EC:** `proton-ge10-arm64ec-latest`
- **ProtonWine10 GameNative ARM64EC:** `protonwine10-gamenative-arm64ec-latest`

### **Stable releases**

- **Winlator app:** `v0.9b`
- **WCP bundle:** `wcp-stable`

**Принцип:** *новый артефакт заменяет предыдущий внутри своего релиза*; дубли и лишние служебные файлы удаляются.

---

## **Contents / пакеты внутри Winlator**

- **WCP Hub** используется для общего контента (layers/tools и т.п.)
- **Наш репозиторий** используется для **Wine/Proton** пакетов
- В UI `Wine/Proton` отображается как одна группа (совместимый internal type остаётся `Wine`)
- Для `Wine/Proton` **нет искусственного разделения на stable/nightly**
- Для пустых/неустановленных значений используется честный placeholder: **`—`**

См. также:
- `docs/CONTENT_PACKAGES_ARCHITECTURE.md`
- `docs/CONTENTS_QA_CHECKLIST.md`

---

## **Winlator Patch Stack**

Ниже — *эволюция форка* (ключевые этапы):

- `0001`–`0004` — ARM64EC/FEX runtime база, debug/no-embedded-runtime, WCPHub baseline, dark-green theme
- `0005`–`0009` — Aero.so branding, logs, contents fixes, Turnip/contents UX, container create/download fixes
- `0010`–`0014` — driver probe hardening, session-exit diagnostics, contents UI polish, WCPHub channels, Adrenotools source links
- `0015`–`0019` — driver catalog expansion, dynamic sources, ARM64EC switch logic, glibc wrapper/rseq compatibility
- `0020`–`0024` — glibc `LD_PRELOAD` fix, forensic logging defaults, honest Wine picker, hierarchical Adrenotools browser, dead-code cleanup

Патчи Winlator всегда применяются через:
- `ci/winlator/apply-repo-patches.sh`
- `ci/winlator/ci-build-winlator-ludashi.sh`

---

## **Локальная сборка (быстрый старт)**

### **WCP пакеты**

```bash
bash ci/ci-build.sh
bash ci/proton-ge10/ci-build-proton-ge10-wcp.sh
bash ci/protonwine10/ci-build-protonwine10-wcp.sh
```

### **Winlator APK**

```bash
bash ci/winlator/ci-build-winlator-ludashi.sh
```

Обычно APK именуется в формате:
- `by.aero.so.benchmark-debug-<upstream_sha>.apk`

---

## **Диагностика и forensic workflow**

### **Что добавлено в форк**

- structured runtime/launch events (`ROUTE_*`, `RUNTIME_*`, `LAUNCH_*`, `SESSION_EXIT_*`)
- логирование `FEX / Vulkan / Turnip / Box64`
- строгий bionic donor preflight (URL + SHA256 + ABI verification до долгой сборки)
- forensic индекс `share/wcp-forensics/unix-module-abi.tsv` для контроля glibc/bionic unix-модулей
- вкладка **Diagnostics** для прямого forensic-запуска `XServerDisplayActivity`
- ADB сценарии для сравнения контейнеров и поиска root cause

### **Полезные скрипты**

- `ci/winlator/forensic-adb-matrix.sh`
- `ci/winlator/forensic-regression-local.sh`
- `ci/winlator/adb-logcat-winlator.sh`
- `ci/validation/inspect-wcp-runtime-contract.sh`

---

## **Upstream Research (reproducible)**

- `ci/research/gamenative_forensic_audit.py` -> `docs/GAMENATIVE_BRANCH_AUDIT_LOG.md`
- `ci/research/gamehub_provenance_audit.py` -> `docs/GAMEHUB_PROVENANCE_REPORT.md`
- `bash ci/research/run_upstream_audits.sh` -> regenerates both reports + raw evidence in `docs/research/`

---

## **Структура репозитория**

- `ci/` — сборка, публикация, maintenance-утилиты
- `ci/lib/` — общие runtime/WCP helper-скрипты
- `ci/winlator/patches/` — patch stack форка Winlator
- `.github/workflows/` — GitHub Actions workflows
- `contents/` — overlay index для Winlator `Contents`
- `docs/` — архитектура, QA, forensic/reflective документы
- `work/`, `out/` — локальные рабочие директории *(gitignored)*

---

## **Credits / Thanks**

- **Original Winlator** — [brunodev85](https://github.com/brunodev85/winlator)
- **Winlator Bionic** — [Pipetto-crypto](https://github.com/Pipetto-crypto/winlator)
- **Winlator Ludashi (upstream base for this fork)** — [StevenMXZ](https://github.com/StevenMXZ)
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

*Отдельная благодарность Ludashi-ветке за практическую базу, UI-идеи и исходный импульс форка.*
