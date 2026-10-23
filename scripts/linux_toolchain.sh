# Selects the compilers, readelf and binary runner for a linux target. Sourced by build_linux.sh
# and audit_linux.sh so the build and the audit use the same toolchain.
#
# x86_64 and aarch64 build natively, so the target must match the machine. cortexa9t2hf
# cross-compiles with the Poky 3.3 SDK in the FLIR toolchain image and runs target binaries
# under qemu-arm.

poky_env=/opt/poky/3.3-cortexa9t2hf/environment-setup-cortexa9t2hf-neon-oe-linux-gnueabi
poky_cross_prefix=arm-oe-linux-gnueabi-
poky_toolchain_file="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/poky_toolchain.cmake"

requireNativeMachine() {
  [ "$(uname -m)" = "$1" ] || {
    echo "Target $1 builds natively, but this machine is $(uname -m)" >&2
    exit 1
  }
}

# The SDK script reads LD_LIBRARY_PATH before setting it, so nounset is off while sourcing.
# Its default CFLAGS/CXXFLAGS carry -g, which would put debug info into the published static
# libraries; no other platform ships it.
loadPokySdk() {
  set +u
  # shellcheck disable=SC1090
  source "$poky_env"
  set -u
  CFLAGS="$(echo " $CFLAGS " | sed 's/ -g / /g')"
  CXXFLAGS="$(echo " $CXXFLAGS " | sed 's/ -g / /g')"
  export CFLAGS CXXFLAGS
}

# Sets TARGET_CC, TARGET_CXX, TARGET_READELF, TARGET_RUNNER (the command prefix that runs a
# target binary) and TARGET_CMAKE_FLAGS (how CMake finds the compilers). The Poky SDK's $CC
# carries its CPU flags, so cross builds use the SDK's toolchain file instead of
# CMAKE_C_COMPILER.
loadLinuxToolchain() {
  case "$1" in
    x86_64)
      requireNativeMachine "$1"
      TARGET_CC=cc
      TARGET_CXX=c++
      TARGET_READELF=readelf
      TARGET_RUNNER=(env)
      TARGET_CMAKE_FLAGS=(-DCMAKE_C_COMPILER="$TARGET_CC" -DCMAKE_CXX_COMPILER="$TARGET_CXX")
      ;;
    # Ubuntu 18.04's default GCC 7.5 is older than KleidiCV's minimum (8.4); gcc-8 comes from the
    # same release's archive and shares its libstdc++.so.6, so the glibc floor is unchanged.
    aarch64)
      requireNativeMachine "$1"
      TARGET_CC=gcc-8
      TARGET_CXX=g++-8
      TARGET_READELF=readelf
      TARGET_RUNNER=(env)
      TARGET_CMAKE_FLAGS=(-DCMAKE_C_COMPILER="$TARGET_CC" -DCMAKE_CXX_COMPILER="$TARGET_CXX")
      ;;
    cortexa9t2hf)
      loadPokySdk
      TARGET_CC="$CC"
      TARGET_CXX="$CXX"
      TARGET_READELF="${poky_cross_prefix}readelf"
      TARGET_RUNNER=(qemu-arm -L "$SDKTARGETSYSROOT")
      TARGET_CMAKE_FLAGS=(-DCMAKE_TOOLCHAIN_FILE="$poky_toolchain_file")
      ;;
    *)
      echo "Unsupported linux target: $1" >&2
      exit 1
      ;;
  esac
}

# Reads the glibc version from the target's headers, which also works for a cross sysroot.
targetGlibcVersion() {
  printf '#include <features.h>\n__GLIBC__.__GLIBC_MINOR__\n' | $TARGET_CC -E -P - | tail -1 | tr -d ' '
}
