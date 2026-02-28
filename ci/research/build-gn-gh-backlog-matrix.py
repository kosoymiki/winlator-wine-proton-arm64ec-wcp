#!/usr/bin/env python3
"""Build a unified GameNative/GameHub migration backlog matrix.

This script converts raw research artifacts into a decision-focused migration matrix
used by the Winlator CMOD integration track.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--gamenative-raw",
        default="docs/research/gamenative_branch_audit_raw.json",
        help="Path to GameNative branch audit raw JSON",
    )
    parser.add_argument(
        "--gamehub-raw",
        default="docs/research/gamehub_provenance_raw.json",
        help="Path to GameHub provenance raw JSON",
    )
    parser.add_argument(
        "--output",
        default="docs/GN_GH_BACKLOG_MATRIX.md",
        help="Output markdown path",
    )
    return parser.parse_args()


def load_json(path: Path) -> dict:
    if not path.is_file():
        raise FileNotFoundError(f"missing required input: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def classify_bucket(item: dict) -> str:
    portability = (item.get("portability") or "").strip()
    risk = (item.get("risk") or "").strip()
    topic = (item.get("topic") or "").strip()

    if portability == "already-in-default":
        return "already-covered"
    if portability == "good-cherry-pick-candidate" and risk in {"low", "medium"}:
        return "priority-port"
    if topic in {"runtime", "content-delivery", "graphics"} and risk in {"medium", "high"}:
        return "deep-review"
    if risk == "high":
        return "research-only"
    return "selective-review"


def main() -> int:
    args = parse_args()
    gamenative_raw = load_json(Path(args.gamenative_raw))
    gamehub_raw = load_json(Path(args.gamehub_raw))

    branches = gamenative_raw.get("branch_results") or []
    audits = gamehub_raw.get("audits") or []

    bucket_counts = Counter()
    topic_counts = Counter()
    risk_counts = Counter()

    prepared = []
    for item in branches:
        if not isinstance(item, dict):
            continue
        bucket = classify_bucket(item)
        item = dict(item)
        item["bucket"] = bucket
        prepared.append(item)
        bucket_counts[bucket] += 1
        topic_counts[item.get("topic", "misc")] += 1
        risk_counts[item.get("risk", "unknown")] += 1

    # Priority list: low drift + runtime/content relevance.
    priority = sorted(
        [
            x
            for x in prepared
            if x.get("bucket") in {"priority-port", "selective-review"}
        ],
        key=lambda x: (
            {"priority-port": 0, "selective-review": 1}.get(x.get("bucket", "selective-review"), 2),
            {"runtime": 0, "content-delivery": 1, "graphics": 2}.get(x.get("topic", "misc"), 3),
            int(x.get("behind_by") or 0),
            int(x.get("files_changed") or 0),
        ),
    )

    lines = []
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")
    lines.append("# GN + GH Unified Backlog Matrix")
    lines.append("")
    lines.append(f"- Generated (UTC): `{ts}`")
    lines.append("- Purpose: anti-conflict migration matrix for GameNative + GameHub signals into Ae.solator mainline")
    lines.append("- Mainline policy: `bionic-native` + `external-only runtime`")
    lines.append("")

    lines.append("## GameNative branch coverage")
    lines.append("")
    lines.append(f"- Audited branches: `{len(prepared)}`")
    lines.append("- Bucket policy:")
    lines.append("  - `priority-port`: low-drift branches suitable for direct behavior transfer")
    lines.append("  - `selective-review`: moderate-drift branches for scoped transfer")
    lines.append("  - `deep-review`: high-impact runtime/graphics/content branches requiring design review")
    lines.append("  - `research-only`: high-risk branches kept as evidence, not direct port")
    lines.append("  - `already-covered`: branch behavior already represented in default line")
    lines.append("")

    lines.append("| Bucket | Count |")
    lines.append("| --- | ---: |")
    for bucket in ("priority-port", "selective-review", "deep-review", "research-only", "already-covered"):
        lines.append(f"| `{bucket}` | {bucket_counts.get(bucket, 0)} |")

    lines.append("")
    lines.append("| Topic | Count |")
    lines.append("| --- | ---: |")
    for topic, count in topic_counts.most_common():
        lines.append(f"| `{topic}` | {count} |")

    lines.append("")
    lines.append("| Risk | Count |")
    lines.append("| --- | ---: |")
    for risk in ("low", "medium", "high", "unknown"):
        lines.append(f"| `{risk}` | {risk_counts.get(risk, 0)} |")

    lines.append("")
    lines.append("## Priority migration queue (behavior-level)")
    lines.append("")
    lines.append("| Branch | Topic | Bucket | Ahead | Behind | Files | Portability |")
    lines.append("| --- | --- | --- | ---: | ---: | ---: | --- |")
    for item in priority[:40]:
        lines.append(
            "| `{branch}` | `{topic}` | `{bucket}` | {ahead} | {behind} | {files} | `{portability}` |".format(
                branch=item.get("branch", "-"),
                topic=item.get("topic", "misc"),
                bucket=item.get("bucket", "-"),
                ahead=int(item.get("ahead_by") or 0),
                behind=int(item.get("behind_by") or 0),
                files=int(item.get("files_changed") or 0),
                portability=item.get("portability", "-") or "-",
            )
        )

    lines.append("")
    lines.append("## GameHub provenance constraints")
    lines.append("")
    lines.append("| Repo | Classification | Confidence | Rationale |")
    lines.append("| --- | --- | --- | --- |")
    for audit in audits:
        if not isinstance(audit, dict):
            continue
        lines.append(
            "| `{repo}` | `{classification}` | `{confidence}` | {rationale} |".format(
                repo=audit.get("repo", "-"),
                classification=audit.get("classification", "unknown"),
                confidence=audit.get("confidence", "unknown"),
                rationale=str(audit.get("rationale", "")).replace("|", "\\|"),
            )
        )

    lines.append("")
    lines.append("## Conflict arbitration defaults (GN vs GH)")
    lines.append("")
    lines.append("1. Runtime stability and launch determinism > everything else.")
    lines.append("2. Mainline external-only policy is non-negotiable.")
    lines.append("3. If GN/GH disagree, prefer the path with lower regression risk and explicit forensic observability.")
    lines.append("4. Asset-first ideas from external repos stay out of mainline; only behavior contracts are portable.")
    lines.append("")

    lines.append("## Required reflective checkpoints")
    lines.append("")
    lines.append("- Every merged migration item must have a record in `docs/REFLECTIVE_HARVARD_LEDGER.md`.")
    lines.append("- Each record must include: hypothesis, evidence, counter-evidence, decision, impact, verification.")
    lines.append("")

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"[gn-gh-backlog] wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
