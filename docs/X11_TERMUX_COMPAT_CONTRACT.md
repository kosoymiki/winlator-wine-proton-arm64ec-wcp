# X11 Termux Compat Contract

This document describes the optional X11 compatibility contract added for the
`termux_compat` backend mode.

## Goal

Keep Winlator's internal XServer as default while exposing a compatibility
profile that follows key `termux-x11` runtime assumptions:

- explicit backend selection
- TMPDIR/shared-tmp preflight
- optional XKB root validation
- structured forensic telemetry with fallback reason

## Preferences

Global settings keys:

- `x11_backend`: `internal` (default) or `termux_compat`
- `x11_require_shared_tmp`: `true|false`
- `x11_xkb_root`: optional absolute path, e.g. `/usr/share/X11/xkb`
- `x11_debug_level`: `0..3`

## Runtime Env Contract

Exported env keys:

- `WCP_X11_BACKEND`
- `WCP_X11_TERMUX_COMPAT`
- `WCP_X11_REQUIRE_SHARED_TMP`
- `WCP_X11_XKB_ROOT`
- `WCP_X11_DEBUG_LEVEL`
- `WCP_X11_PREFLIGHT_STATUS`
- `WCP_X11_PREFLIGHT_REASON`
- `WCP_X11_TMPDIR_EXPECTED`
- `WCP_X11_TMPDIR_EFFECTIVE`

When `termux_compat` is active:

- `TMPDIR` and `XDG_RUNTIME_DIR` are normalized if absent
- `XKB_CONFIG_ROOT` is exported when configured
- `TERMUX_X11_DEBUG` is exported when debug level is non-zero

## Forensic Events

Preflight emits:

- `X11_PREFLIGHT_OK` or `X11_PREFLIGHT_FAIL`
- `X11_TMPDIR_MISMATCH` (reason-specific)
- `X11_XKB_MISSING` (reason-specific)
- `X11_LOADER_FALLBACK` (compat requested but internal fallback applied)

Diagnostics UI provides a manual trigger (`Run X11 compat preflight`) that uses
the same preflight code path and writes `X11_PREFLIGHT_DIAG_UI`.
