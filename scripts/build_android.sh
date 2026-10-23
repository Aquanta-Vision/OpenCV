#!/usr/bin/env bash
# Builds the android-<abi> OpenCV static libraries with the NDK from an extracted release source
# archive.
#
# Usage: scripts/build_android.sh <abi> <source_root> <out_dir>
#   abi:         arm64-v8a, armeabi-v7a, x86 or x86_64
#   source_root: the extracted pam-opencv-<version> directory (from make_source.sh)
#   out_dir:     where the platform tree (sdk/native/..., LICENSE, licenses/, BUILDINFO.txt) is
#                installed, in the layout of OpenCV's Android SDK that PAM uses today
# Needs ANDROID_NDK_HOME pointing at the NDK from opencv.env.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
abi="$1"
source_root="$(cd "$2" && pwd)"
out_dir="$(mkdir -p "$3" && cd "$3" && pwd)"
# shellcheck source=../opencv.env
source "$script_dir/../opencv.env"
# shellcheck source=common_cmake.sh
source "$script_dir/common_cmake.sh"
# shellcheck source=hal_licenses.sh
source "$script_dir/hal_licenses.sh"

platform="android-$abi"
opencv_dir="$source_root/opencv-${OPENCV_VERSION}"
build_dir="$source_root/build-$platform"

# IPP on x86 ABIs (SPEC O4), KleidiCV on arm64-v8a (O5); Carotene is OpenCV's default on both
# ARM ABIs. c++_shared like PAM, so there is one C++ runtime in the app.
selectAbiFlags() {
  case "$abi" in
    arm64-v8a) ABI_CMAKE_FLAGS=(-DWITH_IPP=OFF -DWITH_KLEIDICV=ON) ;;
    armeabi-v7a) ABI_CMAKE_FLAGS=(-DWITH_IPP=OFF) ;;
    x86 | x86_64) ABI_CMAKE_FLAGS=(-DWITH_IPP=ON) ;;
    *)
      echo "Unsupported android ABI: $abi" >&2
      exit 1
      ;;
  esac
}

configureOpencv() {
  CMAKE_FLAGS=(
    -G Ninja
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake"
    -DANDROID_ABI="$abi"
    -DANDROID_PLATFORM="android-${ANDROID_API}"
    -DANDROID_STL=c++_shared
    -DCMAKE_INSTALL_PREFIX="$out_dir"
    -DOPENCV_DOWNLOAD_PATH="$source_root/opencv-downloads"
    "${COMMON_CMAKE_FLAGS[@]}"
    -DWITH_GTK=OFF
    -DBUILD_ANDROID_PROJECTS=OFF
    -DBUILD_ANDROID_EXAMPLES=OFF
    -DBUILD_FAT_JAVA_LIB=OFF
    "${ABI_CMAKE_FLAGS[@]}"
  )
  cmake -S "$opencv_dir" -B "$build_dir" "${CMAKE_FLAGS[@]}"
}

compileAndInstall() {
  cmake --build "$build_dir" -j"$(nproc)"
  cmake --install "$build_dir"
}

# OpenCV installs its 3rdparty license files under sdk/etc/; the rest of sdk/etc/ (cascades),
# binaries and samples are not part of the published tree.
pruneInstall() {
  mv "$out_dir/sdk/etc/licenses" "$out_dir/licenses"
  rm -rf "$out_dir/sdk/etc" "$out_dir/sdk/native/bin" "$out_dir/sdk/native/samples" "$out_dir/samples"
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
    echo "NDK: ${ANDROID_NDK_VERSION}, API ${ANDROID_API}"
    echo "CMake: $(cmake --version | head -1)"
    echo "CMake flags: ${CMAKE_FLAGS[*]}"
    buildInformation
  } > "$out_dir/BUILDINFO.txt"
}

selectAbiFlags
configureOpencv
"$script_dir/audit_build_tree.sh" "$build_dir"
compileAndInstall
pruneInstall
writeLicenseAndBuildInfo
