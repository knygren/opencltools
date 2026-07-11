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
#' re-implementing the same plumbing.
#'
#' @details
#' Typical workflow for a library author:
#' \enumerate{
#'   \item Annotate \code{.cl} shards with \code{@depends} / \code{@provides}.
#'   \item Use \code{\link{load_library_for_kernel}} or
#'     \code{\link{extract_library_subset}} to assemble minimal subsets.
#'   \item Probe the workstation with \code{\link{has_opencl}},
#'     \code{\link{verify_opencl_runtime}}, and \code{\link{diagnose_glmbayes}}.
#'   \item For a new downstream package, call \code{\link{use_opencl_configure}}
#'     or \code{\link{port_to_opencl_configure}} to install CRAN-safe configure
#'     scripts.
#' }
#'
#' @seealso
#' \code{\link{load_kernel_library}}, \code{\link{load_kernel_source}},
#' \code{\link{has_opencl}}, \code{\link{opencl_device_info}}.
#'
#' @author
#' Kjell Nygren
#'
#' @section Citation:
#' Use \code{citation("opencltools")} for BibTeX. The first entry cites this
#' package as software; the second cites Stone \emph{et al.} (2010) when
#' reporting OpenCL GPU execution. Cite \pkg{nmathopencl} for ported Mathlib
#' kernels and \pkg{glmbayes} for the Bayesian GLM application layer.
#' Likelihood subgradient methodology (Nygren and Nygren, 2006) applies to
#' \pkg{glmbayes} envelope sampling, not to citing this loader/runtime layer alone.
#'
#' @references
#' Stone JE, Gohara D, Shi G (2010).
#' \emph{OpenCL: A Parallel Programming Standard for Heterogeneous Computing Systems.}
#' Computing in Science and Engineering \bold{12}(3), 66--72.
#' \doi{10.1109/MCSE.2010.69}
#'
#' @import stats Rcpp
#' @importFrom Rcpp evalCpp
#' @importFrom Rdpack reprompt
#' @importFrom RcppParallel RcppParallelLibs
#' @importFrom utils read.delim
#' @useDynLib opencltools, .registration = TRUE
"_PACKAGE"
