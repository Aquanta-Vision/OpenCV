#!/usr/bin/env bash
# Builds OpenCV static libraries for one Apple target with Xcode's clang from an extracted
# release source archive.
#
# Usage: scripts/build_apple.sh <target> <source_root> <out_dir>
#   target:      macos-arm64, macos-x86_64, ios-arm64 or ios-simulator-arm64
#   source_root: the extracted pam-opencv-<version> directory (from make_source.sh)
#   out_dir:     where the target tree (include/, lib/, LICENSE, licenses/, BUILDINFO.txt) is
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
# shellcheck source=hal_licenses.sh
source "$script_dir/hal_licenses.sh"

opencv_dir="$source_root/opencv-${OPENCV_VERSION}"
build_dir="$source_root/build-$target"

# The x86_64 slice is a cross build on the arm64 runner and says so: CMake otherwise reports the
# runner's arm64 as the processor, and OpenCV would pick NEON code for it.
# macOS: no IPP or Carotene on either slice (SPEC O6), so both slices link the same libraries and
# one CMake package describes the universal tree; highgui uses Cocoa (O2). iOS: headless.
selectTarget() {
  case "$target" in
    macos-arm64 | macos-x86_64)
      sdk=macosx
      TARGET_CMAKE_FLAGS=(
        -DCMAKE_OSX_ARCHITECTURES="${target#macos-}"
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET"
        -DWITH_IPP=OFF
        -DWITH_CAROTENE=OFF
      )
      [ "$target" = macos-arm64 ] ||
        TARGET_CMAKE_FLAGS+=(-DCMAKE_SYSTEM_NAME=Darwin -DCMAKE_SYSTEM_PROCESSOR=x86_64)
      ;;
    ios-arm64 | ios-simulator-arm64)
      [ "$target" = ios-arm64 ] && sdk=iphoneos || sdk=iphonesimulator
      TARGET_CMAKE_FLAGS=(
        -DCMAKE_SYSTEM_NAME=iOS
        -DCMAKE_SYSTEM_PROCESSOR=arm64
        -DCMAKE_OSX_ARCHITECTURES=arm64
        -DCMAKE_OSX_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET"
      )
      ;;
    *)
      echo "Unsupported apple target: $target" >&2
      exit 1
      ;;
  esac
  TARGET_CMAKE_FLAGS+=(-DCMAKE_OSX_SYSROOT="$(xcrun --sdk "$sdk" --show-sdk-path)" -DWITH_GTK=OFF)
}

configureOpencv() {
  CMAKE_FLAGS=(
    -G Ninja
    -DCMAKE_INSTALL_PREFIX="$out_dir"
    -DOPENCV_DOWNLOAD_PATH="$source_root/opencv-downloads"
    "${COMMON_CMAKE_FLAGS[@]}"
    "${TARGET_CMAKE_FLAGS[@]}"
  )
  cmake -S "$opencv_dir" -B "$build_dir" "${CMAKE_FLAGS[@]}"
}

compileAndInstall() {
  cmake --build "$build_dir" -j"$(sysctl -n hw.ncpu)"
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
    echo "Platform: $target"
    echo "Compiler: $(xcrun --sdk "$sdk" clang --version | head -1)"
    echo "SDK: $sdk $(xcrun --sdk "$sdk" --show-sdk-version)"
    echo "CMake: $(cmake --version | head -1)"
    echo "CMake flags: ${CMAKE_FLAGS[*]}"
    buildInformation
  } > "$out_dir/BUILDINFO.txt"
}

selectTarget
configureOpencv
"$script_dir/audit_build_tree.sh" "$build_dir"
compileAndInstall
pruneInstall
writeLicenseAndBuildInfo
