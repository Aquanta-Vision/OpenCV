#!/usr/bin/env bash
# CI entry point inside a linux build container: installs the build tools, then builds and
# audits one target from the extracted release source archive. Runs as root.
#
# Usage: scripts/ci_linux.sh <target> <source_root> <out_dir>
set -euo pipefail

script_dir="$(cd "$(dirname "$0")" && pwd)"
target="$1"
source_root="$2"
out_dir="$3"

# nasm builds libjpeg-turbo's SIMD code; GTK3 headers are for highgui on x86_64 only (SPEC O2).
# OpenCV picks up ccache on its own; the workflow persists CCACHE_DIR between runs.
installBuildTools() {
  local packages=(build-essential cmake ninja-build pkg-config file ccache)
  case "$target" in
    x86_64) packages+=(nasm libgtk-3-dev) ;;
  esac
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends "${packages[@]}"
}

installBuildTools
"$script_dir/build_linux.sh" "$target" "$source_root" "$out_dir"
ccache --show-stats
"$script_dir/audit_linux.sh" "$target" "$out_dir"
