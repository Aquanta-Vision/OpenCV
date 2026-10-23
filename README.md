# OpenCV for PAM

Apache-2.0 OpenCV static libraries for every platform PAM ships on, built from source in CI and
published as GitHub Releases. PAM pins one release by URL and SHA256 and links OpenCV into its
own library, so no OpenCV file ships in a PAM package.

Each release contains a `pam-opencv-<version>-<platform>.tar.xz` per platform (headers, static
libraries, OpenCV's CMake package, `LICENSE`, `licenses/` with every 3rdparty notice,
`BUILDINFO.txt` with the exact CMake flags and `cv::getBuildInformation()`), the
`pam-opencv-<version>-source.tar.xz` every platform was built from, and `SHA256SUMS`.

## Releasing

1. Edit `opencv.env` (upstream version, commit and SHA256, IPP ICV packages) or the build scripts.
2. Push a tag `opencv-<OPENCV_VERSION>-pam.<N>`; bump `N` for recipe-only changes.

The `Release` workflow builds, audits and publishes. Run it with `workflow_dispatch` to build and
audit without publishing.

## What is in the build

CMake flags live in `scripts/common_cmake.sh` plus a short platform list in each
`scripts/build_<platform>.sh`. Only the modules PAM uses, PNG and JPEG codecs, no video I/O
backend other than OpenCV's built-in image sequences and MJPEG, no plugin loading, no FFmpeg or
GStreamer, nothing detected from the build machine and nothing downloaded at configure time.
`scripts/audit_<platform>.sh` enforces this on every build.
