#' Attach Cross-Library Dependency Tags to Kernel Files
#'
#' Given a set of user-facing kernel `.cl` files and a library directory,
#' computes the full transitive dependency list for each kernel (using the
#' library's pre-built dependency index) and writes the results back into the
#' kernel files as annotation tags.
#'
#' Cross-library analogue of \link{attach_kernel_dependency_tags}: it targets
#' kernels that depend on a library through a `@{depends_tag}` tag (entry-point stems),
#' instead of expanding `@depends` purely inside one library tree.
#'
#' Typical usage for kernels that call nmath functions:
#'
#' ```r
#' nmath_dir <- system.file(
#'   "cl", "nmath", package = "opencltools")
#' idx <- readRDS(file.path(nmath_dir, "kernel_dependency_index.rds"))
#'
#' attach_cross_library_tags(
#'   kernel_paths = list.files("inst/cl/src", "\\\\.cl$", full.names = TRUE),
#'   library_dir  = nmath_dir,
#'   depends_tag  = "depends_nmath",
#'   index        = idx
#' )
#' ```
#'
#' This writes `@all_depends_nmath_count` and `@all_depends_nmath` into each
#' kernel file that carries a `@depends_nmath` annotation.
#'
#' @param kernel_paths Character vector of paths to kernel `.cl` files.
#' @param library_dir Path to the library directory containing
#'   `kernel_dependency_index.rds` and the library `.cl` files.
#' @param depends_tag Name of the annotation tag in the kernel files that lists
#'   the direct library entry-point stems (e.g. `"depends_nmath"`).
#'   The function reads `@{depends_tag}` and writes `@all_{depends_tag}` and
#'   `@all_{depends_tag}_count`.
#' @param index Optional dependency index (\link{write_kernel_dependency_index}, load via
#'   \code{readRDS}). If \code{NULL}, reads
#'   \code{file.path(library_dir, "kernel_dependency_index.rds")} with \code{message()}.
#' @param dry_run Logical; if `TRUE`, compute tags but do not write any files.
#'
#' @return A data frame (returned invisibly) with one row per kernel file and
#'   columns:
#'   \describe{
#'     \item{`file`}{Basename of the kernel file.}
#'     \item{`direct_stems`}{Comma-separated direct entry-point stems read from
#'       `@{depends_tag}`.}
#'     \item{`all_depends_count`}{Number of library files in the full transitive
#'       closure.}
#'     \item{`all_depends`}{Comma-separated full transitive dependency list in
#'       load order.}
#'     \item{`changed`}{`TRUE` if the file was (or would be, under `dry_run`)
#'       modified.}
#'   }
#'
#' @seealso \link{attach_kernel_dependency_tags}
#' \link{write_kernel_dependency_index}
#' \link{load_library_for_kernel}
#' @example inst/examples/Ex_kernel_tagging_workflow.R
#' @export
attach_cross_library_tags <- function(kernel_paths,
                                      library_dir,
                                      depends_tag = "depends_nmath",
                                      index       = NULL,
                                      dry_run     = FALSE) {
  if (!dir.exists(library_dir)) {
    stop("`library_dir` does not exist: ", library_dir, call. = FALSE)
  }

  missing_kernels <- kernel_paths[!file.exists(kernel_paths)]
  if (length(missing_kernels) > 0L) {
    stop("The following `kernel_paths` do not exist:\n",
         paste(" ", missing_kernels, collapse = "\n"), call. = FALSE)
  }

  index <- .cl_load_index(index, library_dir)

  all_tag       <- paste0("all_", depends_tag)
  all_tag_count <- paste0("all_", depends_tag, "_count")

  rows <- lapply(kernel_paths, function(path) {
    lines <- readLines(path, warn = FALSE)

    direct_stems <- parse_port_annotation(lines, depends_tag)
    if (length(direct_stems) == 0L) {
      return(data.frame(
        file              = basename(path),
        direct_stems      = "",
        all_depends_count = 0L,
        all_depends       = "",
        changed           = FALSE,
        stringsAsFactors  = FALSE
      ))
    }

    if (length(direct_stems) == 1L && direct_stems[[1L]] == "none") {
      sorted_stems <- character()
      n            <- 0L
      updated      <- set_port_annotation(lines, all_tag_count, as.character(n))
      updated      <- set_port_annotation(updated, all_tag, sorted_stems)

      changed <- !identical(lines, updated)
      if (changed && !isTRUE(dry_run)) {
        writeLines(updated, path, useBytes = TRUE)
      }

      return(data.frame(
        file              = basename(path),
        direct_stems      = "none",
        all_depends_count = n,
        all_depends       = "",
        changed           = changed,
        stringsAsFactors  = FALSE
      ))
    }

    all_needed <- character()
    for (stem in direct_stems) {
      deps <- index[["all_depends"]][[stem]]
      if (is.null(deps)) {
        warning("Stem '", stem, "' not found in index (file: ",
                basename(path), ")", call. = FALSE)
        deps <- character()
      }
      all_needed <- union(all_needed, c(deps, stem))
    }

    known   <- all_needed[all_needed %in% names(index[["load_order"]])]
    unknown <- setdiff(all_needed, known)
    if (length(unknown) > 0L) {
      warning("Stems not found in index (skipped): ",
              paste(unknown, collapse = ", "),
              " (file: ", basename(path), ")", call. = FALSE)
    }
    sorted_stems <- known[order(index[["load_order"]][known])]
    n            <- length(sorted_stems)

    updated <- set_port_annotation(lines, all_tag_count, as.character(n))
    updated <- set_port_annotation(updated, all_tag, sorted_stems)

    changed <- !identical(lines, updated)
    if (changed && !isTRUE(dry_run)) {
      writeLines(updated, path, useBytes = TRUE)
    }

    data.frame(
      file              = basename(path),
      direct_stems      = paste(direct_stems, collapse = ", "),
      all_depends_count = n,
      all_depends       = paste(sorted_stems, collapse = ", "),
      changed           = changed,
      stringsAsFactors  = FALSE
    )
  })

  result <- do.call(rbind, rows)
  rownames(result) <- NULL

  n_changed <- sum(result$changed)
  n_skipped <- sum(result$direct_stems == "")
  msg <- sprintf(
    paste0(
      "attach_cross_library_tags: %d kernel file(s) processed",
      " (%d tagged/updated, %d skipped - no @%s annotation)%s."
    ),
    nrow(result),
    n_changed,
    n_skipped,
    depends_tag,
    if (isTRUE(dry_run)) " [dry run]" else ""
  )
  message(msg)

  invisible(result)
}
