# Installs the build tools on a macOS runner. Sourced by ci_macos.sh and ci_ios.sh.
#
# CMake is the release pinned in opencv.env rather than the runner image's, which changes over
# time. OpenCV picks up ccache on its own; the workflow persists CCACHE_DIR between runs.

installAppleBuildTools() {
  local work_dir
  brew install --quiet ninja ccache
  work_dir="$(mktemp -d)"
  curl -sSfL "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-macos-universal.tar.gz" \
    -o "$work_dir/cmake.tar.gz"
  echo "${CMAKE_MACOS_UNIVERSAL_SHA256}  $work_dir/cmake.tar.gz" | shasum -a 256 -c
  tar -xzf "$work_dir/cmake.tar.gz" -C "$work_dir" --strip-components=1
  export PATH="$work_dir/CMake.app/Contents/bin:$PATH"
}
