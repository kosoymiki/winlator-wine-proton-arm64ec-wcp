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
        source_repo = str(item.get("sourceRepo", "")).strip()
        release_tag = str(item.get("releaseTag", "")).strip()
        source_version = str(item.get("sourceVersion", "")).strip()
        artifact_name = str(item.get("artifactName", "")).strip()
        sha256_url = str(item.get("sha256Url", "")).strip()

        if channel not in ALLOWED_CHANNELS:
            fail(f"entry {idx} has invalid channel: {channel}")
        if delivery not in ALLOWED_DELIVERY:
            fail(f"entry {idx} has invalid delivery: {delivery}")
        if not remote_url.startswith("https://github.com/kosoymiki/winlator-wine-proton-arm64ec-wcp/releases/download/"):
            fail(f"entry {idx} remoteUrl must point to this repo releases: {remote_url}")
        if type_name.lower() == "wine" and not WINE_VERSION_RE.match(ver_name):
            fail(f"entry {idx} verName is not Winlator-parseable: {ver_name}")
        if not source_repo:
            fail(f"entry {idx} missing sourceRepo")
        if not release_tag:
            fail(f"entry {idx} missing releaseTag")
        if not source_version:
            fail(f"entry {idx} missing sourceVersion")
        if not artifact_name:
            fail(f"entry {idx} missing artifactName")
        if not remote_url.endswith("/" + artifact_name):
            fail(f"entry {idx} remoteUrl must end with artifactName ({artifact_name}): {remote_url}")
        if not sha256_url:
            fail(f"entry {idx} missing sha256Url")
        if not sha256_url.startswith("https://github.com/kosoymiki/winlator-wine-proton-arm64ec-wcp/releases/download/"):
            fail(f"entry {idx} sha256Url must point to this repo releases: {sha256_url}")
        if f"/{release_tag}/" not in sha256_url:
            fail(f"entry {idx} sha256Url must use matching releaseTag {release_tag}: {sha256_url}")
        if not artifact_name.endswith(".wcp"):
            fail(f"entry {idx} artifactName must end with .wcp: {artifact_name}")

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
