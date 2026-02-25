#!/usr/bin/env python3
"""Build GameNative/GameHub patch crosswalk from focus artifacts.

The report highlights where both APKs expose similar runtime behavior so we can
merge patches by function instead of by source repository.
"""

from __future__ import annotations

import argparse
import re
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path


MODULE_RULES = [
    {
        "id": "box64_fex_translator",
        "label": "Translator/FEX/Box64",
        "kind": "port_contract",
        "lane": "0030/0037/0039/0040/0043 (+0044 bridge)",
        "patterns": [
            r"box64",
            r"wowbox64",
            r"fex",
            r"fexcore",
            r"translator",
            r"trans_layer",
            r"fextranslatorconfig",
            r"box64translatorconfig",
        ],
    },
    {
        "id": "launch_pipeline",
        "label": "Launch pipeline",
        "kind": "adapt_urc",
        "lane": "0044",
        "patterns": [
            r"launchapp",
            r"winestart",
            r"guestprogramlauncher",
            r"xserver",
            r"xserverscreen",
            r"programcontroller",
            r"environmentcontroller",
            r"containercontroller",
            r"intentlaunchmanager",
            r"setupxenvironment",
            r"winuibridge",
            r"winemuserviceimpl",
        ],
    },
    {
        "id": "graphics_driver_probe",
        "label": "Graphics/driver",
        "kind": "adapt_urc",
        "lane": "0045",
        "patterns": [
            r"vulkan",
            r"driver",
            r"adrenotools",
            r"turnip",
            r"gpu",
            r"directrender",
            r"dxvk",
            r"vkd3d",
        ],
    },
    {
        "id": "registry_runtime",
        "label": "Registry/runtime mutation",
        "kind": "adapt_guarded",
        "lane": "0046",
        "patterns": [
            r"registry",
            r"regedit",
            r"dependencymanager",
            r"wineutils",
            r"wincomponent",
            r"wineregistryeditor",
            r"setwincomponentregistrykeys",
        ],
    },
    {
        "id": "content_download_layers",
        "label": "Content/download flows",
        "kind": "reject_mainline",
        "lane": "research-only",
        "patterns": [
            r"download",
            r"manifest",
            r"contentprofile",
            r"componentsinstall",
            r"aria",
            r"envlayer",
        ],
    },
    {
        "id": "ui_translation_layers",
        "label": "UI/app shell",
        "kind": "reject_mainline",
        "lane": "research-only",
        "patterns": [
            r"/ui/",
            r"compose",
            r"viewholder",
            r"sidebar",
            r"screen",
            r"dialog",
        ],
    },
]


STOP_TOKENS = {
    "get",
    "set",
    "is",
    "has",
    "to",
    "from",
    "with",
    "for",
    "default",
    "lambda",
    "invoke",
    "create",
    "copy",
    "component",
    "companion",
    "manager",
    "controller",
    "service",
    "helper",
    "utils",
    "config",
    "state",
    "dialog",
    "screen",
    "view",
    "data",
    "list",
    "string",
    "app",
    "release",
    "main",
    "kt",
    "access",
    "init",
    "clinit",
    "suspend",
    "equals",
    "hashcode",
    "tostring",
}


CAMEL_SPLIT_RE = re.compile(r"(?<!^)(?=[A-Z])")
NON_WORD_RE = re.compile(r"[^A-Za-z0-9]+")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gn-methods", default="", help="GameNative methods_focus.txt path")
    parser.add_argument("--gn-edges", default="", help="GameNative call_edges_runtime_graphics.tsv path")
    parser.add_argument("--gh-methods", default="", help="GameHub methods_focus.txt path")
    parser.add_argument("--gh-edges", default="", help="GameHub call_edges_runtime_graphics.tsv path")
    parser.add_argument("--output", default="docs/GN_GH_PATCH_CROSSWALK.md", help="Output markdown path")
    return parser.parse_args()


def latest_bundle(prefix: str) -> Path:
    matches = sorted(Path("/home/mikhail").glob(f"{prefix}_*"))
    if not matches:
        raise FileNotFoundError(f"No /home/mikhail/{prefix}_* bundles found")
    return matches[-1]


def resolve_paths(args: argparse.Namespace) -> tuple[Path, Path, Path, Path]:
    if args.gn_methods and args.gn_edges:
        gn_methods = Path(args.gn_methods)
        gn_edges = Path(args.gn_edges)
    else:
        gn_base = latest_bundle("gamenative-v0.7.2_reverse") / "focus"
        gn_methods = gn_base / "methods_focus.txt"
        gn_edges = gn_base / "call_edges_runtime_graphics.tsv"

    if args.gh_methods and args.gh_edges:
        gh_methods = Path(args.gh_methods)
        gh_edges = Path(args.gh_edges)
    else:
        gh_base = latest_bundle("gamehub_reverse") / "focus"
        gh_methods = gh_base / "methods_focus.txt"
        gh_edges = gh_base / "call_edges_runtime_graphics.tsv"

    return gn_methods, gn_edges, gh_methods, gh_edges


def load_lines(path: Path) -> list[str]:
    if not path.is_file():
        raise FileNotFoundError(path)
    return [line.rstrip("\n") for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def detect_module(signature: str) -> str:
    for rule in MODULE_RULES:
        for pattern in rule["patterns"]:
            if re.search(pattern, signature, re.IGNORECASE):
                return rule["id"]
    return "other"


def normalize_sig_tokens(signature: str) -> list[str]:
    class_part, method_part = signature, ""
    if "->" in signature:
        class_part, method_part = signature.split("->", 1)

    class_short = class_part.strip("L;").split("/")[-1]
    method_name = method_part.split("(", 1)[0]

    raw = f"{class_short} {method_name}"
    raw = raw.replace("$", " ")
    raw = CAMEL_SPLIT_RE.sub(" ", raw)
    raw = NON_WORD_RE.sub(" ", raw)

    tokens: list[str] = []
    for tok in raw.lower().split():
        if len(tok) < 3:
            continue
        if tok in STOP_TOKENS:
            continue
        tokens.append(tok)
    return tokens


def group_methods(lines: list[str]) -> dict[str, list[str]]:
    grouped: dict[str, list[str]] = defaultdict(list)
    for sig in lines:
        grouped[detect_module(sig)].append(sig)
    return grouped


def group_edges(lines: list[str]) -> dict[str, int]:
    grouped: dict[str, int] = defaultdict(int)
    for line in lines:
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
        grouped[detect_module(caller + " " + callee)] += c
    return grouped


def token_counter(signatures: list[str]) -> Counter[str]:
    counter: Counter[str] = Counter()
    for sig in signatures:
        counter.update(normalize_sig_tokens(sig))
    return counter


def similarity_score(a: Counter[str], b: Counter[str]) -> float:
    sa = set(a.keys())
    sb = set(b.keys())
    if not sa and not sb:
        return 0.0
    if not sa or not sb:
        return 0.0
    return len(sa & sb) / len(sa | sb)


def merge_action(kind: str, score: float, gn_count: int, gh_count: int) -> str:
    if kind == "reject_mainline":
        return "research-only"
    if gn_count == 0 or gh_count == 0:
        return "queue-manual"
    if kind == "port_contract":
        return "merge-contract" if score >= 0.05 else "merge-guarded"
    if score >= 0.12:
        return "merge-now"
    if score >= 0.06:
        return "merge-guarded"
    return "queue-manual"


def confidence(score: float) -> str:
    if score >= 0.16:
        return "high"
    if score >= 0.08:
        return "medium"
    return "low"


def module_rule_map() -> dict[str, dict]:
    return {rule["id"]: rule for rule in MODULE_RULES}


def main() -> int:
    args = parse_args()
    gn_methods_path, gn_edges_path, gh_methods_path, gh_edges_path = resolve_paths(args)
    output = Path(args.output)

    gn_methods = load_lines(gn_methods_path)
    gh_methods = load_lines(gh_methods_path)
    gn_edges = load_lines(gn_edges_path)
    gh_edges = load_lines(gh_edges_path)

    gn_grouped = group_methods(gn_methods)
    gh_grouped = group_methods(gh_methods)
    gn_edge_grouped = group_edges(gn_edges)
    gh_edge_grouped = group_edges(gh_edges)

    rmap = module_rule_map()
    module_ids = [rule["id"] for rule in MODULE_RULES]

    lines: list[str] = []
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    lines.append("# GN + GH Patch Crosswalk")
    lines.append("")
    lines.append(f"- Generated (UTC): `{ts}`")
    lines.append("- Goal: merge GameNative and GameHub patches by shared runtime function")
    lines.append("- Mainline policy: `bionic-native + external-only runtime`")
    lines.append(f"- GameNative methods: `{gn_methods_path}`")
    lines.append(f"- GameNative edges: `{gn_edges_path}`")
    lines.append(f"- GameHub methods: `{gh_methods_path}`")
    lines.append(f"- GameHub edges: `{gh_edges_path}`")
    lines.append("")

    lines.append("## Function-Level Crosswalk")
    lines.append("")
    lines.append(
        "| Module | GN methods | GH methods | GN edge events | GH edge events | Similarity | Confidence | Action | Patch lane |"
    )
    lines.append("| --- | ---: | ---: | ---: | ---: | ---: | --- | --- | --- |")

    for mid in module_ids:
        rule = rmap[mid]
        gn_mod_methods = gn_grouped.get(mid, [])
        gh_mod_methods = gh_grouped.get(mid, [])
        gn_tokens = token_counter(gn_mod_methods)
        gh_tokens = token_counter(gh_mod_methods)
        score = similarity_score(gn_tokens, gh_tokens)
        action = merge_action(rule["kind"], score, len(gn_mod_methods), len(gh_mod_methods))
        lines.append(
            f"| `{rule['label']}` | {len(gn_mod_methods)} | {len(gh_mod_methods)} | "
            f"{gn_edge_grouped.get(mid, 0)} | {gh_edge_grouped.get(mid, 0)} | "
            f"{score:.3f} | `{confidence(score)}` | `{action}` | `{rule['lane']}` |"
        )

    lines.append("")
    lines.append("## Shared Function Tokens (Evidence)")
    lines.append("")
    for mid in module_ids:
        rule = rmap[mid]
        gn_tokens = token_counter(gn_grouped.get(mid, []))
        gh_tokens = token_counter(gh_grouped.get(mid, []))
        common = gn_tokens & gh_tokens
        common_tokens = [f"`{tok}` ({cnt})" for tok, cnt in common.most_common(12)]
        lines.append(f"### {rule['label']}")
        lines.append("")
        if common_tokens:
            lines.append("- Shared tokens: " + ", ".join(common_tokens))
        else:
            lines.append("- Shared tokens: none")
        gn_examples = gn_grouped.get(mid, [])[:4]
        gh_examples = gh_grouped.get(mid, [])[:4]
        if gn_examples:
            lines.append("- GameNative examples:")
            for sig in gn_examples:
                lines.append(f"  - `{sig}`")
        if gh_examples:
            lines.append("- GameHub examples:")
            for sig in gh_examples:
                lines.append(f"  - `{sig}`")
        lines.append("")

    lines.append("## Merge Queue")
    lines.append("")
    lines.append("1. `0044`: launch pipeline merge (GN+GH) under URC with reason-coded forensics.")
    lines.append("2. `0045`: graphics/driver decision merge with deterministic fallback chain.")
    lines.append("3. `0046`: registry/runtime guarded deltas only (no asset-first side effects).")
    lines.append("4. Keep content/download/UI modules in research-only lane until explicit promote decision.")
    lines.append("")

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"[gn-gh-crosswalk] wrote {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
