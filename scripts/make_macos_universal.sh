#!/usr/bin/env bash
# Merges the macos-arm64 and macos-x86_64 trees into one macos-universal tree: each static
# library becomes a fat archive with both slices; headers, the CMake package and licenses come
# from the arm64 tree, and BUILDINFO.txt keeps both builds' details.
#
# One CMake package can only describe both slices if they link the same libraries (SPEC O6), so
# the merge fails if the library sets, the generated CMake files or the headers differ.
#
# Usage: scripts/make_macos_universal.sh <arm64_dir> <x86_64_dir> <out_dir>
set -euo pipefail

arm64_dir="$(cd "$1" && pwd)"
x86_64_dir="$(cd "$2" && pwd)"
out_dir="$3"

staticLibraries() {
  (cd "$1" && find lib -name '*.a' | sort)
}

checkSlicesMatch() {
  diff <(staticLibraries "$arm64_dir") <(staticLibraries "$x86_64_dir") || {
    echo "macOS slices link different libraries" >&2
    exit 1
  }
  diff -r "$arm64_dir/lib/cmake" "$x86_64_dir/lib/cmake" || {
    echo "macOS slices generated different CMake packages" >&2
    exit 1
  }
  diff -r "$arm64_dir/include" "$x86_64_dir/include" || {
    echo "macOS slices installed different headers" >&2
    exit 1
  }
}

copyArm64Tree() {
  rm -rf "$out_dir"
  mkdir -p "$(dirname "$out_dir")"
  cp -R "$arm64_dir" "$out_dir"
}

mergeStaticLibraries() {
  local lib
  for lib in $(staticLibraries "$arm64_dir"); do
    lipo -create "$arm64_dir/$lib" "$x86_64_dir/$lib" -output "$out_dir/$lib"
  done
}

mergeBuildInfo() {
  cat "$arm64_dir/BUILDINFO.txt" <(echo) "$x86_64_dir/BUILDINFO.txt" > "$out_dir/BUILDINFO.txt"
}

checkSlicesMatch
copyArm64Tree
mergeStaticLibraries
mergeBuildInfo
