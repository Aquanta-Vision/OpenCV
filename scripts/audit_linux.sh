#!/usr/bin/env bash
# Runs the spec's compliance checks against an installed linux platform tree: build information
# and videoio backend audit, no plugins or FFmpeg code, static-only output, no executables, a
# runtime dependency allowlist, and a license file for every built 3rdparty library.
#
# Usage: scripts/audit_linux.sh <target> <platform_dir>
#   target: x86_64, aarch64 or cortexa9t2hf, as passed to build_linux.sh
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
target="$1"
platform_dir="$(cd "$2" && pwd)"
# shellcheck source=linux_toolchain.sh
source "$script_dir/linux_toolchain.sh"
failures=0

# The C/C++ runtime; x86_64 adds the system GTK3 stack behind highgui (SPEC O2).
runtime_deps='libc|libm|libdl|libpthread|librt|libstdc\+\+|libgcc_s|ld-linux-(x86-64|aarch64|armhf)|linux-vdso'
gtk3_deps='libgtk-3|libgdk-3|libgdk_pixbuf-2\.0|libcairo|libcairo-gobject|libpango-1\.0|libpangocairo-1\.0|libatk-1\.0|libharfbuzz|libgio-2\.0|libglib-2\.0|libgobject-2\.0|libgthread-2\.0'

fail() {
  echo "FAIL $*"
  failures=$((failures + 1))
}

selectExpectations() {
  case "$target" in
    x86_64)
      expected_gui=GTK3
      expected_hal=ipp
      allowed_deps_pattern="^($runtime_deps|$gtk3_deps)\.so"
      ;;
    aarch64)
      expected_gui=NONE
      expected_hal=KleidiCV
      allowed_deps_pattern="^($runtime_deps)\.so"
      ;;
    cortexa9t2hf)
      expected_gui=NONE
      expected_hal=carotene
      allowed_deps_pattern="^($runtime_deps)\.so"
      ;;
  esac
}

# The acceleration library the spec chose for this target (O4, O5) must actually be in use.
checkHal() {
  [ -n "$expected_hal" ] || return 0
  grep -E '^ *Custom HAL:' "$platform_dir/BUILDINFO.txt" | grep -q "$expected_hal" ||
    fail "custom HAL $expected_hal not in use: $(grep -E '^ *Custom HAL:' "$platform_dir/BUILDINFO.txt")"
}

buildAuditProgram() {
  audit_build_dir="$(mktemp -d)"
  cmake -S "$script_dir/audit" -B "$audit_build_dir" -G Ninja \
    "${TARGET_CMAKE_FLAGS[@]}" -DCMAKE_BUILD_TYPE=Release \
    -DOpenCV_DIR="$platform_dir/lib/cmake/opencv4" >/dev/null
  cmake --build "$audit_build_dir" >/dev/null
  audit_bin="$audit_build_dir/audit"
}

runOpencvAudit() {
  "${TARGET_RUNNER[@]}" "$audit_bin" "$expected_gui" || fail "OpenCV audit"
}

checkNoPluginsOrFfmpeg() {
  local plugins lib
  plugins="$(find "$platform_dir" -name 'opencv_videoio_*' -o -name 'opencv_highgui_*')"
  [ -z "$plugins" ] || fail "plugin files present: $plugins"
  # The plugin loaders' search path variables only exist when loading is compiled in.
  while IFS= read -r lib; do
    ! grep -aqE 'avcodec_|openh264|OPENCV_(VIDEOIO|CORE)_PLUGIN_PATH' "$lib" ||
      fail "$(basename "$lib") contains FFmpeg, OpenH264 or plugin loader strings"
  done < <(find "$platform_dir/lib" -name '*.a')
}

checkStaticOnly() {
  local shared_libs
  shared_libs="$(find "$platform_dir" -name '*.so' -o -name '*.so.*')"
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
  for dep in $($TARGET_READELF -d "$audit_bin" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p'); do
    echo "  $dep"
    echo "$dep" | grep -qE "$allowed_deps_pattern" || fail "audit program needs $dep"
  done
}

loadLinuxToolchain "$target"
selectExpectations
buildAuditProgram
runOpencvAudit
checkHal
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
