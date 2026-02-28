# IDE-level ELF Reflective Report

- Label: `device_vkd3d_proton_3_0b_wcp`
- Source: `out/reverse/sources/device/vkd3d-proton-3.0b.wcp`
- Binary files (ELF+PE): **4**
- ELF files: **0**
- PE files: **4**
- Critical libs: **4**
- Machine distribution: `{'unknown': 4}`
- Cluster distribution: `{'graphics_translation': 2, 'wine_runtime_core': 2}`

## Top critical libraries

- `system32/d3d12.dll` [graphics_translation] needed=9 defined=0 undefined=0 jni=0 vk=0
- `system32/d3d12core.dll` [graphics_translation] needed=17 defined=0 undefined=0 jni=0 vk=0
- `syswow64/d3d12.dll` [wine_runtime_core] needed=9 defined=0 undefined=0 jni=0 vk=0
- `syswow64/d3d12core.dll` [wine_runtime_core] needed=17 defined=0 undefined=0 jni=0 vk=0
