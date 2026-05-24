#' Extract a Minimal Library Subset for a Set of Kernels
#'
#' Given one or more kernel `.cl` files and a library directory, determines the
#' minimal set of library files required (union of all kernels' dependency
#' annotations) and copies them --- in dependency order --- to a destination
#' directory.
#'
#' Use this to populate a project-local copy containing only the library files
#' actually needed by your kernels.  The result can then be committed alongside
#' your kernel files, removing a runtime dependency on the full library.
#'
#' Bundled libraries such as \verb{inst/cl/nmath} ship
#' \code{kernel_dependency_index.rds} next to their \code{.cl} shards.  Pass
#' \code{index =} when you preload that object to avoid redundant reads; regenerate
#' the files with \link{write_kernel_dependency_index}, for example after porting via
#' \verb{nmathtools/port_inst_cl_nmath_from_src.R} in the \code{openclport}
#' package source tree.
#'
#' ```r
#' lib_dir <- system.file("cl/nmath", package = "opencltools")
#' kernel_paths <- system.file(
#'   c("cl/src/dnorm_kernel.cl", "cl/src/pnorm_kernel.cl"),
#'   package = "opencltools"
#' )
#' dest_dir <- tempfile("ex_subset"); dir.create(dest_dir)
#' ## on.exit(unlink(dest_dir, recursive = TRUE), add = TRUE)
#' result <- extract_library_subset(
#'   kernel_paths, lib_dir, dest_dir,
#'   depends_tag = "all_depends_nmath")
#' ```
#'
#' @param kernel_paths Character vector of paths to kernel `.cl` files.  Each
#'   file is scanned for the annotation tag given by `depends_tag`.
#' @param library_dir Path to the source library directory.
#' @param dest_dir Path where files would be written.  Must already exist for any
#'   copying to occur.  If absent, a warning is issued, no directories are created,
#'   and nothing is copied; the returned \code{data.frame} still describes the planned
#'   subset (sources, intended destinations, \code{copied = FALSE}).
#'   In addition to the `.cl` files, \code{kernel_dependency_index.rds} is copied
#'   here when copying runs so the extracted subset can be used with a pre-loaded index.
#' @param depends_tag Name of the annotation tag listing library file stems.
#'   Defaults to `"all_depends"`.  Pass `"all_depends_nmath"` for kernels that
#'   annotate their nmath dependencies with that tag.
#' @param index Pre-loaded dependency index.  If `NULL`, read from
#'   `file.path(library_dir, "kernel_dependency_index.rds")` with a
#'   `message()` nudging toward the recommended pattern.
#' @param overwrite Logical; if `FALSE` (default) existing files in `dest_dir`
#'   are not overwritten --- the copy is skipped and `copied = FALSE` in the
#'   returned data frame.
#'
#' @details \verb{extract_library_subset()} evaluates
#' \verb{inst/extdata/opencl_known_failures.json} against the union of
#' \code{depends_tag} annotations and launcher paths.
#'
#' @return A \verb{nmathopencl_lib_extract_df} subclass of \verb{data.frame}
#'   with one row per library shard (\code{.cl} files in dependency order, followed by
#'   companion index files when planned or copied) and columns:
#'   \describe{
#'     \item{`stem`}{Stem name (filename without `.cl`), or index filenames.}
#'     \item{`source`}{Full path to the source file under \code{library_dir}.}
#'     \item{`dest`}{Intended destination path under \code{dest_dir}.}
#'     \item{`copied`}{\code{TRUE} if copied; otherwise \code{FALSE} including when
#'       \code{dest_dir} is missing (\code{copied = FALSE} for every row),
#'       a source path is missing, or an existing destination was skipped.}
#'   }
#'
#' @seealso \link[=kernel_lib_subset_printing]{printing methods}
#' @seealso \link{load_library_for_kernel}
#' @seealso \link{write_kernel_dependency_index}
#' @family OpenCL kernel library subsets
#'
#' @example inst/examples/Ex_extract_library_subset.R
#'
#' @export
extract_library_subset <- function(kernel_paths,
                                   library_dir,
                                   dest_dir,
                                   depends_tag = "all_depends",
                                   index = NULL,
                                   overwrite = FALSE) {
  empty_df <- function() {
    data.frame(stem = character(), source = character(),
               dest = character(), copied = logical(),
               stringsAsFactors = FALSE)
  }

  kernel_paths_norm <- suppressWarnings(
    normalizePath(kernel_paths, winslash = "/", mustWork = FALSE))
  lib_dir_norm <- suppressWarnings(
    normalizePath(library_dir, winslash = "/", mustWork = FALSE))
  dest_ok <- dir.exists(dest_dir)

  dest_norm <- if (dest_ok) {
    suppressWarnings(normalizePath(dest_dir, winslash = "/", mustWork = FALSE))
  } else {
    suppressWarnings(normalizePath(
      as.character(dest_dir)[1L], winslash = "/", mustWork = FALSE))
  }

  if (!dir.exists(library_dir)) {
    stop("`library_dir` does not exist: ", library_dir, call. = FALSE)
  }

  missing_kernels <- kernel_paths[!file.exists(kernel_paths)]
  if (length(missing_kernels) > 0L) {
    stop("The following `kernel_paths` do not exist:\n",
         paste(" ", missing_kernels, collapse = "\n"), call. = FALSE)
  }

  index <- .cl_load_index(index, library_dir)

  all_needed <- character()
  for (kpath in kernel_paths) {
    lines <- readLines(kpath, warn = FALSE)
    stems <- parse_port_annotation(lines, depends_tag)
    all_needed <- union(all_needed, stems)
  }

  .cl_maybe_warn_opencl_known_failures(
    kernel_paths_norm, all_needed,
    stems_loaded_optional = NULL,
    warn_on_loaded_mesh = FALSE
  )

  if (length(all_needed) == 0L) {
    message("No `@", depends_tag, "` annotations found in any kernel file. ",
            "Nothing to copy.")
    out <- .cl_attach_extract_attrs(empty_df(), kernel_paths_norm,
                                    lib_dir_norm, dest_norm, depends_tag,
                                    manifest_only = !dest_ok)
    return(invisible(out))
  }

  stems_to_copy <- .cl_filter_stems(all_needed, index, depends_tag)
  if (length(stems_to_copy) == 0L) {
    out <- .cl_attach_extract_attrs(empty_df(), kernel_paths_norm,
                                    lib_dir_norm, dest_norm, depends_tag,
                                    manifest_only = !dest_ok)
    return(invisible(out))
  }

  stems_to_copy <- stems_to_copy[order(index$load_order[stems_to_copy])]

  if (!dest_ok) {
    warning("`dest_dir` does not exist: ", dest_dir,
            ". Showing planned extraction only (no directories created; ",
            "no files copied).", call. = FALSE)
  }

  result_rows <- lapply(stems_to_copy, function(stem) {
    src <- file.path(library_dir, paste0(stem, ".cl"))
    dst <- file.path(dest_dir,    paste0(stem, ".cl"))

    if (!file.exists(src)) {
      warning("Source file not found for stem '", stem, "': ", src,
              call. = FALSE)
      return(data.frame(stem = stem, source = src, dest = dst,
                        copied = FALSE, stringsAsFactors = FALSE))
    }

    if (!dest_ok) {
      return(data.frame(stem = stem, source = src, dest = dst,
                        copied = FALSE, stringsAsFactors = FALSE))
    }

    do_copy <- isTRUE(overwrite) || !file.exists(dst)
    if (do_copy) {
      file.copy(src, dst, overwrite = overwrite)
    }
    data.frame(stem = stem, source = src, dest = dst,
               copied = do_copy, stringsAsFactors = FALSE)
  })

  index_files <- c("kernel_dependency_index.rds", "kernel_dependency_index.tsv")
  index_rows <- lapply(index_files, function(idx_name) {
    src <- file.path(library_dir, idx_name)
    dst <- file.path(dest_dir,    idx_name)
    if (!file.exists(src)) {
      warning("No `", idx_name, "` found in `library_dir`; not copied. ",
              "Run `write_kernel_dependency_index()` to create it.",
              call. = FALSE)
      return(NULL)
    }
    if (!dest_ok) {
      return(data.frame(stem = idx_name, source = src, dest = dst,
                        copied = FALSE, stringsAsFactors = FALSE))
    }
    do_copy <- isTRUE(overwrite) || !file.exists(dst)
    if (do_copy) {
      file.copy(src, dst, overwrite = overwrite)
    }
    data.frame(stem = idx_name, source = src, dest = dst,
               copied = do_copy, stringsAsFactors = FALSE)
  })

  result <- do.call(rbind, c(result_rows, Filter(Negate(is.null), index_rows)))
  out <- .cl_attach_extract_attrs(result, kernel_paths_norm,
                                  lib_dir_norm, dest_norm, depends_tag,
                                  manifest_only = !dest_ok)
  invisible(out)
}
