#!/usr/bin/env python3
import json
import re
import sys
from pathlib import Path

ALLOWED_CHANNELS = {"stable", "beta", "nightly"}
ALLOWED_DELIVERY = {"remote", "embedded", ""}
WINE_VERSION_RE = re.compile(r"^[0-9]+(?:\.[0-9]+)*(?:-[0-9]+(?:\.[0-9]+)*)?-(x86|x86_64|arm64ec)$")


def fail(msg: str) -> None:
    print(f"[contents-validate][error] {msg}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    path = Path(sys.argv[1] if len(sys.argv) > 1 else "contents/contents.json")
    if not path.is_file():
        fail(f"file not found: {path}")

    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, list):
        fail("root must be a JSON array")

    seen = set()
    nightly_seen = 0
    stable_seen = 0
    for idx, item in enumerate(data):
        if not isinstance(item, dict):
            fail(f"entry {idx} is not an object")
        for key in ("type", "verName", "verCode", "remoteUrl"):
            if key not in item:
                fail(f"entry {idx} missing required field: {key}")

        type_name = str(item["type"])
        ver_name = str(item["verName"])
        ver_code = int(item["verCode"])
        channel = str(item.get("channel", "stable")).strip().lower()
        delivery = str(item.get("delivery", "")).strip().lower()
        remote_url = str(item["remoteUrl"])

        if channel not in ALLOWED_CHANNELS:
            fail(f"entry {idx} has invalid channel: {channel}")
        if delivery not in ALLOWED_DELIVERY:
            fail(f"entry {idx} has invalid delivery: {delivery}")
        if not remote_url.startswith("https://github.com/kosoymiki/winlator-wine-proton-arm64ec-wcp/releases/download/"):
            fail(f"entry {idx} remoteUrl must point to this repo releases: {remote_url}")
        if type_name.lower() == "wine" and not WINE_VERSION_RE.match(ver_name):
            fail(f"entry {idx} verName is not Winlator-parseable: {ver_name}")

        key = (type_name.lower(), ver_name, ver_code)
        if key in seen:
            fail(f"duplicate type/verName/verCode entry: {key}")
        seen.add(key)

        if channel == "nightly":
            nightly_seen += 1
        if channel == "stable":
            stable_seen += 1

    if stable_seen == 0:
        fail("no stable entries found")
    print(f"[contents-validate] OK: {len(data)} entries ({stable_seen} stable, {nightly_seen} beta/nightly)")


if __name__ == "__main__":
    main()
