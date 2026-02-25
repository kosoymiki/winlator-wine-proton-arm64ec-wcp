# Commit Progression Journal (0a-9z)

- База отсчёта: `1cd36fb` (первый commit в текущей длинной линии работ)
- Текущий диапазон: `0a..6h` (164 commit(s))
- Схема версий: `0a..0z`, `1a..1z`, `2a..2z` ... до `9z` (260 слотов)
- Назначение: фиксировать этапы и причины добавления commit-ов без потери причинной истории patch-stack

## Этапы (группировка по версиям)

### `0a-0g` — Восстановление patch-stack и базовой применимости Winlator
- Зачем добавлялись: Исправление битых hunk/context ошибок, восстановление применения базовых патчей и первичная стабилизация patch pipeline.

### `0h-0p` — Формирование линии 0.2b: forensic/contents/релизная инфраструктура
- Зачем добавлялись: Добавление forensic/contents патчей, release tooling 0.2b, документации и утилит cleanup для GitHub workflows/releases.

### `0q-0t` — Переэкспорт базовых патчей и визуальная подстройка темы
- Зачем добавлялись: Переэкспорт 0005–0007 поверх 0001–0004, выравнивание emerald-палитры и фиксы cleanup-скриптов.

### `0u-1f` — Contents/Container/Adrenotools/WCPHub функциональная линия
- Зачем добавлялись: Починка логики контейнеров и загрузок, WCPHub/ARM64EC фильтры, каталог драйверов, разделение rolling-релизов, интеграция Citron/Yuzu ссылок.

### `1g-1o` — glibc wrapper mitigations + forensic defaults + cleanup UX/docs
- Зачем добавлялись: Митигации glibc-wrapped launcher path (rseq/LD_PRELOAD), forensic defaults, честный Wine picker, иерархический Adrenotools browser, cleanup и README.

### `1p-1x` — Перенос control-plane апскейла + контейнерная конфигурация + аудит патчей
- Зачем добавлялись: Пошаговый перенос ScaleForce/SWFG control-plane, guardrails, UI контейнера, плюс audit tooling и консолидация upscale patch-stack.

### `1y-2h` — Forensic runtime telemetry и glibc runtime lane инфраструктура
- Зачем добавлялись: Усиление Adrenotools browser/ADB forensic capture, pre-exec telemetry, pinned glibc lane plumbing, FEX preset vars и инфраструктурные фиксы.

### `2i-2p` — Стабилизация CI pinned glibc lane и аналитика источников
- Зачем добавлялись: Build deps/parallelism для WCP, ScaleForce binding gate, forensic sink fallback, Hangover/source audits, UI fixes Adrenotools.

### `2q-2x` — Стабилизация Winlator патчей, FEX separation, bionic-native mainline и релизная линия (Winlator 0.9b / WCP stable)
- Зачем добавлялись: Compile-fix патчей Adrenotools, разделение FEX/WCP, Steven reverse analysis, bionic-native mainline policy и обновление stable line (Winlator 0.9b, WCP stable без номера).

### `2y-2z` — Полный импорт Box/WoWBox параметров и runtime-common профили
- Зачем добавлялись: Расширение Box/WoWBox env surface и device-tier пресетов, плюс внедрение унифицированной runtime-common профильной модели в container/settings/launcher path.

### `3a-6h` — Mainline bionic donor contract hardening + forensic lock
- Зачем добавлялись: Жесткий preflight донор-архивов (SHA/ABI), кэш доноров в workflows, строгая проверка runtime-контракта на каждом WCP артефакте, расширение forensic-индексов (`unix-module-abi.tsv`, `bionic-source-entry.json`) и закрепление этих инвариантов в валидации/документации.

## Полная карта commit -> версия

| Версия | Commit | Этап/направление |
|---|---|---|
| `0a` | `1cd36fb` | winlator: fix 0001 hunk line count |
| `0b` | `5923a8e` | winlator: fix corrupt hunk header in patch 0001 |
| `0c` | `fbb1a2d` | Merge pull request #29 from kosoymiki/wcp/0001-base |
| `0d` | `fe26155` | winlator: drop missing SwitchCompat style from patch 0003 |
| `0e` | `7e7eadc` | winlator: fix contents patch symbols and tolerate CRLF in patch apply |
| `0f` | `ee11993` | winlator: fix contents visibility, turnip selection UI, theme polish |
| `0g` | `51f32fc` | ci: stabilize winlator patch apply and baseline patch stack |
| `0h` | `2c7d5e2` | winlator: add forensic diagnostics and contents/turnip patch series |
| `0i` | `8db3baf` | ci: add repo-backed contents metadata and validation for WCP packages |
| `0j` | `66ed052` | ci: clean legacy workflows and add 0.2b release tooling |
| `0k` | `9e9ed93` | docs: refresh Aero.so contributor and content package documentation |
| `0l` | `1a7fefe` | ci: fix gh cleanup scripts pagination and stdin parsing |
| `0m` | `821a4db` | ci: fix workflow cleanup script python quoting |
| `0n` | `361b763` | ci: trim repo slug in gh cleanup scripts |
| `0o` | `b973452` | ci: use gh run list in workflow cleanup script |
| `0p` | `b018f39` | ci: use gh release list in release cleanup script |
| `0q` | `0984ae8` | winlator: re-export 0005-0007 for current 0001-0004 patch base |
| `0r` | `6e10452` | winlator: retune theme patches to dark emerald palette |
| `0s` | `b131bc1` | winlator: align 0005 colors hunk with emerald 0004 base |
| `0t` | `d88b0be` | ci: fix workflow cleanup script parsing and run deletion flags |
| `0u` | `1ab48d7` | winlator: restore WCP Hub contents and make Wine/Proton single-track |
| `0v` | `d7aa340` | winlator: fix container creation diagnostics and content download fallbacks |
| `0w` | `3ea2677` | winlator: harden adrenotools driver probe and runtime fallback reporting |
| `0x` | `ed65c61` | winlator: stop app restart on guest termination and log exit kind |
| `0y` | `b96496b` | winlator: clean contents placeholders and align list action controls |
| `0z` | `be2628e` | winlator: use WCPHub pack.json channels without mixing stable and nightly |
| `1a` | `735d5c5` | winlator: add WCPHub adreno driver source links and quick info |
| `1b` | `d0a15ef` | winlator: expand adrenotools driver catalog links without 4pda references |
| `1c` | `3097183` | winlator: make adrenotools driver catalog dynamic and theme-aligned |
| `1d` | `d30f859` | winlator: switch DXVK/VKD3D contents filter to ARM64EC and hide fake wine entries |
| `1e` | `f85a94d` | ci: split rolling WCP releases per package with package hashes |
| `1f` | `0baa684` | winlator: add citron and yuzu source references to adrenotools catalog |
| `1g` | `109c5f7` | winlator: disable glibc rseq for wrapped wine launchers |
| `1h` | `6127b43` | ci: add android glibc rseq compatibility to wrapper generator |
| `1i` | `8197b8c` | winlator: strip bionic LD_PRELOAD for glibc wine launchers |
| `1j` | `6f94e03` | ci: validate glibc wrapper preload/rseq guards for all WCP builds |
| `1k` | `e386b78` | winlator: enable maximum debug logging defaults for forensic builds |
| `1l` | `f6d0257` | winlator: hide fake wine entries in container artifact picker |
| `1m` | `f016c3a` | winlator: make adrenotools driver browser hierarchical |
| `1n` | `a8160dd` | winlator: remove legacy adrenotools catalog dead code |
| `1o` | `a17aa55` | docs: rewrite readme for clean release policy and patch stack |
| `1p` | `055a32a` | winlator: add upscale control plane and scaleforce preset resolver |
| `1q` | `9455726` | winlator: add graphics suitability guardrails for upscale presets |
| `1r` | `bdc4a85` | winlator: complete swfg env contract and guard conflict telemetry |
| `1s` | `e72cfb2` | winlator: bridge container upscale config into runtime env |
| `1t` | `0dc162b` | winlator: normalize and log upscale env at launcher submit |
| `1u` | `db7b71d` | winlator: add container upscale controls and persist runtime preset config |
| `1v` | `ac563f8` | ci/docs: add upscale forensic matrix and patch stack audit tooling |
| `1w` | `b9fa234` | ci/winlator: consolidate upscale patch stack and remove redundant patch artifacts |
| `1x` | `59526a9` | winlator: make container settings the owner of upscale config |
| `1y` | `d0bb947` | winlator: improve adrenotools browser sources and version sorting |
| `1z` | `3f0753e` | ci: add complete adb forensic matrix capture script |
| `2a` | `212e84b` | ci: fix complete adb forensic trace detection and runtime log harvesting |
| `2b` | `bc29385` | winlator: add launcher wrapper pre-exec forensic telemetry patch |
| `2c` | `05ce520` | ci: add pinned glibc runtime lane plumbing and forensics metadata |
| `2d` | `206798c` | ci: lock glibc runtime bundle policy and patch hooks |
| `2e` | `307f3b0` | ci: default WCP builds to pinned glibc 2.43 runtime lane |
| `2f` | `564eb57` | ci: pin winlator upstream ref for patch stack stability |
| `2g` | `b6b2696` | winlator: expand fex preset env vars from upstream config |
| `2h` | `c5bfdbf` | winlator: fix launcher pre-exec forensics patch syntax |
| `2i` | `eee703b` | ci: add glibc source build deps to WCP workflows |
| `2j` | `68386a7` | winlator: add missing back string for driver browser dialogs |
| `2k` | `932ae40` | winlator: bind scaleforce to graphics launches only |
| `2l` | `06f6eeb` | winlator: add forensic jsonl sink fallback to app-private storage |
| `2m` | `536be05` | ci: prune glibc source-build staging to reduce WCP runner disk usage |
| `2n` | `c893996` | ci/docs: add hangover transfer analysis and driver source audit tooling |
| `2o` | `fcf58e4` | winlator: polish driver browser rows and prune dead XForYouX source |
| `2p` | `e202df7` | ci: cap WCP build parallelism for pinned glibc lane stability |
| `2q` | `5e39d43` | winlator: fix adrenotools version picker dialog and gamenative browser UX |
| `2r` | `7dc9d4c` | winlator: fix adrenotools browser patch compile regression |
| `2s` | `f043dbe` | ci: separate FEX from WCP payloads and harden glibc runtime lane |
| `2t` | `cebc36f` | ci/docs: harden adb forensic capture and add Steven WCP reverse analysis |
| `2u` | `4136943` | winlator: defer upscale binding at shell launches for child graphics |
| `2v` | `ef4933d` | winlator: fix deferred upscale binding patch for EnvVars API |
| `2w` | `3dc2d5a` | ci/winlator: default WCP runtime class to bionic-native and fix 0035 compile patch |
| `2x` | `3b91bcf` | ci/release: switch mainline WCP to bionic-native and switch mainline WCP to bionic-native and stabilize release naming |
| `2y` | `a30f123` | winlator: add 0039/0040 box tiers and runtime common profile patches |
| `2z` | `708a942` | docs: document 0040 patch stack and 2026 device tier profile model |

## Примечания

- Исторические журналы (`docs/AEROSO_IMPLEMENTATION_REFLECTIVE_LOG.md` и др.) сохраняют исходные метки `0.2b`; они не переписывались как архивные артефакты.
- Эта карта отражает инженерную последовательность commit-ов в `main`, а не маркетинговые релизные версии.

## Карта patch-stack (`0001..0048`) по этапам

### `0001-0004` — Базовый форк, runtime/FEX и тема
- `0001`: базовый ARM64EC runtime/FEX patch-stack поверх `winlator_bionic`
- `0002`: debug/no-embedded-runtime branding baseline
- `0003`: ранняя WCPHub/turnip логика
- `0004`: dark emerald theme baseline

### `0005-0009` — Aero.so линия, contents/turnip, контейнеры и релизный baseline
- `0005`: branding + turnip/nightly + cleanup (большой интеграционный слой)
- `0006`: forensic/diagnostics/contents/turnip/repo-contents (ранняя интеграция)
- `0007`: версия Aero.so (`0.9b`)
- `0008`: WCPHub overlay для `Wine/Proton`, single-track policy
- `0009`: container create hardening + content download fixes

### `0010-0012` — Runtime launch стабильность + базовый UI cleanup
- `0010`: driver probe hardening и fallback telemetry
- `0011`: no app restart on guest termination
- `0012`: placeholders/rows polish для `Contents`

### `0013-0018` — WCPHub/Adrenotools каталог и data-source линия
- `0013`: WCPHub channels/ARM64EC switch UX
- `0014-0018`: эволюция каталога драйверов, ссылки авторов, динамический каталог, Citron/Yuzu references

### `0019-0024` — glibc mitigations + forensic defaults + честный Wine picker + cleanup
- `0019`: `rseq` compat для glibc wrappers
- `0020`: strip bionic `LD_PRELOAD` для glibc wrappers
- `0021`: default max debug logging
- `0022`: только реальные Wine артефакты в picker
- `0023-0024`: ранний `Adrenotools` browser + cleanup legacy path

### `0025-0027` — Upscale core (консолидированная линия)
- `0025`: upscale runtime guardrails + SWFG contract
- `0026`: container bridge + launch normalization + upscale UI layer
- `0027`: container settings как owner upscale config + legacy env migration

### `0028-0048` — Adrenotools UX, forensic telemetry, FEX/Box/FEXCore UI, upscale binding refinements, Contents row polish, runtime-common profiles, runtime appcompat and source-trust/fallback orchestration
- `0028`: native GameNative browser + version sorting + `Recommended`
- `0029`: launcher pre-exec forensic telemetry
- `0030`: FEXCore upstream config vars + inline help
- `0031`: upscale binding gate для service/graphics launches
- `0032`: ForensicLogger app-private JSONL fallback
- `0033-0035`: `Adrenotools` version-list UI, contents-style rows, version dialog/GameNative UX fixes
- `0036`: defer upscale binding на shell launch до child graphics
- `0037`: FEX/Box preset toggle semantics + Box inline descriptions
- `0038`: `Contents` row layout polish для длинных названий пакетов
- `0039`: полный импорт Box64/WoWBox64 env-vars + пресеты по классам устройств 2026
- `0040`: унифицированный runtime-common профиль (container/settings UI + launcher overlay + forensic)
- `0041-0042`: runtime unix-path linking + external runtime placeholders/FEX resolution
- `0043-0044`: runtime profile migration + launch precheck forensic guardrails
- `0045-0048`: driver fallback chain ranking, guarded appcompat rules, source-trust orchestration в `Adrenotools`

## Что можно безопасно объединять (кандидаты)

> Это не выполнено автоматически. Это карта для аккуратной консолидации без потери причинной истории.

### Высокая вероятность безопасного объединения
- `0014 + 0015 + 0016` — одна линия каталога драйверов/ссылок (эволюция одного UX/data слоя).
- `0023 + 0024` — ранний `Adrenotools` browser + cleanup мёртвого legacy-кода.
- `0033 + 0034 + 0035` — чистая UI/UX-ветка `Adrenotools` browser rows/dialog fixes.
- `0039 + 0040` — связанная линия профилей (Box/FEX device tiers + runtime-common profile). Рекомендуется объединять только вместе, т.к. `0040` использует предпосылки `0039`.

### Условно безопасно (если нужен более короткий стек)
- `0019 + 0020` — glibc-wrapper mitigations (один причинный слой, но сейчас полезно держать раздельно для forensic-истории).
- `0021 + 0022` — forensic defaults + container wine picker honesty (разные подсистемы, но low-risk для merge при желании сокращения).
- `0025 + 0026` уже фактически консолидированы из более мелкой upscale-серии.

### Лучше не объединять (держать раздельно)
- `0008` и `0013`/`0017` (`Contents` policy/filters): пересекаются по `Contents`, но отражают разные этапы бизнес-логики.
- `0009`, `0010`, `0011` (container/driver probe/session exit): это разные причинные runtime-слои, их разделение полезно для расследований.
- `0028` и `0035`: оба про `Adrenotools`, но `0035` — compile/runtime UI fix поверх `0028`; объединение скроет реальную регрессию.
- `0031` и `0036`: оба про upscale binding, но `0036` — корректировка логики после device forensic (важно как отдельный postmortem-fix).

## Практический порядок консолидации (если делать)

1. Сначала только UI/Adrenotools серии (`0014-0016`, `0023-0024`, `0033-0035`).
2. Затем повторный `ci/winlator/check-patch-stack.sh` + Winlator CI.
3. Только после этого рассматривать glibc/upscale серии, и только при явной цели сокращения стека.
