# IDE-level ELF Reflective Report

- Label: `by_aero_so_benchmark_apk_device`
- Source: `out/reverse/sources/device/by_aero_so_benchmark.base.apk`
- Binary files (ELF+PE): **17**
- ELF files: **15**
- PE files: **2**
- Critical libs: **4**
- Machine distribution: `{'unknown': 2, 'AArch64': 15}`
- Cluster distribution: `{'misc': 10, 'cpu_translation': 4, 'audio': 3}`

## Top critical libraries

- `lib/arm64-v8a/libconscrypt_jni.so` [cpu_translation] needed=4 defined=3347 undefined=116 jni=1 vk=0
- `lib/arm64-v8a/libopenxr_loader.so` [cpu_translation] needed=5 defined=58 undefined=171 jni=0 vk=0
- `lib/arm64-v8a/libpatchelf.so` [cpu_translation] needed=3 defined=2623 undefined=127 jni=0 vk=0
- `lib/arm64-v8a/libpulsecore-13.0.so` [cpu_translation] needed=7 defined=642 undefined=297 jni=0 vk=0
