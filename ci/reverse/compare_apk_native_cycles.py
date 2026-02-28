#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
from typing import Dict, List, Tuple


def load_summary(path: Path) -> Dict:
    return json.loads(path.read_text(encoding="utf-8"))


def lib_map(summary: Dict) -> Dict[str, Dict]:
    out: Dict[str, Dict] = {}
    for item in summary.get("libraries", []):
        key = f"{item.get('abi','?')}/{item.get('name','?')}"
        out[key] = item
    return out


def tier1_names(summary: Dict) -> List[str]:
    return sorted({f"{x.get('abi')}/{x.get('name')}" for x in summary.get("libraries", []) if x.get("tier") == "tier1"})


def compare(a: Dict, b: Dict) -> Tuple[List[str], List[str], List[str], List[Tuple[str, str, str]]]:
    amap = lib_map(a)
    bmap = lib_map(b)
    akeys = set(amap.keys())
    bkeys = set(bmap.keys())

    common = sorted(akeys & bkeys)
    only_a = sorted(akeys - bkeys)
    only_b = sorted(bkeys - akeys)

    changed: List[Tuple[str, str, str]] = []
    for key in common:
        if amap[key].get("sha256") != bmap[key].get("sha256"):
            changed.append((key, amap[key].get("sha256", ""), bmap[key].get("sha256", "")))

    return common, only_a, only_b, changed


def write_report(a: Dict, b: Dict, out_md: Path) -> None:
    common, only_a, only_b, changed = compare(a, b)

    out_md.parent.mkdir(parents=True, exist_ok=True)
    with out_md.open("w", encoding="utf-8") as f:
        f.write("# Cross APK Native Comparison\n\n")
        f.write(f"- A: `{a.get('apk')}`\n")
        f.write(f"- B: `{b.get('apk')}`\n")
        f.write(f"- A libs: **{a.get('lib_count', 0)}**\n")
        f.write(f"- B libs: **{b.get('lib_count', 0)}**\n")
        f.write(f"- Common (abi/name): **{len(common)}**\n")
        f.write(f"- Only A: **{len(only_a)}**\n")
        f.write(f"- Only B: **{len(only_b)}**\n")
        f.write(f"- Common with different sha256: **{len(changed)}**\n\n")

        f.write("## Tier1 overlap\n\n")
        a_t1 = set(tier1_names(a))
        b_t1 = set(tier1_names(b))
        t1_common = sorted(a_t1 & b_t1)
        t1_only_a = sorted(a_t1 - b_t1)
        t1_only_b = sorted(b_t1 - a_t1)

        f.write(f"- Tier1 common: {len(t1_common)}\n")
        for x in t1_common[:40]:
            f.write(f"  - `{x}`\n")
        f.write(f"- Tier1 only A: {len(t1_only_a)}\n")
        for x in t1_only_a[:40]:
            f.write(f"  - `{x}`\n")
        f.write(f"- Tier1 only B: {len(t1_only_b)}\n")
        for x in t1_only_b[:40]:
            f.write(f"  - `{x}`\n")

        f.write("\n## High value transferable clusters\n\n")
        f.write("- runtime_orchestration\n")
        f.write("- virtual_fs\n")
        f.write("- gpu_probe\n")
        f.write("- translator_runtime\n\n")

        f.write("## Common library binary drift (sha mismatch, first 120)\n\n")
        for key, a_sha, b_sha in changed[:120]:
            f.write(f"- `{key}`\n")
            f.write(f"  - A sha: `{a_sha}`\n")
            f.write(f"  - B sha: `{b_sha}`\n")

        f.write("\n## Reflective note\n\n")
        f.write("- This is native-library level parity and drift analysis.\n")
        f.write("- It is not equivalent to full decompilation of every Java/SMALI/native instruction.\n")
        f.write("- Use this report to target deterministic patch candidates in our patch stack.\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare two APK native reverse summaries")
    parser.add_argument("--a", required=True, help="SUMMARY.json for A")
    parser.add_argument("--b", required=True, help="SUMMARY.json for B")
    parser.add_argument("--out", required=True, help="Output markdown file")
    args = parser.parse_args()

    a = load_summary(Path(args.a))
    b = load_summary(Path(args.b))
    write_report(a, b, Path(args.out))
    print(f"[reverse-compare] wrote {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
