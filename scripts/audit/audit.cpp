// Fails (exit 1) if the OpenCV libraries it is linked against break the PAM licensing rules: a
// module list other than the spec's, any external video I/O backend, an unexpected GUI backend,
// or a videoio backend other than the built-in image sequence and MJPEG ones. Prints the build
// information and every finding, not just the first.
//
// Usage: audit <expected GUI backend>, e.g. GTK3, WIN32UI, COCOA or NONE
#include <opencv2/core.hpp>
#include <opencv2/videoio/registry.hpp>

#include <algorithm>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace {

const std::string expected_modules =
  "calib3d core features2d flann highgui imgcodecs imgproc photo video videoio";

const std::vector<cv::VideoCaptureAPIs> allowed_backends = {cv::CAP_IMAGES, cv::CAP_OPENCV_MJPEG};

std::string trim(const std::string& text) {
  const auto first = text.find_first_not_of(' ');
  const auto last  = text.find_last_not_of(' ');
  return first == std::string::npos ? "" : text.substr(first, last - first + 1);
}

std::vector<std::string> buildInformationLines() {
  std::istringstream stream(cv::getBuildInformation());
  std::vector<std::string> lines;
  for (std::string line; std::getline(stream, line);) {
    lines.push_back(line);
  }
  return lines;
}

// Rows look like "    To be built:                 calib3d core ...".
std::string rowValue(const std::vector<std::string>& lines, const std::string& label) {
  for (const auto& line : lines) {
    const auto at = line.find(label);
    if (at != std::string::npos && trim(line.substr(0, at)).empty()) {
      return trim(line.substr(at + label.size()));
    }
  }
  return "<missing>";
}

int checkModules(const std::vector<std::string>& lines) {
  const auto modules = rowValue(lines, "To be built:");
  if (modules != expected_modules) {
    std::cout << "FAIL modules are \"" << modules << "\", expected \"" << expected_modules << "\"\n";
    return 1;
  }
  return 0;
}

int checkGui(const std::vector<std::string>& lines, const std::string& expected) {
  const auto gui = rowValue(lines, "GUI:");
  if (gui != expected) {
    std::cout << "FAIL GUI backend is \"" << gui << "\", expected \"" << expected << "\"\n";
    return 1;
  }
  return 0;
}

// Every row in the Video I/O section names an optional backend; none may be enabled.
int checkVideoIoSection(const std::vector<std::string>& lines) {
  int failures    = 0;
  bool in_section = false;
  for (const auto& line : lines) {
    if (trim(line) == "Video I/O:") {
      in_section = true;
      continue;
    }
    if (in_section && line.rfind("    ", 0) != 0) {
      break;
    }
    if (in_section && line.find("YES") != std::string::npos) {
      std::cout << "FAIL video I/O backend enabled: " << trim(line) << "\n";
      ++failures;
    }
  }
  return failures;
}

int checkBackends(const char* kind, const std::vector<cv::VideoCaptureAPIs>& backends) {
  int failures = 0;
  for (const auto backend : backends) {
    const auto name = cv::videoio_registry::getBackendName(backend);
    std::cout << "  " << kind << " " << name << "\n";
    if (std::find(allowed_backends.begin(), allowed_backends.end(), backend) == allowed_backends.end()) {
      std::cout << "FAIL " << kind << " backend not allowed: " << name << "\n";
      ++failures;
    }
  }
  return failures;
}

int checkAllBackends() {
  std::cout << "videoio backends:\n";
  return checkBackends("any", cv::videoio_registry::getBackends()) +
         checkBackends("camera", cv::videoio_registry::getCameraBackends()) +
         checkBackends("stream", cv::videoio_registry::getStreamBackends()) +
         checkBackends("writer", cv::videoio_registry::getWriterBackends());
}

}  // namespace

int main(int argc, char** argv) {
  if (argc != 2) {
    std::cerr << "Usage: audit <expected GUI backend>\n";
    return 2;
  }
  std::cout << cv::getBuildInformation() << "\n";
  const auto lines = buildInformationLines();
  const int failures =
    checkModules(lines) + checkGui(lines, argv[1]) + checkVideoIoSection(lines) + checkAllBackends();
  if (failures == 0) {
    std::cout << "PASS\n";
  } else {
    std::cout << "FAILED with " << failures << " finding(s)\n";
  }
  return failures == 0 ? 0 : 1;
}
