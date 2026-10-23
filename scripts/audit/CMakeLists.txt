# Links the audit program against a published platform tree through OpenCV's own CMake package,
# the same way PAM consumes it, so a successful build also proves the package works.
cmake_minimum_required(VERSION 3.16)
project(pam_opencv_audit CXX)

find_package(OpenCV REQUIRED
  COMPONENTS core imgproc photo features2d flann calib3d video videoio highgui imgcodecs)

add_executable(audit audit.cpp)
target_link_libraries(audit PRIVATE ${OpenCV_LIBS})
