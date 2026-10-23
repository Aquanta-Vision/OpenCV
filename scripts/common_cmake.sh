# CMake flags shared by every platform (SPEC "CMake baseline"). Sourced by the per-platform build
# scripts, which add the GUI backend and IPP per target.
#
# Most of this list turns off OpenCV defaults. Left on, they detect and link whatever the build
# machine has (system libjpeg, LAPACK, GStreamer, CUDA codecs) or add video backends with H.264
# (FFmpeg, Media Foundation, AVFoundation, Android MediaNDK). Plugin loading (videoio, highgui and
# core's parallel backends) is off too: it would load any opencv_videoio_ffmpeg* found next to the
# binary, even in a static build. WITH_ADE is
# for G-API, which isn't built, but its configure step downloads ADE before BUILD_LIST applies.

# shellcheck disable=SC2034
COMMON_CMAKE_FLAGS=(
  -DCMAKE_BUILD_TYPE=Release
  -DBUILD_SHARED_LIBS=OFF
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DBUILD_WITH_STATIC_CRT=OFF
  -DBUILD_LIST=core,imgproc,photo,features2d,flann,calib3d,video,videoio,highgui,imgcodecs
  -DOPENCV_ENABLE_NONFREE=OFF
  -DBUILD_opencv_world=OFF

  -DVIDEOIO_ENABLE_PLUGINS=OFF
  -DHIGHGUI_ENABLE_PLUGINS=OFF
  -DPARALLEL_ENABLE_PLUGINS=OFF
  -DWITH_FFMPEG=OFF
  -DWITH_GSTREAMER=OFF
  -DWITH_MSMF=OFF
  -DWITH_AVFOUNDATION=OFF
  -DWITH_DSHOW=OFF
  -DWITH_V4L=OFF
  -DWITH_1394=OFF
  -DWITH_GPHOTO2=OFF
  -DWITH_OBSENSOR=OFF
  -DWITH_ANDROID_MEDIANDK=OFF
  -DWITH_ANDROID_NATIVE_CAMERA=OFF
  -DWITH_CAP_IOS=OFF
  -DWITH_NVCUVID=OFF
  -DWITH_NVCUVENC=OFF
  -DWITH_CUDA=OFF
  -DWITH_VA=OFF
  -DWITH_VA_INTEL=OFF
  -DWITH_DIRECTX=OFF
  -DWITH_DIRECTML=OFF
  -DWITH_QT=OFF
  -DWITH_VTK=OFF
  -DWITH_OPENGL=OFF

  -DWITH_OPENEXR=OFF
  -DWITH_TIFF=OFF
  -DWITH_WEBP=OFF
  -DWITH_OPENJPEG=OFF
  -DWITH_JASPER=OFF
  -DWITH_AVIF=OFF
  -DWITH_JPEGXL=OFF
  -DWITH_SPNG=OFF
  -DWITH_IMGCODEC_GIF=OFF
  -DWITH_IMGCODEC_HDR=OFF
  -DWITH_IMGCODEC_SUNRASTER=OFF
  -DWITH_IMGCODEC_PXM=OFF
  -DWITH_IMGCODEC_PFM=OFF
  -DBUILD_ZLIB=ON
  -DBUILD_PNG=ON
  -DBUILD_JPEG=ON

  -DWITH_OPENCL=OFF
  -DWITH_ITT=OFF
  -DWITH_TBB=OFF
  -DWITH_EIGEN=OFF
  -DWITH_LAPACK=OFF
  -DWITH_PROTOBUF=OFF
  -DWITH_FLATBUFFERS=OFF
  -DWITH_ADE=OFF
  -DWITH_KLEIDICV=OFF
  -DWITH_FASTCV=OFF

  -DOPENCV_GENERATE_PKGCONFIG=OFF
  -DBUILD_TESTS=OFF
  -DBUILD_PERF_TESTS=OFF
  -DBUILD_EXAMPLES=OFF
  -DBUILD_opencv_apps=OFF
  -DBUILD_JAVA=OFF
  -DBUILD_opencv_python3=OFF
  -DBUILD_DOCS=OFF
  -DINSTALL_C_EXAMPLES=OFF
  -DOPENCV_SKIP_PYTHON_LOADER=ON
)
