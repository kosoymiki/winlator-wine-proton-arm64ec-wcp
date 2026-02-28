#!/usr/bin/env python3
"""Build GameNative v0.7.2 -> Ae.solator runtime transfer matrix."""

from __future__ import annotations

import argparse
import re
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path


MODULE_RULES = [
    {
        "id": "box64_fex_translator",
        "label": "Box64/FEX translator config",
        "kind": "port_contract",
        "target": "Translator preset/profile contract + runtime-profile migration rules",
        "repo_target": "ci/winlator/patches/0030,0037,0039,0040,0043",
        "patterns": [
            r"trans_layer/Box64Config",
            r"trans_layer/FEXConfig",
            r"Box64TranslatorConfig",
            r"FEXTranslatorConfig",
            r"wowbox64",
            r"libwow64fex",
            r"fexcore",
            r"FEXCore",
            r"WowBox64Manifest",
            r"TranslatorPreset",
        ],
    },
    {
        "id": "launch_pipeline",
        "label": "Launch pipeline orchestration",
        "kind": "adapt_runtime_contract",
        "target": "Runtime Contract launch preflight + deterministic env submit + forensic reasons",
        "repo_target": "XServerDisplayActivity + GuestProgramLauncherComponent (0044 queue)",
        "patterns": [
            r"WinEmuServiceImpl",
            r"WinUIBridge",
            r"ProgramController",
            r"EnvironmentController",
            r"ContainerController",
            r"EmuContainerImpl",
            r"IntentLaunchManager",
            r"launchApp",
            r"XServerScreenKt",
            r"GuestProgramLauncherComponent",
            r"ContainerManager",
            r"getWineStartCommand",
            r"setupXEnvironment",
            r"createNewContainer",
        ],
    },
    {
        "id": "registry_runtime",
        "label": "Registry/runtime mutation layer",
        "kind": "adapt_guarded",
        "target": "Guarded compat deltas with forensic markers",
        "repo_target": "ContainerNormalizer + registry/compat path",
        "patterns": [
            r"RegistryHelper",
            r"RegistryController",
            r"DependencyManager",
            r"regedit",
            r"WineRegistryEditor",
            r"setWinComponentRegistryKeys",
            r"setupSystemFonts",
            r"setWindowMetrics",
        ],
    },
    {
        "id": "graphics_driver_probe",
        "label": "Graphics + driver decision tree",
        "kind": "adapt_runtime_contract",
        "target": "Adrenotools/Vulkan decision telemetry and fallback reasons",
        "repo_target": "AdrenotoolsManager + driver probe path + vulkan fallback",
        "patterns": [
            r"GPUInfoQuery",
            r"DirectRendering",
            r"graphics_driver",
            r"vulkan",
            r"driver",
            r"adrenotools",
            r"Turnip",
            r"Vortek",
        ],
    },
    {
        "id": "content_download_layers",
        "label": "Content download/install app layers",
        "kind": "reject_mainline",
        "target": "Keep out of runtime mainline (research-only)",
        "repo_target": "Research lane only",
        "patterns": [
            r"/download/",
            r"EnvLayer",
            r"setup/tasks",
            r"GameConfigDownload",
            r"ComponentsInstall",
            r"AriaDownload",
            r"manifestinstall",
            r"ManifestEntry",
            r"ContentProfile",
            r"setupSystemComponents",
        ],
    },
    {
        "id": "ui_translation_layers",
        "label": "UI/compose/app-shell layers",
        "kind": "reject_mainline",
        "target": "No direct port into runtime core",
        "repo_target": "Optional UI lane only",
        "patterns": [
            r"/ui/",
            r"/sidebar/",
            r"databinding",
            r"compose",
            r"ViewHolder",
            r"Navigation",
        ],
    },
]

KIND_ORDER = {
    "port_contract": 0,
    "adapt_runtime_contract": 1,
    "adapt_guarded": 2,
    "reject_mainline": 3,
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--methods-focus", default="", help="Path to methods_focus.txt")
    parser.add_argument("--edges-focus", default="", help="Path to call_edges_runtime_graphics.tsv")
    parser.add_argument("--summary", default="", help="Path to focus_summary.txt")
    parser.add_argument(
        "--output",
        default="docs/GAMENATIVE_072_RUNTIME_TRANSFER_MATRIX.md",
        help="Output markdown path",
    )
    parser.add_argument(
        "--source-apk",
        default="/home/mikhail/gamenative-v0.7.2.apk",
        help="Source APK path for report metadata",
    )
    return parser.parse_args()


def latest_gn_bundle() -> Path:
    matches = sorted(Path("/home/mikhail").glob("gamenative-v0.7.2_reverse_*"))
    if not matches:
        raise FileNotFoundError("No /home/mikhail/gamenative-v0.7.2_reverse_* bundles found")
    return matches[-1]


def resolve_inputs(args: argparse.Namespace) -> tuple[Path, Path, Path]:
    if args.methods_focus and args.edges_focus:
        methods = Path(args.methods_focus)
        edges = Path(args.edges_focus)
        summary = Path(args.summary) if args.summary else methods.parent / "focus_summary.txt"
    else:
        base = latest_gn_bundle() / "focus"
        methods = base / "methods_focus.txt"
        edges = base / "call_edges_runtime_graphics.tsv"
        summary = base / "focus_summary.txt"
    return methods, edges, summary


def load_lines(path: Path) -> list[str]:
    if not path.is_file():
        raise FileNotFoundError(path)
    return [line.rstrip("\n") for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


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


def detect_module(signature: str) -> str:
    for rule in MODULE_RULES:
        for pattern in rule["patterns"]:
            if re.search(pattern, signature, re.IGNORECASE):
                return rule["id"]
    return "other"


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
    for line in edges:
        if line.startswith("caller\tcallee\tcount\ttype"):
            continue
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        caller, callee, count = parts[0], parts[1], parts[2]
        try:
            c = int(count)
        except ValueError:
            c = 1
        module = detect_module(caller + " " + callee)
        edge_group_count[module] += c

    ordered = sorted(MODULE_RULES, key=lambda x: KIND_ORDER.get(x["kind"], 99))

    lines: list[str] = []
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    lines.append("# GameNative v0.7.2 Runtime Transfer Matrix (for Ae.solator mainline)")
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
    for rule in ordered:
        methods_n = len(grouped.get(rule["id"], []))
        edges_n = edge_group_count.get(rule["id"], 0)
        lines.append(
            f"| `{rule['label']}` | `{rule['kind']}` | {methods_n} | {edges_n} | {rule['target']} | `{rule['repo_target']}` |"
        )

    other_n = len(grouped.get("other", []))
    other_edges = edge_group_count.get("other", 0)
    lines.append(
        f"| `Unclassified` | `manual-review` | {other_n} | {other_edges} | Keep in research lane | `docs/REFLECTIVE_HARVARD_LEDGER.md` |"
    )
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

    lines.append("## Anti-Conflict Rules (GN v0.7.2 vs GameHub)")
    lines.append("")
    lines.append("1. Shared runtime behavior is integrated only through Runtime Contract + forensic fields.")
    lines.append("2. Any path implying bundled runtime payload stays out of mainline.")
    lines.append("3. Launch/environment changes must preserve deterministic fallback reasons.")
    lines.append("4. If GN/GH diverge, choose lower-regression behavior with explicit telemetry.")
    lines.append("")

    lines.append("## 0044 Queue (post-analysis)")
    lines.append("")
    lines.append("1. Integrate launch orchestration deltas into Runtime Contract preflight path (`XServerDisplayActivity` + launcher).")
    lines.append("2. Add reason-coded guardrails for runtime/profile mismatch decisions.")
    lines.append("3. Keep content/UI/install layers in research lane unless explicitly promoted.")
    lines.append("")

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"[gamenative-transfer] wrote {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
