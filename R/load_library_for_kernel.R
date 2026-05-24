#' Load a Minimal OpenCL Library Subset for a Single Kernel
#'
#' Given a single kernel `.cl` file and a library directory (with an associated
#' dependency index), reads the annotation tag that lists needed library files
#' and returns their source code concatenated in the correct dependency order.
#'
#' For repeated calls in R code, loading \code{kernel_dependency_index.rds} once
#' and passing \code{index =} avoids redundant disk reads.  The bundled
#' \verb{cl/nmath} directory ships \code{kernel_dependency_index.rds} beside the
#' \code{.cl} files; use \link{write_kernel_dependency_index} to regenerate it after
#' porting (for example via \verb{nmathtools/port_inst_cl_nmath_from_src.R} in the
#' \code{openclport} package source tree).
#'
#' ```r
#' lib_dir <- system.file("cl/nmath", package = "opencltools")
#' kpath <- system.file("cl/src/dnorm_kernel.cl", package = "opencltools")
#' src <- load_library_for_kernel(
#'   kpath, lib_dir,
#'   depends_tag = "all_depends_nmath")
#' ```
#'
#' @param kernel_path Path to a single `.cl` kernel file.  The file is scanned
#'   for the annotation tag given by `depends_tag`.
#' @param library_dir Path to the library directory containing the `.cl` source
#'   files (e.g. `system.file("cl/nmath", package = "opencltools")`).
#' @param depends_tag Name of the annotation tag in the kernel file that lists
#'   the required library file stems.  Defaults to `"all_depends"`.  For
#'   kernels annotated with `@all_depends_nmath`, pass
#'   `depends_tag = "all_depends_nmath"`.
#' @param index Optional RDS list; \code{NULL} triggers lazy reads.
#'
#' @details Subsets come only from each launcher file's transitive
#' \code{@all_depends_nmath}-style annotations (use \code{\link{attach_cross_library_tags}}
#' where subgraphs span libraries). Deliberately loading every \verb{.cl} under
#' \verb{cl/nmath} remains available via \code{\link{load_kernel_library}(..., "nmath")}
#' where appropriate.
#'
#' When \verb{inst/extdata/opencl_known_failures.json} matches the launcher path or
#' the declared / loaded stems, \code{\link{warning}(...)} points to fragile ports.
#'
#' @return A character vector subclass \verb{nmathopencl_concatenated_lib} holding
#'   concatenated sources (often length 1; blank annotations yield length-zero
#'   concatenation). Attachments describe requested and loaded library stems,
#'   paths, and byte size; see \link[=kernel_lib_subset_printing]{print methods}.
#'
#' @seealso \link{extract_library_subset}
#' @seealso \link[=kernel_lib_subset_printing]{printing methods}
#' @seealso \link{write_kernel_dependency_index}
#' @family OpenCL kernel library subsets
#'
#' @example inst/examples/Ex_load_library_for_kernel.R
#'
#' @export
load_library_for_kernel <- function(kernel_path,
                                    library_dir,
                                    depends_tag = "all_depends",
                                    index = NULL) {
  if (!file.exists(kernel_path)) {
    stop("`kernel_path` does not exist: ", kernel_path, call. = FALSE)
  }
  if (!dir.exists(library_dir)) {
    stop("`library_dir` does not exist: ", library_dir, call. = FALSE)
  }

  kpath_norm <- suppressWarnings(
    normalizePath(kernel_path, winslash = "/", mustWork = FALSE))
  lib_norm <- suppressWarnings(
    normalizePath(library_dir, winslash = "/", mustWork = FALSE))

  index <- .cl_load_index(index, library_dir)

  lines <- readLines(kernel_path, warn = FALSE)
  needed <- parse_port_annotation(lines, depends_tag)

  if (length(needed) == 0L) {
    .cl_maybe_warn_opencl_known_failures(
      kpath_norm, needed,
      stems_loaded_optional = character(),
      warn_on_loaded_mesh = TRUE
    )
    out <- .cl_concat_result("", character(), character(),
                             kpath_norm, lib_norm, depends_tag, 0L)
    return(invisible(out))
  }

  stems_to_load <- .cl_filter_stems(needed, index, depends_tag)
  if (length(stems_to_load) == 0L) {
    .cl_maybe_warn_opencl_known_failures(
      kpath_norm, needed,
      stems_loaded_optional = character(),
      warn_on_loaded_mesh = TRUE
    )
    out <- .cl_concat_result("", needed, character(),
                             kpath_norm, lib_norm, depends_tag, 0L)
    return(invisible(out))
  }

  stems_to_load <- stems_to_load[order(index$load_order[stems_to_load])]

  .cl_maybe_warn_opencl_known_failures(
    kpath_norm, needed,
    stems_loaded_optional = stems_to_load,
    warn_on_loaded_mesh = TRUE
  )

  parts <- vapply(stems_to_load, function(stem) {
    path <- file.path(library_dir, paste0(stem, ".cl"))
    if (!file.exists(path)) {
      warning("Library file not found for stem '", stem, "': ", path,
              call. = FALSE)
      return("")
    }
    paste(readLines(path, warn = FALSE), collapse = "\n")
  }, character(1L))

  merged <- paste(parts[nzchar(parts)], collapse = "\n\n")
  stems_loaded <- stems_to_load[nzchar(parts)]
  nbytes <- if (nzchar(merged)) {
    nchar(enc2utf8(merged), type = "bytes")
  } else {
    0L
  }
  out <- .cl_concat_result(merged, stems_to_load, stems_loaded,
                           kpath_norm, lib_norm, depends_tag, nbytes)
  invisible(out)
}
