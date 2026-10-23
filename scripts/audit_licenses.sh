#!/usr/bin/env bash
# Checks that licenses/ has a notice for every 3rdparty library the build information lists as
# linked (SPEC good-to-go 8). OpenCV installs those notices as <library>-<file>; libraries that
# are OpenCV's own code are covered by its LICENSE.
#
# Usage: scripts/audit_licenses.sh <platform_dir>
set -euo pipefail

platform_dir="$(cd "$1" && pwd)"
failures=0

# OpenCV's own HAL glue (Apache-2.0, part of OpenCV).
opencv_own_pattern='^(ipphal)$'

fail() {
  echo "FAIL $*"
  failures=$((failures + 1))
}

# Build targets whose license file is named after the project rather than the target.
licenseName() {
  case "$1" in
    tegra_hal) echo carotene ;;
    kleidicv_hal | kleidicv_thread) echo kleidicv ;;
    *) echo "$1" ;;
  esac
}

thirdPartyLibraries() {
  sed -n 's/^ *3rdparty dependencies: *//p' "$platform_dir/BUILDINFO.txt" | tr ' ' '\n' | grep -v '^$'
}

checkLicenseFiles() {
  local library
  [ -f "$platform_dir/LICENSE" ] || fail "LICENSE missing"
  for library in $(thirdPartyLibraries); do
    echo "$library" | grep -qE "$opencv_own_pattern" && continue
    compgen -G "$platform_dir/licenses/$(licenseName "$library")-*" >/dev/null ||
      fail "no license file for $library"
  done
}

checkLicenseFiles

[ "$failures" -eq 0 ] || {
  echo "License audit FAILED with $failures finding(s)"
  exit 1
}
echo "License audit PASSED"
