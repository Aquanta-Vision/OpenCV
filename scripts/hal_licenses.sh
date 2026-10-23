# Adds the license notices OpenCV doesn't install for the ARM HALs it builds. Sourced by the
# build scripts of every platform that can build them.
#
# Carotene (tegra_hal, BSD-3, NVIDIA) has no license file, only the notice in each source
# header, which BSD-3 requires to ship with binaries. KleidiCV (Apache-2.0) is unpacked into the
# build directory from the source archive's download cache.

# Keyed off the 3rdparty dependencies in the build information, the list audit_licenses.sh checks.
installHalLicenses() {
  local opencv_dir="$1" build_dir="$2" licenses_dir="$3"
  local build_info="$build_dir/modules/core/version_string.inc"
  local kleidicv_license
  if grep -q '3rdparty dependencies:.* tegra_hal' "$build_info"; then
    sed -n '2,/^ \*\//p' "$opencv_dir/hal/carotene/src/add.cpp" | sed -e '$d' -e 's/^ \* \{0,1\}//' \
      > "$licenses_dir/carotene-LICENSE"
  fi
  kleidicv_license="$(find "$build_dir/3rdparty/kleidicv" -path '*/LICENSES/Apache-2.0.txt' 2>/dev/null | head -1)"
  if [ -n "$kleidicv_license" ]; then
    cp "$kleidicv_license" "$licenses_dir/kleidicv-LICENSE"
  fi
}
