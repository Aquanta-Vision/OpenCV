#!/usr/bin/env bash
# Builds the windows-<target> OpenCV static libraries with MSVC from an extracted release source
# archive. Runs in Git Bash with the Visual Studio developer environment for the target loaded
# (msvc_env.ps1), which also puts Visual Studio's CMake and Ninja on PATH.
#
# Usage: scripts/build_windows.sh <target> <source_root> <out_dir>
#   target:      x64, or arm64 (cross-compiled on x64 with the x64_arm64 environment)
#   source_root: the extracted pam-opencv-<version> directory (from make_source.sh)
#   out_dir:     where the platform tree (include/, <arch>/vc17/staticlib/, OpenCVConfig.cmake,
#                LICENSE, licenses/, BUILDINFO.txt) is installed
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

platform="windows-$target"
opencv_dir="$source_root/opencv-${OPENCV_VERSION}"
build_dir="$source_root/build-$platform"

# CMake and MSVC take Windows paths; mixed form (C:/...) avoids backslash escaping.
cmakePath() {
  cygpath -m "$1"
}

# x64: IPP. arm64: IPP is x86 only, and CMake must be told it is cross-compiling so OpenCV
# doesn't try to run target binaries. Both: highgui on the Win32 UI (SPEC O2), /MD CRT from the
# baseline (BUILD_WITH_STATIC_CRT=OFF) like PAM.
selectPlatformFlags() {
  case "$target" in
    x64) PLATFORM_CMAKE_FLAGS=(-DWITH_IPP=ON -DWITH_WIN32UI=ON) ;;
    arm64)
      PLATFORM_CMAKE_FLAGS=(
        -DWITH_IPP=OFF -DWITH_WIN32UI=ON
        -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_PROCESSOR=ARM64
      )
      ;;
    *)
      echo "Unsupported windows target: $target" >&2
      exit 1
      ;;
  esac
}

# CMake prints its errors itself; its check log is mostly expected failures, so it isn't dumped.
configureOpencv() {
  CMAKE_FLAGS=(
    -G Ninja
    -DCMAKE_C_COMPILER=cl
    -DCMAKE_CXX_COMPILER=cl
    -DCMAKE_INSTALL_PREFIX="$(cmakePath "$out_dir")"
    -DOPENCV_DOWNLOAD_PATH="$(cmakePath "$source_root/opencv-downloads")"
    "${COMMON_CMAKE_FLAGS[@]}"
    "${PLATFORM_CMAKE_FLAGS[@]}"
  )
  cmake -S "$(cmakePath "$opencv_dir")" -B "$(cmakePath "$build_dir")" "${CMAKE_FLAGS[@]}"
}

compileAndInstall() {
  cmake --build "$(cmakePath "$build_dir")" -j"$NUMBER_OF_PROCESSORS"
  cmake --install "$(cmakePath "$build_dir")"
}

# OpenCV installs its 3rdparty license files under etc/; the rest of etc/, the bin/ directories
# and the environment setup script are not part of the published tree.
pruneInstall() {
  mv "$out_dir/etc/licenses" "$out_dir/licenses"
  rm -rf "$out_dir/etc" "$out_dir"/*/*/bin "$out_dir"/setup_vars_opencv4.cmd
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
    echo "Compiler: $(cl.exe 2>&1 | head -1 | tr -d '\r')"
    echo "CMake: $(cmake --version | head -1)"
    echo "CMake flags: ${CMAKE_FLAGS[*]}"
    buildInformation
  } > "$out_dir/BUILDINFO.txt"
}

selectPlatformFlags
configureOpencv
"$script_dir/audit_build_tree.sh" "$build_dir"
compileAndInstall
pruneInstall
writeLicenseAndBuildInfo
