#!/usr/bin/env python3
"""Audit Turnip strict-bind fallback contract for runtime patches."""

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
        description="Validate strict Turnip bind fallback behavior and conflict markers in patch sources."
    )
    parser.add_argument(
        "--source",
        action="append",
        dest="sources",
        default=[],
        help="Patch source to audit (repeatable). Defaults to 0003 + 0010 patch.",
    )
    parser.add_argument(
        "--output",
        default="-",
        help="Markdown output path ('-' for stdout).",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero when any required check fails.",
    )
    return parser.parse_args()


def materialize_patch_text(raw: str) -> str:
    out: list[str] = []
    for line in raw.splitlines():
        if line.startswith(("diff --git ", "index ", "@@ ", "--- ", "+++ ")):
            out.append(line)
            continue
        if line.startswith("-"):
            continue
        if line.startswith("+"):
            out.append(line[1:])
            continue
        if line.startswith(" "):
            out.append(line[1:])
            continue
        out.append(line)
    return "\n".join(out) + "\n"


def find_first(pattern: str, text: str, flags: int = re.MULTILINE | re.DOTALL) -> re.Match[str] | None:
    return re.search(pattern, text, flags=flags)


def has_turnip_bind_logic(text: str) -> bool:
    return all(
        token in text
        for token in (
            "AERO_TURNIP_BIND_MODE",
            "AERO_TURNIP_BIND_VERDICT",
            "TURNIP_RUNTIME_BOUND",
        )
    )


def has_turnip_conflict_logic(text: str) -> bool:
    return "turnip_bind_not_strict" in text and "resolveRuntimeLibraryConflicts" in text


def check_turnip_bind_source(text: str) -> list[CheckResult]:
    checks: list[CheckResult] = []

    checks.append(
        CheckResult(
            "default_bind_mode_strict",
            find_first(r'turnipBindMode\s*=\s*"strict";', text) is not None,
            "turnip bind mode defaults to strict",
        )
    )

    checks.append(
        CheckResult(
            "bind_mode_normalization",
            find_first(
                r'if\s*\(!turnipBindMode\.equals\("strict"\)\s*&&\s*!turnipBindMode\.equals\("relaxed"\)\)\s*\{\s*turnipBindMode\s*=\s*"strict";',
                text,
            )
            is not None,
            "only strict/relaxed accepted; invalid values normalized to strict",
        )
    )

    checks.append(
        CheckResult(
            "strict_mode_blocks_non_integrated",
            find_first(
                r'else if\s*\("strict"\.equals\(turnipBindMode\)\)\s*\{\s*turnipBindVerdict\s*=\s*"mirror_blocked";',
                text,
            )
            is not None,
            "strict mode blocks non-integrated turnip providers",
        )
    )

    checks.append(
        CheckResult(
            "strict_mode_fallback_reason",
            find_first(r'WINLATOR_DRIVER_FALLBACK_REASON".*?non_integrated_turnip_provider', text) is not None,
            "strict-mode mirror block appends explicit non_integrated_turnip_provider fallback reason",
        )
    )

    checks.append(
        CheckResult(
            "relaxed_mode_allows_mirror",
            find_first(r"turnipBindVerdict\s*=\s*\"mirror_allowed\";", text) is not None,
            "relaxed mode keeps mirror provider allowed",
        )
    )

    checks.append(
        CheckResult(
            "bind_markers_exported",
            all(token in text for token in ("AERO_TURNIP_PROVIDER", "AERO_TURNIP_BIND_MODE", "AERO_TURNIP_BIND_VERDICT")),
            "turnip provider/bind mode/verdict markers exported to runtime env",
        )
    )

    checks.append(
        CheckResult(
            "forensic_turnip_runtime_bound",
            find_first(
                r'ForensicLogger\.logEvent\(.*?"TURNIP_RUNTIME_BOUND".*?"turnip_bind_verdict",\s*turnipBindVerdict',
                text,
            )
            is not None,
            "TURNIP_RUNTIME_BOUND forensic event emitted with bind verdict fields",
        )
    )

    checks.append(
        CheckResult(
            "forensic_warn_on_block_or_system",
            find_first(
                r'\("mirror_blocked"\.equals\(turnipBindVerdict\)\s*\|\|\s*useSystemVulkan\)\s*\?\s*"warn"\s*:\s*"info"',
                text,
            )
            is not None,
            "forensic severity escalates to warn for mirror_blocked/system_vulkan paths",
        )
    )

    return checks


def check_turnip_conflict_source(text: str) -> list[CheckResult]:
    checks: list[CheckResult] = []

    checks.append(
        CheckResult(
            "turnip_provider_missing_conflict",
            "conflicts.add(\"turnip_provider_missing\")" in text,
            "conflict classification includes missing turnip provider marker",
        )
    )

    checks.append(
        CheckResult(
            "turnip_verdict_missing_conflict",
            "conflicts.add(\"turnip_bind_verdict_missing\")" in text,
            "conflict classification includes missing turnip bind verdict marker",
        )
    )

    checks.append(
        CheckResult(
            "turnip_not_strict_conflict",
            find_first(
                r"turnipBindVerdict\.contains\(\"fallback\"\)\s*\|\|\s*turnipBindVerdict\.contains\(\"mismatch\"\)",
                text,
            )
            is not None
            and "conflicts.add(\"turnip_bind_not_strict\")" in text,
            "fallback/mismatch verdicts are mapped to turnip_bind_not_strict conflict",
        )
    )

    checks.append(
        CheckResult(
            "turnip_component_signal",
            "emitRuntimeLibraryComponentSignal(\"turnip_bind\"" in text,
            "turnip bind verdict emitted into runtime library component signal stream",
        )
    )

    return checks


def audit_source(path: Path, text: str) -> tuple[list[CheckResult], bool]:
    checks: list[CheckResult] = []
    active = False

    if has_turnip_bind_logic(text):
        active = True
        checks.extend(check_turnip_bind_source(text))
    if has_turnip_conflict_logic(text):
        active = True
        checks.extend(check_turnip_conflict_source(text))

    if not active:
        checks.append(
            CheckResult(
                "source_has_turnip_bind_logic",
                True,
                "turnip strict-bind/fallback markers are not present in this source (skipped)",
            )
        )
    return checks, active


def render_markdown(results: list[tuple[Path, list[CheckResult]]]) -> str:
    ts = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    lines: list[str] = []
    lines.append("# Turnip Strict-Bind Fallback Audit")
    lines.append("")
    lines.append(f"Generated: `{ts}`")
    lines.append("")
    lines.append("## Scope")
    lines.append("")
    for path, _ in results:
        lines.append(f"- `{path.as_posix()}`")
    lines.append("")
    lines.append("## Results")
    lines.append("")

    failed = 0
    for path, checks in results:
        lines.append(f"### {path.as_posix()}")
        lines.append("")
        for item in checks:
            status = "ok" if item.ok else "missing"
            if item.name == "source_has_turnip_bind_logic" and item.ok:
                status = "skipped"
            if not item.ok:
                failed += 1
            lines.append(f"- `{item.name}`: `{status}` - {item.detail}")
        lines.append("")

    lines.append("## Summary")
    lines.append("")
    if failed:
        lines.append(f"- Failed checks: `{failed}`")
        lines.append("- Action: align Turnip strict-bind fallback and conflict marker contract before release.")
    else:
        lines.append("- All Turnip strict-bind fallback checks passed for audited sources.")
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    root = Path(__file__).resolve().parents[2]
    default_sources = [
        root / "ci/winlator/patches/0003-aeturnip-runtime-bind-and-forensics.patch",
        root / "ci/winlator/patches/0010-dxvk-capability-envelope-proton-fsr-gate-upscaler-matrix.patch",
    ]
    sources = [Path(p) for p in args.sources] if args.sources else default_sources
    existing = [p.resolve() for p in sources if p.exists()]
    if not existing:
        raise SystemExit("[turnip-bind-audit][error] no source patch files found")

    audits: list[tuple[Path, list[CheckResult]]] = []
    active_count = 0
    for source in existing:
        text = materialize_patch_text(source.read_text(encoding="utf-8", errors="ignore"))
        checks, active = audit_source(source, text)
        if active:
            active_count += 1
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
        print(f"[turnip-bind-audit] wrote {out_path}")

    failed = sum(1 for _, checks in audits for item in checks if not item.ok)
    if args.strict and (failed > 0 or active_count == 0):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
