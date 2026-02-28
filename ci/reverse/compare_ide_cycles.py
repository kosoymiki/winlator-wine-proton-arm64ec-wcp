#!/usr/bin/env python3
import argparse
import json
from pathlib import Path
from typing import Dict, List, Tuple


def load_summary(path: Path) -> Dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def key_by_rel(lib: Dict[str, object]) -> Tuple[str, str]:
    rel = str(lib.get("relative_path", ""))
    soname = str(lib.get("soname", ""))
    return rel, soname


def main() -> int:
    parser = argparse.ArgumentParser(description="Compare multiple IDE ELF cycle summaries")
    parser.add_argument("--summary", action="append", required=True, help="Path to SUMMARY.json (repeat)")
    parser.add_argument("--out", required=True, help="Output markdown")
    args = parser.parse_args()

    summaries: List[Dict[str, object]] = []
    for p in args.summary:
        path = Path(p)
        if not path.is_file():
            raise SystemExit(f"[compare-ide][error] missing summary: {path}")
        summaries.append(load_summary(path))

    labels = [str(s.get("label", "unknown")) for s in summaries]
    lib_maps: List[Dict[Tuple[str, str], Dict[str, object]]] = []
    key_union = set()

    for s in summaries:
        m = {}
        for lib in s.get("libraries", []):
            k = key_by_rel(lib)
            m[k] = lib
            key_union.add(k)
        lib_maps.append(m)

    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        f.write("# IDE Cycle Multi-source Comparison\n\n")
        f.write("## Sources\n\n")
        for s in summaries:
            f.write(
                f"- `{s.get('label')}`: source=`{s.get('source')}` "
                f"binary_count=**{s.get('binary_count', s.get('elf_count'))}** "
                f"(elf={s.get('elf_count', 0)}, pe={s.get('pe_count', 0)}) "
                f"critical=**{s.get('critical_count')}**\n"
            )
        f.write("\n## Cluster distribution by source\n\n")
        for s in summaries:
            f.write(f"- `{s.get('label')}`: `{s.get('cluster_distribution')}`\n")

        f.write("\n## Pairwise overlap\n\n")
        for i in range(len(labels)):
            for j in range(i + 1, len(labels)):
                a_keys = set(lib_maps[i].keys())
                b_keys = set(lib_maps[j].keys())
                common = len(a_keys & b_keys)
                only_a = len(a_keys - b_keys)
                only_b = len(b_keys - a_keys)
                f.write(f"- `{labels[i]}` vs `{labels[j]}`: common={common}, only_a={only_a}, only_b={only_b}\n")

        f.write("\n## High-value drift candidates\n\n")
        shown = 0
        for k in sorted(key_union):
            rows = []
            for idx, m in enumerate(lib_maps):
                lib = m.get(k)
                if lib:
                    rows.append((labels[idx], lib))
            if len(rows) < 2:
                continue
            sha_set = {r[1].get("sha256", "") for r in rows}
            critical_set = {bool(r[1].get("critical")) for r in rows}
            if len(sha_set) <= 1 and critical_set == {False}:
                continue
            rel, soname = k
            f.write(f"- `{rel}` (soname=`{soname}`)\n")
            for lbl, lib in rows:
                f.write(
                    f"  - {lbl}: sha={str(lib.get('sha256', ''))[:12]} "
                    f"cluster={lib.get('cluster')} critical={lib.get('critical')} "
                    f"defined={lib.get('defined_symbols')} undefined={lib.get('undefined_symbols')}\n"
                )
            shown += 1
            if shown >= 120:
                break

    print(f"[compare-ide] wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
