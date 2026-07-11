#' Read a program preload manifest
#'
#' Reads the tab-separated manifest that lists the fixed OpenCL prelude
#' (single files and annotated library directories) in load order.  Production
#' manifests ship with downstream packages such as **nmathopencl**; this package
#' includes a small teaching manifest at
#' \code{inst/cl/program_preload_manifest.tsv} for examples and tests.
#'
#' When a companion \code{program_preload_manifest.rds} exists beside the
#' \code{.tsv} file (see \link{write_program_preload_manifest}), the RDS copy
#' is preferred for repeated R-side reads.
#'
#' @param manifest_relative_path Path relative to \verb{inst/cl/} inside
#'   \code{source_package}. Defaults to \code{"program_preload_manifest.tsv"}.
#' @param source_package Installed package that owns the manifest and prelude
#'   sources. Defaults to \code{"nmathopencl"}.
#' @param manifest_path Optional absolute path to a \code{.tsv} manifest. When
#'   supplied, \code{source_package} is still recorded in metadata but
#'   \code{system.file()} is not used.
#'
#' @return A \code{data.frame} with columns \code{rank}, \code{kind}
#'   (\code{"file"} or \code{"library"}), and \code{rel_path}, sorted by
#'   \code{rank}.
#'
#' @seealso \link{load_program_preload}, \link{write_program_preload_manifest}
#' @family OpenCL program preload
#'
#' @example inst/examples/Ex_load_program_preload.R
#'
#' @export
read_program_preload_manifest <- function(
    manifest_relative_path = "program_preload_manifest.tsv",
    source_package = "nmathopencl",
    manifest_path = NULL) {
  paths <- .program_preload_resolve_paths(
    manifest_relative_path, source_package, manifest_path
  )

  if (file.exists(paths$rds_path)) {
    obj <- readRDS(paths$rds_path)
    if (!is.list(obj) || !is.data.frame(obj$entries)) {
      stop("Invalid program_preload_manifest.rds structure.", call. = FALSE)
    }
    return(.program_preload_validate_entries(obj$entries, "manifest"))
  }

  entries <- if (!is.null(manifest_path) && nzchar(as.character(manifest_path)[1L])) {
    read.delim(paths$tsv_path, stringsAsFactors = FALSE)
  } else {
    .read_program_preload_manifest_cpp(
      paths$manifest_relative_path,
      paths$source_package
    )
  }
  .program_preload_validate_entries(entries, "manifest")
}


#' Concatenate a program preload from a manifest
#'
#' Loads the fixed OpenCL prelude listed in a program preload manifest: single
#' \verb{.cl} files via \link{load_kernel_source} and annotated library
#' directories via \link{load_kernel_library}.  This mirrors the C++ helper
#' \code{openclPort::load_program_preload()} used by downstream packages such
#' as **glmbayes** when assembling likelihood-subgradient programs.
#'
#' @param manifest_relative_path Path relative to \verb{inst/cl/} inside
#'   \code{source_package}.
#' @param source_package Installed package that owns the manifest and prelude
#'   sources.
#' @param verbose Passed to \link{load_kernel_library} for library rows.
#' @param manifest Optional pre-validated manifest \code{data.frame} from
#'   \link{read_program_preload_manifest}. When supplied, assembly runs in R
#'   without re-reading the manifest from disk.
#'
#' @return A length-one \code{character} vector with class
#'   \code{opencltools_program_preload} holding the concatenated OpenCL C
#'   source text.
#'
#' @seealso \link{read_program_preload_manifest},
#'   \link{load_library_for_kernel_cross_package}, \link{load_kernel_source}
#' @family OpenCL program preload
#'
#' @example inst/examples/Ex_load_program_preload.R
#'
#' @export
load_program_preload <- function(
    manifest_relative_path = "program_preload_manifest.tsv",
    source_package = "nmathopencl",
    verbose = FALSE,
    manifest = NULL) {
  paths <- .program_preload_resolve_paths(
    manifest_relative_path, source_package
  )

  entries <- if (is.null(manifest)) {
    read_program_preload_manifest(
      paths$manifest_relative_path,
      paths$source_package
    )
  } else {
    .program_preload_validate_entries(manifest, "manifest")
  }

  out <- if (is.null(manifest)) {
    .load_program_preload_wrapper_cpp(
      paths$manifest_relative_path,
      paths$source_package,
      verbose
    )
  } else {
    .program_preload_from_entries(
      entries,
      paths$source_package,
      verbose
    )
  }

  out <- .message_if_empty_kernel_text(out, "program preload")

  .program_preload_result(out, paths, entries, verbose)
}


#' Build and save a program preload manifest
#'
#' Writes companion manifest files next to the prelude sources under
#' \verb{inst/cl/}:
#'
#' \itemize{
#'   \item tab-separated \code{program_preload_manifest.tsv} for C++ loaders;
#'   \item \code{program_preload_manifest.rds} for fast R-side reuse.
#' }
#'
#' @param manifest Optional manifest \code{data.frame}. When \code{NULL}, the
#'   function reads \code{manifest_path} or resolves
#'   \code{system.file("cl", manifest_relative_path, package = source_package)}.
#' @param manifest_path Optional path to an existing \code{.tsv} manifest.
#' @param source_package Package name recorded in RDS metadata.
#' @param manifest_relative_path Relative path under \verb{inst/cl/} used when
#'   resolving the default manifest location.
#' @param write If \code{FALSE}, validates and returns the manifest object
#'   without writing files.
#' @param verbose If \code{TRUE}, reports output paths.
#'
#' @return Invisibly, a \code{list()} with schema \code{version = 1L},
#'   \code{generated_at}, \code{source_package}, \code{manifest_relative_path},
#'   \code{manifest_path}, and \code{entries}.
#'
#' @seealso \link{read_program_preload_manifest}, \link{load_program_preload}
#' @family OpenCL program preload
#'
#' @example inst/examples/Ex_write_program_preload_manifest.R
#'
#' @export
write_program_preload_manifest <- function(
    manifest = NULL,
    manifest_path = NULL,
    source_package = "nmathopencl",
    manifest_relative_path = "program_preload_manifest.tsv",
    write = TRUE,
    verbose = FALSE) {
  paths <- .program_preload_write_paths(
    manifest_relative_path, source_package, manifest_path
  )

  entries <- if (is.null(manifest)) {
    if (!file.exists(paths$tsv_path)) {
      stop("Manifest not found: ", paths$tsv_path, call. = FALSE)
    }
    read.delim(paths$tsv_path, stringsAsFactors = FALSE)
  } else {
    manifest
  }

  entries <- .program_preload_validate_entries(entries, "manifest")
  obj <- .program_preload_object(entries, paths)

  if (!is.logical(write) || length(write) != 1L || is.na(write)) {
    stop("`write` must be a single logical value.", call. = FALSE)
  }

  if (isTRUE(write)) {
    tsv_lines <- c(
      "rank\tkind\trel_path",
      paste(entries$rank, entries$kind, entries$rel_path, sep = "\t")
    )
    writeLines(tsv_lines, con = paths$tsv_path, useBytes = FALSE)
    if (isTRUE(verbose)) {
      message("Wrote program preload manifest (tsv): ", paths$tsv_path)
    }

    saveRDS(obj, file = paths$rds_path, compress = TRUE)
    if (isTRUE(verbose)) {
      message("Wrote program preload manifest (rds): ", paths$rds_path)
    }
  }

  invisible(obj)
}
