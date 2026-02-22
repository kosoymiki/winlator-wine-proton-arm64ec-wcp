#!/usr/bin/env bash
set -euo pipefail

COMMITS_TSV="${1:-}"
OUT_MD="${2:-}"
UPSTREAM_REPO="${3:-https://github.com/StevenMXZ/Winlator-Ludashi}"

log() { printf '[winlator-review] %s\n' "$*"; }
fail() { printf '[winlator-review][error] %s\n' "$*" >&2; exit 1; }

[[ -n "${COMMITS_TSV}" && -n "${OUT_MD}" ]] || fail "usage: $0 <commits.tsv> <out-md> [upstream-repo-url]"
[[ -f "${COMMITS_TSV}" ]] || fail "commits.tsv not found: ${COMMITS_TSV}"

mkdir -p "$(dirname -- "${OUT_MD}")"

python3 - "$COMMITS_TSV" "$OUT_MD" "$UPSTREAM_REPO" <<'PY'
import datetime as dt
import pathlib
import re
import sys

commits_path = pathlib.Path(sys.argv[1])
out_path = pathlib.Path(sys.argv[2])
repo_url = sys.argv[3].rstrip('/')

lines = [l.strip() for l in commits_path.read_text(encoding='utf-8').splitlines() if l.strip()]
rows = []
for line in lines:
    parts = line.split('|', 3)
    if len(parts) != 4:
        continue
    sha, date_iso, author, subject = parts
    rows.append((sha, date_iso, author, subject))

keywords = [
    ("arm64ec", "ARM64EC compatibility"),
    ("arm64", "ARM64 compatibility"),
    ("fex", "FEX runner logic"),
    ("box64", "Box64 runner logic"),
    ("wine", "Wine runtime behavior"),
    ("container", "Container lifecycle"),
    ("android", "Android platform behavior"),
    ("build", "Build and CI behavior"),
    ("crash", "Crash handling"),
    ("fix", "Bug fix signal"),
]

def score(subject: str) -> int:
    s = subject.lower()
    base = 0
    for key, _ in keywords:
        if key in s:
            base += 3
    if re.search(r"\bfix\b|\bbug\b|\bcrash\b|\bregress", s):
        base += 3
    if re.search(r"\brefactor\b|\bcleanup\b", s):
        base += 1
    return base

ranked = sorted(rows, key=lambda r: score(r[3]), reverse=True)
focus = ranked[:10]

now = dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")

md = []
md.append("# Winlator Ludashi Reflective Analysis")
md.append("")
md.append(f"Generated: {now}")
md.append(f"Upstream: {repo_url}")
md.append(f"Commits inspected: {len(rows)}")
md.append("")
md.append("## Snapshot")
if rows:
    md.append(f"- Latest commit: `{rows[0][0]}` — {rows[0][3]}")
    md.append(f"- Latest author/date: {rows[0][2]} / {rows[0][1]}")
else:
    md.append("- No commits captured.")
md.append("")
md.append("## Top Impact Candidates")
if focus:
    for sha, date_iso, author, subject in focus:
        s = subject.lower()
        reasons = [label for key, label in keywords if key in s]
        if not reasons:
            reasons = ["General maintenance"]
        md.append(f"- `{sha[:12]}` {subject}")
        md.append(f"  - Why it matters: {', '.join(reasons)}")
        md.append(f"  - Trace: {repo_url}/commit/{sha}")
else:
    md.append("- No high-impact commits identified.")
md.append("")
md.append("## Integration Risks For Our Fork")
md.append("- Identifier parsing in Winlator is historically strict; non-standard runtime names can be misdetected as x86_64.")
md.append("- Runner UX is coupled to arch detection; if ARM64EC detection fails, FEX options are hidden and Box64 becomes forced.")
md.append("- Runtime startup depends on LD/Wine library paths; missing `/opt/<runtime>/lib` search paths produces launch-time crashes.")
md.append("- Container creation reads runtime DLL trees directly; missing guards can cause null dereferences on malformed runtime layouts.")
md.append("")
md.append("## Applied Mitigation Strategy")
md.append("- Patch `WineInfo.fromIdentifier` to parse generic `*-arm64ec` identifiers, not only numeric proton/wine formats.")
md.append("- Force robust emulator defaults for ARM64EC (`FEXCore`) and explicit Box64 fallback for non-ARM64EC runtimes.")
md.append("- Expand startup `LD_LIBRARY_PATH` / `WINEDLLPATH` / `PATH` to include selected runtime under `/opt/<runtime>`.")
md.append("- Fail gracefully during container DLL extraction if expected runtime directories are missing.")

out_path.write_text("\n".join(md) + "\n", encoding='utf-8')
PY

log "Reflective analysis written to ${OUT_MD}"
