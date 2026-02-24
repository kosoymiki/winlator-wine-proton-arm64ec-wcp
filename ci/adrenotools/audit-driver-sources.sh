#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCH_FILE="${PATCH_FILE:-${ROOT_DIR}/ci/winlator/patches/0028-adrenotools-native-gamenative-browser-polish-and-version-sorting.patch}"
OUT_FILE="${OUT_FILE:-${ROOT_DIR}/docs/ADRENOTOOLS_DRIVER_SOURCES_AUDIT.md}"
TIMEOUT_SEC="${TIMEOUT_SEC:-15}"

log() { printf '[driver-audit] %s\n' "$*" >&2; }
fail() { printf '[driver-audit][error] %s\n' "$*" >&2; exit 1; }

need_cmd() { command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"; }

[[ -f "${PATCH_FILE}" ]] || fail "patch file not found: ${PATCH_FILE}"
need_cmd awk
need_cmd sed
need_cmd grep
need_cmd sort
need_cmd uniq
need_cmd curl
need_cmd getent

TMP_DIR="$(mktemp -d /tmp/adrenotools_driver_audit_XXXXXX)"
trap 'rm -rf "${TMP_DIR}"' EXIT

REPO_LIST="${TMP_DIR}/repos.tsv"
URL_LIST="${TMP_DIR}/urls.txt"
HOST_LIST="${TMP_DIR}/hosts.txt"

extract_sources() {
  local current_author="" line owner repo
  : > "${REPO_LIST}"
  while IFS= read -r line; do
    line="${line%$'\r'}"
    if [[ "${line}" =~ DriverSourceAuthor\.githubWithFallbacks\(\"([^\"]+)\" ]]; then
      current_author="${BASH_REMATCH[1]}"
    elif [[ "${line}" =~ DriverSourceAuthor\.github\(\"([^\"]+)\" ]]; then
      current_author="${BASH_REMATCH[1]}"
    elif [[ "${line}" =~ DriverSourceAuthor\.gameNative\( ]]; then
      printf 'gamenative\tGameNative\thttps://gamenative.app/drivers/\tgamenative.app\tgamenative.app/drivers\n' >> "${REPO_LIST}"
    fi

    if [[ "${line}" =~ \"([A-Za-z0-9_.-]+)\",[[:space:]]+\"([A-Za-z0-9_.-]+)\",?$ ]]; then
      owner="${BASH_REMATCH[1]}"
      repo="${BASH_REMATCH[2]}"
      if [[ "${owner}" =~ ^(StevenMXZ|K11MCH1|zoerakk|whitebelyash|Weab-chan|MrPurple666|XForYouX)$ ]]; then
        printf 'github\t%s\thttps://github.com/%s/%s/releases\tgithub.com\t%s/%s\n' \
          "${current_author:-$owner}" "${owner}" "${repo}" "${owner}" "${repo}" >> "${REPO_LIST}"
        printf 'github-api\t%s\thttps://api.github.com/repos/%s/%s/releases?per_page=1\tapi.github.com\t%s/%s\n' \
          "${current_author:-$owner}" "${owner}" "${repo}" "${owner}" "${repo}" >> "${REPO_LIST}"
      fi
    fi

    if [[ "${line}" =~ \{\"([A-Za-z0-9_.-]+)\",[[:space:]]+\"([A-Za-z0-9_.-]+)\" ]]; then
      owner="${BASH_REMATCH[1]}"
      repo="${BASH_REMATCH[2]}"
      printf 'github-fallback\t%s\thttps://github.com/%s/%s/releases\tgithub.com\t%s/%s\n' \
        "${current_author:-$owner}" "${owner}" "${repo}" "${owner}" "${repo}" >> "${REPO_LIST}"
      printf 'github-api-fallback\t%s\thttps://api.github.com/repos/%s/%s/releases?per_page=1\tapi.github.com\t%s/%s\n' \
        "${current_author:-$owner}" "${owner}" "${repo}" "${owner}" "${repo}" >> "${REPO_LIST}"
    fi
  done < "${PATCH_FILE}"
  sort -u -o "${REPO_LIST}" "${REPO_LIST}"

  awk -F'\t' '{print $3}' "${REPO_LIST}" | sort -u > "${URL_LIST}"
  awk -F'\t' '{print $4}' "${REPO_LIST}" | sort -u > "${HOST_LIST}"
  printf '%s\n' "https://downloads.gamenative.app/" >> "${URL_LIST}"
  printf '%s\n' "downloads.gamenative.app" >> "${HOST_LIST}"
  sort -u -o "${URL_LIST}" "${URL_LIST}"
  sort -u -o "${HOST_LIST}" "${HOST_LIST}"
}

host_ips() {
  local host="$1"
  local out
  out="$(getent ahosts "${host}" 2>/dev/null || true)"
  [[ -n "${out}" ]] || return 0
  printf '%s\n' "${out}" | awk '{print $1}' | sort -u | paste -sd ',' -
}

probe_url() {
  local url="$1"
  local out status code effective ct
  out="$(curl -sSIL --max-time "${TIMEOUT_SEC}" -o /dev/null -w 'code=%{http_code}\neffective=%{url_effective}\nctype=%{content_type}\n' "${url}" 2>&1 || true)"
  code="$(printf '%s\n' "${out}" | awk -F= '/^code=/{print $2; exit}')"
  effective="$(printf '%s\n' "${out}" | awk -F= '/^effective=/{print substr($0,11); exit}')"
  ct="$(printf '%s\n' "${out}" | awk -F= '/^ctype=/{print substr($0,7); exit}')"
  if printf '%s\n' "${out}" | grep -qiE 'Could not resolve host|Failed to connect|Connection timed out|SSL'; then
    status="error"
  elif [[ -n "${code}" && "${code}" != "000" ]]; then
    status="ok"
  else
    status="error"
  fi
  printf '%s\t%s\t%s\t%s\n' "${status}" "${code:-000}" "${effective:-}" "${ct:-}"
}

write_report() {
  mkdir -p "$(dirname -- "${OUT_FILE}")"
  {
    echo "# Adrenotools Driver Sources Audit"
    echo
    echo "- Generated: $(date -Is)"
    echo "- Patch source: \`${PATCH_FILE#${ROOT_DIR}/}\`"
    echo "- Timeout per URL: ${TIMEOUT_SEC}s"
    echo
    echo "## Summary"
    echo
    echo "- This audit checks the driver sources referenced by the Adrenotools driver browser patch."
    echo "- It records URL health, redirect target, content type, and host IPs."
    echo "- IPs are point-in-time DNS results and may change (CDN / geo routing)."
    echo
    echo "## Source Endpoints"
    echo
    echo "| Kind | Author | URL | Host | IPs | Status | HTTP | Effective URL | Content-Type | Repo |"
    echo "|---|---|---|---|---|---|---:|---|---|---|"
    while IFS=$'\t' read -r kind author url host repo; do
      local ips probe status code effective ctype
      ips="$(host_ips "${host}")"
      probe="$(probe_url "${url}")"
      status="$(printf '%s\n' "${probe}" | awk -F'\t' '{print $1}')"
      code="$(printf '%s\n' "${probe}" | awk -F'\t' '{print $2}')"
      effective="$(printf '%s\n' "${probe}" | awk -F'\t' '{print $3}')"
      ctype="$(printf '%s\n' "${probe}" | awk -F'\t' '{print $4}')"
      [[ -n "${ips}" ]] || ips="—"
      [[ -n "${effective}" ]] || effective="—"
      [[ -n "${ctype}" ]] || ctype="—"
      printf '| %s | %s | `%s` | `%s` | `%s` | %s | %s | `%s` | `%s` | `%s` |\n' \
        "${kind}" "${author:-—}" "${url}" "${host}" "${ips}" "${status}" "${code}" "${effective}" "${ctype}" "${repo:-—}"
    done < "${REPO_LIST}"
    echo
    echo "## Hosts"
    echo
    echo "| Host | IPs |"
    echo "|---|---|"
    while IFS= read -r host; do
      [[ -n "${host}" ]] || continue
      local ips
      ips="$(host_ips "${host}")"
      [[ -n "${ips}" ]] || ips="—"
      printf '| `%s` | `%s` |\n' "${host}" "${ips}"
    done < "${HOST_LIST}"
    echo
    echo "## Notes"
    echo
    echo '- `github-api*` rows validate API reachability only; asset filtering is an app-side parser concern.'
    echo '- If `XForYouX` is still empty in-app while endpoints are healthy, the issue is parser/filter logic, not link availability.'
    echo '- `GameNative` uses HTML parsing; if `gamenative.app/drivers` changes layout, app parsing may fail even if the URL is reachable.'
  } > "${OUT_FILE}"
}

main() {
  extract_sources
  write_report
  log "Wrote audit report: ${OUT_FILE}"
}

main "$@"
