#!/usr/bin/env bash
# Runs the spec's compliance checks against an Apple platform tree: build information and
# videoio backend audit, no plugins or FFmpeg code, static-only output, no executables, a
# dependency allowlist, and a license file for every built 3rdparty library.
#
# macOS: the audit program runs for every slice of the universal tree (x86_64 under Rosetta on
# the arm64 runner). iOS: CI cannot run it, so the build information is checked statically and
# the audit program is only linked, which proves the slice's CMake package links.
#
# Usage: scripts/audit_apple.sh macos <platform_dir>
#        scripts/audit_apple.sh ios <slice_dir> <ios-arm64|ios-simulator-arm64>
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
kind="$1"
platform_dir="$(cd "$2" && pwd)"
slice="${3:-}"
# shellcheck source=../opencv.env
source "$script_dir/../opencv.env"
failures=0

# The OS: system libraries (incl. libc++) and frameworks.
allowed_deps_pattern='^(/usr/lib/.*|/System/Library/Frameworks/.*)$'

fail() {
  echo "FAIL $*"
  failures=$((failures + 1))
}

# Prints the path of the linked audit program.
buildAuditProgram() {
  local arch="$1" build_dir
  shift
  build_dir="$(mktemp -d)"
  cmake -S "$script_dir/audit" -B "$build_dir" -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES="$arch" "$@" \
    -DOpenCV_DIR="$platform_dir/lib/cmake/opencv4" >/dev/null
  cmake --build "$build_dir" >/dev/null
  echo "$build_dir/audit"
}

checkDependencies() {
  local binary="$1" dep
  echo "audit program dependencies:"
  for dep in $(otool -L "$binary" | awk '/^\t/ { print $1 }' | sort -u); do
    echo "  $dep"
    echo "$dep" | grep -qE "$allowed_deps_pattern" || fail "audit program needs $dep"
  done
}

auditMacos() {
  local arch audit_bin
  for arch in $(lipo -archs "$platform_dir/lib/libopencv_core.a"); do
    echo "== $arch"
    audit_bin="$(buildAuditProgram "$arch" -DCMAKE_OSX_DEPLOYMENT_TARGET="$MACOS_DEPLOYMENT_TARGET")"
    arch "-$arch" "$audit_bin" COCOA || fail "OpenCV audit ($arch)"
    checkDependencies "$audit_bin"
  done
}

auditIosSlice() {
  local sdk audit_bin
  [ "$slice" = ios-arm64 ] && sdk=iphoneos || sdk=iphonesimulator
  "$script_dir/audit_build_info.sh" "$platform_dir" NONE || fail "build info"
  # CMake makes iOS executables app bundles by default; a plain binary is enough to link-check.
  audit_bin="$(buildAuditProgram arm64 -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_MACOSX_BUNDLE=OFF \
    -DCMAKE_OSX_SYSROOT="$(xcrun --sdk "$sdk" --show-sdk-path)" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET")"
  checkDependencies "$audit_bin"
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
  shared_libs="$(find "$platform_dir" -name '*.dylib' -o -name '*.framework')"
  [ -z "$shared_libs" ] || fail "shared libraries present: $shared_libs"
}

checkNoExecutables() {
  local executables
  executables="$(find "$platform_dir" -type f -perm +111)"
  [ -z "$executables" ] || fail "executables present: $executables"
}

case "$kind" in
  macos) auditMacos ;;
  ios) auditIosSlice ;;
  *)
    echo "Unsupported apple audit: $kind" >&2
    exit 1
    ;;
esac
checkNoPluginsOrFfmpeg
checkStaticOnly
checkNoExecutables
"$script_dir/audit_licenses.sh" "$platform_dir" || fail "licenses"

if [ "$failures" -ne 0 ]; then
  echo "Audit FAILED with $failures finding(s)"
  exit 1
fi
echo "Audit PASSED"
