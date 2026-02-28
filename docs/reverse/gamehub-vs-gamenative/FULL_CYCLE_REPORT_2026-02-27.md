# Full Reflective Cycle Report

- Date: 2026-02-27T13:45:22+03:00
- GameHub APK: `/home/mikhail/GameHub+5.3.5.Lite_RM.mod_DocProv_mod.apk`
- GameNative APK: `/home/mikhail/gamenative-v0.7.2.apk`
- Capture serial: `edb0acd0`

## Static reverse outputs

- `docs/reverse/gamehub-5.3.5-native-cycle/`
- `docs/reverse/gamenative-0.7.2-native-cycle/`
- `docs/reverse/gamehub-vs-gamenative/CROSS_APK_NATIVE_COMPARISON.md`

## Runtime capture outputs

- GameNative: `out/app-forensics/20260227_134321_gamenative_startup_live`
- GameHub: `out/app-forensics/20260227_134508_gamehub_startup_live`
- Ae.solator: `out/app-forensics/20260227_133812_aerosolator_startup_live`

## Capture metrics: `20260227_134321_gamenative_startup_live`

- wineserver lines in ps_samples: **0**
- wine lines in ps_samples: **0**
- auth/login/token/steam lines: **182**
- x11/window teardown markers: **42**
- network timeout/dns markers: **6**

## Capture metrics: `20260227_134508_gamehub_startup_live`

- wineserver lines in ps_samples: **0**
- wine lines in ps_samples: **0**
- auth/login/token/steam lines: **30**
- x11/window teardown markers: **6**
- network timeout/dns markers: **5**

## Capture metrics: `20260227_133812_aerosolator_startup_live`

- wineserver lines in ps_samples: **56**
- wine lines in ps_samples: **374**
- auth/login/token/steam lines: **353**
- x11/window teardown markers: **191**
- network timeout/dns markers: **6**

## Compliance note

- This cycle does not include bypassing third-party authentication/account controls.
- Any gated container/emulation path that requires account rights is logged as an external constraint.
