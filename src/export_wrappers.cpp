#include "RcppArmadillo.h"
#include "openclPort.h"

using namespace openclPort;

// -----------------------------------------------------------------------------
// R-facing C++ exports for opencltools runtime helpers.
// -----------------------------------------------------------------------------

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
std::string load_program_preload_wrapper_cpp_export(
    const std::string& manifest_relative_path,
    const std::string& source_package,
    bool verbose = false
) {
  return load_program_preload_wrapper(manifest_relative_path, source_package, verbose);
}

// [[Rcpp::export]]
std::string load_library_for_kernel_cross_package_wrapper_cpp_export(
    const std::string& kernel_relative_path,
    const std::string& kernel_package,
    const std::string& library_subdir,
    const std::string& library_package,
    const std::string& depends_tag
) {
  return load_library_for_kernel_cross_package_wrapper(
      kernel_relative_path, kernel_package, library_subdir,
      library_package, depends_tag);
}

// [[Rcpp::export]]
Rcpp::DataFrame read_program_preload_manifest_cpp_export(
    const std::string& manifest_relative_path,
    const std::string& source_package
) {
  const std::vector<ProgramPreloadEntry> entries =
      read_program_preload_manifest(manifest_relative_path, source_package);

  Rcpp::IntegerVector rank(entries.size());
  Rcpp::CharacterVector kind(entries.size());
  Rcpp::CharacterVector rel_path(entries.size());

  for (std::size_t i = 0; i < entries.size(); ++i) {
    rank[static_cast<R_xlen_t>(i)] = entries[i].rank;
    kind[static_cast<R_xlen_t>(i)] =
        entries[i].kind == ProgramPreloadKind::file ? "file" : "library";
    rel_path[static_cast<R_xlen_t>(i)] = entries[i].rel_path;
  }

  return Rcpp::DataFrame::create(
      Rcpp::Named("rank") = rank,
      Rcpp::Named("kind") = kind,
      Rcpp::Named("rel_path") = rel_path,
      Rcpp::_["stringsAsFactors"] = false);
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
