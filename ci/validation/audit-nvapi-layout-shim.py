#!/usr/bin/env python3
"""Audit NVAPI layout shim behavior for ARM64EC lanes."""

from __future__ import annotations

import argparse
import datetime as dt
import re
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class CheckResult:
    name: str
    ok: bool
    detail: str


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate NVAPI layout shim override order and fallback semantics in patch sources."
    )
    parser.add_argument(
        "--source",
        action="append",
        dest="sources",
        default=[],
        help="Patch file to audit (repeatable). Defaults to mainline + 0010 patch.",
    )
    parser.add_argument(
        "--output",
        default="-",
        help="Markdown output path ('-' for stdout).",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero when any audit check fails.",
    )
    return parser.parse_args()


def materialize_patch_text(raw: str) -> str:
    """Drop deleted hunk lines and strip diff prefixes for added/context lines."""
    out: list[str] = []
    for line in raw.splitlines():
        if line.startswith(("diff --git ", "index ", "@@ ")):
            out.append(line)
            continue
        if line.startswith(("--- ", "+++ ")):
            out.append(line)
            continue
        if line.startswith("-") and not line.startswith("--- "):
            continue
        if line.startswith("+") and not line.startswith("+++ "):
            out.append(line[1:])
            continue
        if line.startswith(" "):
            out.append(line[1:])
            continue
        out.append(line)
    return "\n".join(out) + "\n"


def find_first(pattern: str, text: str, flags: int = re.MULTILINE | re.DOTALL) -> re.Match[str] | None:
    return re.search(pattern, text, flags=flags)


def check_nvapi_layout(source: Path, text: str) -> list[CheckResult]:
    results: list[CheckResult] = []

    has_signals = any(
        token in text
        for token in (
            "applyUpscalerLibraryLayoutEnv",
            "AERO_DXVK_NVAPI_ARCH_GATE",
            "DXVK_ENABLE_NVAPI",
        )
    )
    if not has_signals:
        return [
            CheckResult(
                "source_has_nvapi_layout_logic",
                True,
                "NVAPI layout shim markers are not present in this source (skipped)",
            )
        ]

    layout_fn = find_first(
        r"private void applyUpscalerLibraryLayoutEnv\(\)\s*\{(?P<body>.*?)\n\s*private void logUpscalerModuleState",
        text,
    )
    if not layout_fn:
        return [CheckResult("layout_function_present", False, "applyUpscalerLibraryLayoutEnv block not found")]

    body = layout_fn.group("body")
    body_lower = body.lower()

    dxvk_merge = find_first(
        r'overrides\s*=\s*mergeDllOverrides\(\s*overrides,\s*"dxgi=native,builtin".*?"d3d8=native,builtin"\s*\);',
        body,
    )
    results.append(
        CheckResult(
            "dxvk_stack_override_block",
            dxvk_merge is not None,
            "dxvk overrides include dxgi..d3d8 native,builtin in one merge block",
        )
    )

    nvapi_native = find_first(
        r'if\s*\(nvapiEffective\)\s*\{\s*overrides\s*=\s*mergeDllOverrides\(overrides,\s*"nvapi=native,builtin",\s*"nvapi64=native,builtin"\);\s*layoutNvapi\s*=\s*"native";',
        body,
    )
    results.append(
        CheckResult(
            "nvapi_native_branch",
            nvapi_native is not None,
            "nvapi effective branch sets native,builtin override and layoutNvapi=native",
        )
    )

    nvapi_fallback_inner = find_first(
        r"\}\s*else\s*\{\s*overrides\s*=\s*mergeDllOverrides\(overrides,\s*\"nvapi=builtin,native\",\s*\"nvapi64=builtin,native\"\);\s*layoutNvapi\s*=\s*\"builtin_fallback\";",
        body,
    )
    results.append(
        CheckResult(
            "nvapi_inner_fallback_branch",
            nvapi_fallback_inner is not None,
            "nvapi non-effective branch uses builtin,native fallback in dxvk stack",
        )
    )

    nvapi_fallback_no_dxvk = find_first(
        r"\}\s*else if\s*\(nvapiRequested\)\s*\{\s*overrides\s*=\s*mergeDllOverrides\(overrides,\s*\"nvapi=builtin,native\",\s*\"nvapi64=builtin,native\"\);\s*layoutNvapi\s*=\s*\"builtin_fallback\";\s*layoutReason\s*=\s*\"nvapi_requested_without_dxvk\";",
        body,
    )
    results.append(
        CheckResult(
            "nvapi_no_dxvk_fallback",
            nvapi_fallback_no_dxvk is not None,
            "nvapi request without dxvk stack falls back to builtin,native and sets explicit reason",
        )
    )

    order_ok = bool(
        dxvk_merge
        and nvapi_native
        and dxvk_merge.start() < nvapi_native.start()
    )
    results.append(
        CheckResult(
            "override_order_dxvk_before_nvapi",
            order_ok,
            "dxvk override block appears before nvapi merge in layout function",
        )
    )

    arch_gate = find_first(
        r"boolean\s+dxvkNvapiArchGate\s*=\s*!runtimeArm64ec\s*\|\|\s*dxvkArtifactArm64ec;",
        text,
    )
    results.append(
        CheckResult(
            "arm64ec_arch_gate",
            arch_gate is not None,
            "arm64ec nvapi gate requires arm64ec dxvk artifact",
        )
    )

    arch_reason = find_first(
        r"dxvkNvapiArchReason\s*=\s*runtimeArm64ec\s*\?\s*\(dxvkArtifactArm64ec\s*\?\s*\"arm64ec_dxvk_matched\"\s*:\s*\"arm64ec_dxvk_missing\"\)\s*:\s*\"non_arm64ec_runtime\";",
        text,
    )
    results.append(
        CheckResult(
            "arm64ec_arch_reason",
            arch_reason is not None,
            "arch reason distinguishes arm64ec matched/missing vs non-arm64ec runtime",
        )
    )

    toggle_nvapi = find_first(
        r"if\s*\(dxvkNvapiEffective\)\s*\{\s*envVars\.put\(\"DXVK_ENABLE_NVAPI\",\s*\"1\"\);\s*\}\s*else\s*\{\s*envVars\.remove\(\"DXVK_ENABLE_NVAPI\"\);\s*\}",
        text,
    )
    results.append(
        CheckResult(
            "dxvk_enable_nvapi_toggle",
            toggle_nvapi is not None,
            "DXVK_ENABLE_NVAPI is only set when effective and removed on fallback",
        )
    )

    layout_sha = find_first(r"AERO_UPSCALE_LAYOUT_WINEDLLOVERRIDES_SHA256", text)
    results.append(
        CheckResult(
            "layout_override_sha_marker",
            layout_sha is not None,
            "layout override sha marker is emitted for forensic reproducibility",
        )
    )

    merge_map = find_first(r"LinkedHashMap<\s*String,\s*String\s*>\s+merged\s*=\s*new LinkedHashMap<>\(\);", text)
    results.append(
        CheckResult(
            "merge_preserves_key_order",
            merge_map is not None and "merged.put(dll, mode);" in text,
            "merge uses LinkedHashMap + key replacement semantics for deterministic override output",
        )
    )

    if "layoutlibs = \"dxgi,d3d11,d3d12,d3d12core,d3d9,d3d8\";" in body_lower:
        results.append(
            CheckResult(
                "layout_libs_dxvk_set",
                True,
                "layout libs include DXVK stack with d3d8 lane",
            )
        )
    else:
        results.append(
            CheckResult(
                "layout_libs_dxvk_set",
                False,
                "layout libs for dxvk stack not found",
            )
        )

    return results


def render_markdown(audits: list[tuple[Path, list[CheckResult]]]) -> str:
    ts = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    lines: list[str] = []
    lines.append("# NVAPI Layout Shim Compatibility Audit")
    lines.append("")
    lines.append(f"Generated: `{ts}`")
    lines.append("")
    lines.append("## Scope")
    lines.append("")
    for path, _ in audits:
        lines.append(f"- `{path.as_posix()}`")
    lines.append("")
    lines.append("## Results")
    lines.append("")

    failed = 0
    for path, checks in audits:
        lines.append(f"### {path.as_posix()}")
        lines.append("")
        for item in checks:
            status = "ok" if item.ok else "missing"
            if item.name == "source_has_nvapi_layout_logic" and item.ok:
                status = "skipped"
            if not item.ok:
                failed += 1
            lines.append(f"- `{item.name}`: `{status}` - {item.detail}")
        lines.append("")

    lines.append("## Summary")
    lines.append("")
    if failed:
        lines.append(f"- Failed checks: `{failed}`")
        lines.append("- Action: fix NVAPI override order/gating/fallback contract before release.")
    else:
        lines.append("- All NVAPI layout shim checks passed for audited sources.")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    root = Path(__file__).resolve().parents[2]

    default_sources = [
        root / "ci/winlator/patches/0001-mainline-full-stack-consolidated.patch",
        root / "ci/winlator/patches/0010-dxvk-capability-envelope-proton-fsr-gate-upscaler-matrix.patch",
    ]
    sources = [Path(p) for p in args.sources] if args.sources else default_sources

    existing_sources = [p.resolve() for p in sources if p.exists()]
    if not existing_sources:
        raise SystemExit("[nvapi-audit][error] no source patch files found")

    audits: list[tuple[Path, list[CheckResult]]] = []
    active_sources = 0
    for source in existing_sources:
        materialized = materialize_patch_text(source.read_text(encoding="utf-8", errors="ignore"))
        checks = check_nvapi_layout(source, materialized)
        if not (len(checks) == 1 and checks[0].name == "source_has_nvapi_layout_logic"):
            active_sources += 1
        audits.append((source, checks))

    report = render_markdown(audits)
    if args.output == "-":
        print(report, end="")
    else:
        out_path = Path(args.output)
        if not out_path.is_absolute():
            out_path = (root / out_path).resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(report, encoding="utf-8")
        print(f"[nvapi-audit] wrote {out_path}")

    failed = sum(1 for _, checks in audits for item in checks if not item.ok)
    if args.strict and active_sources == 0:
        return 1
    if failed and args.strict:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
