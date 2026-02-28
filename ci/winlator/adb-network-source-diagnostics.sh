#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${WLT_PACKAGE:=by.aero.so.benchmark}"
: "${WLT_OUT_DIR:=/tmp/winlator-network-diag-$(date +%Y%m%d_%H%M%S)}"
: "${WLT_SOURCE_MAP:=${ROOT_DIR}/ci/winlator/artifact-source-map.json}"
: "${WLT_URL_TIMEOUT:=20}"

log() { printf '[adb-network-diag] %s\n' "$*"; }
fail() { printf '[adb-network-diag][error] %s\n' "$*" >&2; exit 1; }

require_cmd() { command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"; }

pick_serial() {
  local serial
  serial="${ADB_SERIAL:-}"
  if [[ -n "${serial}" ]]; then
    printf '%s\n' "${serial}"
    return 0
  fi
  adb devices | awk 'NR>1 && $2=="device" {print $1; exit}'
}

adb_s() { adb -s "${ADB_SERIAL_PICKED}" "$@"; }

main() {
  local endpoints_file out_json

  require_cmd adb
  require_cmd python3
  require_cmd jq
  [[ -f "${WLT_SOURCE_MAP}" ]] || fail "source map not found: ${WLT_SOURCE_MAP}"

  mkdir -p "${WLT_OUT_DIR}"

  ADB_SERIAL_PICKED="$(pick_serial)"
  [[ -n "${ADB_SERIAL_PICKED}" ]] || fail "no active adb device"
  log "device=${ADB_SERIAL_PICKED} package=${WLT_PACKAGE}"

  endpoints_file="${WLT_OUT_DIR}/endpoints.txt"
  python3 - "${WLT_SOURCE_MAP}" "${endpoints_file}" <<'PY'
import json
import sys
from pathlib import Path

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
data = json.loads(src.read_text(encoding="utf-8"))
urls = set()
for key, row in (data.get("artifacts") or {}).items():
    if not isinstance(row, dict):
        continue
    for field in ("remoteUrl", "url", "sha256Url", "releaseUrl", "metadataUrl"):
        value = str(row.get(field, "")).strip()
        if value.startswith("http"):
            urls.add(value)
for fallback in (
    "https://api.github.com",
    "https://raw.githubusercontent.com",
    "https://github.com",
    "https://gamenative.app/drivers/",
):
    urls.add(fallback)
dst.write_text("\n".join(sorted(urls)) + "\n", encoding="utf-8")
PY

  adb_s shell settings get global http_proxy > "${WLT_OUT_DIR}/global-http-proxy.txt" 2>/dev/null || true
  adb_s shell settings get global private_dns_mode > "${WLT_OUT_DIR}/global-private-dns-mode.txt" 2>/dev/null || true
  adb_s shell settings get global private_dns_specifier > "${WLT_OUT_DIR}/global-private-dns-specifier.txt" 2>/dev/null || true
  adb_s shell getprop > "${WLT_OUT_DIR}/getprop.txt" 2>/dev/null || true
  adb_s shell dumpsys connectivity > "${WLT_OUT_DIR}/dumpsys-connectivity.txt" 2>/dev/null || true
  adb_s shell ip route > "${WLT_OUT_DIR}/ip-route.txt" 2>/dev/null || true
  adb_s shell "run-as ${WLT_PACKAGE} sh -c 'cat ./shared_prefs/by.aero.so.benchmark_preferences.xml 2>/dev/null'" > "${WLT_OUT_DIR}/prefs.xml" 2>/dev/null || true

  out_json="${WLT_OUT_DIR}/endpoint-probes.tsv"
  printf 'url\thttp_code\ttime_dns\ttime_connect\ttime_tls\ttime_total\tcurl_status\n' > "${out_json}"
  while IFS= read -r url; do
    [[ -n "${url}" ]] || continue
    probe="$(
      adb_s shell "curl -L -m ${WLT_URL_TIMEOUT} -sS -o /dev/null -w 'code=%{http_code} dns=%{time_namelookup} conn=%{time_connect} tls=%{time_appconnect} total=%{time_total} status=%{exitcode}' '${url}'" \
        < /dev/null 2>/dev/null || true
    )"
    code="$(printf '%s' "${probe}" | sed -n 's/.*code=\([^ ]*\).*/\1/p')"
    dns="$(printf '%s' "${probe}" | sed -n 's/.*dns=\([^ ]*\).*/\1/p')"
    conn="$(printf '%s' "${probe}" | sed -n 's/.*conn=\([^ ]*\).*/\1/p')"
    tls="$(printf '%s' "${probe}" | sed -n 's/.*tls=\([^ ]*\).*/\1/p')"
    total="$(printf '%s' "${probe}" | sed -n 's/.*total=\([^ ]*\).*/\1/p')"
    status="$(printf '%s' "${probe}" | sed -n 's/.*status=\([^ ]*\).*/\1/p')"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "${url}" "${code:-}" "${dns:-}" "${conn:-}" "${tls:-}" "${total:-}" "${status:-}" >> "${out_json}"
  done < "${endpoints_file}"

python3 - "${out_json}" "${WLT_OUT_DIR}/endpoint-probes.summary.json" <<'PY'
import csv
import json
import sys
from pathlib import Path

tsv = Path(sys.argv[1])
out = Path(sys.argv[2])
rows = []
status_counts = {}
http_counts = {}
dns_zero = 0
problem_rows = []

with tsv.open("r", encoding="utf-8", newline="") as h:
    reader = csv.DictReader(h, delimiter="\t")
    for row in reader:
        rows.append(row)
        status = row.get("curl_status", "")
        code = row.get("http_code", "")
        status_counts[status] = status_counts.get(status, 0) + 1
        http_counts[code] = http_counts.get(code, 0) + 1
        if row.get("time_dns") in ("0", "0.0", "0.000000", "") and code in ("000", ""):
            dns_zero += 1
        if status not in ("0", "") or code.startswith(("4", "5")) or code == "000":
            problem_rows.append(
                {
                    "url": row.get("url", ""),
                    "http_code": code,
                    "curl_status": status,
                    "time_total": row.get("time_total", ""),
                }
            )

payload = {
    "totalEndpoints": len(rows),
    "curlStatusCounts": status_counts,
    "httpCodeCounts": http_counts,
    "dnsZeroAndCode000": dns_zero,
    "problemEndpoints": problem_rows[:20],
}
out.write_text(json.dumps(payload, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
PY

  log "wrote diagnostics: ${WLT_OUT_DIR}"
}

main "$@"
