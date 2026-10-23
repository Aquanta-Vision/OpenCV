#!/usr/bin/env bash
# The configure-time half of the spec's audit, run on the CMake build directory right after
# configure on every platform: plugin loading is off, and nothing was downloaded (everything
# OpenCV needs comes from the source archive).
#
# Usage: scripts/audit_build_tree.sh <build_dir>
set -euo pipefail

build_dir="$(cd "$1" && pwd)"
failures=0

fail() {
  echo "FAIL $*"
  failures=$((failures + 1))
}

checkPluginsDisabled() {
  local option
  for option in VIDEOIO_ENABLE_PLUGINS HIGHGUI_ENABLE_PLUGINS PARALLEL_ENABLE_PLUGINS; do
    grep -qx "$option:BOOL=OFF" "$build_dir/CMakeCache.txt" || fail "$option is not OFF"
  done
}

# OpenCV logs every fetch that missed the OPENCV_DOWNLOAD_PATH cache as #cmake_download.
checkNoDownloads() {
  local downloads
  downloads="$(grep '^#cmake_download' "$build_dir/CMakeDownloadLog.txt" || true)"
  [ -z "$downloads" ] || fail "configure downloaded files missing from the source archive: $downloads"
}

checkPluginsDisabled
checkNoDownloads

[ "$failures" -eq 0 ] || {
  echo "Build tree audit FAILED with $failures finding(s)"
  exit 1
}
echo "Build tree audit PASSED"
