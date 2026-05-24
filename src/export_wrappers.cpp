#include "RcppArmadillo.h"
#include "openclPort.h"
#include "nmathopencl.h"

using namespace openclPort;

// -----------------------------------------------------------------------------
// R-facing C++ exports for opencltools runtime helpers.
// Stats/math *_opencl mirror exports were removed with the R wrappers.
// -----------------------------------------------------------------------------

// [[Rcpp::export]]
Rcpp::NumericVector r_check_user_interrupt_opencl_cpp_export(
    int n,
    bool verbose = false
) {
  return nmathopencl::r_check_user_interrupt_opencl(n, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector r_check_stack_opencl_cpp_export(
    int n,
    bool verbose = false
) {
  return nmathopencl::r_check_stack_opencl(n, verbose);
}

// [[Rcpp::export]]
std::string load_kernel_source_wrapper_cpp_export(
    const std::string& relative_path,
    const std::string& package = "opencltools"
) {
  return load_kernel_source_wrapper(relative_path, package);
}

// [[Rcpp::export]]
std::string load_kernel_library_wrapper_cpp_export(
    const std::string& subdir,
    const std::string& package = "opencltools",
    bool verbose = false
) {
  return load_kernel_library_wrapper(subdir, package, verbose);
}

// [[Rcpp::export]]
bool has_opencl_cpp_export() {
  return has_opencl();
}

// [[Rcpp::export]]
int get_opencl_core_count_cpp_export() {
  return get_opencl_core_count();
}

// [[Rcpp::export]]
Rcpp::CharacterVector gpu_names_cpp_export() {
  return gpu_names();
}

// [[Rcpp::export]]
Rcpp::List opencl_device_info_cpp_export(bool force = false, bool details = false) {
  return opencl_device_info_rcpp(force, details);
}

// [[Rcpp::export]]
bool opencl_fp64_available_cpp_export(bool force = false) {
  return opencl_fp64_available_impl(force);
}

// [[Rcpp::export]]
void opencl_reset_device_selection_cpp_export() {
  opencl_reset_fp64_selection();
}
