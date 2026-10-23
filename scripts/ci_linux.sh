#!/usr/bin/env bash
# CI entry point inside a linux build container: installs the build tools, then builds and
# audits one target from the extracted release source archive. Runs as root.
#
# Usage: scripts/ci_linux.sh <target> <source_root> <out_dir>
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
target="$1"
source_root="$2"
out_dir="$3"
# shellcheck source=../opencv.env
source "$script_dir/../opencv.env"

# nasm builds libjpeg-turbo's SIMD code; GTK3 headers are for highgui on x86_64 only (SPEC O2).
# aarch64 runs on Ubuntu 18.04, whose CMake (3.10) and GCC (7.5) are both older than KleidiCV
# needs, so it gets gcc-8 and a pinned CMake release instead.
# OpenCV picks up ccache on its own; the workflow persists CCACHE_DIR between runs.
installBuildTools() {
  local packages=(build-essential ninja-build pkg-config file ccache)
  case "$target" in
    x86_64) packages+=(cmake nasm libgtk-3-dev) ;;
    aarch64) packages+=(gcc-8 g++-8 curl ca-certificates) ;;
  esac
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends "${packages[@]}"
}

installPinnedCmake() {
  [ "$target" = aarch64 ] || return 0
  local tarball=/tmp/cmake.tar.gz
  curl -sSfL "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-aarch64.tar.gz" -o "$tarball"
  echo "${CMAKE_LINUX_AARCH64_SHA256}  $tarball" | sha256sum --check --strict
  mkdir -p /opt/cmake
  tar -xzf "$tarball" -C /opt/cmake --strip-components=1
  export PATH="/opt/cmake/bin:$PATH"
}

installBuildTools
installPinnedCmake
"$script_dir/build_linux.sh" "$target" "$source_root" "$out_dir"
ccache --show-stats
"$script_dir/audit_linux.sh" "$target" "$out_dir"
