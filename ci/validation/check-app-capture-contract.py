#!/usr/bin/env python3
import argparse
import json
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate app capture contract from metrics.json")
    parser.add_argument("--capture-dir", required=True, help="Path to one capture directory")
    parser.add_argument(
        "--expect-wine-process",
        choices=["required", "optional", "forbidden"],
        default="optional",
        help="Expected wine/wineserver process presence in ps samples",
    )
    parser.add_argument(
        "--min-external-container-setup-count",
        type=int,
        default=0,
        help="Minimal external container setup markers count",
    )
    parser.add_argument("--out", required=True, help="Output markdown report path")
    args = parser.parse_args()

    capture = Path(args.capture_dir)
    metrics_file = capture / "metrics.json"
    if not metrics_file.is_file():
        raise SystemExit(f"[capture-contract][error] missing metrics file: {metrics_file}")

    data = json.loads(metrics_file.read_text(encoding="utf-8"))
    metrics = data.get("metrics", {})
    wine_process_present = int(metrics.get("wine_process_present", 0))
    container_markers = int(metrics.get("external_container_setup_count", 0))

    failures = []
    if args.expect_wine_process == "required" and wine_process_present == 0:
        failures.append("wine_process_required_but_absent")
    if args.expect_wine_process == "forbidden" and wine_process_present != 0:
        failures.append("wine_process_forbidden_but_present")
    if container_markers < args.min_external_container_setup_count:
        failures.append(
            f"external_container_setup_markers_below_min({container_markers}<{args.min_external_container_setup_count})"
        )

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("w", encoding="utf-8") as f:
        f.write("# App Capture Contract Report\n\n")
        f.write(f"- Capture dir: `{capture}`\n")
        f.write(f"- Scenario: `{data.get('scenario', '')}`\n")
        f.write(f"- Package: `{data.get('package', '')}`\n")
        f.write(f"- Expect wine process: `{args.expect_wine_process}`\n")
        f.write(f"- Min external container setup count: `{args.min_external_container_setup_count}`\n\n")
        f.write("## Metrics\n\n")
        for key in sorted(metrics):
            f.write(f"- `{key}`: `{metrics[key]}`\n")
        f.write("\n## Result\n\n")
        if failures:
            f.write("- status: **FAIL**\n")
            for item in failures:
                f.write(f"- failure: `{item}`\n")
        else:
            f.write("- status: **PASS**\n")

    json_out = out.with_suffix(".json")
    json_out.write_text(
        json.dumps(
            {
                "capture_dir": str(capture),
                "scenario": data.get("scenario", ""),
                "package": data.get("package", ""),
                "expect_wine_process": args.expect_wine_process,
                "min_external_container_setup_count": args.min_external_container_setup_count,
                "metrics": metrics,
                "failures": failures,
                "passed": not failures,
            },
            indent=2,
            ensure_ascii=True,
        )
        + "\n",
        encoding="utf-8",
    )

    if failures:
        print(f"[capture-contract][fail] {capture} failures={len(failures)}")
        return 1
    print(f"[capture-contract] pass {capture}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
