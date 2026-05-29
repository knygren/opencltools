/**
 * @file openclPort.h
 * @brief OpenCL runtime utilities for opencltools: kernel loading,
 *        device discovery, and fp64 capability probing.
 *
 * Installed copy for LinkingTo: opencltools (#include <opencltools/openclPort.h>).
 * Keep in sync with src/openclPort.h. Khronos CL headers are not bundled under
 * include/CL/; downstream configure must add the system/SDK -I paths.
 *
 * @namespace openclPort
 */

#ifndef OPENCLPORT_H
#define OPENCLPORT_H

#include <RcppArmadillo.h>
#include <string>
#include <vector>

#ifdef __linux__
#include <stdio.h>
#include <stdlib.h>
#endif

#ifdef USE_OPENCL
#define CL_TARGET_OPENCL_VERSION 300
#include <CL/cl.h>
#endif

using namespace Rcpp;

namespace openclPort {

std::vector<double> flattenMatrix(const Rcpp::NumericMatrix& mat);
std::vector<double> copyVector(const Rcpp::NumericVector& vec);

Rcpp::CharacterVector gpu_names();
int detect_num_gpus_internal();

std::string load_kernel_source_wrapper(
    std::string relative_path,
    std::string package = "opencltools"
);

std::string load_kernel_library_wrapper(
    std::string subdir,
    std::string package = "opencltools",
    bool verbose = false
);

bool has_opencl();
int get_opencl_core_count();

std::string load_kernel_source(
    const std::string& relative_path,
    const std::string& package = "opencltools"
);

std::string load_kernel_library(
    const std::string& subdir,
    const std::string& package = "opencltools",
    bool verbose = false
);

std::string load_library_for_kernel(
    const std::string& kernel_relative_path,
    const std::string& library_subdir,
    const std::string& package,
    const std::string& depends_tag);

#ifdef USE_OPENCL

struct OpenCLConfig {
  bool have_expm1;
  bool have_log1p;
  std::string buildOptions;
};

OpenCLConfig configureOpenCL(cl_context context,
                             cl_device_id device);

#endif // USE_OPENCL

struct OpenCLFp64DeviceCache {
  bool valid = false;
  std::string reason;
  bool extension_cl_khr_fp64 = false;
  bool probe_fp64_ok = false;
  int platform_index = -1;
  int device_index = -1;
  std::string platform_vendor;
  std::string platform_name;
  std::string device_vendor;
  std::string device_name;
  std::string device_version;
  std::string driver_version;
  std::string device_type_label;
  std::string selection_policy;
  std::string probe_failure_log;
  void* platform = nullptr;
  void* device = nullptr;
};

bool opencl_ensure_fp64_selection(bool force);
const OpenCLFp64DeviceCache& opencl_fp64_selection();
void opencl_reset_fp64_selection();
Rcpp::List opencl_device_info_rcpp(bool force = false, bool details = false);
bool opencl_fp64_available_impl(bool force = false);

#ifdef USE_OPENCL

inline std::string opencl_read_platform_info_str(cl_platform_id platform, cl_platform_info param) {
  if (platform == nullptr) return "unknown";
  size_t n = 0;
  if (clGetPlatformInfo(platform, param, 0, nullptr, &n) != CL_SUCCESS || n == 0) return "unknown";
  std::string out(n, '\0');
  if (clGetPlatformInfo(platform, param, n, &out[0], nullptr) != CL_SUCCESS) return "unknown";
  if (!out.empty() && out.back() == '\0') out.pop_back();
  return out.empty() ? "unknown" : out;
}

inline std::string opencl_read_device_info_str(cl_device_id device, cl_device_info param) {
  if (device == nullptr) return "unknown";
  size_t n = 0;
  if (clGetDeviceInfo(device, param, 0, nullptr, &n) != CL_SUCCESS || n == 0) return "unknown";
  std::string out(n, '\0');
  if (clGetDeviceInfo(device, param, n, &out[0], nullptr) != CL_SUCCESS) return "unknown";
  if (!out.empty() && out.back() == '\0') out.pop_back();
  return out.empty() ? "unknown" : out;
}

#endif // USE_OPENCL

} // namespace openclPort

#endif // OPENCLPORT_H
