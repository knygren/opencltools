#' @aliases opencltools
#'
#' @title opencltools: OpenCL Tools for R Package Developers
#'
#' @description
#' \pkg{opencltools} provides runtime OpenCL support for R: probe hardware and
#' drivers, load and concatenate kernel sources, and manage dependency-annotated
#' \code{.cl} libraries. Downstream packages such as \pkg{nmathopencl} ship
#' ported kernel trees and call \code{\link{load_kernel_library}} /
#' \code{\link{load_library_for_kernel}} from this package rather than
#' reimplementing the same plumbing.
#'
#' @details
#' Typical workflow for a library author:
#' \enumerate{
#'   \item Annotate \code{.cl} shards with \code{@depends} / \code{@provides}.
#'   \item Use \code{\link{load_library_for_kernel}} or
#'     \code{\link{extract_library_subset}} to assemble minimal subsets.
#'   \item Probe the workstation with \code{\link{has_opencl}},
#'     \code{\link{verify_opencl_runtime}}, and \code{\link{diagnose_glmbayes}}.
#' }
#'
#' @seealso
#' \code{\link{load_kernel_library}}, \code{\link{load_kernel_source}},
#' \code{\link{has_opencl}}, \code{\link{opencl_device_info}}.
#'
#' @author
#' Kjell Nygren
#'
#' @import stats Rcpp
#' @importFrom Rcpp evalCpp
#' @importFrom Rdpack reprompt
#' @importFrom RcppParallel RcppParallelLibs
#' @useDynLib opencltools, .registration = TRUE
"_PACKAGE"
