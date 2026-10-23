# The Poky SDK's CMake toolchain, with the processor name OpenCV and libjpeg-turbo recognize.
# The SDK reports "cortexa9t2hf-neon-oe", which matches none of their patterns, so OpenCV turns
# off NEON (and Carotene) and libjpeg-turbo its ARM SIMD code.
include("$ENV{OE_CMAKE_TOOLCHAIN_FILE}")
set(CMAKE_SYSTEM_PROCESSOR arm)
