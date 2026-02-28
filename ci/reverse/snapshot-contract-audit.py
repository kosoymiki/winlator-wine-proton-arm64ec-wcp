#!/usr/bin/env python3
import argparse
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List


@dataclass
class Rule:
    rule_id: str
    label: str
    file_path: Path
    required: List[str]
    hard_fail: bool = True


def evaluate_rule(rule: Rule) -> Dict:
    row = {
        "id": rule.rule_id,
        "label": rule.label,
        "path": str(rule.file_path),
        "hard_fail": int(bool(rule.hard_fail)),
        "exists": rule.file_path.is_file(),
        "missing_tokens": [],
        "status": "missing_file",
    }
    if not row["exists"]:
        return row
    text = rule.file_path.read_text(encoding="utf-8", errors="replace")
    missing = [token for token in rule.required if token not in text]
    row["missing_tokens"] = missing
    row["status"] = "ready" if not missing else "missing_tokens"
    return row


def write_markdown(path: Path, rows: List[Dict]) -> None:
    lines = [
        "# Snapshot Contract Audit",
        "",
        "| Check | File | Status | Missing Tokens |",
        "| --- | --- | --- | --- |",
    ]
    for row in rows:
        missing = ", ".join(f"`{token}`" for token in row.get("missing_tokens") or [])
        lines.append(
            f"| `{row.get('id','')}` | `{row.get('path','')}` | `{row.get('status','')}` | {missing or '-'} |"
        )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build_rules(repo_root: Path, snapshot_root: Path) -> List[Rule]:
    return [
        Rule(
            rule_id="coffin_mouse_snapshot_markers",
            label="coffin wine mouse snapshot keeps no-XInput2 markers",
            file_path=snapshot_root / "coffin_wine/dlls/winex11.drv/mouse.c",
            required=["xinput2_available", "NtUserSendHardwareInput"],
            hard_fail=False,
        ),
        Rule(
            rule_id="coffin_winebrowser_snapshot_markers",
            label="coffin winebrowser snapshot keeps android-browser bridge marker",
            file_path=snapshot_root / "coffin_wine/programs/winebrowser/main.c",
            required=["WINE_OPEN_WITH_ANDROID_BROWSER", "send("],
            hard_fail=False,
        ),
        Rule(
            rule_id="coffin_loader_snapshot_markers",
            label="coffin loader snapshot keeps wow64 suspend symbol marker",
            file_path=snapshot_root / "coffin_wine/dlls/ntdll/unix/loader.c",
            required=["Wow64SuspendLocalThread", "RtlWow64SuspendThread"],
            hard_fail=False,
        ),
        Rule(
            rule_id="gn_patch_mouse_contract",
            label="GN patch mouse contract keeps helper-gated NO_RAW path",
            file_path=repo_root / "ci/gamenative/patchsets/28c3a06/android/patches/dlls_winex11_drv_mouse_c_wm_input_fix.patch",
            required=["get_send_mouse_flags", "SEND_HWMSG_NO_RAW"],
        ),
        Rule(
            rule_id="gn_patch_winebrowser_contract",
            label="GN winebrowser patch keeps canonical browser env marker",
            file_path=repo_root / "ci/gamenative/patchsets/28c3a06/android/patches/programs_winebrowser_main_c.patch",
            required=["WINE_OPEN_WITH_ANDROID_BROWSER", "(const char *)&net_requestcode"],
        ),
        Rule(
            rule_id="gn_patch_loader_contract",
            label="GN loader patch keeps wow64 suspend exports",
            file_path=repo_root / "ci/gamenative/patchsets/28c3a06/android/patches/dlls_ntdll_loader_c.patch",
            required=["pWow64SuspendLocalThread", "GET_PTR( Wow64SuspendLocalThread );"],
        ),
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit upstream snapshot markers vs local GN patch contracts")
    parser.add_argument("--snapshot-root", default="ci/reverse/upstream_snapshots")
    parser.add_argument("--output-md", default="docs/reverse/online-intake/harvest/snapshot-contract-audit.md")
    parser.add_argument("--output-json", default="docs/reverse/online-intake/harvest/snapshot-contract-audit.json")
    parser.add_argument("--strict", choices=("0", "1"), default="1")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    snapshot_root = (repo_root / args.snapshot_root).resolve()
    rules = build_rules(repo_root, snapshot_root)
    rows = [evaluate_rule(rule) for rule in rules]

    failed = [row for row in rows if row.get("status") != "ready"]
    failed_hard = [row for row in failed if int(row.get("hard_fail", 1)) == 1]
    payload = {
        "snapshot_root": str(snapshot_root),
        "rows": rows,
        "summary": {
            "total": len(rows),
            "ready": len(rows) - len(failed),
            "failed": len(failed),
            "failed_hard": len(failed_hard),
        },
    }

    json_path = (repo_root / args.output_json).resolve()
    json_path.parent.mkdir(parents=True, exist_ok=True)
    json_path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    write_markdown((repo_root / args.output_md).resolve(), rows)
    print(f"[snapshot-audit] wrote {(repo_root / args.output_md)}")
    print(f"[snapshot-audit] wrote {(repo_root / args.output_json)}")
    if failed:
        print(f"[snapshot-audit] failed checks: {len(failed)} (hard={len(failed_hard)})")
    if failed_hard and args.strict == "1":
        return 1
    if failed:
        print("[snapshot-audit] advisory snapshot drift detected")
        return 0
    print("[snapshot-audit] contract checks passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
