#!/usr/bin/env bash
# The build-information half of the spec's audit, for platforms whose binaries CI cannot execute
# (Android, iOS). Reads the same cv::getBuildInformation() text audit.cpp checks at runtime, from
# BUILDINFO.txt: the module list, the GUI backend, and that no video I/O backend is enabled.
#
# Usage: scripts/audit_build_info.sh <platform_dir> <expected GUI backend>
set -euo pipefail

platform_dir="$(cd "$1" && pwd)"
expected_gui="$2"
build_info="$platform_dir/BUILDINFO.txt"
failures=0

# Same list as audit.cpp.
expected_modules='calib3d core features2d flann highgui imgcodecs imgproc photo video videoio'

fail() {
  echo "FAIL $*"
  failures=$((failures + 1))
}

rowValue() {
  sed -n "s/^ *$1 *//p" "$build_info" | head -1 | sed 's/ *$//'
}

checkModules() {
  local modules
  modules="$(rowValue 'To be built:')"
  echo "modules: $modules"
  [ "$modules" = "$expected_modules" ] || fail "modules are \"$modules\", expected \"$expected_modules\""
}

checkGui() {
  local gui
  gui="$(rowValue 'GUI:')"
  echo "GUI: $gui"
  [ "$gui" = "$expected_gui" ] || fail "GUI backend is \"$gui\", expected \"$expected_gui\""
}

# Every row in the Video I/O section names an optional backend; none may be enabled.
checkVideoIoSection() {
  local enabled
  enabled="$(sed -n '/^  Video I\/O:/,/^  [^ ]/p' "$build_info" | sed '1d;$d' | grep YES || true)"
  [ -z "$enabled" ] || fail "video I/O backend enabled: $enabled"
}

checkModules
checkGui
checkVideoIoSection

[ "$failures" -eq 0 ] || {
  echo "Build info audit FAILED with $failures finding(s)"
  exit 1
}
echo "Build info audit PASSED"
