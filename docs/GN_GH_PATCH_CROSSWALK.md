# GN + GH Patch Crosswalk

- Generated (UTC): `2026-02-25 14:43:11`
- Goal: merge GameNative and GameHub patches by shared runtime function
- Mainline policy: `bionic-native + external-only runtime`
- GameNative methods: `/home/mikhail/gamenative-v0.7.2_reverse_20260225_143304/focus/methods_focus.txt`
- GameNative edges: `/home/mikhail/gamenative-v0.7.2_reverse_20260225_143304/focus/call_edges_runtime_graphics.tsv`
- GameHub methods: `/home/mikhail/gamehub_reverse_20260225_164606/focus/methods_focus.txt`
- GameHub edges: `/home/mikhail/gamehub_reverse_20260225_164606/focus/call_edges_runtime_graphics.tsv`

## Function-Level Crosswalk

| Module | GN methods | GH methods | GN edge events | GH edge events | Similarity | Confidence | Action | Patch lane |
| --- | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |
| `Translator/FEX/Box64` | 404 | 707 | 1998 | 2078 | 0.027 | `low` | `merge-guarded` | `0030/0037/0039/0040/0043 (+0044 bridge)` |
| `Launch pipeline` | 1410 | 360 | 1344 | 2589 | 0.059 | `low` | `queue-manual` | `0044` |
| `Graphics/driver` | 430 | 183 | 2244 | 88 | 0.078 | `low` | `merge-guarded` | `0045` |
| `Registry/runtime mutation` | 69 | 407 | 558 | 1925 | 0.085 | `medium` | `merge-guarded` | `0046` |
| `Content/download flows` | 1611 | 2767 | 4665 | 3439 | 0.129 | `medium` | `research-only` | `research-only` |
| `UI/app shell` | 9658 | 3376 | 745 | 2088 | 0.032 | `low` | `research-only` | `research-only` |

## Shared Function Tokens (Evidence)

### Translator/FEX/Box64

- Shared tokens: `box64` (225), `preset` (6), `env` (6), `block` (3), `mode` (3), `x87` (3), `custom` (3), `container` (1), `options` (1), `file` (1)
- GameNative examples:
  - `Lapp/gamenative/PrefManager;->getBox64Preset()Ljava/lang/String;`
  - `Lapp/gamenative/PrefManager;->getBox64Version()Ljava/lang/String;`
  - `Lapp/gamenative/PrefManager;->getFexcoreMultiBlock()Ljava/lang/String;`
  - `Lapp/gamenative/PrefManager;->getFexcorePreset()Ljava/lang/String;`
- GameHub examples:
  - `Lcom/winemu/core/trans_layer/Box64Config$Creator;-><init>()V`
  - `Lcom/winemu/core/trans_layer/Box64Config$Creator;->createFromParcel(Landroid/os/Parcel;)Lcom/winemu/core/trans_layer/Box64Config;`
  - `Lcom/winemu/core/trans_layer/Box64Config$Creator;->createFromParcel(Landroid/os/Parcel;)Ljava/lang/Object;`
  - `Lcom/winemu/core/trans_layer/Box64Config$Creator;->newArray(I)[Lcom/winemu/core/trans_layer/Box64Config;`

### Launch pipeline

- Shared tokens: `server` (27), `window` (23), `program` (20), `game` (14), `environment` (14), `launch` (13), `keyboard` (12), `start` (12), `win` (12), `present` (10), `steam` (9), `wine` (9)
- GameNative examples:
  - `Lapp/gamenative/MainActivity$Companion;->consumePendingLaunchRequest()Lapp/gamenative/utils/IntentLaunchManager$LaunchRequest;`
  - `Lapp/gamenative/MainActivity$Companion;->setPendingLaunchRequest(Lapp/gamenative/utils/IntentLaunchManager$LaunchRequest;)V`
  - `Lapp/gamenative/MainActivity$handleLaunchIntent$1;-><init>(Lapp/gamenative/utils/IntentLaunchManager$LaunchRequest;Lkotlin/coroutines/Continuation;)V`
  - `Lapp/gamenative/MainActivity;->access$getPendingLaunchRequest$cp()Lapp/gamenative/utils/IntentLaunchManager$LaunchRequest;`
- GameHub examples:
  - `Lcom/winemu/core/controller/ContainerController$Companion;-><init>()V`
  - `Lcom/winemu/core/controller/ContainerController$Companion;-><init>(Lkotlin/jvm/internal/DefaultConstructorMarker;)V`
  - `Lcom/winemu/core/controller/ContainerController;-><clinit>()V`
  - `Lcom/winemu/core/controller/ContainerController;-><init>(Lcom/winemu/core/BootData;Lcom/winemu/core/server/environment/ImageFs;Landroid/app/ActivityManager;Lcom/winemu/openapi/Config;Lcom/winemu/core/Container;)V`

### Graphics/driver

- Shared tokens: `driver` (23), `audio` (7), `info` (7), `download` (6), `game` (5), `dxvk` (4), `vkd3d` (4), `gpu` (4), `hash` (3), `code` (3), `version` (1), `name` (1)
- GameNative examples:
  - `Lapp/gamenative/PrefManager;->getAudioDriver()Ljava/lang/String;`
  - `Lapp/gamenative/PrefManager;->getGraphicsDriver()Ljava/lang/String;`
  - `Lapp/gamenative/PrefManager;->getGraphicsDriverConfig()Ljava/lang/String;`
  - `Lapp/gamenative/PrefManager;->getGraphicsDriverVersion()Ljava/lang/String;`
- GameHub examples:
  - `Lcom/winemu/core/DirectRendering$Companion;-><init>()V`
  - `Lcom/winemu/core/DirectRendering$Companion;-><init>(Lkotlin/jvm/internal/DefaultConstructorMarker;)V`
  - `Lcom/winemu/core/DirectRendering$Companion;->a(Lcom/winemu/core/DirectRenderingStateListener;)V`
  - `Lcom/winemu/core/DirectRendering$Companion;->b()Lcom/winemu/core/DirectRendering;`

### Registry/runtime mutation

- Shared tokens: `registry` (37), `value` (10), `key` (8), `editor` (4), `win` (3), `components` (2), `dword` (2), `line` (1), `name` (1), `values` (1), `change` (1)
- GameNative examples:
  - `Lapp/gamenative/PrefManager;->getWinComponents()Ljava/lang/String;`
  - `Lapp/gamenative/PrefManager;->setWinComponents(Ljava/lang/String;)V`
  - `Lapp/gamenative/enums/SpecialGameSaveMapping$Companion;->getRegistry()Ljava/util/List;`
  - `Lapp/gamenative/enums/SpecialGameSaveMapping;->access$getRegistry$cp()Ljava/util/List;`
- GameHub examples:
  - `Lcom/winemu/core/DependencyManager$Companion$DownloadEntry;-><init>(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;Ljava/lang/Integer;)V`
  - `Lcom/winemu/core/DependencyManager$Companion$DownloadEntry;->a()Ljava/lang/String;`
  - `Lcom/winemu/core/DependencyManager$Companion$DownloadEntry;->b()Ljava/lang/String;`
  - `Lcom/winemu/core/DependencyManager$Companion$DownloadEntry;->c()Ljava/lang/String;`

### Content/download flows

- Shared tokens: `download` (928), `game` (132), `and` (119), `file` (115), `info` (98), `manifest` (79), `files` (74), `install` (60), `fetch` (55), `impl` (39), `downloading` (37), `wine` (33)
- GameNative examples:
  - `Lapp/gamenative/DaggerPluviaApp_HiltComponents_SingletonC$SingletonCImpl;->-$$Nest$fgetepicDownloadManagerProvider(Lapp/gamenative/DaggerPluviaApp_HiltComponents_SingletonC$SingletonCImpl;)Ldagger/internal/Provider;`
  - `Lapp/gamenative/DaggerPluviaApp_HiltComponents_SingletonC$SingletonCImpl;->-$$Nest$fgetgOGDownloadManagerProvider(Lapp/gamenative/DaggerPluviaApp_HiltComponents_SingletonC$SingletonCImpl;)Ldagger/internal/Provider;`
  - `Lapp/gamenative/DaggerPluviaApp_HiltComponents_SingletonC$SingletonCImpl;->-$$Nest$fgetgOGManifestParserProvider(Lapp/gamenative/DaggerPluviaApp_HiltComponents_SingletonC$SingletonCImpl;)Ldagger/internal/Provider;`
  - `Lapp/gamenative/DaggerPluviaApp_HiltComponents_SingletonC$SingletonCImpl;->-$$Nest$fgetprovideDownloadingAppInfoDaoProvider(Lapp/gamenative/DaggerPluviaApp_HiltComponents_SingletonC$SingletonCImpl;)Ldagger/internal/Provider;`
- GameHub examples:
  - `Lcom/xj/winemu/EmuComponents$isComponentNeed2Download$1;-><init>(Lcom/xj/winemu/EmuComponents;Lkotlin/coroutines/Continuation;)V`
  - `Lcom/xj/winemu/EmuComponents$isComponentNeed2Download$1;->invokeSuspend(Ljava/lang/Object;)Ljava/lang/Object;`
  - `Lcom/xj/winemu/EmuComponents$resetComponentDownloadedState$1;-><init>(Lcom/xj/winemu/EmuComponents;Lkotlin/coroutines/Continuation;)V`
  - `Lcom/xj/winemu/EmuComponents$resetComponentDownloadedState$1;->invokeSuspend(Ljava/lang/Object;)Ljava/lang/Object;`

### UI/app shell

- Shared tokens: `game` (735), `model` (273), `info` (248), `item` (223), `binding` (180), `steam` (145), `wine` (131), `inlined` (118), `settings` (83), `env` (82), `activity` (77), `confirm` (61)
- GameNative examples:
  - `Lapp/gamenative/ComposableSingletons$MainActivityKt$lambda$-779870676$1;->invoke(Landroidx/compose/runtime/Composer;I)V`
  - `Lapp/gamenative/ComposableSingletons$MainActivityKt$lambda$992852332$1$$ExternalSyntheticLambda0;-><init>(Landroidx/compose/runtime/MutableState;)V`
  - `Lapp/gamenative/ComposableSingletons$MainActivityKt$lambda$992852332$1$1$1;-><init>(Landroidx/activity/compose/ManagedActivityResultLauncher;Landroidx/compose/runtime/MutableState;Lkotlin/coroutines/Continuation;)V`
  - `Lapp/gamenative/ComposableSingletons$MainActivityKt$lambda$992852332$1;->$r8$lambda$vV2sw221QKlRPW51l1bHfxV6IEU(Landroidx/compose/runtime/MutableState;Z)Lkotlin/Unit;`
- GameHub examples:
  - `Lcom/winemu/core/controller/X11Controller;->C(Lcom/winemu/ui/X11View;Lcom/winemu/core/controller/X11Controller;Z)V`
  - `Lcom/winemu/core/controller/X11Controller;->c(Lcom/winemu/ui/X11View;Lcom/winemu/core/controller/X11Controller;Z)V`
  - `Lcom/winemu/core/controller/m;-><init>(Lcom/winemu/ui/X11View;Lcom/winemu/core/controller/X11Controller;)V`
  - `Lcom/winemu/ui/BootLogView$LogLine;-><init>(Ljava/lang/String;Lcom/winemu/ui/BootLogView$LogType;Ljava/util/List;)V`

## Merge Queue

1. `0044` (`done`): launch pipeline merge (GN+GH) under Runtime Contract with reason-coded forensics.
2. `0045` (`next`): graphics/driver decision merge with deterministic fallback chain.
3. `0046` (`next`): registry/runtime guarded deltas only (no asset-first side effects).
4. Keep content/download/UI modules in research-only lane until explicit promote decision.
