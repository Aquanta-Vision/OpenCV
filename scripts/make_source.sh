#!/usr/bin/env bash
# Assembles the release source archive: the pristine upstream OpenCV tree, the IPP ICV packages
# OpenCV would otherwise download at configure time, and this repo's build scripts. Every platform
# build starts from this archive, so the published source always matches the published binaries.
#
# Usage: scripts/make_source.sh <out_dir>
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
out_dir="$(mkdir -p "$1" && cd "$1" && pwd)"
# shellcheck source=../opencv.env
source "$repo_root/opencv.env"

stage_name="pam-opencv-${OPENCV_VERSION}"
work_dir="$(mktemp -d)"
stage_dir="$work_dir/$stage_name"

fetchOpencv() {
  local tarball="$work_dir/opencv-${OPENCV_VERSION}.tar.gz"
  curl -sSfL "https://github.com/opencv/opencv/archive/refs/tags/${OPENCV_VERSION}.tar.gz" -o "$tarball"
  echo "${OPENCV_SHA256}  $tarball" | sha256sum --check --strict
  tar -xzf "$tarball" -C "$stage_dir"
}

# OpenCV looks for downloads in OPENCV_DOWNLOAD_PATH as <id>/<md5>-<file name> before going to the
# network, so a pre-filled cache keeps the builds offline. The MD5 is OpenCV's own check; the
# SHA256 in opencv.env is ours.
fetchIppicv() {
  local path="$1" sha256="$2"
  local name file md5
  name="$(basename "$path")"
  file="$work_dir/$name"
  curl -sSfL "https://raw.githubusercontent.com/opencv/opencv_3rdparty/$path" -o "$file"
  echo "$sha256  $file" | sha256sum --check --strict
  md5="$(md5sum "$file" | cut -d' ' -f1)"
  mkdir -p "$stage_dir/opencv-downloads/ippicv"
  mv "$file" "$stage_dir/opencv-downloads/ippicv/$md5-$name"
}

fetchAllIppicv() {
  fetchIppicv "$IPPICV_LINUX_X86_64" "$IPPICV_LINUX_X86_64_SHA256"
  fetchIppicv "$IPPICV_ANDROID_X86" "$IPPICV_ANDROID_X86_SHA256"
  fetchIppicv "$IPPICV_WINDOWS_X64" "$IPPICV_WINDOWS_X64_SHA256"
  fetchIppicv "$IPPICV_MACOS_X86_64" "$IPPICV_MACOS_X86_64_SHA256"
}

copyBuildScripts() {
  mkdir -p "$stage_dir/pam-build"
  cp -r "$repo_root/scripts" "$repo_root/opencv.env" "$repo_root/README.md" "$stage_dir/pam-build/"
}

packSource() {
  XZ_OPT=-T0 tar -cJf "$out_dir/${stage_name}-source.tar.xz" -C "$work_dir" "$stage_name"
}

mkdir -p "$stage_dir"
fetchOpencv
fetchAllIppicv
copyBuildScripts
packSource
rm -rf "$work_dir"
echo "Wrote $out_dir/${stage_name}-source.tar.xz"
