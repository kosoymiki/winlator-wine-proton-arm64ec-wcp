#!/usr/bin/env python3
"""Build GameHub -> Ae.solator runtime transfer matrix from extracted signatures."""

from __future__ import annotations

import argparse
import re
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--methods-focus",
        default="",
        help="Path to extracted focus methods list",
    )
    parser.add_argument(
        "--edges-focus",
        default="",
        help="Path to extracted focus call-edges TSV",
    )
    parser.add_argument(
        "--summary",
        default="",
        help="Path to focus summary",
    )
    parser.add_argument(
        "--output",
        default="docs/GAMEHUB_RUNTIME_TRANSFER_MATRIX.md",
        help="Output markdown path",
    )
    parser.add_argument(
        "--source-apk",
        default="/home/mikhail/GameHub-Lite-5.3.3-RC2.apk",
        help="Source APK path for report metadata",
    )
    return parser.parse_args()


MODULE_RULES = [
    {
        "id": "box64_fex_translator",
        "label": "Box64/FEX translator config",
        "kind": "port_contract",
        "target": "Box64/FEX preset + runtime common profile layers",
        "repo_target": "ci/winlator/patches/0030,0039,0040",
        "patterns": [
            r"Lcom/winemu/core/trans_layer/Box64Config;",
            r"Lcom/winemu/core/trans_layer/FEXConfig;",
            r"Lcom/winemu/core/trans_layer/FEXConfigData;",
            r"Lcom/xj/winemu/bean/Box64TranslatorConfig;",
            r"Lcom/xj/winemu/bean/FEXTranslatorConfig;",
            r"Lcom/winemu/fexcore/",
            r"WowBox64Manifest",
            r"TranslatorPreset",
            r"->export\(Lcom/winemu/core/utils/EnvVars;",
        ],
    },
    {
        "id": "launch_pipeline",
        "label": "Launch pipeline orchestration",
        "kind": "adapt_urc",
        "target": "URC launch plan + preflight + telemetry",
        "repo_target": "XServerDisplayActivity + GuestProgramLauncherComponent",
        "patterns": [
            r"Lcom/xj/winemu/service/WinEmuServiceImpl;",
            r"Lcom/winemu/openapi/WinUIBridge;",
            r"Lcom/winemu/core/controller/ProgramController;",
            r"Lcom/winemu/core/controller/EnvironmentController;",
            r"Lcom/winemu/core/controller/ContainerController;",
            r"Lcom/winemu/core/controller/X11Controller;",
            r"GuestProgramLauncherComponent",
            r"WineStartCommand",
            r"launch",
        ],
    },
    {
        "id": "registry_runtime",
        "label": "Registry/runtime mutation layer",
        "kind": "adapt_guarded",
        "target": "Container/runtime compatibility rules with strict guardrails",
        "repo_target": "Container migration + compat registry layer",
        "patterns": [
            r"Lcom/winemu/core/RegistryHelper;",
            r"Lcom/winemu/core/controller/RegistryController;",
            r"Lcom/winemu/core/DependencyManager;",
            r"Lcom/winemu/core/regedit/",
            r"WineRegistryEditor",
            r"setWinComponentRegistryKeys",
        ],
    },
    {
        "id": "graphics_driver_probe",
        "label": "Graphics + driver decision tree",
        "kind": "adapt_urc",
        "target": "Adrenotools probe + Vulkan fallback telemetry",
        "repo_target": "AdrenotoolsManager + native vulkan.c",
        "patterns": [
            r"GPU",
            r"Vulkan",
            r"Driver",
            r"DirectRendering",
            r"SurfaceFormat",
            r"Lcom/winemu/core/GPUInfoQuery;",
        ],
    },
    {
        "id": "content_download_layers",
        "label": "Content download/install app layers",
        "kind": "reject_mainline",
        "target": "Do not port directly (asset-first behavior)",
        "repo_target": "Research-only, no mainline import",
        "patterns": [
            r"/download/",
            r"EnvLayer",
            r"setup/tasks",
            r"GameConfigDownload",
            r"ComponentsInstall",
            r"ManifestEntry",
            r"ContentProfile",
            r"AriaDownload",
        ],
    },
    {
        "id": "ui_translation_layers",
        "label": "UI and translation-specific features",
        "kind": "reject_mainline",
        "target": "Do not port into runtime core",
        "repo_target": "Optional UI lane only",
        "patterns": [
            r"/ui/",
            r"/sidebar/",
            r"Translation",
            r"ViewHolder",
            r"DataBinderMapper",
        ],
    },
]


KIND_ORDER = {
    "port_contract": 0,
    "adapt_urc": 1,
    "adapt_guarded": 2,
    "reject_mainline": 3,
}


def load_lines(path: Path) -> list[str]:
    if not path.is_file():
        raise FileNotFoundError(path)
    return [line.rstrip("\n") for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def detect_module(signature: str) -> str:
    for rule in MODULE_RULES:
        for pattern in rule["patterns"]:
            if re.search(pattern, signature):
                return rule["id"]
    return "other"


def rule_map() -> dict[str, dict]:
    return {rule["id"]: rule for rule in MODULE_RULES}


def read_focus_summary(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    if not path.is_file():
        return data
    for line in path.read_text(encoding="utf-8").splitlines():
        if ": " not in line:
            continue
        key, val = line.split(": ", 1)
        data[key.strip()] = val.strip()
    return data


def latest_gamehub_bundle() -> Path:
    matches = sorted(Path("/home/mikhail").glob("gamehub_reverse_*"))
    if not matches:
        raise FileNotFoundError("No /home/mikhail/gamehub_reverse_* bundles found")
    return matches[-1]


def resolve_inputs(args: argparse.Namespace) -> tuple[Path, Path, Path]:
    if args.methods_focus and args.edges_focus:
        methods = Path(args.methods_focus)
        edges = Path(args.edges_focus)
        summary = Path(args.summary) if args.summary else methods.parent / "focus_summary.txt"
    else:
        base = latest_gamehub_bundle() / "focus"
        methods = base / "methods_focus.txt"
        edges = base / "call_edges_runtime_graphics.tsv"
        summary = base / "focus_summary.txt"
    return methods, edges, summary


def main() -> int:
    args = parse_args()
    methods_focus, edges_focus, summary_path = resolve_inputs(args)
    output = Path(args.output)
    source_apk = Path(args.source_apk)

    signatures = load_lines(methods_focus)
    edges = load_lines(edges_focus)
    focus_summary = read_focus_summary(summary_path)

    grouped: dict[str, list[str]] = defaultdict(list)
    for sig in signatures:
        grouped[detect_module(sig)].append(sig)

    edge_group_count: dict[str, int] = defaultdict(int)
    # Skip header line if present.
    for line in edges:
        if line.startswith("caller\tcallee\tcount\ttype"):
            continue
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        caller, callee, count, _etype = parts[0], parts[1], parts[2], parts[3]
        try:
            c = int(count)
        except ValueError:
            c = 1
        module = detect_module(caller + " " + callee)
        edge_group_count[module] += c

    lines: list[str] = []
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    lines.append("# GameHub Runtime Transfer Matrix (for Ae.solator mainline)")
    lines.append("")
    lines.append(f"- Generated (UTC): `{ts}`")
    lines.append(f"- Source APK: `{source_apk}`")
    lines.append(f"- Source methods file: `{methods_focus}`")
    lines.append(f"- Source edges file: `{edges_focus}`")
    lines.append("- Mainline policy: `bionic-native + external-only runtime`")
    lines.append("- Plan slot: `pre-0044`")
    lines.append("")

    if focus_summary:
        lines.append("## Extraction Snapshot")
        lines.append("")
        for key in (
            "All classes",
            "All methods",
            "Focus classes",
            "Focus methods",
            "Focus call edges (unique)",
            "Focus outbound/inbound/internal events (total)",
            "Runtime+graphics call edges (unique)",
            "Runtime+graphics outbound/inbound/internal events (total)",
        ):
            if key in focus_summary:
                lines.append(f"- {key}: `{focus_summary[key]}`")
        lines.append("")

    lines.append("## Transfer Decisions")
    lines.append("")
    lines.append("| Module | Decision | Methods | Edge events | Target in Ae.solator | Existing anchor |")
    lines.append("| --- | --- | ---: | ---: | --- | --- |")

    ordered = sorted(MODULE_RULES, key=lambda x: KIND_ORDER.get(x["kind"], 99))
    for rule in ordered:
        methods_n = len(grouped.get(rule["id"], []))
        edges_n = edge_group_count.get(rule["id"], 0)
        lines.append(
            f"| `{rule['label']}` | `{rule['kind']}` | {methods_n} | {edges_n} | {rule['target']} | `{rule['repo_target']}` |"
        )

    other_n = len(grouped.get("other", []))
    other_edges = edge_group_count.get("other", 0)
    lines.append(f"| `Unclassified` | `manual-review` | {other_n} | {other_edges} | Review in research lane | `docs/REFLECTIVE_HARVARD_LEDGER.md` |")

    lines.append("")
    lines.append("## High-Value Signatures (examples)")
    lines.append("")

    for rule in ordered:
        samples = grouped.get(rule["id"], [])[:20]
        if not samples:
            continue
        lines.append(f"### {rule['label']}")
        lines.append("")
        lines.append(f"Decision: `{rule['kind']}`")
        lines.append("")
        for sig in samples:
            lines.append(f"- `{sig}`")
        lines.append("")

    lines.append("## Anti-Conflict Rules (GameNative vs GameHub)")
    lines.append("")
    lines.append("1. GN/GH behavior is integrated only through unified runtime contract fields.")
    lines.append("2. Any GameHub path that implies bundled runtime assets is rejected in mainline.")
    lines.append("3. Launch/Env changes must preserve existing GN-origin preflight and forensic telemetry.")
    lines.append("4. If GN and GH differ, keep the lower-regression path with explicit fallback reasons.")
    lines.append("")

    lines.append("## Implementation Queue")
    lines.append("")
    lines.append("1. Port translator config semantics (Box64/FEX) into existing preset/profile layers.")
    lines.append("2. Adapt launch orchestration into URC (without importing app-specific asset/download flows).")
    lines.append("3. Add guarded registry compatibility deltas only with forensic trace points.")
    lines.append("4. Keep download/UI translation layers in research lane unless explicitly requested.")
    lines.append("")

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"[gamehub-transfer] wrote {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
