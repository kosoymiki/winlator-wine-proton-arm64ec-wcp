# Adrenotools Driver Sources Audit

- Generated: 2026-02-24T22:44:42+03:00
- Patch source: `ci/winlator/patches/0001-mainline-full-stack-consolidated.patch`
- Timeout per URL: 15s

## Summary

- This audit checks the driver sources referenced by the Adrenotools driver browser patch.
- It records URL health, redirect target, content type, and host IPs.
- IPs are point-in-time DNS results and may change (CDN / geo routing).

## Source Endpoints

| Kind | Author | URL | Host | IPs | Status | HTTP | Effective URL | Content-Type | Repo |
|---|---|---|---|---|---|---:|---|---|---|
| gamenative | GameNative | `https://gamenative.app/drivers/` | `gamenative.app` | `198.18.0.39,fc00::1b` | ok | 200 | `https://gamenative.app/drivers/` | `text/html; charset=utf-8` | `gamenative.app/drivers` |
| github | K11MCH1 | `https://github.com/K11MCH1/AdrenoToolsDrivers/releases` | `github.com` | `198.18.0.21,fc00::8` | ok | 200 | `https://github.com/K11MCH1/AdrenoToolsDrivers/releases` | `text/html; charset=utf-8` | `K11MCH1/AdrenoToolsDrivers` |
| github | MrPurple666 | `https://github.com/MrPurple666/purple-turnip/releases` | `github.com` | `198.18.0.21,fc00::8` | ok | 200 | `https://github.com/MrPurple666/purple-turnip/releases` | `text/html; charset=utf-8` | `MrPurple666/purple-turnip` |
| github | StevenMXZ | `https://github.com/StevenMXZ/freedreno_turnip-CI/releases` | `github.com` | `198.18.0.21,fc00::8` | ok | 200 | `https://github.com/StevenMXZ/freedreno_turnip-CI/releases` | `text/html; charset=utf-8` | `StevenMXZ/freedreno_turnip-CI` |
| github | Weab-chan | `https://github.com/Weab-chan/freedreno_turnip-CI/releases` | `github.com` | `198.18.0.21,fc00::8` | ok | 200 | `https://github.com/Weab-chan/freedreno_turnip-CI/releases` | `text/html; charset=utf-8` | `Weab-chan/freedreno_turnip-CI` |
| github | XForYouX | `https://github.com/XForYouX/Turnip_Driver/releases` | `github.com` | `198.18.0.21,fc00::8` | ok | 404 | `https://github.com/XForYouX/Turnip_Driver/releases` | `text/plain; charset=utf-8` | `XForYouX/Turnip_Driver` |
| github | whitebelyash | `https://github.com/whitebelyash/freedreno_turnip-CI/releases` | `github.com` | `198.18.0.21,fc00::8` | ok | 200 | `https://github.com/whitebelyash/freedreno_turnip-CI/releases` | `text/html; charset=utf-8` | `whitebelyash/freedreno_turnip-CI` |
| github | zoerakk | `https://github.com/zoerakk/qualcomm-adreno-driver/releases` | `github.com` | `198.18.0.21,fc00::8` | ok | 200 | `https://github.com/zoerakk/qualcomm-adreno-driver/releases` | `text/html; charset=utf-8` | `zoerakk/qualcomm-adreno-driver` |
| github-api | K11MCH1 | `https://api.github.com/repos/K11MCH1/AdrenoToolsDrivers/releases?per_page=1` | `api.github.com` | `198.18.0.23,fc00::a` | ok | 200 | `https://api.github.com/repos/K11MCH1/AdrenoToolsDrivers/releases?per_page=1` | `application/json; charset=utf-8` | `K11MCH1/AdrenoToolsDrivers` |
| github-api | MrPurple666 | `https://api.github.com/repos/MrPurple666/purple-turnip/releases?per_page=1` | `api.github.com` | `198.18.0.23,fc00::a` | ok | 200 | `https://api.github.com/repos/MrPurple666/purple-turnip/releases?per_page=1` | `application/json; charset=utf-8` | `MrPurple666/purple-turnip` |
| github-api | StevenMXZ | `https://api.github.com/repos/StevenMXZ/freedreno_turnip-CI/releases?per_page=1` | `api.github.com` | `198.18.0.23,fc00::a` | ok | 200 | `https://api.github.com/repos/StevenMXZ/freedreno_turnip-CI/releases?per_page=1` | `application/json; charset=utf-8` | `StevenMXZ/freedreno_turnip-CI` |
| github-api | Weab-chan | `https://api.github.com/repos/Weab-chan/freedreno_turnip-CI/releases?per_page=1` | `api.github.com` | `198.18.0.23,fc00::a` | ok | 200 | `https://api.github.com/repos/Weab-chan/freedreno_turnip-CI/releases?per_page=1` | `application/json; charset=utf-8` | `Weab-chan/freedreno_turnip-CI` |
| github-api | XForYouX | `https://api.github.com/repos/XForYouX/Turnip_Driver/releases?per_page=1` | `api.github.com` | `198.18.0.23,fc00::a` | ok | 404 | `https://api.github.com/repos/XForYouX/Turnip_Driver/releases?per_page=1` | `application/json; charset=utf-8` | `XForYouX/Turnip_Driver` |
| github-api | whitebelyash | `https://api.github.com/repos/whitebelyash/freedreno_turnip-CI/releases?per_page=1` | `api.github.com` | `198.18.0.23,fc00::a` | ok | 200 | `https://api.github.com/repos/whitebelyash/freedreno_turnip-CI/releases?per_page=1` | `application/json; charset=utf-8` | `whitebelyash/freedreno_turnip-CI` |
| github-api | zoerakk | `https://api.github.com/repos/zoerakk/qualcomm-adreno-driver/releases?per_page=1` | `api.github.com` | `198.18.0.23,fc00::a` | ok | 200 | `https://api.github.com/repos/zoerakk/qualcomm-adreno-driver/releases?per_page=1` | `application/json; charset=utf-8` | `zoerakk/qualcomm-adreno-driver` |
| github-api-fallback | XForYouX | `https://api.github.com/repos/XForYouX/Turnip-Driver/releases?per_page=1` | `api.github.com` | `198.18.0.23,fc00::a` | ok | 404 | `https://api.github.com/repos/XForYouX/Turnip-Driver/releases?per_page=1` | `application/json; charset=utf-8` | `XForYouX/Turnip-Driver` |
| github-api-fallback | XForYouX | `https://api.github.com/repos/XForYouX/Turnip_Driver/releases?per_page=1` | `api.github.com` | `198.18.0.23,fc00::a` | ok | 404 | `https://api.github.com/repos/XForYouX/Turnip_Driver/releases?per_page=1` | `application/json; charset=utf-8` | `XForYouX/Turnip_Driver` |
| github-api-fallback | XForYouX | `https://api.github.com/repos/XForYouX/freedreno_turnip-CI/releases?per_page=1` | `api.github.com` | `198.18.0.23,fc00::a` | ok | 404 | `https://api.github.com/repos/XForYouX/freedreno_turnip-CI/releases?per_page=1` | `application/json; charset=utf-8` | `XForYouX/freedreno_turnip-CI` |
| github-fallback | XForYouX | `https://github.com/XForYouX/Turnip-Driver/releases` | `github.com` | `198.18.0.21,fc00::8` | ok | 404 | `https://github.com/XForYouX/Turnip-Driver/releases` | `text/plain; charset=utf-8` | `XForYouX/Turnip-Driver` |
| github-fallback | XForYouX | `https://github.com/XForYouX/Turnip_Driver/releases` | `github.com` | `198.18.0.21,fc00::8` | ok | 404 | `https://github.com/XForYouX/Turnip_Driver/releases` | `text/plain; charset=utf-8` | `XForYouX/Turnip_Driver` |
| github-fallback | XForYouX | `https://github.com/XForYouX/freedreno_turnip-CI/releases` | `github.com` | `198.18.0.21,fc00::8` | ok | 404 | `https://github.com/XForYouX/freedreno_turnip-CI/releases` | `text/plain; charset=utf-8` | `XForYouX/freedreno_turnip-CI` |

## Hosts

| Host | IPs |
|---|---|
| `api.github.com` | `198.18.0.23,fc00::a` |
| `downloads.gamenative.app` | `198.18.0.40,fc00::1c` |
| `gamenative.app` | `198.18.0.39,fc00::1b` |
| `github.com` | `198.18.0.21,fc00::8` |

## Notes

- `github-api*` rows validate API reachability only; asset filtering is an app-side parser concern.
- If `XForYouX` is still empty in-app while endpoints are healthy, the issue is parser/filter logic, not link availability.
- `GameNative` uses HTML parsing; if `gamenative.app/drivers` changes layout, app parsing may fail even if the URL is reachable.
