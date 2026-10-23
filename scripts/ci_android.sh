#!/usr/bin/env bash
# CI entry point on an ubuntu runner: installs the build tools and the pinned NDK and CMake, then
# builds and audits one android ABI from the extracted release source archive.
#
# Usage: scripts/ci_android.sh <abi> <source_root> <out_dir>
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
abi="$1"
source_root="$2"
out_dir="$3"
# shellcheck source=../opencv.env
source "$script_dir/../opencv.env"

# OpenCV picks up ccache on its own; the workflow persists CCACHE_DIR between runs.
installBuildTools() {
  sudo apt-get update -qq
  sudo apt-get install -y -qq --no-install-recommends ninja-build ccache
}

# The runner image's NDKs and CMake change over time; the pinned ones keep builds reproducible.
fetchNdk() {
  local work_dir
  work_dir="$(mktemp -d)"
  curl -sSfL "https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux.zip" \
    -o "$work_dir/ndk.zip"
  echo "${ANDROID_NDK_SHA256}  $work_dir/ndk.zip" | sha256sum --check --strict
  unzip -q "$work_dir/ndk.zip" -d "$work_dir"
  export ANDROID_NDK_HOME="$work_dir/android-ndk-${ANDROID_NDK_VERSION}"
}

fetchCmake() {
  local work_dir
  work_dir="$(mktemp -d)"
  curl -sSfL "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz" \
    -o "$work_dir/cmake.tar.gz"
  echo "${CMAKE_LINUX_X86_64_SHA256}  $work_dir/cmake.tar.gz" | sha256sum --check --strict
  tar -xzf "$work_dir/cmake.tar.gz" -C "$work_dir" --strip-components=1
  export PATH="$work_dir/bin:$PATH"
}

installBuildTools
fetchNdk
fetchCmake
"$script_dir/build_android.sh" "$abi" "$source_root" "$out_dir"
ccache --show-stats
"$script_dir/audit_android.sh" "$abi" "$out_dir"
