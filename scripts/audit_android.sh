#!/usr/bin/env bash
# Runs the spec's compliance checks against an android platform tree. CI cannot execute Android
# binaries, so the build information is checked statically (audit_build_info.sh); the audit
# program is still linked through OpenCV's CMake package, which proves the package links and
# gives the dependency allowlist something to check.
#
# Usage: scripts/audit_android.sh <abi> <platform_dir>
# Needs ANDROID_NDK_HOME pointing at the NDK from opencv.env.
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
abi="$1"
platform_dir="$(cd "$2" && pwd)"
# shellcheck source=../opencv.env
source "$script_dir/../opencv.env"
readelf="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-readelf"
failures=0

# Android's C runtime and logging library, and the NDK's shared C++ runtime (c++_shared).
allowed_deps_pattern='^(libc|libm|libdl|liblog|libc\+\+_shared)\.so$'

fail() {
  echo "FAIL $*"
  failures=$((failures + 1))
}

selectExpectations() {
  case "$abi" in
    arm64-v8a) expected_hal=KleidiCV ;;
    armeabi-v7a) expected_hal=carotene ;;
    x86 | x86_64) expected_hal=ipp ;;
  esac
}

checkBuildInfo() {
  "$script_dir/audit_build_info.sh" "$platform_dir" NONE || fail "build info"
}

# The acceleration library the spec chose for this ABI (O4, O5) must actually be in use.
checkHal() {
  grep -E '^ *Custom HAL:' "$platform_dir/BUILDINFO.txt" | grep -q "$expected_hal" ||
    fail "custom HAL $expected_hal not in use: $(grep -E '^ *Custom HAL:' "$platform_dir/BUILDINFO.txt")"
}

buildAuditProgram() {
  audit_build_dir="$(mktemp -d)"
  cmake -S "$script_dir/audit" -B "$audit_build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$abi" -DANDROID_PLATFORM="android-${ANDROID_API}" -DANDROID_STL=c++_shared \
    -DOpenCV_DIR="$platform_dir/sdk/native/jni" >/dev/null
  cmake --build "$audit_build_dir" >/dev/null
  audit_bin="$audit_build_dir/audit"
}

# The plugin loaders' search path variables only exist when loading is compiled in.
checkNoPluginsOrFfmpeg() {
  local plugins lib
  plugins="$(find "$platform_dir" -name 'libopencv_videoio_*' -o -name 'libopencv_highgui_*')"
  [ -z "$plugins" ] || fail "plugin files present: $plugins"
  while IFS= read -r lib; do
    ! grep -aqE 'avcodec_|openh264|OPENCV_(VIDEOIO|CORE)_PLUGIN_PATH' "$lib" ||
      fail "$(basename "$lib") contains FFmpeg, OpenH264 or plugin loader strings"
  done < <(find "$platform_dir" -name '*.a')
}

checkStaticOnly() {
  local shared_libs
  shared_libs="$(find "$platform_dir" -name '*.so')"
  [ -z "$shared_libs" ] || fail "shared libraries present: $shared_libs"
}

checkNoExecutables() {
  local executables
  executables="$(find "$platform_dir" -type f -perm /111)"
  [ -z "$executables" ] || fail "executables present: $executables"
}

checkRuntimeDependencies() {
  local dep
  echo "audit program dependencies:"
  for dep in $("$readelf" -d "$audit_bin" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'); do
    echo "  $dep"
    echo "$dep" | grep -qE "$allowed_deps_pattern" || fail "audit program needs $dep"
  done
}

selectExpectations
checkBuildInfo
checkHal
buildAuditProgram
checkNoPluginsOrFfmpeg
checkStaticOnly
checkNoExecutables
checkRuntimeDependencies
"$script_dir/audit_licenses.sh" "$platform_dir" || fail "licenses"
rm -rf "$audit_build_dir"

if [ "$failures" -ne 0 ]; then
  echo "Audit FAILED with $failures finding(s)"
  exit 1
fi
echo "Audit PASSED"
