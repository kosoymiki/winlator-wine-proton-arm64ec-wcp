#!/usr/bin/env python3
"""Static contract gate for Contents QA checklist.

This gate validates repository-side invariants that do not require device access.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Sequence

ALLOWED_WINE_INTERNAL_TYPES = {"wine", "proton", "protonge", "protonwine"}
TARGET_REPO = "kosoymiki/winlator-wine-proton-arm64ec-wcp"
TARGET_RELEASE_PREFIX = f"https://github.com/{TARGET_REPO}/releases/download/"
TARGET_OVERLAY_URL = (
    "https://raw.githubusercontent.com/"
    f"{TARGET_REPO}/main/contents/contents.json"
)
TARGET_HUB_PROFILES_URL = "https://raw.githubusercontent.com/Arihany/WinlatorWCPHub/main/pack.json"

WORKFLOW_EXPECTATIONS = {
    ".github/workflows/ci-arm64ec-wine.yml": {
        "WCP_VERSION_CODE": "\"1\"",
        "WCP_CHANNEL": "nightly",
        "WCP_DELIVERY": "remote",
        "WCP_DISPLAY_CATEGORY": "Wine/Proton",
        "WCP_RELEASE_TAG": "wine-11-arm64ec-latest",
    },
    ".github/workflows/ci-proton-ge10-wcp.yml": {
        "WCP_VERSION_CODE": "\"1\"",
        "WCP_CHANNEL": "nightly",
        "WCP_DELIVERY": "remote",
        "WCP_DISPLAY_CATEGORY": "Wine/Proton",
        "WCP_RELEASE_TAG": "proton-ge10-arm64ec-latest",
    },
    ".github/workflows/ci-protonwine10-wcp.yml": {
        "WCP_VERSION_CODE": "\"1\"",
        "WCP_CHANNEL": "nightly",
        "WCP_DELIVERY": "remote",
        "WCP_DISPLAY_CATEGORY": "Wine/Proton",
        "WCP_RELEASE_TAG": "protonwine10-gamenative-arm64ec-latest",
    },
}

ARTIFACT_EXPECTED_KEYS = {
    "wine11": "wine",
    "protonge10": "protonge",
    "protonwine10": "protonwine",
}


@dataclass
class CheckResult:
    failures: List[str]
    warnings: List[str]


def fail(msg: str, failures: List[str]) -> None:
    failures.append(msg)


def warn(msg: str, warnings: List[str]) -> None:
    warnings.append(msg)


def load_json(path: Path) -> object:
    return json.loads(path.read_text(encoding="utf-8"))


def check_contents_schema(
    contents_path: Path,
    artifact_map_path: Path,
    failures: List[str],
    _warnings: List[str],
) -> None:
    payload = load_json(contents_path)
    if not isinstance(payload, list):
        fail("contents root must be JSON array", failures)
        return
    if not payload:
        fail("contents list is empty", failures)
        return

    artifact_map = load_json(artifact_map_path)
    artifacts = artifact_map.get("artifacts", {}) if isinstance(artifact_map, dict) else {}
    if not isinstance(artifacts, dict):
        fail("artifact-source-map artifacts must be object", failures)
        artifacts = {}

    required_fields = {
        "type",
        "internalType",
        "verName",
        "verCode",
        "channel",
        "delivery",
        "displayCategory",
        "sourceRepo",
        "releaseTag",
        "artifactName",
        "remoteUrl",
        "sha256Url",
    }

    seen_identity = set()
    wine_entries_by_internal: Dict[str, dict] = {}

    for idx, row in enumerate(payload):
        if not isinstance(row, dict):
            fail(f"entry[{idx}] is not object", failures)
            continue

        missing = sorted(required_fields - set(row.keys()))
        if missing:
            fail(f"entry[{idx}] missing fields: {','.join(missing)}", failures)
            continue

        type_name = str(row.get("type", ""))
        internal_type = str(row.get("internalType", "")).strip().lower()
        channel = str(row.get("channel", "")).strip().lower()
        delivery = str(row.get("delivery", "")).strip().lower()
        display_category = str(row.get("displayCategory", "")).strip()
        source_repo = str(row.get("sourceRepo", "")).strip()
        release_tag = str(row.get("releaseTag", "")).strip()
        artifact_name = str(row.get("artifactName", "")).strip()
        remote_url = str(row.get("remoteUrl", "")).strip()
        sha256_url = str(row.get("sha256Url", "")).strip()
        ver_name = str(row.get("verName", "")).strip()
        ver_code = str(row.get("verCode", "")).strip()

        identity = (type_name.lower(), internal_type, ver_name, ver_code)
        if identity in seen_identity:
            fail(f"duplicate entry identity: {identity}", failures)
        seen_identity.add(identity)

        if type_name != "Wine":
            fail(f"entry[{idx}] type must stay 'Wine' for Wine-family package rows", failures)

        if internal_type not in ALLOWED_WINE_INTERNAL_TYPES:
            fail(
                f"entry[{idx}] internalType must be one of {sorted(ALLOWED_WINE_INTERNAL_TYPES)}; got {internal_type}",
                failures,
            )

        if channel != "stable":
            fail(f"entry[{idx}] channel must be stable in overlay contents; got {channel}", failures)

        if delivery != "remote":
            fail(f"entry[{idx}] delivery must be remote; got {delivery}", failures)

        if display_category != "Wine/Proton":
            fail(f"entry[{idx}] displayCategory must be Wine/Proton; got {display_category}", failures)

        if source_repo != TARGET_REPO:
            fail(f"entry[{idx}] sourceRepo must be {TARGET_REPO}; got {source_repo}", failures)

        if not release_tag.endswith("-latest"):
            fail(f"entry[{idx}] releaseTag must end with -latest: {release_tag}", failures)

        if not artifact_name.endswith(".wcp"):
            fail(f"entry[{idx}] artifactName must end with .wcp; got {artifact_name}", failures)

        if not remote_url.startswith(TARGET_RELEASE_PREFIX):
            fail(f"entry[{idx}] remoteUrl must point to target releases repo; got {remote_url}", failures)

        if f"/{release_tag}/" not in remote_url:
            fail(f"entry[{idx}] remoteUrl must include releaseTag segment {release_tag}", failures)

        if not remote_url.endswith("/" + artifact_name):
            fail(
                f"entry[{idx}] remoteUrl must end with artifactName ({artifact_name}); got {remote_url}",
                failures,
            )

        if not sha256_url.startswith(TARGET_RELEASE_PREFIX):
            fail(f"entry[{idx}] sha256Url must point to target releases repo; got {sha256_url}", failures)

        if f"/{release_tag}/" not in sha256_url:
            fail(f"entry[{idx}] sha256Url must include releaseTag segment {release_tag}", failures)

        source_version = str(row.get("sourceVersion", "")).strip()
        if source_version != "rolling-latest":
            fail(
                f"entry[{idx}] sourceVersion must be rolling-latest for overlay rows; got {source_version}",
                failures,
            )

        wine_entries_by_internal[internal_type] = row

    for artifact_key, internal_type in ARTIFACT_EXPECTED_KEYS.items():
        artifact = artifacts.get(artifact_key)
        if not isinstance(artifact, dict):
            fail(f"artifact-source-map missing artifact key: {artifact_key}", failures)
            continue

        entry = wine_entries_by_internal.get(internal_type)
        if not entry:
            fail(f"contents missing internalType entry for artifact key {artifact_key}: {internal_type}", failures)
            continue

        expected_remote = str(artifact.get("remoteUrl", "")).strip()
        expected_sha = str(artifact.get("sha256Url", "")).strip()
        actual_remote = str(entry.get("remoteUrl", "")).strip()
        actual_sha = str(entry.get("sha256Url", "")).strip()

        if expected_remote != actual_remote:
            fail(
                f"remoteUrl mismatch for {artifact_key}: contents={actual_remote} artifact-map={expected_remote}",
                failures,
            )
        if expected_sha != actual_sha:
            fail(
                f"sha256Url mismatch for {artifact_key}: contents={actual_sha} artifact-map={expected_sha}",
                failures,
            )


def check_patch_contract(patch_path: Path, failures: List[str]) -> None:
    text = patch_path.read_text(encoding="utf-8", errors="ignore")

    required_tokens = [
        'REMOTE_PROFILES = "' + TARGET_HUB_PROFILES_URL + '";',
        'REMOTE_WINE_PROTON_OVERLAY = "' + TARGET_OVERLAY_URL + '"',
        'sp.getBoolean("beta_contents_enabled", false)',
        'ContentProfile.MARK_DISPLAY_CATEGORY',
        'ContentProfile.MARK_SOURCE_REPO',
        'ContentProfile.MARK_RELEASE_TAG',
        'profile.sourceRepo != null && !profile.sourceRepo.isEmpty()',
        'profile.releaseTag != null && !profile.releaseTag.isEmpty()',
        'if (includeBeta && !isBeta) continue;',
        'if (!includeBeta && isBeta) continue;',
    ]

    for token in required_tokens:
        if token not in text:
            fail(f"patch contract token missing in 0001: {token}", failures)


def check_contents_validator_contract(root: Path, failures: List[str]) -> None:
    validator = root / "ci/contents/validate-contents-json.py"
    contents = root / "contents/contents.json"
    if not validator.is_file():
        fail("contents validator missing: ci/contents/validate-contents-json.py", failures)
        return
    if not contents.is_file():
        fail("contents file missing: contents/contents.json", failures)
        return
    result = subprocess.run(
        [sys.executable, str(validator), str(contents)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        first_line = stderr.splitlines()[0] if stderr else f"rc={result.returncode}"
        fail(f"contents validator failed: {first_line}", failures)


def check_release_publish_contract(root: Path, failures: List[str]) -> None:
    publish_script = root / "ci/release/publish-0.9c.sh"
    notes_template = root / "ci/release/templates/wcp-stable.ru-en.md"
    notes_prepare = root / "ci/release/prepare-0.9c-notes.sh"

    for path in (publish_script, notes_template, notes_prepare):
        if not path.is_file():
            fail(f"required release contract file missing: {path}", failures)
            return

    publish_text = publish_script.read_text(encoding="utf-8", errors="ignore")
    template_text = notes_template.read_text(encoding="utf-8", errors="ignore")
    prepare_text = notes_prepare.read_text(encoding="utf-8", errors="ignore")

    required_publish_tokens = [
        'WCP_TAG="wcp-stable"',
        'WCP_NOTES="${ROOT_DIR}/out/release-notes/wcp-stable.md"',
        'mkdir -p "${STAGE_DIR}/wcp-stable" "${STAGE_DIR}/winlator-v0.9c"',
        'gh release upload "${WCP_TAG}" --repo "${REPO}" --clobber "${WCP_ASSETS[@]}"',
    ]
    for token in required_publish_tokens:
        if token not in publish_text:
            fail(f"release publish contract token missing: {token}", failures)

    if "wcp-stable" not in template_text or "stable" not in template_text:
        fail("wcp-stable notes template must describe stable lane metadata", failures)

    if 'wcp-stable.md' not in prepare_text:
        fail("prepare release notes flow must produce wcp-stable.md", failures)


def check_workflow_contract(root: Path, failures: List[str]) -> None:
    for rel_path, expectations in WORKFLOW_EXPECTATIONS.items():
        workflow_path = root / rel_path
        if not workflow_path.is_file():
            fail(f"workflow missing: {rel_path}", failures)
            continue
        text = workflow_path.read_text(encoding="utf-8", errors="ignore")

        for key, value in expectations.items():
            pattern = rf"^\s*{re.escape(key)}\s*:\s*{re.escape(value)}\s*$"
            if not re.search(pattern, text, re.MULTILINE):
                fail(f"workflow {rel_path} missing expected env contract: {key}: {value}", failures)


def render_markdown(result: CheckResult) -> str:
    status = "PASS" if not result.failures else "FAIL"
    lines: List[str] = [
        "# Contents QA Contract",
        "",
        f"- status: **{status}**",
        f"- failures: **{len(result.failures)}**",
        f"- warnings: **{len(result.warnings)}**",
        "",
        "## Failures",
        "",
    ]
    if not result.failures:
        lines.append("- none")
    else:
        for item in result.failures:
            lines.append(f"- {item}")

    lines.extend(["", "## Warnings", ""])
    if not result.warnings:
        lines.append("- none")
    else:
        for item in result.warnings:
            lines.append(f"- {item}")
    lines.append("")
    return "\n".join(lines)


def write_report(output: Path, result: CheckResult) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(render_markdown(result), encoding="utf-8")

    json_out = output.with_suffix(".json")
    json_out.write_text(
        json.dumps(
            {
                "passed": not result.failures,
                "failures": result.failures,
                "warnings": result.warnings,
            },
            indent=2,
            ensure_ascii=True,
        )
        + "\n",
        encoding="utf-8",
    )


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate static contents QA contract")
    parser.add_argument("--root", default=".", help="Repository root")
    parser.add_argument("--output", default="-", help="Markdown report path or '-' for stdout")
    parser.add_argument("--strict", action="store_true", help="Exit non-zero on warnings too")
    return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
    args = parse_args(argv)
    root = Path(args.root).resolve()

    contents_path = root / "contents/contents.json"
    artifact_map_path = root / "ci/winlator/artifact-source-map.json"
    patch_path = root / "ci/winlator/patches/0001-mainline-full-stack-consolidated.patch"

    failures: List[str] = []
    warnings: List[str] = []

    for path in (contents_path, artifact_map_path, patch_path):
        if not path.is_file():
            fail(f"required file missing: {path}", failures)

    if not failures:
        check_contents_schema(contents_path, artifact_map_path, failures, warnings)
        check_patch_contract(patch_path, failures)
        check_contents_validator_contract(root, failures)
        check_release_publish_contract(root, failures)
        check_workflow_contract(root, failures)

    result = CheckResult(failures=failures, warnings=warnings)

    if args.output == "-":
        sys.stdout.write(render_markdown(result))
    else:
        write_report(Path(args.output), result)

    if result.failures:
        return 1
    if args.strict and result.warnings:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
