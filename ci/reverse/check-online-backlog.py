#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate online intake patch backlog status")
    parser.add_argument("--backlog-json", default="docs/reverse/online-intake/PATCH_TRANSFER_BACKLOG.json")
    parser.add_argument("--fail-on-needs-review", action="store_true")
    parser.add_argument("--fail-on-intake-errors", action="store_true")
    parser.add_argument("--fail-on-commit-scan-errors", action="store_true")
    parser.add_argument("--require-ready-validated", action="store_true")
    parser.add_argument("--require-medium-ready-validated", action="store_true")
    parser.add_argument("--require-low-ready-validated", action="store_true")
    parser.add_argument("--require-high-markers", default="")
    parser.add_argument("--require-medium-markers", default="")
    parser.add_argument("--require-low-markers", default="")
    args = parser.parse_args()

    path = Path(args.backlog_json)
    if not path.exists():
        raise SystemExit(f"[online-backlog-check][error] missing file: {path}")

    payload = json.loads(path.read_text(encoding="utf-8"))
    rows = payload.get("rows") or []
    intake_errors = int(payload.get("intake_errors", 0) or 0)
    commit_scan_errors = int(payload.get("commit_scan_errors", 0) or 0)
    commit_scan_used = bool(payload.get("commit_scan_used", False))
    if not isinstance(rows, list):
        raise SystemExit("[online-backlog-check][error] rows must be a list")

    high_rows = [row for row in rows if str(row.get("priority", "")).lower() == "high"]
    medium_rows = [row for row in rows if str(row.get("priority", "")).lower() == "medium"]
    low_rows = [row for row in rows if str(row.get("priority", "")).lower() == "low"]
    high_markers = {str(row.get("marker", "")).strip() for row in high_rows if str(row.get("marker", "")).strip()}
    medium_markers = {str(row.get("marker", "")).strip() for row in medium_rows if str(row.get("marker", "")).strip()}
    low_markers = {str(row.get("marker", "")).strip() for row in low_rows if str(row.get("marker", "")).strip()}
    missing_target = [row for row in high_rows if row.get("status") == "missing_target"]
    needs_review = [row for row in high_rows if row.get("status") == "needs_review"]
    not_validated = [row for row in high_rows if row.get("status") != "ready_validated"]
    medium_not_validated = [row for row in medium_rows if row.get("status") != "ready_validated"]
    low_not_validated = [row for row in low_rows if row.get("status") != "ready_validated"]
    required_markers = {
        item.strip()
        for item in str(args.require_high_markers).split(",")
        if item.strip()
    }
    missing_markers = sorted(required_markers - high_markers)
    required_medium_markers = {
        item.strip()
        for item in str(args.require_medium_markers).split(",")
        if item.strip()
    }
    missing_medium_markers = sorted(required_medium_markers - medium_markers)
    required_low_markers = {
        item.strip()
        for item in str(args.require_low_markers).split(",")
        if item.strip()
    }
    missing_low_markers = sorted(required_low_markers - low_markers)

    print(f"[online-backlog-check] high_rows={len(high_rows)}")
    print(f"[online-backlog-check] intake_errors={intake_errors}")
    print(f"[online-backlog-check] commit_scan_used={int(commit_scan_used)}")
    print(f"[online-backlog-check] commit_scan_errors={commit_scan_errors}")
    print(f"[online-backlog-check] missing_target={len(missing_target)}")
    print(f"[online-backlog-check] needs_review={len(needs_review)}")
    print(f"[online-backlog-check] not_ready_validated={len(not_validated)}")
    print(f"[online-backlog-check] medium_not_ready_validated={len(medium_not_validated)}")
    print(f"[online-backlog-check] low_rows={len(low_rows)}")
    print(f"[online-backlog-check] low_not_ready_validated={len(low_not_validated)}")
    print(f"[online-backlog-check] missing_required_markers={len(missing_markers)}")
    print(f"[online-backlog-check] missing_required_medium_markers={len(missing_medium_markers)}")
    print(f"[online-backlog-check] missing_required_low_markers={len(missing_low_markers)}")

    if args.fail_on_intake_errors and intake_errors > 0:
        print(f"[online-backlog-check][error] intake_errors={intake_errors}")
        raise SystemExit(1)

    if args.fail_on_commit_scan_errors and commit_scan_errors > 0:
        print(f"[online-backlog-check][error] commit_scan_errors={commit_scan_errors}")
        raise SystemExit(1)

    if missing_target:
        for row in missing_target:
            marker = row.get("marker", "")
            target = row.get("target", "")
            evidence = row.get("first_evidence", "")
            detail = f" evidence={evidence}" if evidence else ""
            print(f"[online-backlog-check][error] missing target for high marker {marker}: {target}{detail}")
        raise SystemExit(1)

    if args.fail_on_needs_review and needs_review:
        for row in needs_review:
            marker = row.get("marker", "")
            target = row.get("target", "")
            evidence = row.get("first_evidence", "")
            detail = f" evidence={evidence}" if evidence else ""
            print(f"[online-backlog-check][error] high marker still needs review: {marker} -> {target}{detail}")
        raise SystemExit(1)

    if args.require_ready_validated and not_validated:
        for row in not_validated:
            marker = row.get("marker", "")
            target = row.get("target", "")
            status = row.get("status", "")
            evidence = row.get("first_evidence", "")
            detail = f" evidence={evidence}" if evidence else ""
            print(
                f"[online-backlog-check][error] high marker not ready_validated: {marker} -> {target} status={status}{detail}"
            )
        raise SystemExit(1)

    if args.require_medium_ready_validated and medium_not_validated:
        for row in medium_not_validated:
            marker = row.get("marker", "")
            target = row.get("target", "")
            status = row.get("status", "")
            evidence = row.get("first_evidence", "")
            detail = f" evidence={evidence}" if evidence else ""
            print(
                f"[online-backlog-check][error] medium marker not ready_validated: {marker} -> {target} status={status}{detail}"
            )
        raise SystemExit(1)

    if args.require_low_ready_validated and low_not_validated:
        for row in low_not_validated:
            marker = row.get("marker", "")
            target = row.get("target", "")
            status = row.get("status", "")
            evidence = row.get("first_evidence", "")
            detail = f" evidence={evidence}" if evidence else ""
            print(
                f"[online-backlog-check][error] low marker not ready_validated: {marker} -> {target} status={status}{detail}"
            )
        raise SystemExit(1)

    if missing_markers:
        print(
            "[online-backlog-check][error] missing required high markers: "
            + ", ".join(missing_markers)
        )
        raise SystemExit(1)

    if missing_medium_markers:
        print(
            "[online-backlog-check][error] missing required medium markers: "
            + ", ".join(missing_medium_markers)
        )
        raise SystemExit(1)

    if missing_low_markers:
        print(
            "[online-backlog-check][error] missing required low markers: "
            + ", ".join(missing_low_markers)
        )
        raise SystemExit(1)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
