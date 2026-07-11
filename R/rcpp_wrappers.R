# -------------------------------------------------------------------------
#  Rcpp Interface Wrappers for opencltools
#
#  Minimal, strictly positional R -> C++ bridges for runtime OpenCL helpers.
#  All wrappers are internal (@noRd).
# -------------------------------------------------------------------------

# =============================================================================
#  OpenCL / GPU runtime
#  Callers: load_kernel_source, load_kernel_library, has_opencl,
#           get_opencl_core_count, gpu_names
# =============================================================================

#' @noRd
#' @keywords internal
.load_kernel_source_wrapper_cpp <- function(relative_path, package = "opencltools") {
  .Call(`_opencltools_load_kernel_source_wrapper_cpp_export`, relative_path, package)
}

#' @noRd
#' @keywords internal
.load_kernel_library_wrapper_cpp <- function(subdir, package = "opencltools", verbose = FALSE) {
  .Call(`_opencltools_load_kernel_library_wrapper_cpp_export`, subdir, package, verbose)
}

#' @noRd
#' @keywords internal
.load_program_preload_wrapper_cpp <- function(manifest_relative_path,
                                              source_package,
                                              verbose = FALSE) {
  .Call(`_opencltools_load_program_preload_wrapper_cpp_export`,
        manifest_relative_path, source_package, verbose)
}

#' @noRd
#' @keywords internal
.load_library_for_kernel_cross_package_wrapper_cpp <- function(
    kernel_relative_path,
    kernel_package,
    library_subdir,
    library_package,
    depends_tag) {
  .Call(`_opencltools_load_library_for_kernel_cross_package_wrapper_cpp_export`,
        kernel_relative_path, kernel_package, library_subdir,
        library_package, depends_tag)
}

#' @noRd
#' @keywords internal
.read_program_preload_manifest_cpp <- function(manifest_relative_path,
                                              source_package) {
  .Call(`_opencltools_read_program_preload_manifest_cpp_export`,
        manifest_relative_path, source_package)
}

#' @noRd
#' @keywords internal
.has_opencl_cpp <- function() {
  .Call("_opencltools_has_opencl_cpp_export")
}

#' @noRd
#' @keywords internal
.get_opencl_core_count_cpp <- function() {
  .Call("_opencltools_get_opencl_core_count_cpp_export")
}

#' @noRd
#' @keywords internal
.gpu_names_cpp <- function() {
  .Call("_opencltools_gpu_names_cpp_export")
}
