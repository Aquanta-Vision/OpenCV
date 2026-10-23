#!/usr/bin/env bash
# CI entry point on a macOS runner: builds the iOS device and simulator slices from the
# extracted release source archive into one ios tree (one subdirectory per slice, each with its
# own static libraries and CMake package) and audits both.
#
# Usage: scripts/ci_ios.sh <source_root> <out_dir>
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
source_root="$1"
out_dir="$2"
# shellcheck source=../opencv.env
source "$script_dir/../opencv.env"
# shellcheck source=apple_tools.sh
source "$script_dir/apple_tools.sh"

installAppleBuildTools
for slice in ios-arm64 ios-simulator-arm64; do
  "$script_dir/build_apple.sh" "$slice" "$source_root" "$out_dir/$slice"
done
ccache --show-stats
for slice in ios-arm64 ios-simulator-arm64; do
  "$script_dir/audit_apple.sh" ios "$out_dir/$slice" "$slice"
done
