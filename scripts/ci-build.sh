#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  build-essential ninja-build cmake clang libunwind-dev libxml2-dev \
  libfreetype-dev libjpeg-dev libpng-dev libtiff-dev \
  libgstreamer-plugins-base1.0-dev libfaudio-dev libvulkan-dev \
  libxcb1-dev libx11-dev libxext-dev libxrandr-dev libxi-dev \
  libxcursor-dev libxinerama-dev libxcomposite-dev libxkbcommon-dev \
  libpulse-dev libudev-dev gettext bison flex pkg-config zlib1g-dev \
  libtool wget git xz-utils

./build.sh
