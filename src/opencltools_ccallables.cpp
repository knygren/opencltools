#include <R_ext/Rdynload.h>
#include <R_ext/Error.h>
#include <cstdlib>
#include <cstring>
#include <string>

#include "openclPort.h"

using namespace openclPort;

extern "C" {
  
  // ---- C ABI wrappers ----
  // All boolean-ish returns are int (0/1) for C ABI stability.
  
  int opencltools_has_opencl(void) {
    return openclPort::has_opencl() ? 1 : 0;
  }
  
  int opencltools_get_opencl_core_count(void) {
    return openclPort::get_opencl_core_count();
  }
  
  int opencltools_opencl_ensure_fp64_selection(int force) {
    return openclPort::opencl_ensure_fp64_selection(force != 0) ? 1 : 0;
  }
  
  void opencltools_opencl_reset_fp64_selection(void) {
    openclPort::opencl_reset_fp64_selection();
  }
  
  int opencltools_opencl_fp64_available(int force) {
    return openclPort::opencl_fp64_available_impl(force != 0) ? 1 : 0;
  }
  
  // String-returning wrappers (caller frees with opencltools_free_cstr).
  // Return nullptr on error; never throw across C ABI.
  const char* opencltools_load_kernel_source(const char* relative_path, const char* package) {
    if (!relative_path || !package) return nullptr;
    try {
      std::string out = openclPort::load_kernel_source(relative_path, package);
      char* p = static_cast<char*>(std::malloc(out.size() + 1));
      if (!p) return nullptr;
      std::memcpy(p, out.c_str(), out.size() + 1);
      return p;
    } catch (...) {
      return nullptr;
    }
  }
  
  const char* opencltools_load_kernel_library(const char* subdir, const char* package, int verbose) {
    if (!subdir || !package) return nullptr;
    try {
      std::string out = openclPort::load_kernel_library(subdir, package, verbose != 0);
      char* p = static_cast<char*>(std::malloc(out.size() + 1));
      if (!p) return nullptr;
      std::memcpy(p, out.c_str(), out.size() + 1);
      return p;
    } catch (...) {
      return nullptr;
    }
  }
  
  const char* opencltools_load_library_for_kernel(
      const char* kernel_relative_path,
      const char* library_subdir,
      const char* package,
      const char* depends_tag) {
    if (!kernel_relative_path || !library_subdir || !package || !depends_tag) return nullptr;
    try {
      std::string out = openclPort::load_library_for_kernel(
        kernel_relative_path, library_subdir, package, depends_tag);
      char* p = static_cast<char*>(std::malloc(out.size() + 1));
      if (!p) return nullptr;
      std::memcpy(p, out.c_str(), out.size() + 1);
      return p;
    } catch (...) {
      return nullptr;
    }
  }
  
  void opencltools_free_cstr(const char* p) {
    std::free((void*)p);
  }
  
  int opencltools_api_version(void) {
    return 1;
  }
  
} // extern "C"

// [[Rcpp::export]]
void register_opencltools_ccallables_cpp_export() {
  R_RegisterCCallable("opencltools", "opencltools_has_opencl",                   (DL_FUNC) &opencltools_has_opencl);
  R_RegisterCCallable("opencltools", "opencltools_get_opencl_core_count",        (DL_FUNC) &opencltools_get_opencl_core_count);
  R_RegisterCCallable("opencltools", "opencltools_opencl_ensure_fp64_selection", (DL_FUNC) &opencltools_opencl_ensure_fp64_selection);
  R_RegisterCCallable("opencltools", "opencltools_opencl_reset_fp64_selection",  (DL_FUNC) &opencltools_opencl_reset_fp64_selection);
  R_RegisterCCallable("opencltools", "opencltools_opencl_fp64_available",        (DL_FUNC) &opencltools_opencl_fp64_available);
  R_RegisterCCallable("opencltools", "opencltools_load_kernel_source",           (DL_FUNC) &opencltools_load_kernel_source);
  R_RegisterCCallable("opencltools", "opencltools_load_kernel_library",          (DL_FUNC) &opencltools_load_kernel_library);
  R_RegisterCCallable("opencltools", "opencltools_load_library_for_kernel",      (DL_FUNC) &opencltools_load_library_for_kernel);
  R_RegisterCCallable("opencltools", "opencltools_free_cstr",                    (DL_FUNC) &opencltools_free_cstr);
  R_RegisterCCallable("opencltools", "opencltools_api_version",                  (DL_FUNC) &opencltools_api_version);
}