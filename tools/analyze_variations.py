#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from dataclasses import asdict, dataclass

PAIR_RE = re.compile(r"^[0-9a-f]+-[0-9a-f]+$", re.IGNORECASE)

@dataclass
class Summary:
    total: int
    valid: int
    invalid: int
    unique_pairs: int
    dominant_suffix: str
    dominant_suffix_count: int
    dominant_suffix_percent: float
    top_suffixes: list[tuple[str, int]]
    top_prefixes: list[tuple[str, int]]
    invalid_entries: list[str]


def parse_tokens(raw: str) -> list[str]:
    return [t.strip().lower() for t in raw.replace("\n", ",").split(",") if t.strip()]


def analyze(tokens: list[str]) -> tuple[Summary, list[str]]:
    valid_pairs: list[str] = []
    invalid: list[str] = []
    prefixes: list[str] = []
    suffixes: list[str] = []

    for token in tokens:
        if PAIR_RE.match(token):
            left, right = token.split("-", 1)
            valid_pairs.append(token)
            prefixes.append(left)
            suffixes.append(right)
        else:
            invalid.append(token)

    suffix_counter = Counter(suffixes)
    prefix_counter = Counter(prefixes)
    dominant_suffix, dominant_count = (suffix_counter.most_common(1)[0] if suffix_counter else ("n/a", 0))
    valid = len(valid_pairs)
    pct = (dominant_count / valid * 100.0) if valid else 0.0

    summary = Summary(
        total=len(tokens),
        valid=valid,
        invalid=len(invalid),
        unique_pairs=len(set(valid_pairs)),
        dominant_suffix=dominant_suffix,
        dominant_suffix_count=dominant_count,
        dominant_suffix_percent=round(pct, 2),
        top_suffixes=suffix_counter.most_common(10),
        top_prefixes=prefix_counter.most_common(10),
        invalid_entries=invalid,
    )
    return summary, valid_pairs


def markdown(summary: Summary, pairs: list[str]) -> str:
    lines = [
        "# ANR variation analysis",
        "",
        f"- Total entries: {summary.total}",
        f"- Valid entries: {summary.valid}",
        f"- Invalid entries: {summary.invalid}",
        f"- Unique variation pairs: {summary.unique_pairs}",
        f"- Dominant suffix: `{summary.dominant_suffix}` ({summary.dominant_suffix_count}/{summary.valid}, {summary.dominant_suffix_percent:.2f}%)",
        "",
        "## Top suffixes",
    ]
    lines.extend([f"- `{k}`: {v}" for k, v in summary.top_suffixes])
    lines.append("")
    lines.append("## Top prefixes")
    lines.extend([f"- `{k}`: {v}" for k, v in summary.top_prefixes])
    if summary.invalid_entries:
        lines.append("")
        lines.append("## Invalid entries")
        lines.extend([f"- `{x}`" for x in summary.invalid_entries])
    lines.append("")
    lines.append("## Full valid pairs")
    lines.extend([f"- `{p}`" for p in pairs])
    return "\n".join(lines) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description="Analyze crashreport variation codes (prefix-suffix pairs)")
    parser.add_argument("--input", help="Input text file with comma/newline-separated tokens")
    parser.add_argument("--codes", help="Raw codes string (comma-separated)")
    parser.add_argument("--out-md", default="ANR_REPORT.md")
    parser.add_argument("--out-json", default="ANR_REPORT.json")
    args = parser.parse_args()

    if not args.input and not args.codes:
        parser.error("Provide --input FILE or --codes 'a-b,c-d,...'")

    raw = args.codes
    if args.input:
        with open(args.input, "r", encoding="utf-8") as f:
            raw = f.read()

    tokens = parse_tokens(raw or "")
    summary, pairs = analyze(tokens)

    with open(args.out_md, "w", encoding="utf-8") as f:
        f.write(markdown(summary, pairs))

    with open(args.out_json, "w", encoding="utf-8") as f:
        json.dump({"summary": asdict(summary), "pairs": pairs}, f, ensure_ascii=False, indent=2)

    print(f"Wrote {args.out_md} and {args.out_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
