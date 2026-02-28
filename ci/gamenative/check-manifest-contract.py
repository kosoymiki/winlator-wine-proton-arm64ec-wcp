#!/usr/bin/env python3
import argparse
import csv
import re
from pathlib import Path


ACTION_RE = re.compile(r"^(skip|apply|verify|backport_[a-z0-9_]+)$")
REQUIRED_TOKEN_RE = re.compile(r"^(wine|protonge|both|all)$")


def parse_required(raw: str) -> list:
    value = (raw or "").replace(" ", "").strip()
    if not value:
        return []
    return [token for token in value.split(",") if token]


def validate_required(raw: str) -> bool:
    for token in parse_required(raw):
        if not REQUIRED_TOKEN_RE.match(token):
            return False
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate GameNative patchset manifest contract")
    parser.add_argument("--manifest", default="ci/gamenative/patchsets/28c3a06/manifest.tsv")
    parser.add_argument("--patch-root", default="ci/gamenative/patchsets/28c3a06/android/patches")
    args = parser.parse_args()

    manifest = Path(args.manifest)
    patch_root = Path(args.patch_root)
    if not manifest.exists():
        raise SystemExit(f"[gn-manifest][error] missing manifest: {manifest}")
    if not patch_root.exists():
        raise SystemExit(f"[gn-manifest][error] missing patch root: {patch_root}")

    with manifest.open("r", encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        headers = reader.fieldnames or []
        expected_headers = ["patch", "wine_action", "protonge_action", "required", "note"]
        if headers != expected_headers:
            raise SystemExit(
                f"[gn-manifest][error] invalid headers: {headers}; expected {expected_headers}"
            )

        rows = list(reader)

    errors = []
    seen = set()
    by_patch = {}
    for idx, row in enumerate(rows, start=2):
        patch = (row.get("patch") or "").strip()
        if not patch or patch.startswith("#"):
            continue
        if patch in seen:
            errors.append(f"line {idx}: duplicate patch entry: {patch}")
        seen.add(patch)
        by_patch[patch] = row

        for key in ("wine_action", "protonge_action"):
            action = (row.get(key) or "").strip()
            if not ACTION_RE.match(action):
                errors.append(f"line {idx}: invalid {key}='{action}' for patch {patch}")

        required = (row.get("required") or "").strip()
        if required and not validate_required(required):
            errors.append(f"line {idx}: invalid required='{required}' for patch {patch}")

        patch_file = patch_root / patch
        if not patch_file.exists():
            errors.append(f"line {idx}: patch file missing: {patch_file}")

        required_tokens = set(parse_required(required))
        if ("wine" in required_tokens or "both" in required_tokens or "all" in required_tokens) and (
            (row.get("wine_action") or "").strip() == "skip"
        ):
            errors.append(f"line {idx}: patch {patch} is required for wine but action is skip")
        if ("protonge" in required_tokens or "both" in required_tokens or "all" in required_tokens) and (
            (row.get("protonge_action") or "").strip() == "skip"
        ):
            errors.append(f"line {idx}: patch {patch} is required for protonge but action is skip")

    def require_patch(name: str):
        if name not in by_patch:
            errors.append(f"missing required manifest row: {name}")

    require_patch("dlls_winex11_drv_mouse_c_wm_input_fix.patch")
    require_patch("programs_winebrowser_main_c.patch")
    require_patch("programs_winemenubuilder_winemenubuilder_c.patch")
    require_patch("test-bylaws/include_winternl_h.patch")

    mouse_row = by_patch.get("dlls_winex11_drv_mouse_c_wm_input_fix.patch")
    if mouse_row:
        if (mouse_row.get("required") or "").replace(" ", "") not in ("both", "all"):
            errors.append("dlls_winex11_drv_mouse_c_wm_input_fix.patch must be required for both targets")
        for key in ("wine_action", "protonge_action"):
            if (mouse_row.get(key) or "").strip() != "backport_winex11_mouse_wm_input":
                errors.append(f"dlls_winex11_drv_mouse_c_wm_input_fix.patch expects {key}=backport_winex11_mouse_wm_input")

    browser_row = by_patch.get("programs_winebrowser_main_c.patch")
    if browser_row:
        if (browser_row.get("wine_action") or "").strip() == "skip" or (browser_row.get("protonge_action") or "").strip() == "skip":
            errors.append("programs_winebrowser_main_c.patch cannot be skip for either target")

    menubuilder_row = by_patch.get("programs_winemenubuilder_winemenubuilder_c.patch")
    if menubuilder_row:
        if (menubuilder_row.get("required") or "").replace(" ", "") not in ("both", "all"):
            errors.append("programs_winemenubuilder_winemenubuilder_c.patch must be required for both targets")

    winternl_row = by_patch.get("test-bylaws/include_winternl_h.patch")
    if winternl_row:
        if (winternl_row.get("wine_action") or "").strip() not in ("backport_include_winternl_fex", "verify"):
            errors.append("test-bylaws/include_winternl_h.patch must keep wine_action as backport_include_winternl_fex or verify")

    if errors:
        print("[gn-manifest][error] contract validation failed:")
        for item in errors:
            print(f"[gn-manifest][error] - {item}")
        raise SystemExit(1)

    print(f"[gn-manifest] contract ok: rows={len(by_patch)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
