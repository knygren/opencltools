# Internal helpers for program preload manifest I/O.

.program_preload_kind_ok <- function(kind) {
  kind <- as.character(kind)
  kind %in% c("file", "library")
}


.program_preload_validate_entries <- function(entries, context = "manifest") {
  if (!is.data.frame(entries)) {
    stop("`", context, "` must be a data.frame with columns rank, kind, rel_path.",
         call. = FALSE)
  }
  need <- c("rank", "kind", "rel_path")
  miss <- setdiff(need, names(entries))
  if (length(miss)) {
    stop("`", context, "` is missing column(s): ", paste(miss, collapse = ", "),
         call. = FALSE)
  }
  if (nrow(entries) == 0L) {
    stop("`", context, "` contains no rows.", call. = FALSE)
  }

  rank <- as.integer(entries$rank)
  kind <- trimws(as.character(entries$kind))
  rel_path <- trimws(as.character(entries$rel_path))

  if (any(is.na(rank)) || any(rank < 1L)) {
    stop("`rank` must be positive integers.", call. = FALSE)
  }
  if (any(!nzchar(rel_path))) {
    stop("`rel_path` must be non-empty.", call. = FALSE)
  }
  if (any(!.program_preload_kind_ok(kind))) {
    stop("`kind` must be 'file' or 'library'.", call. = FALSE)
  }
  if (any(duplicated(rank))) {
    stop("Duplicate `rank` values in manifest.", call. = FALSE)
  }

  ord <- order(rank)
  data.frame(
    rank = rank[ord],
    kind = kind[ord],
    rel_path = rel_path[ord],
    row.names = NULL,
    stringsAsFactors = FALSE
  )
}


.program_preload_write_paths <- function(manifest_relative_path,
                                         source_package,
                                         manifest_path = NULL) {
  rel <- as.character(manifest_relative_path)[1L]
  pkg <- as.character(source_package)[1L]
  if (!nzchar(rel)) {
    stop("`manifest_relative_path` must be non-empty.", call. = FALSE)
  }
  if (!nzchar(pkg)) {
    stop("`source_package` must be non-empty.", call. = FALSE)
  }

  if (!is.null(manifest_path) && nzchar(as.character(manifest_path)[1L])) {
    tsv_path <- as.character(manifest_path)[1L]
  } else {
    tsv_path <- system.file("cl", rel, package = pkg)
    if (!nzchar(tsv_path)) {
      stop(
        "program_preload_manifest not found via system.file: cl/", rel,
        " (package=", pkg, ")", call. = FALSE
      )
    }
  }

  rds_path <- sub("\\.tsv$", ".rds", tsv_path, ignore.case = TRUE)
  list(
    manifest_relative_path = rel,
    source_package = pkg,
    tsv_path = tsv_path,
    rds_path = rds_path
  )
}


.program_preload_resolve_paths <- function(manifest_relative_path,
                                           source_package,
                                           manifest_path = NULL) {
  rel <- as.character(manifest_relative_path)[1L]
  pkg <- as.character(source_package)[1L]
  if (!nzchar(rel)) {
    stop("`manifest_relative_path` must be non-empty.", call. = FALSE)
  }
  if (!nzchar(pkg)) {
    stop("`source_package` must be non-empty.", call. = FALSE)
  }

  if (!is.null(manifest_path) && nzchar(as.character(manifest_path)[1L])) {
    tsv_path <- normalizePath(manifest_path, winslash = "/", mustWork = FALSE)
    if (!file.exists(tsv_path)) {
      stop("`manifest_path` does not exist: ", tsv_path, call. = FALSE)
    }
  } else {
    tsv_path <- system.file("cl", rel, package = pkg)
    if (!nzchar(tsv_path)) {
      stop(
        "program_preload_manifest not found via system.file: cl/", rel,
        " (package=", pkg, ")", call. = FALSE
      )
    }
  }

  rds_path <- sub("\\.tsv$", ".rds", tsv_path, ignore.case = TRUE)
  list(
    manifest_relative_path = rel,
    source_package = pkg,
    tsv_path = tsv_path,
    rds_path = rds_path
  )
}


.program_preload_object <- function(entries, paths) {
  list(
    version = 1L,
    generated_at = Sys.time(),
    source_package = paths$source_package,
    manifest_relative_path = paths$manifest_relative_path,
    manifest_path = paths$tsv_path,
    entries = entries
  )
}


.program_preload_from_entries <- function(entries,
                                          source_package,
                                          verbose = FALSE) {
  entries <- .program_preload_validate_entries(entries, "manifest")
  pieces <- vector("list", nrow(entries))
  for (i in seq_len(nrow(entries))) {
    row <- entries[i, , drop = FALSE]
    pieces[[i]] <- if (row$kind[[1L]] == "file") {
      load_kernel_source(row$rel_path[[1L]], source_package)
    } else {
      load_kernel_library(row$rel_path[[1L]], source_package, verbose)
    }
    if (!nzchar(pieces[[i]])) {
      stop(
        "Empty preload source for rank ", row$rank[[1L]],
        " (kind=", row$kind[[1L]], ", rel_path=", row$rel_path[[1L]],
        ", package=", source_package, ")", call. = FALSE
      )
    }
  }
  paste(unlist(pieces), collapse = "\n")
}


.program_preload_result <- function(text,
                                    paths,
                                    entries = NULL,
                                    verbose = FALSE) {
  nbytes <- if (nzchar(text)) {
    nchar(enc2utf8(text), type = "bytes")
  } else {
    0L
  }
  structure(
    text,
    class = c("opencltools_program_preload", "character"),
    source_package = paths$source_package,
    manifest_relative_path = paths$manifest_relative_path,
    manifest_path = paths$tsv_path,
    n_entries = if (is.null(entries)) NA_integer_ else nrow(entries),
    nbytes_concatenated = as.integer(nbytes)[1L],
    verbose = isTRUE(verbose)
  )
}
