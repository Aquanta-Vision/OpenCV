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

# The FLIR Poky image points apt at an internal mirror that CI cannot reach.
usePublicUbuntuMirror() {
  local codename
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  printf 'deb http://archive.ubuntu.com/ubuntu %s main universe\n' \
    "$codename" "$codename-updates" "$codename-security" > /etc/apt/sources.list
}

# nasm builds libjpeg-turbo's SIMD code; GTK3 headers are for highgui on x86_64 only (SPEC O2).
# aarch64 runs on Ubuntu 18.04, whose CMake (3.10) and GCC (7.5) are both older than KleidiCV
# needs, so it gets gcc-8 and a pinned CMake release instead. cortexa9t2hf uses the Poky SDK's
# cross compiler, a pinned CMake, and qemu-user to run the cross-built audit program.
# OpenCV picks up ccache on its own; the workflow persists CCACHE_DIR between runs.
installBuildTools() {
  local packages=(build-essential ninja-build pkg-config file ccache)
  case "$target" in
    x86_64) packages+=(cmake nasm libgtk-3-dev) ;;
    aarch64) packages+=(gcc-8 g++-8 curl ca-certificates) ;;
    cortexa9t2hf)
      usePublicUbuntuMirror
      packages+=(qemu-user curl ca-certificates)
      ;;
  esac
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends "${packages[@]}"
}

# A CMake release for the build machine's architecture, pinned in opencv.env.
installPinnedCmake() {
  [ "$target" != x86_64 ] || return 0
  local arch tarball sha256_var
  arch="$(uname -m)"
  tarball=/tmp/cmake.tar.gz
  sha256_var="CMAKE_LINUX_$(echo "$arch" | tr '[:lower:]' '[:upper:]')_SHA256"
  curl -sSfL "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${arch}.tar.gz" -o "$tarball"
  echo "${!sha256_var}  $tarball" | sha256sum --check --strict
  mkdir -p /opt/cmake
  tar -xzf "$tarball" -C /opt/cmake --strip-components=1
  export PATH="/opt/cmake/bin:$PATH"
}

installBuildTools
installPinnedCmake
"$script_dir/build_linux.sh" "$target" "$source_root" "$out_dir"
ccache --show-stats
"$script_dir/audit_linux.sh" "$target" "$out_dir"
