# GameHub Runtime Transfer Matrix (for Aero.so mainline)

- Generated (UTC): `2026-02-25 14:42:24`
- Source APK: `/home/mikhail/GameHub-Lite-5.3.3-RC2.apk`
- Source methods file: `/home/mikhail/gamehub_reverse_20260225_164606/focus/methods_focus.txt`
- Source edges file: `/home/mikhail/gamehub_reverse_20260225_164606/focus/call_edges_runtime_graphics.tsv`
- Mainline policy: `bionic-native + external-only runtime`
- Plan slot: `pre-0044`

## Extraction Snapshot

- Focus classes: `2601`
- Focus methods: `15138`
- Focus call edges (unique): `40853`
- Focus outbound/inbound/internal events (total): `57837`

## Transfer Decisions

| Module | Decision | Methods | Edge events | Target in Aero.so | Existing anchor |
| --- | --- | ---: | ---: | --- | --- |
| `Box64/FEX translator config` | `port_contract` | 474 | 1289 | Box64/FEX preset + runtime common profile layers | `ci/winlator/patches/0030,0039,0040` |
| `Launch pipeline orchestration` | `adapt_urc` | 311 | 2378 | URC launch plan + preflight + telemetry | `XServerDisplayActivity + GuestProgramLauncherComponent` |
| `Graphics + driver decision tree` | `adapt_urc` | 174 | 89 | Adrenotools probe + Vulkan fallback telemetry | `AdrenotoolsManager + native vulkan.c` |
| `Registry/runtime mutation layer` | `adapt_guarded` | 380 | 1895 | Container/runtime compatibility rules with strict guardrails | `Container migration + compat registry layer` |
| `Content download/install app layers` | `reject_mainline` | 2261 | 3663 | Do not port directly (asset-first behavior) | `Research-only, no mainline import` |
| `UI and translation-specific features` | `reject_mainline` | 2891 | 2193 | Do not port into runtime core | `Optional UI lane only` |
| `Unclassified` | `manual-review` | 8647 | 5793 | Review in research lane | `docs/REFLECTIVE_HARVARD_LEDGER.md` |

## High-Value Signatures (examples)

### Box64/FEX translator config

Decision: `port_contract`

- `Lcom/winemu/core/trans_layer/Box64Config$Creator;->createFromParcel(Landroid/os/Parcel;)Lcom/winemu/core/trans_layer/Box64Config;`
- `Lcom/winemu/core/trans_layer/Box64Config$Creator;->newArray(I)[Lcom/winemu/core/trans_layer/Box64Config;`
- `Lcom/winemu/core/trans_layer/Box64Config;-><clinit>()V`
- `Lcom/winemu/core/trans_layer/Box64Config;-><init>()V`
- `Lcom/winemu/core/trans_layer/Box64Config;-><init>(Ljava/lang/String;IIIIIIIIIIIIIIIIIIILjava/lang/String;IIIIIIILjava/lang/String;)V`
- `Lcom/winemu/core/trans_layer/Box64Config;-><init>(Ljava/lang/String;IIIIIIIIIIIIIIIIIIILjava/lang/String;IIIIIIILjava/lang/String;ILkotlin/jvm/internal/DefaultConstructorMarker;)V`
- `Lcom/winemu/core/trans_layer/Box64Config;->component1()Ljava/lang/String;`
- `Lcom/winemu/core/trans_layer/Box64Config;->component10()I`
- `Lcom/winemu/core/trans_layer/Box64Config;->component11()I`
- `Lcom/winemu/core/trans_layer/Box64Config;->component12()I`
- `Lcom/winemu/core/trans_layer/Box64Config;->component13()I`
- `Lcom/winemu/core/trans_layer/Box64Config;->component14()I`
- `Lcom/winemu/core/trans_layer/Box64Config;->component15()I`
- `Lcom/winemu/core/trans_layer/Box64Config;->component16()I`
- `Lcom/winemu/core/trans_layer/Box64Config;->component17()I`
- `Lcom/winemu/core/trans_layer/Box64Config;->component18()I`
- `Lcom/winemu/core/trans_layer/Box64Config;->component19()I`
- `Lcom/winemu/core/trans_layer/Box64Config;->component2()I`
- `Lcom/winemu/core/trans_layer/Box64Config;->component20()I`
- `Lcom/winemu/core/trans_layer/Box64Config;->component21()Ljava/lang/String;`

### Launch pipeline orchestration

Decision: `adapt_urc`

- `Lcom/winemu/core/controller/ContainerController;-><clinit>()V`
- `Lcom/winemu/core/controller/ContainerController;-><init>(Lcom/winemu/core/BootData;Lcom/winemu/core/server/environment/ImageFs;Landroid/app/ActivityManager;Lcom/winemu/openapi/Config;Lcom/winemu/core/Container;)V`
- `Lcom/winemu/core/controller/ContainerController;->a(Ljava/lang/String;)Z`
- `Lcom/winemu/core/controller/ContainerController;->b(Ljava/lang/String;)V`
- `Lcom/winemu/core/controller/ContainerController;->c(Ljava/io/File;Ljava/lang/String;Ljava/lang/String;)V`
- `Lcom/winemu/core/controller/ContainerController;->d(Ljava/lang/String;Ljava/lang/String;)V`
- `Lcom/winemu/core/controller/ContainerController;->e()Ljava/lang/String;`
- `Lcom/winemu/core/controller/ContainerController;->f(Ljava/lang/String;)V`
- `Lcom/winemu/core/controller/ContainerController;->g(Z)Ljava/util/List;`
- `Lcom/winemu/core/controller/ContainerController;->h(Lcom/winemu/core/controller/ContainerController;ZILjava/lang/Object;)Ljava/util/List;`
- `Lcom/winemu/core/controller/ContainerController;->i(Ljava/lang/String;Ljava/lang/String;)V`
- `Lcom/winemu/core/controller/ContainerController;->j()V`
- `Lcom/winemu/core/controller/ContainerController;->k(Ljava/io/File;Ljava/lang/String;Ljava/lang/String;)V`
- `Lcom/winemu/core/controller/ContainerController;->l(I)Z`
- `Lcom/winemu/core/controller/ContainerController;->m(Ljava/lang/String;)V`
- `Lcom/winemu/core/controller/ContainerController;->n(Ljava/lang/String;)Z`
- `Lcom/winemu/core/controller/ContainerController;->o(Ljava/lang/String;Ljava/lang/String;)V`
- `Lcom/winemu/core/controller/ContainerController;->p(Ljava/lang/String;Ljava/lang/String;)V`
- `Lcom/winemu/core/controller/ContainerController;->q()V`
- `Lcom/winemu/core/controller/ContainerController;->r()V`

### Graphics + driver decision tree

Decision: `adapt_urc`

- `Lcom/winemu/core/DirectRendering$Companion;-><init>()V`
- `Lcom/winemu/core/DirectRendering$Companion;-><init>(Lkotlin/jvm/internal/DefaultConstructorMarker;)V`
- `Lcom/winemu/core/DirectRendering$Companion;->a(Lcom/winemu/core/DirectRenderingStateListener;)V`
- `Lcom/winemu/core/DirectRendering$Companion;->b()Lcom/winemu/core/DirectRendering;`
- `Lcom/winemu/core/DirectRendering$Companion;->c(Z)V`
- `Lcom/winemu/core/DirectRendering$Companion;->nativeInitialize(Landroid/view/Surface;Landroid/view/SurfaceControl;Landroid/view/Surface;Landroid/view/SurfaceControl;Ljava/lang/String;II)V`
- `Lcom/winemu/core/DirectRendering$Companion;->nativeSetSurfaceFormat(I)V`
- `Lcom/winemu/core/DirectRendering$Companion;->nativeStartTestClient(Ljava/lang/String;II)V`
- `Lcom/winemu/core/DirectRendering;-><clinit>()V`
- `Lcom/winemu/core/DirectRendering;-><init>()V`
- `Lcom/winemu/core/DirectRendering;->a(Lcom/winemu/core/DirectRendering;Landroid/view/SurfaceControl;Landroid/view/SurfaceControl$Transaction;)Lkotlin/Unit;`
- `Lcom/winemu/core/DirectRendering;->access$getInstance$delegate$cp()Lkotlin/Lazy;`
- `Lcom/winemu/core/DirectRendering;->access$getListeners$cp()Ljava/util/Set;`
- `Lcom/winemu/core/DirectRendering;->b()Lcom/winemu/core/DirectRendering;`
- `Lcom/winemu/core/DirectRendering;->c(Lcom/winemu/core/DirectRendering;Landroid/view/SurfaceControl$Transaction;)Lkotlin/Unit;`
- `Lcom/winemu/core/DirectRendering;->d(Lcom/winemu/core/DirectRendering;Landroid/view/SurfaceControl$Transaction;)Lkotlin/Unit;`
- `Lcom/winemu/core/DirectRendering;->e(Lkotlin/jvm/functions/Function1;)V`
- `Lcom/winemu/core/DirectRendering;->f(Ljava/lang/String;II)V`
- `Lcom/winemu/core/DirectRendering;->g()Lcom/winemu/core/DirectRendering;`
- `Lcom/winemu/core/DirectRendering;->h(Landroid/view/SurfaceControl;)V`

### Registry/runtime mutation layer

Decision: `adapt_guarded`

- `Lcom/winemu/core/DependencyManager;-><clinit>()V`
- `Lcom/winemu/core/DependencyManager;-><init>(Ljava/io/File;Lcom/winemu/core/Container;Ljava/lang/String;)V`
- `Lcom/winemu/core/DependencyManager;-><init>(Ljava/io/File;Lcom/winemu/core/Container;Ljava/lang/String;ILkotlin/jvm/internal/DefaultConstructorMarker;)V`
- `Lcom/winemu/core/DependencyManager;->A(Ljava/lang/String;Ljava/util/List;)V`
- `Lcom/winemu/core/DependencyManager;->B(Ljava/lang/String;Ljava/lang/String;I)V`
- `Lcom/winemu/core/DependencyManager;->C(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V`
- `Lcom/winemu/core/DependencyManager;->D(Ljava/lang/String;Ljava/lang/String;ILcom/winemu/core/regedit/RegistryKeyDsl;)Lkotlin/Unit;`
- `Lcom/winemu/core/DependencyManager;->E(Ljava/lang/String;ILcom/winemu/core/regedit/RegistryKeyDsl;)Lkotlin/Unit;`
- `Lcom/winemu/core/DependencyManager;->F(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Lcom/winemu/core/regedit/RegistryKeyDsl;)Lkotlin/Unit;`
- `Lcom/winemu/core/DependencyManager;->G(Ljava/lang/String;Ljava/lang/String;Lcom/winemu/core/regedit/RegistryKeyDsl;)Lkotlin/Unit;`
- `Lcom/winemu/core/DependencyManager;->H(Ljava/lang/String;)V`
- `Lcom/winemu/core/DependencyManager;->I(Ljava/lang/String;)Z`
- `Lcom/winemu/core/DependencyManager;->J(Ljava/lang/String;)V`
- `Lcom/winemu/core/DependencyManager;->K(Ljava/lang/String;Ljava/lang/String;)V`
- `Lcom/winemu/core/DependencyManager;->a(Ljava/lang/String;ILcom/winemu/core/regedit/RegistryKeyDsl;)Lkotlin/Unit;`
- `Lcom/winemu/core/DependencyManager;->b(Ljava/lang/String;Ljava/lang/String;Lcom/winemu/core/regedit/RegistryKeyDsl;)Lkotlin/Unit;`
- `Lcom/winemu/core/DependencyManager;->c(Ljava/lang/String;Ljava/lang/String;ILcom/winemu/core/regedit/RegistryKeyDsl;)Lkotlin/Unit;`
- `Lcom/winemu/core/DependencyManager;->d(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Lcom/winemu/core/regedit/RegistryKeyDsl;)Lkotlin/Unit;`
- `Lcom/winemu/core/DependencyManager;->e(Ljava/lang/String;)V`
- `Lcom/winemu/core/DependencyManager;->f(Ljava/lang/String;Ljava/lang/String;)V`

### Content download/install app layers

Decision: `reject_mainline`

- `Lcom/xj/winemu/EmuContainers$getSubDataDownloadedFile$2;-><init>(Ljava/io/File;Lcom/xj/common/download/bean/SubData;Lkotlin/coroutines/Continuation;)V`
- `Lcom/xj/winemu/EmuContainers;->c()Lcom/xj/winemu/data/repository/EnvLayerRepository;`
- `Lcom/xj/winemu/EmuContainers;->k(Lcom/xj/common/download/bean/SubData;Lkotlin/coroutines/Continuation;)Ljava/lang/Object;`
- `Lcom/xj/winemu/EmuContainers;->l()Lcom/xj/winemu/data/repository/EnvLayerRepository;`
- `Lcom/xj/winemu/EmuContainers;->p()Lcom/xj/winemu/data/repository/EnvLayerRepository;`
- `Lcom/xj/winemu/EmuContainers;->q(Lcom/xj/common/download/bean/SubData;Lkotlin/coroutines/Continuation;)Ljava/lang/Object;`
- `Lcom/xj/winemu/EmuContainers;->x(Lcom/xj/common/download/bean/SubData;ZLcom/xj/winemu/download/listener/OnNetDownloadListener;Lkotlin/coroutines/Continuation;)Ljava/lang/Object;`
- `Lcom/xj/winemu/EmuImageFs;->d()Lcom/xj/winemu/data/repository/EnvLayerRepository;`
- `Lcom/xj/winemu/EmuImageFs;->n()Lcom/xj/winemu/data/repository/EnvLayerRepository;`
- `Lcom/xj/winemu/EmuImageFs;->o()Lcom/xj/winemu/data/repository/EnvLayerRepository;`
- `Lcom/xj/winemu/EnvRepo;-><init>(Ljava/lang/String;Ljava/lang/String;LState;Lcom/xj/winemu/api/bean/EnvLayerEntity;)V`
- `Lcom/xj/winemu/EnvRepo;->component4()Lcom/xj/winemu/api/bean/EnvLayerEntity;`
- `Lcom/xj/winemu/EnvRepo;->copy$default(Lcom/xj/winemu/EnvRepo;Ljava/lang/String;Ljava/lang/String;LState;Lcom/xj/winemu/api/bean/EnvLayerEntity;ILjava/lang/Object;)Lcom/xj/winemu/EnvRepo;`
- `Lcom/xj/winemu/EnvRepo;->copy(Ljava/lang/String;Ljava/lang/String;LState;Lcom/xj/winemu/api/bean/EnvLayerEntity;)Lcom/xj/winemu/EnvRepo;`
- `Lcom/xj/winemu/EnvRepo;->getEntry()Lcom/xj/winemu/api/bean/EnvLayerEntity;`
- `Lcom/xj/winemu/EnvRepo;->setEntry(Lcom/xj/winemu/api/bean/EnvLayerEntity;)V`
- `Lcom/xj/winemu/api/bean/EnvLayerEntity$Companion;-><init>()V`
- `Lcom/xj/winemu/api/bean/EnvLayerEntity$Companion;-><init>(Lkotlin/jvm/internal/DefaultConstructorMarker;)V`
- `Lcom/xj/winemu/api/bean/EnvLayerEntity$Companion;->a(ILjava/lang/String;ILjava/lang/String;Ljava/lang/String;Ljava/lang/String;IJLjava/lang/String;Ljava/lang/String;Ljava/lang/String;)Lcom/xj/common/download/bean/AriaDownloadArgs;`
- `Lcom/xj/winemu/api/bean/EnvLayerEntity$Companion;->b(Lcom/xj/winemu/api/bean/EnvLayerEntity;Ljava/lang/String;)Lcom/xj/common/download/bean/AriaDownloadArgs;`

### UI and translation-specific features

Decision: `reject_mainline`

- `Lcom/winemu/ui/BootLogView$LogLine;-><init>(Ljava/lang/String;Lcom/winemu/ui/BootLogView$LogType;Ljava/util/List;)V`
- `Lcom/winemu/ui/BootLogView$LogLine;->a(Ljava/lang/String;Lcom/winemu/ui/BootLogView$LogType;Ljava/util/List;)Lcom/winemu/ui/BootLogView$LogLine;`
- `Lcom/winemu/ui/BootLogView$LogLine;->b(Lcom/winemu/ui/BootLogView$LogLine;Ljava/lang/String;Lcom/winemu/ui/BootLogView$LogType;Ljava/util/List;ILjava/lang/Object;)Lcom/winemu/ui/BootLogView$LogLine;`
- `Lcom/winemu/ui/BootLogView$LogLine;->c()Ljava/lang/String;`
- `Lcom/winemu/ui/BootLogView$LogLine;->d()Lcom/winemu/ui/BootLogView$LogType;`
- `Lcom/winemu/ui/BootLogView$LogLine;->e()Ljava/util/List;`
- `Lcom/winemu/ui/BootLogView$LogLine;->equals(Ljava/lang/Object;)Z`
- `Lcom/winemu/ui/BootLogView$LogLine;->hashCode()I`
- `Lcom/winemu/ui/BootLogView$LogLine;->toString()Ljava/lang/String;`
- `Lcom/winemu/ui/BootLogView$LogType;-><clinit>()V`
- `Lcom/winemu/ui/BootLogView$LogType;-><init>(Ljava/lang/String;II)V`
- `Lcom/winemu/ui/BootLogView$LogType;->a()[Lcom/winemu/ui/BootLogView$LogType;`
- `Lcom/winemu/ui/BootLogView$LogType;->getColor()I`
- `Lcom/winemu/ui/BootLogView$LogType;->getEntries()Lkotlin/enums/EnumEntries;`
- `Lcom/winemu/ui/BootLogView$LogType;->valueOf(Ljava/lang/String;)Lcom/winemu/ui/BootLogView$LogType;`
- `Lcom/winemu/ui/BootLogView$LogType;->values()[Lcom/winemu/ui/BootLogView$LogType;`
- `Lcom/winemu/ui/BootLogView;-><init>(Landroid/content/Context;)V`
- `Lcom/winemu/ui/BootLogView;-><init>(Landroid/content/Context;Landroid/util/AttributeSet;)V`
- `Lcom/winemu/ui/BootLogView;-><init>(Landroid/content/Context;Landroid/util/AttributeSet;I)V`
- `Lcom/winemu/ui/BootLogView;-><init>(Landroid/content/Context;Landroid/util/AttributeSet;IILkotlin/jvm/internal/DefaultConstructorMarker;)V`

## Anti-Conflict Rules (GameNative vs GameHub)

1. GN/GH behavior is integrated only through unified runtime contract fields.
2. Any GameHub path that implies bundled runtime assets is rejected in mainline.
3. Launch/Env changes must preserve existing GN-origin preflight and forensic telemetry.
4. If GN and GH differ, keep the lower-regression path with explicit fallback reasons.

## Implementation Queue

1. Port translator config semantics (Box64/FEX) into existing preset/profile layers.
2. Adapt launch orchestration into URC (without importing app-specific asset/download flows).
3. Add guarded registry compatibility deltas only with forensic trace points.
4. Keep download/UI translation layers in research lane unless explicitly requested.

