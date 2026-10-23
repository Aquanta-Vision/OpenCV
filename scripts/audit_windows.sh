#!/usr/bin/env bash
# Runs the spec's compliance checks against an installed windows platform tree: build
# information and videoio backend audit, no plugins or FFmpeg code, static-only output, no
# executables, a DLL dependency allowlist, and a license file for every built 3rdparty library.
# Runs in Git Bash with the Visual Studio developer environment loaded, on a machine that can
# execute the target's binaries.
#
# Usage: scripts/audit_windows.sh <target> <platform_dir>
#   target: x64 or arm64, as passed to build_windows.sh
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
target="$1"
platform_dir="$(cd "$2" && pwd)"
failures=0

# The MSVC/UCRT runtime (incl. the Concurrency runtime behind OpenCV's parallel_for) and Windows
# system DLLs; anything else is an unreviewed dependency.
allowed_deps_pattern='^(kernel32|user32|gdi32|comdlg32|comctl32|advapi32|shell32|ole32|oleaut32|msvcp140(_[0-9a-z]+)?|vcruntime140(_1)?|concrt140|api-ms-win-[a-z0-9-]+)\.dll$'

fail() {
  echo "FAIL $*"
  failures=$((failures + 1))
}

cmakePath() {
  cygpath -m "$1"
}

selectExpectations() {
  case "$target" in
    x64) expected_hal=ipp ;;
    arm64) expected_hal= ;;
    *)
      echo "Unsupported windows target: $target" >&2
      exit 1
      ;;
  esac
}

# OpenCV's top-level Windows config picks <arch>/<vc>/staticlib only when asked for static
# libraries; PAM passes OpenCV_STATIC=ON the same way.
buildAuditProgram() {
  audit_build_dir="$(mktemp -d)"
  cmake -S "$(cmakePath "$script_dir/audit")" -B "$(cmakePath "$audit_build_dir")" -G Ninja \
    -DCMAKE_CXX_COMPILER=cl -DCMAKE_BUILD_TYPE=Release -DOpenCV_STATIC=ON \
    -DOpenCV_DIR="$(cmakePath "$platform_dir")" >/dev/null
  cmake --build "$(cmakePath "$audit_build_dir")" >/dev/null
  audit_bin="$audit_build_dir/audit.exe"
}

runOpencvAudit() {
  "$audit_bin" WIN32UI || fail "OpenCV audit"
}

# The acceleration library the spec chose for this target (O4) must actually be in use.
checkHal() {
  [ -n "$expected_hal" ] || return 0
  grep -E '^ *Custom HAL:' "$platform_dir/BUILDINFO.txt" | grep -q "$expected_hal" ||
    fail "custom HAL $expected_hal not in use: $(grep -E '^ *Custom HAL:' "$platform_dir/BUILDINFO.txt")"
}

# The plugin loaders' search path variables only exist when loading is compiled in.
checkNoPluginsOrFfmpeg() {
  local plugins lib
  plugins="$(find "$platform_dir" -iname 'opencv_videoio_*' -o -iname 'opencv_highgui_*')"
  [ -z "$plugins" ] || fail "plugin files present: $plugins"
  while IFS= read -r lib; do
    ! grep -aqE 'avcodec_|openh264|OPENCV_(VIDEOIO|CORE)_PLUGIN_PATH' "$lib" ||
      fail "$(basename "$lib") contains FFmpeg, OpenH264 or plugin loader strings"
  done < <(find "$platform_dir" -iname '*.lib')
}

checkStaticOnly() {
  local dlls
  dlls="$(find "$platform_dir" -iname '*.dll')"
  [ -z "$dlls" ] || fail "DLLs present: $dlls"
}

checkNoExecutables() {
  local exes
  exes="$(find "$platform_dir" -iname '*.exe')"
  [ -z "$exes" ] || fail "executables present: $exes"
}

checkRuntimeDependencies() {
  local dep
  echo "audit program dependencies:"
  for dep in $(dumpbin.exe -nologo -dependents "$(cygpath -w "$audit_bin")" | tr -d '\r' | sed -n 's/^ *\([^ ]*\.dll\)$/\1/Ip'); do
    echo "  $dep"
    echo "$dep" | tr 'A-Z' 'a-z' | grep -qE "$allowed_deps_pattern" || fail "audit program needs $dep"
  done
}

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
