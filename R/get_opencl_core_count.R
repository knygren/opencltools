#' Get the number of available OpenCL compute units
#'
#' Returns the number of compute units (cores) available on the default
#' OpenCL device. This can be useful for diagnostics or performance tuning.
#'
#' @return Integer scalar: total GPU compute units across OpenCL platforms when
#'   this build has OpenCL support; \code{1} on CPU-only builds. See
#'   \code{\link{gpu_diagnostics}} for full return details.
#' @example inst/examples/Ex_gpu_diagnostics.R
#' @export
get_opencl_core_count <- function() {
  .get_opencl_core_count_cpp()
}