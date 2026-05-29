#' Build and save a kernel dependency index
#'
#' Writes two companion index files next to the `.cl` files in the kernel
#' library directory:
#'
#' - RDS helper shard for loaders such as \link{load_library_for_kernel}.\cr
#' - Tab-separated (\code{.tsv}) stem map for C++ (rows \verb{stem<TAB>dependencies}, pre-sorted).\cr
#'
#' Both files encode the same information and are always written together so
#' they remain in sync.
#'
#' @param library_dir Library root with annotated \code{.cl} files.\cr
#' When \code{tags} is supplied, must agree with \code{tags$library_dir}.
#' @param tags Optional attachment result from \link{attach_kernel_dependency_tags}.\cr
#'   Must have \code{ok = TRUE} when reused to skip resorting.
#' @param output_path Path for the RDS file. Defaults to
#'   `file.path(<library_dir>, "kernel_dependency_index.rds")`. The \code{.tsv} file is
#'   always written to the same directory with the `.tsv` extension.
#' @param write If `FALSE`, builds the index object and returns it without
#'   writing either file.
#' @param verbose If `TRUE`, emits short messages with the output paths.
#'
#' @return Invisibly, the index `list()` (`version` schema):
#'   - `version`: integer schema version.
#'   - `generated_at`: timestamp from [Sys.time()].
#'   - `library_dir`, `library_name`: resolved library path / basename.
#'   - `stems_ordered`: stems in global load order.
#'   - `load_order`: named integer vector `stem -> rank`.
#'   - `depends`: named list `stem -> character()` (direct `@depends`).
#'   - `all_depends`: named list `stem -> character()` (transitive dependencies, order
#'     consistent with global load order).
#'   - `n_files`: file count.
#'
#' @seealso \link{load_library_for_kernel}
#' @seealso \link{extract_library_subset}
#' @family OpenCL kernel library subsets
#'
#' @example inst/examples/Ex_write_kernel_dependency_index.R
#'
#' @export
write_kernel_dependency_index <- function(
    library_dir = NULL,
    tags = NULL,
    output_path = NULL,
    write = TRUE,
    verbose = FALSE) {
  if (is.null(tags)) {
    if (is.null(library_dir) || !nzchar(as.character(library_dir)[1L])) {
      stop("`library_dir` is required when `tags` is NULL.", call. = FALSE)
    }
    if (!dir.exists(library_dir)) {
      stop("`library_dir` does not exist: ", library_dir, call. = FALSE)
    }
    tags <- attach_kernel_dependency_tags(library_dir, dry_run = TRUE)
    if (!isTRUE(tags$ok)) {
      stop(tags$message, call. = FALSE)
    }
  } else {
    if (!isTRUE(tags$ok)) {
      stop(
        "`tags` has ok=FALSE; resolve dependency sorting before building index.",
        call. = FALSE
      )
    }
    lt <- tags$library_dir
    if (is.null(lt) || !nzchar(as.character(lt)[1L]) || !dir.exists(lt)) {
      stop("`tags$library_dir` must be a valid existing directory.", call. = FALSE)
    }
    if (!is.null(library_dir) && nzchar(as.character(library_dir)[1L])) {
      a <- normalizePath(library_dir, winslash = "/", mustWork = FALSE)
      b <- normalizePath(lt, winslash = "/", mustWork = FALSE)
      if (!identical(tolower(a), tolower(b))) {
        stop(
          "`library_dir` does not match `tags$library_dir`.",
          call. = FALSE
        )
      }
    }
  }

  lib_dir <- normalizePath(tags$library_dir, winslash = "/", mustWork = TRUE)
  idx <- kernel_dependency_index_list_from_tags(tags, lib_dir_resolved = lib_dir)

  out_default <- file.path(lib_dir, "kernel_dependency_index.rds")
  out <- if (is.null(output_path)) out_default else output_path

  out_dir <- normalizePath(dirname(out), winslash = "/", mustWork = TRUE)
  out_final <- file.path(out_dir, basename(out))

  if (!is.logical(write) || length(write) != 1L || is.na(write)) {
    stop("`write` must be a single logical value.", call. = FALSE)
  }
  if (isTRUE(write)) {
    # --- RDS (for R) ---
    saveRDS(idx, file = out_final, compress = TRUE)
    if (isTRUE(verbose)) {
      message("Wrote kernel dependency index (rds): ", out_final)
    }

    # --- TSV (for C++) ---
    # Format: header row + one row per stem in load order.
    # Columns: stem <TAB> all_depends (comma-separated, load-order-correct).
    tsv_final <- sub("\\.rds$", ".tsv", out_final, ignore.case = TRUE)
    tsv_lines <- c(
      paste("stem", "all_depends", sep = "\t"),
      vapply(idx$stems_ordered, function(stem) {
        deps <- idx$all_depends[[stem]]
        paste(stem, paste(deps, collapse = ", "), sep = "\t")
      }, character(1L))
    )
    writeLines(tsv_lines, con = tsv_final, useBytes = FALSE)
    if (isTRUE(verbose)) {
      message("Wrote kernel dependency index (tsv): ", tsv_final)
    }
  }
  invisible(idx)
}


kernel_dependency_index_list_from_tags <- function(tags, lib_dir_resolved = NULL) {
  td <- tags$tags
  if (!is.data.frame(td) || nrow(td) == 0L) {
    stop("`tags$tags` must be a non-empty data frame.", call. = FALSE)
  }

  abs_lib <- if (!is.null(lib_dir_resolved)) {
    lib_dir_resolved
  } else {
    normalizePath(tags$library_dir, winslash = "/", mustWork = TRUE)
  }

  stems_ordered <- td$file[order(td$load_order, td$file)]
  load_order_named <- stats::setNames(as.integer(td$load_order), td$file)

  n <- nrow(td)
  depends_list <- vector("list", n)
  names(depends_list) <- td$file
  all_depends_list <- vector("list", n)
  names(all_depends_list) <- td$file

  for (i in seq_len(n)) {
    stem <- td$file[[i]]
    depends_list[[stem]] <- split_kernel_depends_csv_char(td$depends[[i]])
    all_depends_list[[stem]] <- split_kernel_depends_csv_char(td$all_depends[[i]])
  }

  list(
    version = 1L,
    generated_at = Sys.time(),
    library_dir = abs_lib,
    library_name = basename(abs_lib),
    stems_ordered = stems_ordered,
    load_order = load_order_named,
    depends = depends_list,
    all_depends = all_depends_list,
    n_files = n
  )
}


split_kernel_depends_csv_char <- function(x) {
  if (length(x) != 1L) {
    x <- as.character(x)
    x <- x[[1]]
  }
  if (is.na(x) || !nzchar(x)) {
    return(character())
  }
  parts <- trimws(strsplit(as.character(x), ",", fixed = TRUE)[[1]], which = "both")
  parts[nzchar(parts)]
}
