#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCHSET_SCRIPT="${ROOT_DIR}/ci/gamenative/apply-android-patchset.sh"

log() { printf '[gamenative][selftest] %s\n' "$*"; }
fail() { printf '[gamenative][selftest][error] %s\n' "$*" >&2; exit 1; }

tmp_dir="$(mktemp -d /tmp/gamenative_normalizer_selftest.XXXXXX)"
trap 'rm -rf "${tmp_dir}"' EXIT

mkdir -p \
  "${tmp_dir}/programs/winebrowser" \
  "${tmp_dir}/dlls/winex11.drv" \
  "${tmp_dir}/include"

cat > "${tmp_dir}/programs/winebrowser/main.c" <<'EOF'
int foo(void) {
    int sock_fd = 0;
    int net_requestcode = 1;
    int net_data_length = 2;
    send(sock_fd, &net_requestcode, sizeof(net_requestcode), 0);
    send(sock_fd, &net_data_length, sizeof(net_data_length), 0);
    return getenv("WINE_OPEN_WITH_ANDROID_BROwSER") != 0;
}
EOF

cat > "${tmp_dir}/dlls/winex11.drv/mouse.c" <<'EOF'
void f(void) {
#ifdef HAVE_X11_EXTENSIONS_XFIXES_H
    pXFixesHideCursor( data->display, root_window );
#endif
}
EOF

cat > "${tmp_dir}/include/winnt.h" <<'EOF'
static inline void g(void) {
    LONG dummy;
    InterlockedOr(&dummy, 0);
}
EOF

(
  cd "${tmp_dir}"
  git init -q
  git config user.email "selftest@example.invalid"
  git config user.name "normalizer-selftest"
  git add .
  git commit -qm "selftest seed"
)

log "running normalize-only patchset smoke"
WCP_GN_PATCHSET_MODE=normalize-only \
WCP_GN_PATCHSET_STRICT=1 \
bash "${PATCHSET_SCRIPT}" --target wine --source-dir "${tmp_dir}" >/dev/null

grep -qF '(const char *)&net_requestcode' "${tmp_dir}/programs/winebrowser/main.c" \
  || fail "winebrowser send(net_requestcode) cast was not normalized"
grep -qF '(const char *)&net_data_length' "${tmp_dir}/programs/winebrowser/main.c" \
  || fail "winebrowser send(net_data_length) cast was not normalized"
grep -qF 'WINE_OPEN_WITH_ANDROID_BROWSER' "${tmp_dir}/programs/winebrowser/main.c" \
  || fail "winebrowser env typo was not normalized"
grep -qF '#if defined(HAVE_X11_EXTENSIONS_XFIXES_H) && defined(SONAME_LIBXFIXES)' "${tmp_dir}/dlls/winex11.drv/mouse.c" \
  || fail "winex11 mouse xfixes guard was not normalized"
grep -qF 'long volatile dummy = 0;' "${tmp_dir}/include/winnt.h" \
  || fail "winnt Interlocked dummy normalization missing"

log "normalizer selftest passed"
