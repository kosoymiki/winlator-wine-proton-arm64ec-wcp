# IDE-level ELF Reflective Report

- Label: `gamenative_apk_local`
- Source: `/home/mikhail/gamenative-v0.7.2.apk`
- Binary files (ELF+PE): **37**
- ELF files: **35**
- PE files: **2**
- Critical libs: **10**
- Machine distribution: `{'unknown': 2, 'AArch64': 22, 'ARM': 13}`
- Cluster distribution: `{'misc': 21, 'cpu_translation': 10, 'audio': 6}`

## Top critical libraries

- `lib/arm64-v8a/libc++_shared.so` [cpu_translation] needed=3 defined=2337 undefined=160 jni=0 vk=0
- `lib/arm64-v8a/libdummyvk.so` [cpu_translation] needed=6 defined=1930 undefined=127 jni=1 vk=5
- `lib/arm64-v8a/libextras.so` [cpu_translation] needed=8 defined=557 undefined=93 jni=10 vk=2
- `lib/arm64-v8a/libhook_impl.so` [cpu_translation] needed=5 defined=536 undefined=77 jni=0 vk=0
- `lib/arm64-v8a/libopenxr_loader.so` [cpu_translation] needed=5 defined=58 undefined=172 jni=0 vk=0
- `lib/arm64-v8a/libpatchelf.so` [cpu_translation] needed=3 defined=3056 undefined=146 jni=0 vk=0
- `lib/arm64-v8a/libpulsecore-13.0.so` [cpu_translation] needed=7 defined=642 undefined=297 jni=0 vk=0
- `lib/arm64-v8a/libvortekrenderer.so` [cpu_translation] needed=11 defined=856 undefined=142 jni=4 vk=6
- `lib/armeabi-v7a/libpulsecore-13.0.so` [cpu_translation] needed=7 defined=638 undefined=322 jni=0 vk=0
- `lib/armeabi-v7a/libsndfile.so` [cpu_translation] needed=3 defined=361 undefined=68 jni=0 vk=0
