#' Attach Library Call Tags to Kernel Files
#'
#' Scans kernel `.cl` source files for calls to functions provided by a
#' pre-annotated library, then writes the discovered dependencies as annotation
#' tags directly into the kernel files.
#'
#' For a library such as \pkg{nmathopencl}, each `.cl` shard carries a `@provides`
#' annotation listing the symbols it defines.  This function builds a
#' **provides map** from those annotations (symbol \eqn{\to} shard stem), scans
#' each kernel's source (with comments and string literals stripped) for
#' matching function calls, and writes four annotation tags at the top of each
#' kernel file:
#'
#' \describe{
#'   \item{`@library_deps: <library_tag>`}{Library name (written if absent).}
#'   \item{`@calls_<library_tag>: sym1, sym2`}{Symbols from the library actually
#'     called in this kernel.}
#'   \item{`@depends_<library_tag>: stem1, stem2`}{Library shard stems that
#'     define the called symbols.}
#'   \item{`@calls_opencl_builtin: sym | (none)`}{Detected OpenCL work-item and
#'     synchronization \code{builtins} (standard math \code{builtins} excluded).}
#' }
#'
#' **Two-step tagging workflow:**
#'
#' ```r
#' # Step 1 — this function: infer direct library calls from source
#' nmath_dir <- system.file("cl/nmath_small", package = "opencltools")
#' attach_kernel_call_tags(
#'   kernel_paths = system.file("cl/src/dnorm_kernel.cl", package = "opencltools"),
#'   library_dir  = nmath_dir,
#'   library_tag  = "nmath"
#' )
#'
#' # Step 2 — expand to full transitive closure
#' attach_cross_library_tags(
#'   kernel_paths = system.file("cl/src/dnorm_kernel.cl", package = "opencltools"),
#'   library_dir  = nmath_dir,
#'   depends_tag  = "depends_nmath"
#' )
#' ```
#'
#' @param kernel_paths Character vector of paths to kernel `.cl` files.
#' @param library_dir Path to the pre-annotated library directory.  Each
#'   `.cl` file in this directory must carry a `@provides` annotation listing
#'   the symbols it exports.
#' @param library_tag String tag suffix used for annotation names, e.g.
#'   `"nmath"`.  Must not contain spaces or regex special characters.
#' @param overwrite_existing Logical; if `FALSE` (default), skip files that
#'   already carry a `@calls_<library_tag>` annotation.  Set to `TRUE` to
#'   re-scan and overwrite (also clears any existing `@all_depends_<tag>` so
#'   \link{attach_cross_library_tags} re-computes it cleanly).
#' @param dry_run Logical; if `TRUE`, compute tags but do not write any files.
#'
#' @return A data frame (returned invisibly) with one row per kernel file and
#'   columns:
#'   \describe{
#'     \item{`file`}{Basename of the kernel file.}
#'     \item{`calls`}{Comma-separated library symbols detected in source.}
#'     \item{`depends`}{Comma-separated shard stems for the detected symbols.}
#'     \item{`opencl_builtins`}{Comma-separated OpenCL builtins detected, or
#'       empty string if none.}
#'     \item{`changed`}{`TRUE` if the file was (or would be) modified.
#'       `NA` means the file was skipped (already tagged).}
#'   }
#'
#' @seealso \link{attach_cross_library_tags}, \link{attach_kernel_dependency_tags}
#' @example inst/examples/Ex_kernel_tagging_workflow.R
#' @export
attach_kernel_call_tags <- function(kernel_paths,
                                    library_dir,
                                    library_tag,
                                    overwrite_existing = FALSE,
                                    dry_run            = FALSE) {
  if (!dir.exists(library_dir))
    stop("`library_dir` does not exist: ", library_dir, call. = FALSE)

  missing_kp <- kernel_paths[!file.exists(kernel_paths)]
  if (length(missing_kp) > 0L)
    stop("The following `kernel_paths` do not exist:\n",
         paste(" ", missing_kp, collapse = "\n"), call. = FALSE)

  provides_map <- .build_library_provides_map(library_dir)
  if (length(provides_map) == 0L)
    stop("No @provides annotations found in `library_dir`: ", library_dir,
         call. = FALSE)

  calls_tag   <- paste0("calls_",   library_tag)
  depends_tag <- paste0("depends_", library_tag)

  rows <- lapply(kernel_paths, function(path) {
    lines <- readLines(path, warn = FALSE)

    if (!overwrite_existing &&
        length(parse_port_annotation(lines, calls_tag)) > 0L) {
      return(data.frame(
        file           = basename(path),
        calls          = NA_character_,
        depends        = NA_character_,
        opencl_builtins = NA_character_,
        changed        = NA,
        stringsAsFactors = FALSE
      ))
    }

    # Strip comments and string literals, drop annotation (//) lines
    clean      <- strip_c_strings(strip_c_comments(lines))
    code_lines <- clean[!grepl("^\\s*//", clean, perl = TRUE)]
    code_text  <- paste(code_lines, collapse = "\n")

    # Detect calls to library symbols
    lib_calls <- sort(Filter(
      function(sym)
        grepl(paste0(c_identifier_pattern(sym), "\\s*\\("),
              code_text, perl = TRUE),
      names(provides_map)
    ))
    lib_stems <- if (length(lib_calls) > 0L)
      sort(unique(unname(provides_map[lib_calls])))
    else
      character()

    # Detect OpenCL non-standard builtins
    ocl_builtins <- .detect_opencl_nonstd_builtins(code_text)

    updated <- .insert_kernel_call_annotations(
      lines       = lines,
      library_tag = library_tag,
      lib_calls   = lib_calls,
      lib_stems   = lib_stems,
      ocl_builtins = ocl_builtins
    )

    changed <- !identical(lines, updated)
    if (changed && !isTRUE(dry_run))
      writeLines(updated, path, useBytes = TRUE)

    data.frame(
      file            = basename(path),
      calls           = if (length(lib_calls) > 0L) paste(lib_calls, collapse = ", ") else "",
      depends         = if (length(lib_stems) > 0L) paste(lib_stems, collapse = ", ") else "",
      opencl_builtins = if (length(ocl_builtins) > 0L) paste(ocl_builtins, collapse = ", ") else "",
      changed         = changed,
      stringsAsFactors = FALSE
    )
  })

  result <- do.call(rbind, rows)
  rownames(result) <- NULL

  n_changed <- sum(result$changed %in% TRUE)
  n_skipped <- sum(is.na(result$changed))
  message(sprintf(
    "attach_kernel_call_tags: %d file(s) processed (%d updated, %d skipped - already tagged)%s.",
    nrow(result), n_changed, n_skipped,
    if (isTRUE(dry_run)) " [dry run]" else ""
  ))

  invisible(result)
}


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Build a named character vector: name = library symbol, value = shard stem.
# Reads every .cl file in library_dir and collects @provides annotations.
.build_library_provides_map <- function(library_dir) {
  cl_files <- list.files(library_dir, pattern = "\\.cl$",
                         full.names = TRUE, recursive = FALSE)
  if (length(cl_files) == 0L)
    return(stats::setNames(character(), character()))

  rows <- lapply(cl_files, function(f) {
    stem  <- tools::file_path_sans_ext(basename(f))
    syms  <- parse_port_annotation(readLines(f, warn = FALSE), "provides")
    if (length(syms) == 0L) return(NULL)
    data.frame(symbol = syms, stem = stem, stringsAsFactors = FALSE)
  })
  rows <- do.call(rbind, Filter(Negate(is.null), rows))
  if (is.null(rows) || nrow(rows) == 0L)
    return(stats::setNames(character(), character()))

  stats::setNames(rows$stem, rows$symbol)
}


# OpenCL built-in functions worth flagging with @calls_opencl_builtin.
#
# Two categories are included:
#
# 1. "Special math" functions: in the OpenCL C spec but NOT universally
#    hardware-accelerated or available on all GPU implementations.  When a
#    kernel calls these directly it is bypassing any nmath-ported equivalent
#    and relying on the OpenCL runtime's own implementation.  Examples:
#    lgamma, tgamma, erf, erfc, j0/j1/y0/y1 (Bessel), hypot, remainder.
#    Basic functions like exp, log, sqrt are intentionally excluded because
#    they are part of the mandatory OpenCL C math subset and universally
#    available.
#
# 2. Work-item, synchronization, atomic, and vector I/O functions: these
#    have no C standard library equivalent and explicitly signal an OpenCL
#    execution-model dependency.
.opencl_nonstd_builtins <- function() {
  c(
    # --- Special math (non-universally available or precision-sensitive) ---
    "lgamma", "lgammaf",
    "tgamma", "tgammaf",
    "erf",    "erff",
    "erfc",   "erfcf",
    "hypot",  "hypotf",
    "remainder", "remainderf",
    "remquo",
    "j0", "j1", "y0", "y1",          # POSIX Bessel (not in OpenCL C standard)
    # --- Work-item ---
    "get_global_id", "get_local_id", "get_group_id",
    "get_global_size", "get_local_size", "get_num_groups",
    "get_global_offset", "get_work_dim",
    # --- Synchronisation ---
    "barrier", "mem_fence", "read_mem_fence", "write_mem_fence",
    "work_group_barrier",
    # --- Legacy atomic (cl_khr_global_int32_base_atomics etc.) ---
    "atom_add", "atom_sub", "atom_or", "atom_and",
    "atom_xor", "atom_min", "atom_max", "atom_cmpxchg",
    # --- OpenCL 2.0 atomic ---
    "atomic_store", "atomic_load", "atomic_exchange",
    "atomic_compare_exchange_strong", "atomic_compare_exchange_weak",
    "atomic_fetch_add", "atomic_fetch_sub",
    "atomic_add", "atomic_sub", "atomic_or", "atomic_and",
    "atomic_xor", "atomic_min", "atomic_max",
    # --- Vector loads / stores ---
    "vload2",  "vload4",  "vload8",  "vload16",
    "vstore2", "vstore4", "vstore8", "vstore16",
    # --- Async copy ---
    "async_work_group_copy", "async_work_group_strided_copy",
    "wait_group_events",
    # --- printf extension (cl_khr_printf) ---
    "printf"
  )
}


.detect_opencl_nonstd_builtins <- function(code_text) {
  candidates <- .opencl_nonstd_builtins()
  found <- Filter(
    function(sym)
      grepl(paste0(c_identifier_pattern(sym), "\\s*\\("),
            code_text, perl = TRUE),
    candidates
  )
  sort(unique(found))
}


# Rewrite the managed annotation block in a kernel file.
# Removes any existing @library_deps, @calls_<tag>, @depends_<tag>,
# @calls_opencl_builtin, @all_depends_<tag>, @all_depends_<tag>_count lines,
# then prepends a fresh annotation block before the first #pragma.
.insert_kernel_call_annotations <- function(lines, library_tag,
                                            lib_calls, lib_stems,
                                            ocl_builtins) {
  calls_tag   <- paste0("calls_",   library_tag)
  depends_tag <- paste0("depends_", library_tag)
  all_tag     <- paste0("all_",     depends_tag)
  all_tag_cnt <- paste0(all_tag,    "_count")

  managed <- c("library_deps", calls_tag, depends_tag,
               "calls_opencl_builtin", all_tag, all_tag_cnt)
  for (tg in managed) {
    pat   <- paste0("^\\s*//\\s*@", escape_regex(tg), "(?=\\s|:)")
    lines <- lines[!grepl(pat, lines, perl = TRUE)]
  }

  # Drop any leading blank lines introduced by the removals
  while (length(lines) > 0L && !nzchar(trimws(lines[[1L]])))
    lines <- lines[-1L]

  calls_val <- if (length(lib_calls) > 0L)
    paste(lib_calls, collapse = ", ") else "(none)"
  stems_val <- if (length(lib_stems) > 0L)
    paste(lib_stems, collapse = ", ") else "(none)"
  ocl_val   <- if (length(ocl_builtins) > 0L)
    paste(ocl_builtins, collapse = ", ") else "(none)"

  ann_block <- c(
    paste0("// @library_deps: ",         library_tag),
    paste0("// @", calls_tag,   ": ",    calls_val),
    paste0("// @", depends_tag, ": ",    stems_val),
    paste0("// @calls_opencl_builtin: ", ocl_val),
    ""
  )

  pragma_idx <- grep("^\\s*#pragma\\b", lines, perl = TRUE)
  insert_at  <- if (length(pragma_idx) > 0L) pragma_idx[[1L]] - 1L else 0L

  append(lines, ann_block, after = insert_at)
}
