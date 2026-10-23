#!/usr/bin/env bash
# Builds the linux-<target> OpenCV static libraries from an extracted release source archive.
#
# Usage: scripts/build_linux.sh <target> <source_root> <out_dir>
#   target:      x86_64 or aarch64 (native build), or cortexa9t2hf (Poky SDK cross build)
#   source_root: the extracted pam-opencv-<version> directory (from make_source.sh)
#   out_dir:     where the platform tree (include/, lib/, LICENSE, licenses/, BUILDINFO.txt) is
#                installed
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
target="$1"
source_root="$(cd "$2" && pwd)"
out_dir="$(mkdir -p "$3" && cd "$3" && pwd)"
# shellcheck source=../opencv.env
source "$script_dir/../opencv.env"
# shellcheck source=common_cmake.sh
source "$script_dir/common_cmake.sh"
# shellcheck source=linux_toolchain.sh
source "$script_dir/linux_toolchain.sh"
# shellcheck source=hal_licenses.sh
source "$script_dir/hal_licenses.sh"

platform="linux-$target"
opencv_dir="$source_root/opencv-${OPENCV_VERSION}"
build_dir="$source_root/build-$platform"

# x86_64: IPP, and GTK3 from the system for highgui (never shipped).
# aarch64: headless, KleidiCV (SPEC O5); IPP is x86 only.
# cortexa9t2hf: headless; NEON (from the SDK's -mfpu=neon) with Carotene. KleidiCV is aarch64
# only.
selectPlatformFlags() {
  case "$target" in
    x86_64) PLATFORM_CMAKE_FLAGS=(-DWITH_IPP=ON -DWITH_GTK=ON -DWITH_GTK_2_X=OFF) ;;
    aarch64) PLATFORM_CMAKE_FLAGS=(-DWITH_IPP=OFF -DWITH_GTK=OFF -DWITH_KLEIDICV=ON) ;;
    cortexa9t2hf) PLATFORM_CMAKE_FLAGS=(-DWITH_IPP=OFF -DWITH_GTK=OFF) ;;
    *)
      echo "Unsupported linux target: $target" >&2
      exit 1
      ;;
  esac
}

# CMake prints its errors itself; its check log is mostly expected failures, so it isn't dumped.
configureOpencv() {
  CMAKE_FLAGS=(
    -G Ninja
    "${TARGET_CMAKE_FLAGS[@]}"
    -DCMAKE_INSTALL_PREFIX="$out_dir"
    -DOPENCV_DOWNLOAD_PATH="$source_root/opencv-downloads"
    "${COMMON_CMAKE_FLAGS[@]}"
    "${PLATFORM_CMAKE_FLAGS[@]}"
  )
  cmake -S "$opencv_dir" -B "$build_dir" "${CMAKE_FLAGS[@]}"
}

compileAndInstall() {
  cmake --build "$build_dir" -j"$(nproc)"
  cmake --install "$build_dir"
}

# OpenCV installs its 3rdparty license files under share/; the rest of share/ and bin/ are not
# part of the published tree.
pruneInstall() {
  mv "$out_dir/share/licenses/opencv4" "$out_dir/licenses"
  rm -rf "$out_dir/share" "$out_dir/bin"
}

# getBuildInformation() returns version_string.inc, a C string literal with one line per row.
buildInformation() {
  sed -e 's/^"//' -e 's/\\n"$//' "$build_dir/modules/core/version_string.inc"
}

writeLicenseAndBuildInfo() {
  cp "$opencv_dir/LICENSE" "$out_dir/LICENSE"
  cp "$opencv_dir/COPYRIGHT" "$out_dir/licenses/opencv-COPYRIGHT"
  installHalLicenses "$opencv_dir" "$build_dir" "$out_dir/licenses"
  {
    echo "OpenCV ${OPENCV_VERSION} (commit ${OPENCV_COMMIT}, https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.tar.gz, sha256 ${OPENCV_SHA256})"
    echo "Platform: $platform"
    echo "Compiler: $($TARGET_CXX --version | head -1)"
    echo "CMake: $(cmake --version | head -1)"
    echo "glibc: $(targetGlibcVersion)"
    echo "CMake flags: ${CMAKE_FLAGS[*]}"
    buildInformation
  } > "$out_dir/BUILDINFO.txt"
}

loadLinuxToolchain "$target"
selectPlatformFlags
configureOpencv
"$script_dir/audit_build_tree.sh" "$build_dir"
compileAndInstall
pruneInstall
writeLicenseAndBuildInfo
