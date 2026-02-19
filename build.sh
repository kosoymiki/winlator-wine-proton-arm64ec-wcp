#!/usr/bin/env bash
     2	set -Eeuo pipefail
     3	
     4	ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
     5	cd "$ROOT"
     6	
     7	: "${LLVM_MINGW_VER:=20251216}"
     8	: "${WCP_NAME:=wine-11.1-staging-s8g1}"
     9	: "${WCP_OUTPUT_DIR:=$ROOT/dist}"
    10	: "${TOOLCHAIN_DIR:=$ROOT/.cache/llvm-mingw}"
    11	
    12	mkdir -p "$WCP_OUTPUT_DIR" "$TOOLCHAIN_DIR"
    13	
    14	die() {
    15	  echo "ERROR: $*" >&2
    16	  exit 1
    17	}
    18	
    19	copy_usr_tree() {
    20	  local src_root="$1"
    21	  local dst_root="$2"
    22	  if [[ -d "$src_root/usr/local" ]]; then
    23	    cp -a "$src_root/usr/local/." "$dst_root/"
    24	  elif [[ -d "$src_root/usr" ]]; then
    25	    cp -a "$src_root/usr/." "$dst_root/"
    26	  else
    27	    die "Neither usr/local nor usr exists in staging root: $src_root"
    28	  fi
    29	}
    30	
    31	rm -rf repo-wine-tkg-git wine-tkg-src wcp wine-src
    32	
    33	# 1) Clone wine-tkg sources.
    34	git clone --depth=1 https://github.com/Frogging-Family/wine-tkg-git.git repo-wine-tkg-git
    35	mkdir -p wine-tkg-src
    36	mv repo-wine-tkg-git/wine-tkg-git wine-tkg-src/
    37	rm -rf repo-wine-tkg-git
    38	
    39	# 2) Download llvm-mingw toolchain into cache directory.
    40	LLVM_TAR="llvm-mingw-${LLVM_MINGW_VER}-ucrt-ubuntu-22.04-x86_64.tar.xz"
    41	LLVM_URL="https://github.com/mstorsjo/llvm-mingw/releases/download/${LLVM_MINGW_VER}/${LLVM_TAR}"
    42	LLVM_DST="${TOOLCHAIN_DIR}/${LLVM_MINGW_VER}"
    43	LLVM_BIN="${LLVM_DST}/bin"
    44	
    45	if [[ ! -x "${LLVM_BIN}/clang" ]]; then
    46	  tmpdir="$(mktemp -d)"
    47	  trap 'rm -rf "$tmpdir"' EXIT
    48	
    49	  wget --https-only --tries=3 --timeout=30 -O "${tmpdir}/${LLVM_TAR}" "${LLVM_URL}"
    50	  tar -xf "${tmpdir}/${LLVM_TAR}" -C "$tmpdir"
    51	
    52	  rm -rf "$LLVM_DST"
    53	  mkdir -p "$LLVM_DST"
    54	
    55	  LLVM_SRC_DIR=""
    56	  while IFS= read -r clang_path; do
    57	    candidate_dir="${clang_path%/bin/clang}"
    58	    if [[ -x "$candidate_dir/bin/clang" ]]; then
    59	      LLVM_SRC_DIR="$candidate_dir"
    60	      break
    61	    fi
    62	  done < <(find "$tmpdir" -maxdepth 10 -type f -path '*/bin/clang' -print)
    63	
    64	  [[ -n "$LLVM_SRC_DIR" ]] || {
    65	    find "$tmpdir" -maxdepth 4 -type d | sed 's/^/  - /' >&2
    66	    die "unable to locate llvm-mingw toolchain root after extraction"
    67	  }
    68	
    69	  cp -a "${LLVM_SRC_DIR}/." "$LLVM_DST/"
    70	  [[ -x "${LLVM_DST}/bin/clang" ]] || die "llvm-mingw copied but clang is still missing in ${LLVM_DST}/bin"
    71	fi
    72	
    73	export PATH="${LLVM_BIN}:$PATH"
    74	
    75	# 3) Clone Wine sources and checkout arm64ec branch.
    76	git clone --depth=1 https://github.com/AndreRH/wine.git wine-src
    77	pushd wine-src >/dev/null
    78	git fetch --depth=1 origin arm64ec
    79	git checkout -B arm64ec origin/arm64ec
    80	popd >/dev/null
    81	
    82	# 4) Configure wine-tkg toggles.
    83	CFG="wine-tkg-src/wine-tkg-git/customization.cfg"
    84	[[ -f "$CFG" ]] || die "customization.cfg not found at $CFG"
    85	
    86	set_cfg_bool() {
    87	  local key="$1"
    88	  local val="$2"
    89	  if grep -qE "^${key}=" "$CFG"; then
    90	    sed -i -E "s|^${key}=\"[^\"]*\"|${key}=\"${val}\"|" "$CFG"
    91	  else
    92	    echo "${key}=\"${val}\"" >> "$CFG"
    93	  fi
    94	}
    95	
    96	set_cfg_bool "_use_staging" "true"
    97	set_cfg_bool "_use_fsync" "true"
    98	set_cfg_bool "_use_esync" "true"
    99	set_cfg_bool "_use_vulkan" "true"
   100	
   101	# 5) Cross-compilation environment.
   102	export CC="clang --target=arm64ec-w64-windows-gnu"
   103	export CXX="clang++ --target=arm64ec-w64-windows-gnu"
   104	export AR="llvm-ar"
   105	export RANLIB="llvm-ranlib"
   106	export STRIP="llvm-strip"
   107	export WINECPU="arm64"
   108	export CFLAGS="-O2 -pipe"
   109	export CXXFLAGS="-O2 -pipe"
   110	export LDFLAGS=""
   111	
   112	export _CUSTOM_GIT_URL="file://${ROOT}/wine-src"
   113	export _LOCAL_PRESET="1"
   114	
   115	# 6) Build and install.
   116	pushd wine-tkg-src/wine-tkg-git >/dev/null
   117	./non-makepkg-build.sh --cross
   118	
   119	STAGING="$(pwd)/../wcp/install"
   120	rm -rf "$STAGING"
   121	mkdir -p "$STAGING"
   122	make -C non-makepkg-builds install DESTDIR="$STAGING"
   123	popd >/dev/null
   124	
   125	# 7) Package WCP.
   126	pushd "$STAGING" >/dev/null
   127	rm -rf wcp
   128	mkdir -p wcp/{bin,lib,share,info}
   129	
   130	copy_usr_tree "$STAGING" "wcp"
   131	ln -sf wine64 wcp/bin/wine
   132	
   133	cat > wcp/info/info.json <<EOF
   134	{
   135	  "name": "Wine 11.1 staging (ARM64EC)",
   136	  "os": "windows",
   137	  "arch": "arm64",
   138	  "version": "11.1-staging",
   139	  "features": ["staging", "fsync", "esync", "vulkan"],
   140	  "built": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
   141	}
   142	EOF
   143	
   144	cat > wcp/bin/env.sh <<'EOF'
   145	#!/bin/sh
   146	export WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
   147	exec "$(dirname "$0")/wine64" "$@"
   148	EOF
   149	chmod +x wcp/bin/env.sh
   150	
   151	WCP_PATH="${WCP_OUTPUT_DIR}/${WCP_NAME}.wcp"
   152	tar -cJf "$WCP_PATH" -C wcp .
   153	echo "Created $WCP_PATH"
   154	popd >/dev/null