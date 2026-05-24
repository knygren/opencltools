#' Printing results from minimal kernel-library subset loaders
#'
#' \link{load_library_for_kernel} returns a concatenated OpenCL-sources string
#' with classes \verb{nmathopencl_concatenated_lib}, subclassing \code{character},
#' with attributes listing requested and loaded stems in dependency order.
#'
#' \link{extract_library_subset} returns classes \verb{nmathopencl_lib_extract_df},
#' subclassing \code{data.frame}, with paths and tag metadata attached.
#'
#' @param x From \link{load_library_for_kernel} or \link{extract_library_subset}.
#' @param ... Reserved; the extract \code{data.frame} printer does not forward to
#'   \code{print.data.frame} by default (use \code{print(as.data.frame(x), ...)}
#'   for a full preview).
#' @param max_provides_symbols_per_shard For \code{print.nmathopencl_concatenated_lib}:
#'   maximum \code{//@provides} symbols printed per algorithm-style shard
#'   (default \code{80}). For shards \code{dpq}, \code{Rmath}, \code{nmath}, and
#'   \code{refactored}, only a one-line count is shown (header / internals-style
#'   \verb{//@provides}).
#'   Use \code{NA_integer_} or a negative value for no cap on algorithm shards.
#'
#' @example inst/examples/Ex_kernel_lib_subset_printing.R
#' @name kernel_lib_subset_printing


#' @rdname kernel_lib_subset_printing
#' @export
print.nmathopencl_concatenated_lib <- function(x, ...,
                                               max_provides_symbols_per_shard = 80L) {
  stems_req <- attr(x, "stems_requested", exact = TRUE)
  stems_ld <- attr(x, "stems_loaded", exact = TRUE)
  kpath <- attr(x, "kernel_path", exact = TRUE)
  lib_dir <- attr(x, "library_dir", exact = TRUE)
  tag <- attr(x, "depends_tag", exact = TRUE)

  sr <- if (length(stems_req)) stems_req else character()
  sl <- if (length(stems_ld)) stems_ld else character()

  cat("<nmathopencl_concatenated_lib>\n")

  kp <- suppressWarnings(normalizePath(
    if (is.null(kpath)) NA_character_ else as.character(kpath),
    winslash = "/", mustWork = FALSE
  ))
  ld <- suppressWarnings(normalizePath(
    if (is.null(lib_dir)) NA_character_ else as.character(lib_dir),
    winslash = "/", mustWork = FALSE
  ))

  if (!is.na(kp)) cat("Kernel:", kp, fill = TRUE)
  if (!is.na(ld)) cat("Library directory:", ld, fill = TRUE)

  tc <- if (!is.null(tag)) as.character(tag[1L]) else NA_character_
  cat("Depends tag:",
      ifelse(!is.na(tc) && nzchar(tc), tc, "all_depends"),
      fill = TRUE)

  cat("\nRequested library stems (dependency order,", length(sr), ", files):\n", sep = "")
  .cl_print_stems_numbered(sr)

  missed <- setdiff(sr, sl)
  if (length(missed)) {
    cat("\nStems omitted (missing `.cl` in `library_dir`):\n")
    .cl_print_stems_numbered(missed)
  }

  cat("\nStems concatenated into the returned string (dependency order,",
      length(sl), "):\n", sep = "")
  .cl_print_stems_numbered(sl)

  if (!is.na(kp) && nzchar(as.character(kp)[1])) {
    cat("\nOpenCL __kernel entry point(s):\n")
    if (!file.exists(kp)) {
      cat("  (kernel file missing or unreadable)\n")
    } else {
      kk <- .cl_parse_opencl_kernel_names(as.character(kp)[1])
      if (!length(kk)) {
        cat("  (none found)\n")
      } else {
        for (tj in seq_along(kk)) {
          cat(sprintf(" %3d. %s\n", tj, kk[[tj]]))
        }
      }
    }
  }

  caps_max <- suppressWarnings(as.integer(max_provides_symbols_per_shard))[1]

  cat("\nSymbols from //@provides (library shards concatenated dependency order):\n")
  if (!length(sl) || is.na(ld) || !nzchar(as.character(ld)[1])) {
    cat("  (none)\n")
  } else {
    lib_root <- suppressWarnings(normalizePath(
      as.character(ld)[1L], winslash = "/", mustWork = FALSE))
    if (!nzchar(lib_root) || !dir.exists(lib_root)) {
      cat("  (library directory missing)\n")
    } else {
      any_sym <- FALSE
      for (j in seq_along(sl)) {
        spp <- file.path(lib_root, paste0(sl[[j]], ".cl"))
        if (!file.exists(spp))
          next
        sy <- .cl_parse_provides_symbols(spp)
        if (!length(sy))
          next
        any_sym <- TRUE
        ms <- caps_max
        if (is.na(ms) || ms < 1L)
          ms <- length(sy)
        cat(sprintf("\n%s\n", basename(spp)))
        if (.cl_is_header_style_lib_stem(sl[[j]])) {
          cat(sprintf(
            "  (%d //@provides symbols; header-style shard, list omitted)\n",
            length(sy)))
        } else {
          .cl_print_truncated_symbols(
            sy, indent = " ", max_show = ms, label = "symbol")
        }
      }
      if (!any_sym)
        cat("  (no //@provides lines found under library_dir)\n")
    }
  }

  merged <- paste(as.character(unclass(x)), collapse = "\n\n")
  nbytes_obs <- if (nzchar(merged)) {
    nchar(enc2utf8(merged), type = "bytes")
  } else {
    0L
  }
  nm <- attr(x, "nbytes_concatenated", exact = TRUE)
  nbytes_show <- if (!is.null(nm) && length(nm) && !is.na(nm[1])) {
    as.integer(nm[1])[1]
  } else {
    nbytes_obs
  }
  cat("\nConcatenated source size (bytes, UTF-8 where applicable): ",
      nbytes_show, sep = "")
  cat("\n\n(character vector: substr(), paste(), writeLines(), ...)\n", sep = "")
  invisible(x)
}


#' @rdname kernel_lib_subset_printing
#' @export
print.nmathopencl_lib_extract_df <- function(x, ...) {
  kpaths <- attr(x, "kernel_paths", exact = TRUE)
  lib_dir <- attr(x, "library_dir", exact = TRUE)
  dest_dir <- attr(x, "dest_dir", exact = TRUE)
  tag <- attr(x, "depends_tag", exact = TRUE)
  mo <- isTRUE(attr(x, "manifest_only", exact = TRUE))

  cat("<nmathopencl_lib_extract_df>\n")

  if (mo) {
    cat("Note: Planned extraction manifest only (destination did not exist; ",
        "nothing was copied).", fill = TRUE)
  }

  tc <- ifelse(!is.null(tag), as.character(tag[1L]), NA_character_)

  cat("Depends tag:",
      ifelse(!is.na(tc) && nzchar(tc), tc, "all_depends"),
      fill = TRUE)

  cat("Extracted subset rows:", nrow(x), fill = TRUE)

  if (!is.na(lib_dir) && nzchar(as.character(lib_dir))) {
    cat("Library:",
        suppressWarnings(normalizePath(as.character(lib_dir)[1],
                                       winslash = "/", mustWork = FALSE)),
        fill = TRUE)
  }
  if (!is.na(dest_dir) && nzchar(as.character(dest_dir))) {
    dn <- suppressWarnings(normalizePath(as.character(dest_dir)[1],
                                         winslash = "/", mustWork = FALSE))
    dest_lbl <- if (mo && !suppressWarnings(dir.exists(dn))) {
      "Requested destination (directory missing):"
    } else {
      "Destination:"
    }
    cat(dest_lbl, dn, fill = TRUE)
  }

  nk <- ifelse(!is.null(kpaths), length(as.character(kpaths)), 0L)
  if (!is.null(kpaths) && nk > 0L) {
    cat("Kernels:", nk, fill = TRUE)
  }

  is_idx <- x$stem %in% c("kernel_dependency_index.rds", "kernel_dependency_index.tsv")
  lib_ix <- seq_len(nrow(x))[!is_idx]

  stem_hdr <- if (mo) {
    "Library stems (.cl dependency order; manifest only):"
  } else {
    "Library stems copied (.cl dependency order):"
  }
  cat(stem_hdr, length(lib_ix), fill = TRUE)
  for (jn in seq_along(lib_ix)) {
    r <- lib_ix[jn]
    ds <- ifelse(!is.na(x$dest[r]), basename(as.character(x$dest[r])), "?")
    fl <- if (isTRUE(as.logical(x$copied[r]))) {
      "copied"
    } else if (mo) {
      "plan only"
    } else {
      "skipped(existing)"
    }
    cat(sprintf(" %3d. %-30s %-12s [%s]\n", jn, paste0(as.character(x$stem[r]), ".cl"),
                fl, ds))
  }
  if (!length(lib_ix))
    cat("  (none)\n")

  invisible(x)
}


#' @keywords internal
.cl_print_stems_numbered <- function(stems_vec) {
  if (!length(stems_vec)) {
    cat("  (none)\n")
    return(invisible(NULL))
  }
  for (jj in seq_along(stems_vec)) {
    s <- as.character(stems_vec[[jj]])
    suf <- ifelse(nzchar(s), paste0(s, ".cl"), "(empty stem)")
    cat(sprintf(" %3d. %s\n", jj, suf))
  }
  invisible(NULL)
}


#' Attach class/metadata to extraction `data.frame` (internal helper).
#'
#' @noRd
.cl_attach_extract_attrs <- function(df, kernel_paths, library_dir,
                                     dest_dir, depends_tag,
                                     manifest_only = FALSE) {
  attr(df, "kernel_paths") <- as.character(kernel_paths)
  attr(df, "library_dir") <- as.character(library_dir)[1]
  attr(df, "dest_dir") <- as.character(dest_dir)[1]
  attr(df, "depends_tag") <- as.character(depends_tag)[1]
  attr(df, "manifest_only") <- isTRUE(manifest_only)
  class(df) <- c("nmathopencl_lib_extract_df", "data.frame")
  invisible(df)
}
