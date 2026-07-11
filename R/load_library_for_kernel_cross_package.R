#' Load a minimal OpenCL library subset across packages
#'
#' Cross-package variant of \link{load_library_for_kernel}: the launcher kernel
#' and the annotated library tree may live in different installed packages.
#' Paths are resolved with \code{system.file("cl", ...)} on each package, matching
#' the C++ helper \code{openclPort::load_library_for_kernel_cross_package()}
#' used by **glmbayes** when assembling likelihood-subgradient programs.
#'
#' @param kernel_relative_path Path to the launcher \verb{.cl} file relative to
#'   \verb{inst/cl/} in \code{kernel_package} (for example
#'   \code{"src/f2_f3_poisson.cl"}).
#' @param kernel_package Installed package containing the launcher kernel.
#' @param library_subdir Library subdirectory relative to \verb{inst/cl/} in
#'   \code{library_package} (for example \code{"nmath"}).
#' @param library_package Installed package containing the annotated library
#'   tree and \code{kernel_dependency_index.tsv}.
#' @param depends_tag Annotation tag scanned in the launcher kernel (for example
#'   \code{"all_depends_nmath"}).
#'
#' @return A \code{character} vector with class \code{nmathopencl_concatenated_lib}
#'   holding concatenated library sources. Attributes record the resolved kernel
#'   and library paths, packages, dependency tag, and byte size.
#'
#' @seealso \link{load_library_for_kernel}, \link{load_program_preload},
#'   \link{load_kernel_source}
#' @family OpenCL kernel library subsets
#'
#' @example inst/examples/Ex_load_library_for_kernel_cross_package.R
#'
#' @export
load_library_for_kernel_cross_package <- function(
    kernel_relative_path,
    kernel_package,
    library_subdir,
    library_package,
    depends_tag = "all_depends_nmath") {
  kernel_relative_path <- as.character(kernel_relative_path)[1L]
  kernel_package <- as.character(kernel_package)[1L]
  library_subdir <- as.character(library_subdir)[1L]
  library_package <- as.character(library_package)[1L]
  depends_tag <- as.character(depends_tag)[1L]

  for (nm in c("kernel_relative_path", "kernel_package",
               "library_subdir", "library_package", "depends_tag")) {
    if (!nzchar(get(nm))) {
      stop("`", nm, "` must be non-empty.", call. = FALSE)
    }
  }

  out <- .load_library_for_kernel_cross_package_wrapper_cpp(
    kernel_relative_path,
    kernel_package,
    library_subdir,
    library_package,
    depends_tag
  )
  .message_if_empty_kernel_text(out, "cross-package library subset")

  kernel_path <- system.file("cl", kernel_relative_path, package = kernel_package)
  library_dir <- system.file("cl", library_subdir, package = library_package)

  invisible(.cl_concat_result(
    out,
    stems_requested = character(),
    stems_loaded = character(),
    kernel_path = kernel_path,
    library_dir = library_dir,
    depends_tag = depends_tag,
    nbytes_concatenated = if (nzchar(out)) {
      nchar(enc2utf8(out), type = "bytes")
    } else {
      0L
    }
  ))
}
