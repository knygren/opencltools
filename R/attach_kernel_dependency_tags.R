#' Attach Dependency Tags to a Dependency-Ordered Kernel Library
#'
#' Compute and attach derived tags to each `.cl` file in a library:
#' `@load_order`, `@all_depends`, and `@all_depends_count`.
#'
#' Tags are written only if dependency sorting fully succeeds. If unresolved
#' files remain, no files are modified and a cycle report is returned so source
#' refactoring can be prioritized.
#'
#' @param library_dir Directory containing `.cl` files with `@depends` tags.
#' @param dry_run Logical; if `TRUE`, compute tags and reports without writing.
#'
#' @return A list with:
#' \describe{
#'   \item{ok}{Logical success flag.}
#'   \item{message}{Human-readable summary.}
#'   \item{sorted}{Sorted records data frame.}
#'   \item{unresolved}{Unresolved records data frame (empty on success).}
#'   \item{cycles}{Cycle report data frame (empty on success).}
#'   \item{tags}{Per-file tag data frame with `source_origin`, `source_type`,
#'     `includes`, `depends`, `provides`, `load_order`, `all_depends`, and
#'     `all_depends_count` (present on success).}
#'   \item{header_functions}{Functions declared in header files without
#'     `attribute_hidden`, including declaring header, inferred definition file,
#'     declaration signature, `define_alias`, and `all_depends` for the
#'     definition file.}
#' }
#' An S3 class \code{"opencl_dependency_tags"} is attached for use with
#' \code{\link[=print.opencl_dependency_tags]{print()}}.
#'
#' @example inst/examples/Ex_attach_kernel_dependency_tags.R
#' @export
attach_kernel_dependency_tags <- function(library_dir, dry_run = FALSE) {
  if (!dir.exists(library_dir)) {
    stop("`library_dir` does not exist: ", library_dir, call. = FALSE)
  }

  records <- read_kernel_sort_records(library_dir)
  state <- dependency_sort_prefix(records)

  sorted_report <- sorted_records_to_data_frame(state$sorted)
  unresolved_report <- unresolved_records_to_data_frame(state$unresolved)

  if (length(state$unresolved) > 0) {
    cycle_report <- cycle_report_from_unresolved(state$unresolved)
    msg <- paste0(
      "Dependency sort did not resolve (",
      nrow(unresolved_report),
      " unresolved files; ",
      nrow(cycle_report),
      " cycle paths). Refactor source .c files to break cycles, then regenerate and retry tag attachment."
    )
    return(structure(list(
      ok = FALSE,
      message = msg,
      library_dir = library_dir,
      sorted = sorted_report,
      unresolved = unresolved_report,
      cycles = cycle_report,
      tags = data.frame(),
      header_functions = data.frame()
    ), class = c("opencl_dependency_tags", "list")))
  }

  sorted_names <- names(state$sorted)
  order_index <- stats::setNames(seq_along(sorted_names), sorted_names)
  tags <- lapply(sorted_names, function(file) {
    all_depends <- transitive_depends_for_file(file, records)
    all_depends <- sort_by_order(all_depends, order_index)
    all_depends_count <- length(all_depends)

    path <- state$sorted[[file]]$path
    lines <- readLines(path, warn = FALSE)
    updated <- set_port_annotation(lines, "load_order", as.character(order_index[[file]]))
    updated <- set_port_annotation(updated, "all_depends", all_depends)
    updated <- set_port_annotation(
      updated,
      "all_depends_count",
      as.character(all_depends_count)
    )
    changed <- !identical(lines, updated)
    if (changed && !isTRUE(dry_run)) {
      writeLines(updated, path, useBytes = TRUE)
    }

    list(
      file = file,
      source_origin = state$sorted[[file]]$source_origin %||% "",
      source_type = state$sorted[[file]]$source_type %||% "",
      includes = paste(
        if (is.null(state$sorted[[file]]$includes)) character() else state$sorted[[file]]$includes,
        collapse = ", "
      ),
      depends = paste(
        if (is.null(state$sorted[[file]]$depends)) character() else state$sorted[[file]]$depends,
        collapse = ", "
      ),
      provides = paste(
        if (is.null(state$sorted[[file]]$provides)) character() else state$sorted[[file]]$provides,
        collapse = ", "
      ),
      load_order = as.integer(order_index[[file]]),
      all_depends = paste(all_depends, collapse = ", "),
      all_depends_count = as.integer(all_depends_count),
      changed = changed
    )
  })

  tags_df <- data.frame(
    file = vapply(tags, `[[`, character(1), "file"),
    source_origin = vapply(tags, `[[`, character(1), "source_origin"),
    source_type = vapply(tags, `[[`, character(1), "source_type"),
    includes = vapply(tags, `[[`, character(1), "includes"),
    depends = vapply(tags, `[[`, character(1), "depends"),
    provides = vapply(tags, `[[`, character(1), "provides"),
    load_order = vapply(tags, `[[`, integer(1), "load_order"),
    all_depends = vapply(tags, `[[`, character(1), "all_depends"),
    all_depends_count = vapply(tags, `[[`, integer(1), "all_depends_count"),
    changed = vapply(tags, `[[`, logical(1), "changed"),
    stringsAsFactors = FALSE
  )
  header_functions_df <- header_declared_non_hidden_functions(
    records = records,
    tags_df = tags_df
  )

  msg <- paste0(
    "Dependency sort resolved for ", nrow(sorted_report),
    " files. Attached @load_order and @all_depends tags",
    if (isTRUE(dry_run)) " (dry run)." else "."
  )
  structure(list(
    ok = TRUE,
    message = msg,
    library_dir = library_dir,
    sorted = sorted_report,
    unresolved = data.frame(),
    cycles = data.frame(),
    tags = tags_df,
    header_functions = header_functions_df
  ), class = c("opencl_dependency_tags", "list"))
}


#' Print Dependency Tag Attachment Results
#'
#' Print output from \link{attach_kernel_dependency_tags}.
#'
#' @param x Result of \link{attach_kernel_dependency_tags}.
#' @param max_rows Maximum printed rows per table section.
#' @param ... Forwarded to \code{print.data.frame}.
#'
#' @return Called for side effects. Prints tag tables (and optional
#'   cycle/unresolved reports) from \code{\link{attach_kernel_dependency_tags}}.
#'   Invisibly returns \code{x}, a \code{list} with S3 class
#'   \code{"opencl_dependency_tags"} (same structure as
#'   \code{attach_kernel_dependency_tags()}: \code{ok}, \code{message},
#'   \code{sorted}, \code{unresolved}, \code{cycles}, \code{tags}, \ldots).
#'
#' @example inst/examples/Ex_attach_kernel_dependency_tags.R
#' @export
print.opencl_dependency_tags <- function(x, max_rows = 50, ...) {
  if (isTRUE(x$ok)) {
    tags <- x$tags
    if (nrow(tags) == 0) {
      cat("No tag rows to print.\n")
      return(invisible(x))
    }
    tags <- tags[order(tags$load_order), , drop = FALSE]
    n_show <- min(nrow(tags), as.integer(max_rows))

    cat("<OpenCL dependency tags>\n")
    if (!is.null(x$library_dir) && nzchar(x$library_dir)) {
      cat("Source: ", x$library_dir, "\n", sep = "")
    }

    file_paths <- if (!is.null(x$library_dir) && nzchar(x$library_dir)) {
      file.path(x$library_dir, paste0(tags$file, ".cl"))
    } else {
      rep(NA_character_, nrow(tags))
    }
    file_stats <- lapply(file_paths, function(path) {
      if (is.na(path) || !file.exists(path)) {
        return(list(n_lines = NA_integer_, n_chars = NA_integer_))
      }
      lines <- readLines(path, warn = FALSE)
      list(
        n_lines = length(lines),
        n_chars = nchar(paste(lines, collapse = "\n"), type = "chars")
      )
    })
    total_lines <- sum(vapply(file_stats, `[[`, integer(1), "n_lines"),
                      na.rm = TRUE)
    total_chars <- sum(vapply(file_stats, `[[`, integer(1), "n_chars"),
                      na.rm = TRUE)
    cat("Lines: ", total_lines, "\n", sep = "")
    cat("Characters: ", total_chars, "\n", sep = "")
    cat("Files: ", nrow(tags), "\n", sep = "")
    cat("\nIncluded files:\n")

    for (i in seq_len(n_show)) {
      source_type <- tags$source_type[[i]]
      if (!nzchar(source_type)) {
        source_type <- "unknown"
      }
      includes <- format_tag_csv_values(tags$includes[[i]], max = 8, empty = "none")
      provides <- format_tag_csv_values(tags$provides[[i]], max = 8,
                                        empty = "none listed")
      n_lines <- file_stats[[i]]$n_lines
      n_chars <- file_stats[[i]]$n_chars
      if (is.na(n_lines) || is.na(n_chars)) {
        cat(sprintf(
          "%3d. %s [%s] (includes: %s; provides: %s)\n",
          i, tags$file[[i]], source_type, includes, provides
        ))
      } else {
        cat(sprintf(
          "%3d. %s [%s] (%d lines, %d chars; includes: %s; provides: %s)\n",
          i, tags$file[[i]], source_type, n_lines, n_chars, includes, provides
        ))
      }
    }
    if (n_show < nrow(tags)) {
      cat("... <", nrow(tags) - n_show, " more rows>\n", sep = "")
    }
    return(invisible(x))
  }

  cat("Dependency Tag Attachment\n")
  cat("Status: FAILED\n")
  if (!is.null(x$message) && nzchar(x$message)) {
    cat(x$message, "\n", sep = "")
  }
  cat("\n")

  if (nrow(x$unresolved) > 0) {
    cat("Unresolved files: ", nrow(x$unresolved), "\n", sep = "")
    n_show_unresolved <- min(nrow(x$unresolved), as.integer(max_rows))
    unresolved_cols <- intersect(
      c("file", "remaining_depends_count", "missing_depends"),
      names(x$unresolved)
    )
    print.data.frame(
      x$unresolved[seq_len(n_show_unresolved), unresolved_cols, drop = FALSE],
      row.names = FALSE, ...
    )
    if (n_show_unresolved < nrow(x$unresolved)) {
      cat("... <", nrow(x$unresolved) - n_show_unresolved,
          " more unresolved rows>\n", sep = "")
    }
    cat("\n")
  }

  if (nrow(x$cycles) > 0) {
    cat("Cycle paths: ", nrow(x$cycles), "\n", sep = "")
    n_show_cycles <- min(nrow(x$cycles), as.integer(max_rows))
    print.data.frame(x$cycles[seq_len(n_show_cycles), , drop = FALSE],
                     row.names = FALSE, ...)
    if (n_show_cycles < nrow(x$cycles)) {
      cat("... <", nrow(x$cycles) - n_show_cycles,
          " more cycle rows>\n", sep = "")
    }
  }

  invisible(x)
}


format_tag_csv_values <- function(value, max = 8, empty = "none") {
  if (length(value) == 0 || is.na(value) || !nzchar(value)) {
    return(empty)
  }
  values <- trimws(unlist(strsplit(value, ",", fixed = TRUE)))
  values <- values[nzchar(values)]
  if (length(values) == 0) {
    return(empty)
  }
  shown <- values[seq_len(min(length(values), max))]
  label <- paste(shown, collapse = ", ")
  if (length(values) > max) {
    label <- paste0(label, ", ... [", length(values), " total]")
  }
  label
}


header_declared_non_hidden_functions <- function(records, tags_df) {
  header_records <- records[vapply(records, function(x) {
    x$source_type %in% c("h", "hpp")
  }, logical(1))]
  if (length(header_records) == 0) {
    return(data.frame())
  }

  declaration_rows <- lapply(header_records, function(record) {
    lines <- readLines(record$path, warn = FALSE)
    decl <- extract_non_hidden_function_declarations(
      lines = lines,
      header = record$file
    )
    if (nrow(decl) == 0) {
      return(decl)
    }
    define_map <- extract_define_alias_map(lines)
    decl$define_alias <- unname(define_map[decl$function_name])
    decl$define_alias[is.na(decl$define_alias)] <- ""
    decl
  })
  declaration_rows <- declaration_rows[vapply(declaration_rows, nrow, integer(1)) > 0]
  if (length(declaration_rows) == 0) {
    return(data.frame())
  }
  declarations <- do.call(rbind, declaration_rows)

  definition_index <- build_function_definition_index(records)
  hidden_definition_names <- build_hidden_definition_name_set(records)
  out <- declarations
  keep <- !vapply(seq_len(nrow(out)), function(i) {
    candidates <- definition_name_candidates(
      function_name = out$function_name[[i]],
      define_alias = out$define_alias[[i]]
    )
    any(candidates %in% hidden_definition_names)
  }, logical(1))
  out <- out[keep, , drop = FALSE]
  if (nrow(out) == 0) {
    return(data.frame())
  }
  out$file_defined <- vapply(seq_len(nrow(out)), function(i) {
    resolve_definition_file(
      function_name = out$function_name[[i]],
      define_alias = out$define_alias[[i]],
      definition_index = definition_index
    )
  }, character(1))

  all_depends_index <- stats::setNames(tags_df$all_depends, tags_df$file)
  out$all_depends <- vapply(out$file_defined, function(def_file) {
    if (is.na(def_file) || !nzchar(def_file) || grepl(",", def_file, fixed = TRUE)) {
      return("")
    }
    all_depends_index[[def_file]] %||% ""
  }, character(1))

  out <- out[, c("header", "file_defined", "function_name",
                 "function_signature", "define_alias", "all_depends"), drop = FALSE]
  rownames(out) <- NULL
  out[order(out$header, out$function_name), , drop = FALSE]
}


extract_non_hidden_function_declarations <- function(lines, header) {
  statements <- collect_c_statements_from_lines(lines)
  if (length(statements) == 0) {
    return(data.frame())
  }

  rows <- lapply(statements, function(stmt) {
    if (!nzchar(stmt)) return(NULL)
    if (grepl("^\\s*typedef\\b", stmt)) return(NULL)
    if (!grepl("(", stmt, fixed = TRUE) || !grepl("\\)$", stmt)) return(NULL)
    if (grepl("\\battribute_hidden\\b", stmt)) return(NULL)
    if (grepl("^\\s*(else|return|if|for|while|switch)\\b", stmt)) return(NULL)
    if (grepl("\"", stmt, fixed = TRUE)) return(NULL)
    if (grepl("=", stmt, fixed = TRUE)) return(NULL)

    name_match <- regexec("([A-Za-z_][A-Za-z0-9_]*)\\s*\\([^;{}]*\\)$",
                          stmt, perl = TRUE)
    captured <- regmatches(stmt, name_match)[[1]]
    if (length(captured) < 2) return(NULL)
    fun <- captured[[2]]
    if (fun %in% c("if", "for", "while", "switch", "return", "define")) return(NULL)

    data.frame(
      header = header,
      function_name = fun,
      function_signature = paste0(stmt, ";"),
      stringsAsFactors = FALSE
    )
  })

  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (length(rows) == 0) {
    return(data.frame())
  }
  unique(do.call(rbind, rows))
}


collect_c_statements_from_lines <- function(lines) {
  stripped <- strip_c_comments(lines)
  statements <- character()
  buffer <- ""
  in_macro <- FALSE

  flush_statement_parts <- function(text) {
    parts <- unlist(strsplit(text, ";", fixed = TRUE), use.names = FALSE)
    if (length(parts) == 0) return(character())
    parts <- trimws(gsub("\\s+", " ", parts))
    parts[nzchar(parts)]
  }

  for (line in stripped) {
    line_trim <- trimws(line)
    if (!nzchar(line_trim)) next

    if (in_macro) {
      if (!grepl("\\\\$", line_trim)) {
        in_macro <- FALSE
      }
      next
    }

    if (grepl("^#", line_trim)) {
      in_macro <- grepl("\\\\$", line_trim)
      next
    }

    if (!nzchar(buffer)) {
      buffer <- line_trim
    } else {
      buffer <- paste(buffer, line_trim)
    }

    if (grepl(";", buffer, fixed = TRUE)) {
      statements <- c(statements, flush_statement_parts(buffer))
      buffer <- ""
    }
  }

  unique(statements)
}


build_function_definition_index <- function(records) {
  index <- list()
  source_records <- records[vapply(records, function(x) {
    x$source_type %in% c("c", "cpp")
  }, logical(1))]

  for (record in source_records) {
    lines <- readLines(record$path, warn = FALSE)
    text <- paste(strip_c_comments(lines), collapse = "\n")
    funs <- function_definition_names_from_text(text, include_static = FALSE)
    for (fun in unique(funs)) {
      index[[fun]] <- unique(c(index[[fun]], record$file))
    }
  }
  index
}


build_hidden_definition_name_set <- function(records) {
  source_records <- records[vapply(records, function(x) {
    x$source_type %in% c("c", "cpp")
  }, logical(1))]
  if (length(source_records) == 0) {
    return(character())
  }

  hidden <- character()
  for (record in source_records) {
    lines <- readLines(record$path, warn = FALSE)
    text <- paste(strip_c_comments(lines), collapse = "\n")
    defs <- function_definition_records_from_text(text)
    if (nrow(defs) == 0) {
      next
    }
    hidden <- c(hidden, defs$name[grepl("\\battribute_hidden\\b", defs$storage)])
  }
  unique(hidden[nzchar(hidden)])
}


extract_define_alias_map <- function(lines) {
  stripped <- strip_c_comments(lines)
  pattern <- "^\\s*#\\s*define\\s+([A-Za-z_][A-Za-z0-9_]*)\\s+([A-Za-z_][A-Za-z0-9_]*)\\b"
  matches <- grep(pattern, stripped, value = TRUE, perl = TRUE)
  if (length(matches) == 0) {
    return(character())
  }
  names <- sub(pattern, "\\1", matches, perl = TRUE)
  targets <- sub(pattern, "\\2", matches, perl = TRUE)
  stats::setNames(targets, names)
}


resolve_definition_file <- function(function_name, define_alias, definition_index) {
  candidates <- definition_name_candidates(function_name, define_alias)

  for (candidate in candidates) {
    providers <- definition_index[[candidate]]
    if (!is.null(providers) && length(providers) > 0) {
      return(paste(unique(providers), collapse = ", "))
    }
  }
  ""
}


definition_name_candidates <- function(function_name, define_alias) {
  candidates <- c(function_name)
  if (nzchar(define_alias)) {
    candidates <- c(candidates, define_alias)
    if (startsWith(define_alias, "Rf_") && nchar(define_alias) > 3) {
      candidates <- c(candidates, substring(define_alias, 4))
    }
  }
  unique(candidates[nzchar(candidates)])
}

