# GameNative v0.7.2 Runtime Transfer Matrix (for Aero.so mainline)

- Generated (UTC): `2026-02-25 14:35:19`
- Source APK: `/home/mikhail/gamenative-v0.7.2.apk`
- Source methods file: `/home/mikhail/gamenative-v0.7.2_reverse_20260225_143304/focus/methods_focus.txt`
- Source edges file: `/home/mikhail/gamenative-v0.7.2_reverse_20260225_143304/focus/call_edges_runtime_graphics.tsv`
- Mainline policy: `bionic-native + external-only runtime`
- Plan slot: `pre-0044`

## Extraction Snapshot

- All classes: `28743`
- All methods: `307554`
- Focus classes: `3878`
- Focus methods: `19568`
- Focus call edges (unique): `67046`
- Focus outbound/inbound/internal events (total): `114748`
- Runtime+graphics call edges (unique): `6881`
- Runtime+graphics outbound/inbound/internal events (total): `12475`

## Transfer Decisions

| Module | Decision | Methods | Edge events | Target in Aero.so | Existing anchor |
| --- | --- | ---: | ---: | --- | --- |
| `Box64/FEX translator config` | `port_contract` | 213 | 1073 | Translator preset/profile contract + runtime-profile migration rules | `ci/winlator/patches/0030,0037,0039,0040,0043` |
| `Launch pipeline orchestration` | `adapt_urc` | 630 | 1298 | URC launch preflight + deterministic env submit + forensic reasons | `XServerDisplayActivity + GuestProgramLauncherComponent (0044 queue)` |
| `Graphics + driver decision tree` | `adapt_urc` | 366 | 1939 | Adrenotools/Vulkan decision telemetry and fallback reasons | `AdrenotoolsManager + driver probe path + vulkan fallback` |
| `Registry/runtime mutation layer` | `adapt_guarded` | 37 | 598 | Guarded compat deltas with forensic markers | `ContainerNormalizer + registry/compat path` |
| `Content download/install app layers` | `reject_mainline` | 193 | 581 | Keep out of runtime mainline (research-only) | `Research lane only` |
| `UI/compose/app-shell layers` | `reject_mainline` | 10114 | 2008 | No direct port into runtime core | `Optional UI lane only` |
| `Unclassified` | `manual-review` | 8015 | 4978 | Keep in research lane | `docs/REFLECTIVE_HARVARD_LEDGER.md` |

## High-Value Signatures (examples)

### Box64/FEX translator config

Decision: `port_contract`

- `Lapp/gamenative/PrefManager;->getFexcoreMultiBlock()Ljava/lang/String;`
- `Lapp/gamenative/PrefManager;->getFexcorePreset()Ljava/lang/String;`
- `Lapp/gamenative/PrefManager;->getFexcoreTSOMode()Ljava/lang/String;`
- `Lapp/gamenative/PrefManager;->getFexcoreVersion()Ljava/lang/String;`
- `Lapp/gamenative/PrefManager;->getFexcoreX87Mode()Ljava/lang/String;`
- `Lapp/gamenative/PrefManager;->setFexcoreMultiBlock(Ljava/lang/String;)V`
- `Lapp/gamenative/PrefManager;->setFexcorePreset(Ljava/lang/String;)V`
- `Lapp/gamenative/PrefManager;->setFexcoreTSOMode(Ljava/lang/String;)V`
- `Lapp/gamenative/PrefManager;->setFexcoreVersion(Ljava/lang/String;)V`
- `Lapp/gamenative/PrefManager;->setFexcoreX87Mode(Ljava/lang/String;)V`
- `Lapp/gamenative/ui/component/dialog/ComposableSingletons$FEXCorePresetsDialogKt$lambda$-1057815997$1;-><clinit>()V`
- `Lapp/gamenative/ui/component/dialog/ComposableSingletons$FEXCorePresetsDialogKt$lambda$-1057815997$1;-><init>()V`
- `Lapp/gamenative/ui/component/dialog/ComposableSingletons$FEXCorePresetsDialogKt$lambda$-1057815997$1;->invoke(Landroidx/compose/runtime/Composer;I)V`
- `Lapp/gamenative/ui/component/dialog/ComposableSingletons$FEXCorePresetsDialogKt$lambda$-1057815997$1;->invoke(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;`
- `Lapp/gamenative/ui/component/dialog/ComposableSingletons$FEXCorePresetsDialogKt$lambda$-1263900247$1;-><clinit>()V`
- `Lapp/gamenative/ui/component/dialog/ComposableSingletons$FEXCorePresetsDialogKt$lambda$-1263900247$1;-><init>()V`
- `Lapp/gamenative/ui/component/dialog/ComposableSingletons$FEXCorePresetsDialogKt$lambda$-1263900247$1;->invoke(Landroidx/compose/runtime/Composer;I)V`
- `Lapp/gamenative/ui/component/dialog/ComposableSingletons$FEXCorePresetsDialogKt$lambda$-1263900247$1;->invoke(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;`
- `Lapp/gamenative/ui/component/dialog/ComposableSingletons$FEXCorePresetsDialogKt$lambda$-1465305365$1;-><clinit>()V`
- `Lapp/gamenative/ui/component/dialog/ComposableSingletons$FEXCorePresetsDialogKt$lambda$-1465305365$1;-><init>()V`

### Launch pipeline orchestration

Decision: `adapt_urc`

- `Lapp/gamenative/MainActivity$Companion;->consumePendingLaunchRequest()Lapp/gamenative/utils/IntentLaunchManager$LaunchRequest;`
- `Lapp/gamenative/MainActivity$Companion;->setPendingLaunchRequest(Lapp/gamenative/utils/IntentLaunchManager$LaunchRequest;)V`
- `Lapp/gamenative/MainActivity$handleLaunchIntent$1;-><init>(Lapp/gamenative/utils/IntentLaunchManager$LaunchRequest;Lkotlin/coroutines/Continuation;)V`
- `Lapp/gamenative/MainActivity;->access$getPendingLaunchRequest$cp()Lapp/gamenative/utils/IntentLaunchManager$LaunchRequest;`
- `Lapp/gamenative/MainActivity;->access$setPendingLaunchRequest$cp(Lapp/gamenative/utils/IntentLaunchManager$LaunchRequest;)V`
- `Lapp/gamenative/service/SteamService$Companion$beginLaunchApp$1;-><init>(ZILapp/gamenative/enums/SaveLocation;Lkotlinx/coroutines/CoroutineScope;Lkotlin/jvm/functions/Function1;Lkotlin/jvm/functions/Function2;ZLkotlin/coroutines/Continuation;)V`
- `Lapp/gamenative/service/SteamService$Companion$beginLaunchApp$1;->create(Ljava/lang/Object;Lkotlin/coroutines/Continuation;)Lkotlin/coroutines/Continuation;`
- `Lapp/gamenative/service/SteamService$Companion$beginLaunchApp$1;->invoke(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;`
- `Lapp/gamenative/service/SteamService$Companion$beginLaunchApp$1;->invoke(Lkotlinx/coroutines/CoroutineScope;Lkotlin/coroutines/Continuation;)Ljava/lang/Object;`
- `Lapp/gamenative/service/SteamService$Companion$beginLaunchApp$1;->invokeSuspend(Ljava/lang/Object;)Ljava/lang/Object;`
- `Lapp/gamenative/service/SteamService$Companion;->beginLaunchApp(ILkotlinx/coroutines/CoroutineScope;ZLapp/gamenative/enums/SaveLocation;Lkotlin/jvm/functions/Function1;ZLkotlin/jvm/functions/Function2;)Lkotlinx/coroutines/Deferred;`
- `Lapp/gamenative/service/gog/GOGManager;->getGogWineStartCommand(Lapp/gamenative/data/LibraryItem;Lcom/winlator/container/Container;ZLapp/gamenative/data/LaunchInfo;Lcom/winlator/core/envvars/EnvVars;Lcom/winlator/xenvironment/components/GuestProgramLauncherComponent;)Ljava/lang/String;`
- `Lapp/gamenative/service/gog/GOGService$Companion;->getGogWineStartCommand(Lapp/gamenative/data/LibraryItem;Lcom/winlator/container/Container;ZLapp/gamenative/data/LaunchInfo;Lcom/winlator/core/envvars/EnvVars;Lcom/winlator/xenvironment/components/GuestProgramLauncherComponent;)Ljava/lang/String;`
- `Lapp/gamenative/ui/PluviaMainKt$preLaunchApp$1$$ExternalSyntheticLambda0;-><init>(Lkotlin/jvm/functions/Function1;)V`
- `Lapp/gamenative/ui/PluviaMainKt$preLaunchApp$1$$ExternalSyntheticLambda0;->invoke(Ljava/lang/Object;)Ljava/lang/Object;`
- `Lapp/gamenative/ui/PluviaMainKt$preLaunchApp$1$$ExternalSyntheticLambda1;-><init>(Lkotlin/jvm/functions/Function1;)V`
- `Lapp/gamenative/ui/PluviaMainKt$preLaunchApp$1$$ExternalSyntheticLambda1;->invoke(Ljava/lang/Object;)Ljava/lang/Object;`
- `Lapp/gamenative/ui/PluviaMainKt$preLaunchApp$1$$ExternalSyntheticLambda2;-><init>(Lkotlin/jvm/functions/Function1;)V`
- `Lapp/gamenative/ui/PluviaMainKt$preLaunchApp$1$$ExternalSyntheticLambda2;->invoke(Ljava/lang/Object;)Ljava/lang/Object;`
- `Lapp/gamenative/ui/PluviaMainKt$preLaunchApp$1$$ExternalSyntheticLambda3;-><init>(Lkotlin/jvm/functions/Function1;)V`

### Graphics + driver decision tree

Decision: `adapt_urc`

- `Lapp/gamenative/PrefManager;->getAudioDriver()Ljava/lang/String;`
- `Lapp/gamenative/PrefManager;->getGraphicsDriver()Ljava/lang/String;`
- `Lapp/gamenative/PrefManager;->getGraphicsDriverConfig()Ljava/lang/String;`
- `Lapp/gamenative/PrefManager;->getGraphicsDriverVersion()Ljava/lang/String;`
- `Lapp/gamenative/PrefManager;->setAudioDriver(Ljava/lang/String;)V`
- `Lapp/gamenative/PrefManager;->setGraphicsDriver(Ljava/lang/String;)V`
- `Lapp/gamenative/PrefManager;->setGraphicsDriverConfig(Ljava/lang/String;)V`
- `Lapp/gamenative/PrefManager;->setGraphicsDriverVersion(Ljava/lang/String;)V`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt;->ContainerConfigDialog$getVersionsForDriver(Ljava/util/List;Ljava/util/List;Ljava/util/List;Ljava/util/List;Ljava/util/List;Ljava/util/List;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableIntState;)Ljava/util/List;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt;->ContainerConfigDialog$launchManifestDriverInstall(Landroid/content/Context;Lkotlinx/coroutines/CoroutineScope;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Ljava/util/List;Ljava/util/List;Ljava/util/List;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Lapp/gamenative/utils/ManifestEntry;Lkotlin/jvm/functions/Function0;)V`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigState;->getAdrenotoolsTurnipChecked()Landroidx/compose/runtime/MutableState;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigState;->getAudioDriverIndex()Landroidx/compose/runtime/MutableIntState;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigState;->getAudioDrivers()Ljava/util/List;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigState;->getBionicDriverIndex()Landroidx/compose/runtime/MutableIntState;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigState;->getBionicGraphicsDrivers()Ljava/util/List;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigState;->getGetVersionsForDriver()Lkotlin/jvm/functions/Function0;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigState;->getGraphicsDriverIndex()Landroidx/compose/runtime/MutableIntState;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigState;->getGraphicsDriverVersionIndex()Landroidx/compose/runtime/MutableIntState;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigState;->getGraphicsDrivers()Landroidx/compose/runtime/MutableState;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigState;->getLaunchManifestDriverInstall()Lkotlin/jvm/functions/Function2;`

### Registry/runtime mutation layer

Decision: `adapt_guarded`

- `Lcom/winlator/core/WineRegistryEditor$1;-><init>(Lcom/winlator/core/WineRegistryEditor;)V`
- `Lcom/winlator/core/WineRegistryEditor$1;->applyAsInt(Ljava/lang/Object;)I`
- `Lcom/winlator/core/WineRegistryEditor$Location;->-$$Nest$fgettag(Lcom/winlator/core/WineRegistryEditor$Location;)Ljava/lang/Object;`
- `Lcom/winlator/core/WineRegistryEditor$Location;->-$$Nest$fputtag(Lcom/winlator/core/WineRegistryEditor$Location;Ljava/lang/Object;)V`
- `Lcom/winlator/core/WineRegistryEditor$Location;-><init>(III)V`
- `Lcom/winlator/core/WineRegistryEditor$Location;->equals(Ljava/lang/Object;)Z`
- `Lcom/winlator/core/WineRegistryEditor$Location;->length()I`
- `Lcom/winlator/core/WineRegistryEditor$Location;->toString()Ljava/lang/String;`
- `Lcom/winlator/core/WineRegistryEditor;-><init>(Ljava/io/File;)V`
- `Lcom/winlator/core/WineRegistryEditor;->close()V`
- `Lcom/winlator/core/WineRegistryEditor;->createKey(Ljava/lang/String;)Lcom/winlator/core/WineRegistryEditor$Location;`
- `Lcom/winlator/core/WineRegistryEditor;->escape(Ljava/lang/String;)Ljava/lang/String;`
- `Lcom/winlator/core/WineRegistryEditor;->getDwordValue(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Integer;)Ljava/lang/Integer;`
- `Lcom/winlator/core/WineRegistryEditor;->getKeyLocation(Ljava/lang/String;)Lcom/winlator/core/WineRegistryEditor$Location;`
- `Lcom/winlator/core/WineRegistryEditor;->getKeyLocation(Ljava/lang/String;Z)Lcom/winlator/core/WineRegistryEditor$Location;`
- `Lcom/winlator/core/WineRegistryEditor;->getParentKeyLocation(Ljava/lang/String;)Lcom/winlator/core/WineRegistryEditor$Location;`
- `Lcom/winlator/core/WineRegistryEditor;->getRawValue(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;`
- `Lcom/winlator/core/WineRegistryEditor;->getStringValue(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;`
- `Lcom/winlator/core/WineRegistryEditor;->getValueLocation(Lcom/winlator/core/WineRegistryEditor$Location;Ljava/lang/String;)Lcom/winlator/core/WineRegistryEditor$Location;`
- `Lcom/winlator/core/WineRegistryEditor;->lineHasName(Ljava/lang/String;)Z`

### Content download/install app layers

Decision: `reject_mainline`

- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt$ContainerConfigDialog$launchManifestInstall$1$$ExternalSyntheticLambda0;-><init>(Lkotlinx/coroutines/CoroutineScope;Landroidx/compose/runtime/MutableState;)V`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt$ContainerConfigDialog$launchManifestInstall$1$$ExternalSyntheticLambda0;->invoke(Ljava/lang/Object;)Ljava/lang/Object;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt$ContainerConfigDialog$launchManifestInstall$1$result$1$1;-><init>(FLandroidx/compose/runtime/MutableState;Lkotlin/coroutines/Continuation;)V`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt$ContainerConfigDialog$launchManifestInstall$1$result$1$1;->create(Ljava/lang/Object;Lkotlin/coroutines/Continuation;)Lkotlin/coroutines/Continuation;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt$ContainerConfigDialog$launchManifestInstall$1$result$1$1;->invoke(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt$ContainerConfigDialog$launchManifestInstall$1$result$1$1;->invoke(Lkotlinx/coroutines/CoroutineScope;Lkotlin/coroutines/Continuation;)Ljava/lang/Object;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt$ContainerConfigDialog$launchManifestInstall$1$result$1$1;->invokeSuspend(Ljava/lang/Object;)Ljava/lang/Object;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt$ContainerConfigDialog$launchManifestInstall$1;->$r8$lambda$1HGaJtYuNEvmGziquKZrgcmrNb8(Lkotlinx/coroutines/CoroutineScope;Landroidx/compose/runtime/MutableState;F)Lkotlin/Unit;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt$ContainerConfigDialog$launchManifestInstall$1;-><init>(Landroid/content/Context;Lapp/gamenative/utils/ManifestEntry;ZLcom/winlator/contents/ContentProfile$ContentType;Lkotlin/jvm/functions/Function0;Lkotlinx/coroutines/CoroutineScope;Landroidx/compose/runtime/MutableState;Ljava/util/List;Ljava/util/List;Ljava/util/List;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Lkotlin/coroutines/Continuation;)V`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt$ContainerConfigDialog$launchManifestInstall$1;->create(Ljava/lang/Object;Lkotlin/coroutines/Continuation;)Lkotlin/coroutines/Continuation;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt$ContainerConfigDialog$launchManifestInstall$1;->invoke(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt$ContainerConfigDialog$launchManifestInstall$1;->invoke(Lkotlinx/coroutines/CoroutineScope;Lkotlin/coroutines/Continuation;)Ljava/lang/Object;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt$ContainerConfigDialog$launchManifestInstall$1;->invokeSuspend$lambda$0(Lkotlinx/coroutines/CoroutineScope;Landroidx/compose/runtime/MutableState;F)Lkotlin/Unit;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt$ContainerConfigDialog$launchManifestInstall$1;->invokeSuspend(Ljava/lang/Object;)Ljava/lang/Object;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt;->$r8$lambda$EbKUneOhrcEBvClRY6ALIkTCYl8(Landroid/content/Context;Lkotlinx/coroutines/CoroutineScope;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Ljava/util/List;Ljava/util/List;Ljava/util/List;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Lapp/gamenative/utils/ManifestEntry;Lkotlin/jvm/functions/Function0;)Lkotlin/Unit;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt;->$r8$lambda$_OI-2gZYnqOVOqSoqeNi6bxevW0(Landroid/content/Context;Lkotlinx/coroutines/CoroutineScope;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Ljava/util/List;Ljava/util/List;Ljava/util/List;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Lapp/gamenative/utils/ManifestEntry;Ljava/lang/String;ZLcom/winlator/contents/ContentProfile$ContentType;Lkotlin/jvm/functions/Function0;)Lkotlin/Unit;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt;->$r8$lambda$k3cT5fxqHQmZ8k4RnNbKQ26njI8(Landroid/content/Context;Lkotlinx/coroutines/CoroutineScope;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Ljava/util/List;Ljava/util/List;Ljava/util/List;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Lapp/gamenative/utils/ManifestEntry;Lcom/winlator/contents/ContentProfile$ContentType;Lkotlin/jvm/functions/Function0;)Lkotlin/Unit;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt;->ContainerConfigDialog$lambda$276$lambda$275(Landroid/content/Context;Lkotlinx/coroutines/CoroutineScope;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Ljava/util/List;Ljava/util/List;Ljava/util/List;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Lapp/gamenative/utils/ManifestEntry;Ljava/lang/String;ZLcom/winlator/contents/ContentProfile$ContentType;Lkotlin/jvm/functions/Function0;)Lkotlin/Unit;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt;->ContainerConfigDialog$lambda$278$lambda$277(Landroid/content/Context;Lkotlinx/coroutines/CoroutineScope;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Ljava/util/List;Ljava/util/List;Ljava/util/List;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Lapp/gamenative/utils/ManifestEntry;Lcom/winlator/contents/ContentProfile$ContentType;Lkotlin/jvm/functions/Function0;)Lkotlin/Unit;`
- `Lapp/gamenative/ui/component/dialog/ContainerConfigDialogKt;->ContainerConfigDialog$lambda$280$lambda$279(Landroid/content/Context;Lkotlinx/coroutines/CoroutineScope;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Ljava/util/List;Ljava/util/List;Ljava/util/List;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Landroidx/compose/runtime/MutableState;Lapp/gamenative/utils/ManifestEntry;Lkotlin/jvm/functions/Function0;)Lkotlin/Unit;`

### UI/compose/app-shell layers

Decision: `reject_mainline`

- `Lapp/gamenative/ComposableSingletons$MainActivityKt$lambda$-779870676$1;->invoke(Landroidx/compose/runtime/Composer;I)V`
- `Lapp/gamenative/ComposableSingletons$MainActivityKt$lambda$992852332$1$$ExternalSyntheticLambda0;-><init>(Landroidx/compose/runtime/MutableState;)V`
- `Lapp/gamenative/ComposableSingletons$MainActivityKt$lambda$992852332$1$1$1;-><init>(Landroidx/activity/compose/ManagedActivityResultLauncher;Landroidx/compose/runtime/MutableState;Lkotlin/coroutines/Continuation;)V`
- `Lapp/gamenative/ComposableSingletons$MainActivityKt$lambda$992852332$1;->$r8$lambda$vV2sw221QKlRPW51l1bHfxV6IEU(Landroidx/compose/runtime/MutableState;Z)Lkotlin/Unit;`
- `Lapp/gamenative/ComposableSingletons$MainActivityKt$lambda$992852332$1;->access$invoke$lambda$1(Landroidx/compose/runtime/MutableState;)Z`
- `Lapp/gamenative/ComposableSingletons$MainActivityKt$lambda$992852332$1;->invoke$lambda$1(Landroidx/compose/runtime/MutableState;)Z`
- `Lapp/gamenative/ComposableSingletons$MainActivityKt$lambda$992852332$1;->invoke$lambda$2(Landroidx/compose/runtime/MutableState;Z)V`
- `Lapp/gamenative/ComposableSingletons$MainActivityKt$lambda$992852332$1;->invoke$lambda$4$lambda$3(Landroidx/compose/runtime/MutableState;Z)Lkotlin/Unit;`
- `Lapp/gamenative/ComposableSingletons$MainActivityKt$lambda$992852332$1;->invoke(Landroidx/compose/runtime/Composer;I)V`
- `Lapp/gamenative/PluviaApp$Companion;->getOnDestinationChangedListener$app_release()Landroidx/navigation/NavController$OnDestinationChangedListener;`
- `Lapp/gamenative/PluviaApp$Companion;->setOnDestinationChangedListener$app_release(Landroidx/navigation/NavController$OnDestinationChangedListener;)V`
- `Lapp/gamenative/PluviaApp;->access$getOnDestinationChangedListener$cp()Landroidx/navigation/NavController$OnDestinationChangedListener;`
- `Lapp/gamenative/PluviaApp;->access$setOnDestinationChangedListener$cp(Landroidx/navigation/NavController$OnDestinationChangedListener;)V`
- `Lapp/gamenative/PrefManager;->getLibraryLayout()Lapp/gamenative/ui/enums/PaneType;`
- `Lapp/gamenative/PrefManager;->getStartScreen()Lapp/gamenative/ui/enums/HomeDestination;`
- `Lapp/gamenative/PrefManager;->setLibraryLayout(Lapp/gamenative/ui/enums/PaneType;)V`
- `Lapp/gamenative/ui/PluviaMainKt$$ExternalSyntheticLambda0;-><init>()V`
- `Lapp/gamenative/ui/PluviaMainKt$$ExternalSyntheticLambda0;->invoke()Ljava/lang/Object;`
- `Lapp/gamenative/ui/PluviaMainKt$$ExternalSyntheticLambda10;-><init>(Landroid/content/Context;Lapp/gamenative/ui/model/MainViewModel;Lkotlin/jvm/functions/Function1;Landroidx/compose/runtime/State;Landroidx/compose/runtime/MutableState;)V`
- `Lapp/gamenative/ui/PluviaMainKt$$ExternalSyntheticLambda10;->invoke()Ljava/lang/Object;`

## Anti-Conflict Rules (GN v0.7.2 vs GameHub)

1. Shared runtime behavior is integrated only through URC + forensic fields.
2. Any path implying bundled runtime payload stays out of mainline.
3. Launch/environment changes must preserve deterministic fallback reasons.
4. If GN/GH diverge, choose lower-regression behavior with explicit telemetry.

## 0044 Queue (post-analysis)

1. Integrate launch orchestration deltas into URC preflight path (`XServerDisplayActivity` + launcher).
2. Add reason-coded guardrails for runtime/profile mismatch decisions.
3. Keep content/UI/install layers in research lane unless explicitly promoted.

