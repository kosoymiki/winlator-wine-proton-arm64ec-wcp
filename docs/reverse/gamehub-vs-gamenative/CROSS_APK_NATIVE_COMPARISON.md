# Cross APK Native Comparison

- A: `/home/mikhail/GameHub+5.3.5.Lite_RM.mod_DocProv_mod.apk`
- B: `/home/mikhail/gamenative-v0.7.2.apk`
- A libs: **35**
- B libs: **35**
- Common (abi/name): **2**
- Only A: **33**
- Only B: **33**
- Common with different sha256: **0**

## Tier1 overlap

- Tier1 common: 0
- Tier1 only A: 5
  - `arm64-v8a/libgpuinfo.so`
  - `arm64-v8a/libstreaming-core.so`
  - `arm64-v8a/libvfs.so`
  - `arm64-v8a/libwinemu.so`
  - `arm64-v8a/libxserver.so`
- Tier1 only B: 0

## High value transferable clusters

- runtime_orchestration
- virtual_fs
- gpu_probe
- translator_runtime

## Common library binary drift (sha mismatch, first 120)


## Reflective note

- This is native-library level parity and drift analysis.
- It is not equivalent to full decompilation of every Java/SMALI/native instruction.
- Use this report to target deterministic patch candidates in our patch stack.
