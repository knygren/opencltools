/**
 * @file openclPort.h
 * @brief Public OpenCL interface for glmbayes, including kernel loading,
 *        device discovery, capability probing, and Rcpp-to-std::vector
 *        conversion helpers.
 *
 * @namespace openclPort
 * @brief Lightweight OpenCL utility layer providing kernel management and
 *        device‑level information for optional GPU acceleration.
 *
 * @section ImplementedIn
 *   These declarations are implemented in:
 *     - OpenCL_helper.cpp
 *     - opencl_detect.cpp
 *     - kernel_loader.cpp
 *     - (optional) additional OpenCL backend files guarded by USE_OPENCL
 *
 * @section UsedBy
 *   These functions are consumed by:
 *     - Envelope construction routines (EnvelopeBuild, EnvelopeEval,
 *       EnvelopeDispersionBuild) when OpenCL acceleration is enabled
 *     - R wrappers that expose GPU availability and kernel loading to users
 *
 * @section Responsibilities
 *   Provides:
 *     - Rcpp → std::vector conversion utilities for kernel argument buffers
 *     - GPU/device enumeration and capability checks (gpu_names, has_opencl)
 *     - Kernel source and library loading from inst/cl/ directories
 *     - Conditional OpenCL configuration and build‑option generation
 *
 *   This module:
 *     - is optional and only active when compiled with USE_OPENCL,
 *     - isolates all OpenCL‑specific logic from the statistical code,
 *     - ensures safe fallback to CPU execution when no GPU is available.
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
#include <sstream>
#include <stdexcept>
#endif

using namespace Rcpp;

// Dependencies:

// 1) OpenCL_helper.cpp
// 2) 



//
// -----------------------------------------------------------------------------
// openclPort: Public API for OpenCL kernel loading, device utilities,
//             and Rcpp → std::vector conversion helpers.
// -----------------------------------------------------------------------------
// Everything a user needs to write OpenCL-enabled wrappers lives here.
// -----------------------------------------------------------------------------
namespace openclPort {

// -------------------------------------------------------------------------
// Rcpp → std::vector conversion utilities
// -------------------------------------------------------------------------
std::vector<double> flattenMatrix(const Rcpp::NumericMatrix& mat);
std::vector<double> copyVector(const Rcpp::NumericVector& vec);

// -------------------------------------------------------------------------
// Device / OpenCL utilities
// -------------------------------------------------------------------------
Rcpp::CharacterVector gpu_names();

// Internal-only GPU detection (used by envelope scaling)
int detect_num_gpus_internal();


// -------------------------------------------------------------------------
// R-facing wrappers for kernel source loading
// -------------------------------------------------------------------------
std::string load_kernel_source_wrapper(
    std::string relative_path,
    std::string package = "opencltools"
);

std::string load_kernel_library_wrapper(
    std::string subdir,
    std::string package = "opencltools",
    bool verbose = false
);

// -------------------------------------------------------------------------
// Device / OpenCL utilities
// -------------------------------------------------------------------------

bool has_opencl();
int get_opencl_core_count();

// -------------------------------------------------------------------------
// Kernel file loading (implemented in kernel_loader.cpp). Declared
// unconditionally so optional .cpp sources can compile without -DUSE_OPENCL;
// stubs return safe defaults and are only linked when OpenCL is disabled.
// -------------------------------------------------------------------------
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
    const std::string& package    = "opencltools",
    const std::string& depends_tag = "depends_nmath"
);

// -------------------------------------------------------------------------
// Assemble prelude + indexed-slice nmath + entry kernel OpenCL sources.
// Mirrors glmbayes::opencl::load_likelihood_subgradient_program; entry is
// identified by path under inst/cl/ (e.g. "src/dnorm_kernel.cl").
// -------------------------------------------------------------------------

/// Assembles prelude + shim layers + indexed @all_depends_nmath nmath slice + entry kernel.
std::string build_rmath_opencl_program(
    const std::string& kernel_relative_path,
    const std::string& package,
    const std::string& nmath_depends_annotation);

// -------------------------------------------------------------------------
// fp64-capable OpenCL device selection (cached). Implemented in
// opencl_device_selection.cpp; holds cl_platform_id / cl_device_id as void*
// when USE_OPENCL.
// -------------------------------------------------------------------------
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

// -----------------------------------------------------------------------------
// Conditional OpenCL kernel runner API (requires USE_OPENCL at compile time).
// -----------------------------------------------------------------------------
#ifdef USE_OPENCL

struct OpenCLConfig {
  bool have_expm1;
  bool have_log1p;
  std::string buildOptions;
};

// Probe OpenCL device capabilities and construct build options
OpenCLConfig configureOpenCL(cl_context context,
                             cl_device_id device);

void opencl_bind_selected_fp64_device_or_throw(cl_platform_id& platform, cl_device_id& device);

// -------------------------------------------------------------------------
// Generic double-scalar kernel runner
// Runs any OpenCL kernel whose argument layout is:
//   kernel(double arg0, ..., double argN, __global double* out, int n_out)
// dargs   : scalar double inputs (any count, including zero)
// n_out   : number of output doubles to read back
// out_flat: output buffer (resized to n_out on entry)
// -------------------------------------------------------------------------
void opencl_dbl_scalar_kernel_runner(
    const std::string&         kernel_source,
    const char*                kernel_name,
    const std::vector<double>& dargs,
    int                        n_out,
    std::vector<double>&       out_flat
);

// NDRange-over-len for p*/q* kernels using lower.tail / log.p as int buffers:
// OpenCL entry points *_kernel take arg_cols[] (__global double each), then tails, out, len.
void opencl_pq_tail_kernel_runner(
    const std::string&               kernel_source,
    const char*                      kernel_name,
    int                              len,
    const std::vector<std::vector<double>>& arg_cols,
    const std::vector<int>&          lower_tail,
    const std::vector<int>&          log_p,
    std::vector<double>&             out_flat);

// NDRange-over-len for d* kernels using give_log as int buffer:
// OpenCL entry points *_kernel take arg_cols[] (__global double each), give_log, out, len.
void opencl_d_givelog_kernel_runner(
    const std::string&                     kernel_source,
    const char*                            kernel_name,
    int                                    len,
    const std::vector<std::vector<double>>& arg_cols,
    const std::vector<int>&                give_log,
    std::vector<double>&                   out_flat);

// NDRange-over-len for numeric-only kernels: *_kernel takes one __global column per
// numeric argument (__global double* each), then out, len — no tails / give_log integers.
void opencl_numeric_cols_kernel_runner(
    const std::string&                     kernel_source,
    const char*                            kernel_name,
    int                                    len,
    const std::vector<std::vector<double>>& arg_cols,
    std::vector<double>&                   out_flat);

// Convenience wrapper for pnorm-shaped arguments (delegates to opencl_pq_tail_kernel_runner).
void opencl_pnorm_kernel_runner(
    const std::string&         kernel_source,
    const char*                kernel_name,
    int                        len,
    const std::vector<double>& q,
    const std::vector<double>& mean,
    const std::vector<double>& sd,
    const std::vector<int>&    lower_tail,
    const std::vector<int>&    log_p,
    std::vector<double>&       out_flat
);

// -------------------------------------------------------------------------
// OpenCL error-handling utilities
// (inline so downstream packages get them via #include "openclPort.h")
// -------------------------------------------------------------------------

inline const char* opencl_status_name(cl_int status) {
  switch (status) {
    case CL_SUCCESS:                     return "CL_SUCCESS";
    case CL_DEVICE_NOT_FOUND:            return "CL_DEVICE_NOT_FOUND";
    case CL_DEVICE_NOT_AVAILABLE:        return "CL_DEVICE_NOT_AVAILABLE";
    case CL_COMPILER_NOT_AVAILABLE:      return "CL_COMPILER_NOT_AVAILABLE";
    case CL_MEM_OBJECT_ALLOCATION_FAILURE: return "CL_MEM_OBJECT_ALLOCATION_FAILURE";
    case CL_OUT_OF_RESOURCES:            return "CL_OUT_OF_RESOURCES";
    case CL_OUT_OF_HOST_MEMORY:          return "CL_OUT_OF_HOST_MEMORY";
    case CL_BUILD_PROGRAM_FAILURE:       return "CL_BUILD_PROGRAM_FAILURE";
    case CL_INVALID_VALUE:               return "CL_INVALID_VALUE";
    case CL_INVALID_DEVICE:              return "CL_INVALID_DEVICE";
    case CL_INVALID_BINARY:              return "CL_INVALID_BINARY";
    case CL_INVALID_BUILD_OPTIONS:       return "CL_INVALID_BUILD_OPTIONS";
    case CL_INVALID_PROGRAM:             return "CL_INVALID_PROGRAM";
    case CL_INVALID_OPERATION:           return "CL_INVALID_OPERATION";
    case CL_INVALID_PLATFORM:            return "CL_INVALID_PLATFORM";
    case CL_INVALID_CONTEXT:             return "CL_INVALID_CONTEXT";
    default:                             return "UNKNOWN_OR_VENDOR_SPECIFIC";
  }
}

inline const char* opencl_status_hint(cl_int status) {
  switch (status) {
    case CL_OUT_OF_RESOURCES:
      return "Device/runtime resource limit exceeded (often kernel execution failure, watchdog timeout, or register/local-memory pressure).";
    case CL_OUT_OF_HOST_MEMORY:
      return "Host memory allocation failed while interacting with OpenCL runtime.";
    case CL_MEM_OBJECT_ALLOCATION_FAILURE:
      return "Device memory allocation failed for one or more buffers.";
    case CL_BUILD_PROGRAM_FAILURE:
      return "Kernel compilation/build failed; inspect CL_PROGRAM_BUILD_LOG.";
    case CL_INVALID_CONTEXT:
      return "OpenCL context is invalid; may indicate stale runtime state.";
    case CL_INVALID_DEVICE:
      return "Selected OpenCL device is invalid for this operation.";
    case CL_DEVICE_NOT_AVAILABLE:
      return "OpenCL device is present but temporarily unavailable.";
    default:
      return "No additional hint available.";
  }
}

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

inline std::runtime_error opencl_make_context_error(cl_int status, cl_platform_id platform, cl_device_id device) {
  std::ostringstream msg;
  msg << "OpenCL error at clCreateContext (status=" << status
      << ", name=" << opencl_status_name(status) << "). "
      << "platform_name=" << opencl_read_platform_info_str(platform, CL_PLATFORM_NAME)
      << ", platform_vendor=" << opencl_read_platform_info_str(platform, CL_PLATFORM_VENDOR)
      << ", device_name=" << opencl_read_device_info_str(device, CL_DEVICE_NAME)
      << ", driver_version=" << opencl_read_device_info_str(device, CL_DRIVER_VERSION)
      << ". This may indicate a transient driver/runtime context failure.";
  return std::runtime_error(msg.str());
}

#endif // USE_OPENCL



} // namespace openclPort

#endif // OPENCLPORT_H


