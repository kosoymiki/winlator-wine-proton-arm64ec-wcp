# IDE-level ELF Reflective Report

- Label: `com_miHoYo_GenshinImpact_apk_device`
- Source: `out/reverse/sources/device/com_miHoYo_GenshinImpact.base.apk`
- Binary files (ELF+PE): **39**
- ELF files: **39**
- PE files: **0**
- Critical libs: **12**
- Machine distribution: `{'ARM': 1, 'AArch64': 36, 'Intel 80386': 1, 'Advanced Micro Devices X86-64': 1}`
- Cluster distribution: `{'misc': 28, 'cpu_translation': 9, 'display_windowing': 2}`

## Top critical libraries

- `lib/arm64-v8a/libJieLiUsbOta.so` [cpu_translation] needed=4 defined=1936 undefined=113 jni=3 vk=0
- `lib/arm64-v8a/libavutil-55.so` [cpu_translation] needed=2 defined=489 undefined=81 jni=0 vk=0
- `lib/arm64-v8a/libffmpeg-command.so` [cpu_translation] needed=5 defined=585 undefined=409 jni=15 vk=0
- `lib/arm64-v8a/libffmpeg-org.so` [cpu_translation] needed=6 defined=10114 undefined=248 jni=0 vk=0
- `lib/arm64-v8a/libijkffmpeg.so` [cpu_translation] needed=4 defined=8588 undefined=197 jni=0 vk=0
- `lib/arm64-v8a/libijkplayer.so` [cpu_translation] needed=7 defined=831 undefined=359 jni=1 vk=0
- `lib/arm64-v8a/libjingle_peerconnection_so.so` [cpu_translation] needed=6 defined=183 undefined=240 jni=179 vk=0
- `lib/arm64-v8a/libswscale-4.so` [cpu_translation] needed=3 defined=35 undefined=28 jni=0 vk=0
- `lib/arm64-v8a/libumonitor.so` [cpu_translation] needed=4 defined=1 undefined=88 jni=1 vk=0
- `lib/arm64-v8a/libxjps-jni.so` [display_windowing] needed=7 defined=7661 undefined=258 jni=19 vk=0
- `lib/arm64-v8a/libxserver.so` [display_windowing] needed=7 defined=1 undefined=299 jni=1 vk=0
- `lib/arm64-v8a/libwinemu.so` [misc] needed=6 defined=39 undefined=145 jni=35 vk=0
