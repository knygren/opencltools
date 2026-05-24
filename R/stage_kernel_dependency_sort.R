#' Stage Kernel Library Dependency Sort Results
#'
#' Run the file-level `@depends` sort without requiring full success. Files
#' that can be sorted are copied in order, and files blocked by unresolved
#' dependencies are copied into a separate folder with CSV reports.
#'
#' @param library_dir Directory containing `.cl` files with `@depends` tags.
#' @param output_dir Directory where sorted and unresolved files/reports should
#'   be written.
#' @param overwrite Logical; remove and recreate `output_dir` if it exists.
#'
#' @return A list containing sorted and unresolved data frames.
#'
#' @example inst/examples/Ex_stage_kernel_dependency_sort.R
#'
#' @export
stage_kernel_dependency_sort <- function(library_dir, output_dir,
                                         overwrite = FALSE) {
  if (!dir.exists(library_dir)) {
    stop("`library_dir` does not exist: ", library_dir, call. = FALSE)
  }
  if (dir.exists(output_dir)) {
    if (!isTRUE(overwrite)) {
      stop("`output_dir` already exists. Use `overwrite = TRUE` to replace it.",
           call. = FALSE)
    }
    unlink(output_dir, recursive = TRUE, force = TRUE)
  }

  sorted_dir <- file.path(output_dir, "sorted")
  unresolved_dir <- file.path(output_dir, "unresolved")
  dir.create(sorted_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(unresolved_dir, recursive = TRUE, showWarnings = FALSE)

  records <- read_kernel_sort_records(library_dir)
  state <- dependency_sort_prefix(records)

  copy_sorted_kernel_files(state$sorted, sorted_dir)
  copy_unresolved_kernel_files(state$unresolved, unresolved_dir)

  sorted_report <- sorted_records_to_data_frame(state$sorted)
  unresolved_report <- unresolved_records_to_data_frame(state$unresolved)
  utils::write.csv(sorted_report, file.path(output_dir, "sorted_files.csv"),
                   row.names = FALSE)
  utils::write.csv(unresolved_report, file.path(output_dir, "unresolved_files.csv"),
                   row.names = FALSE)

  list(
    sorted = sorted_report,
    unresolved = unresolved_report,
    sorted_dir = sorted_dir,
    unresolved_dir = unresolved_dir
  )
}


read_kernel_sort_records <- function(library_dir) {
  paths <- list.files(library_dir, pattern = "\\.cl$", full.names = TRUE,
                      recursive = FALSE)
  if (length(paths) == 0) {
    stop("No .cl files found in `library_dir`.", call. = FALSE)
  }
  records <- lapply(paths, function(path) {
    lines <- readLines(path, warn = FALSE)
    file <- tools::file_path_sans_ext(basename(path))
    list(
      file = file,
      path = path,
      source_origin = parse_port_scalar_annotation(lines, "source_origin"),
      depends = parse_port_annotation(lines, "depends"),
      includes = parse_port_annotation(lines, "includes"),
      provides = parse_port_annotation(lines, "provides"),
      source_type = parse_port_scalar_annotation(lines, "source_type")
    )
  })
  names(records) <- vapply(records, `[[`, character(1), "file")
  records
}


dependency_sort_prefix <- function(records) {
  sorted <- list()
  sorted_files <- character()
  remaining <- records
  pass <- 0L

  repeat {
    pass <- pass + 1L
    promoted <- character()
    for (name in names(remaining)) {
      deps <- remaining[[name]]$depends
      missing <- setdiff(deps, sorted_files)
      if (length(missing) == 0) {
        record <- remaining[[name]]
        record$pass <- pass
        record$order <- length(sorted) + 1L
        sorted[[name]] <- record
        sorted_files <- c(sorted_files, name)
        promoted <- c(promoted, name)
      }
    }
    if (length(promoted) == 0 || length(promoted) == length(remaining)) {
      break
    }
    remaining <- remaining[setdiff(names(remaining), promoted)]
  }

  remaining <- remaining[setdiff(names(remaining), names(sorted))]
  unresolved <- lapply(remaining, function(record) {
    record$missing_depends <- setdiff(record$depends, sorted_files)
    record$resolved_depends <- intersect(record$depends, sorted_files)
    graph <- dependency_neighborhood(record, records)
    record$depends_of_depends <- graph$depends_of_depends
    record$two_step_cycles <- graph$two_step_cycles
    record$third_order_depends <- graph$third_order_depends
    record$three_step_cycles <- graph$three_step_cycles
    record$fourth_order_depends <- graph$fourth_order_depends
    record$four_step_cycles <- graph$four_step_cycles
    record
  })

  list(sorted = sorted, unresolved = unresolved)
}


copy_sorted_kernel_files <- function(records, sorted_dir) {
  for (record in records) {
    target <- file.path(
      sorted_dir,
      sprintf("%03d_%s.cl", record$order, record$file)
    )
    file.copy(record$path, target, overwrite = TRUE)
  }
}


copy_unresolved_kernel_files <- function(records, unresolved_dir) {
  for (record in records) {
    target <- file.path(unresolved_dir, paste0(record$file, ".cl"))
    file.copy(record$path, target, overwrite = TRUE)
  }
}


sorted_records_to_data_frame <- function(records) {
  if (length(records) == 0) {
    return(data.frame())
  }
  data.frame(
    order = vapply(records, `[[`, integer(1), "order"),
    pass = vapply(records, `[[`, integer(1), "pass"),
    file = vapply(records, `[[`, character(1), "file"),
    source_type = vapply(records, function(x) x$source_type %||% "",
                         character(1)),
    depends = vapply(records, function(x) paste(x$depends, collapse = ", "),
                     character(1)),
    includes = vapply(records, function(x) paste(x$includes, collapse = ", "),
                      character(1)),
    provides = vapply(records, function(x) paste(x$provides, collapse = ", "),
                      character(1)),
    stringsAsFactors = FALSE
  )
}


unresolved_records_to_data_frame <- function(records) {
  if (length(records) == 0) {
    return(data.frame())
  }
  data.frame(
    file = vapply(records, `[[`, character(1), "file"),
    source_type = vapply(records, function(x) x$source_type %||% "",
                         character(1)),
    depends = vapply(records, function(x) paste(x$depends, collapse = ", "),
                     character(1)),
    depends_of_depends = vapply(records, function(x) {
      paste(x$depends_of_depends, collapse = ", ")
    }, character(1)),
    two_step_cycle_count = vapply(records, function(x) {
      length(x$two_step_cycles)
    }, integer(1)),
    two_step_cycles = vapply(records, function(x) {
      paste(x$two_step_cycles, collapse = ", ")
    }, character(1)),
    third_order_depends = vapply(records, function(x) {
      paste(x$third_order_depends, collapse = ", ")
    }, character(1)),
    three_step_cycle_count = vapply(records, function(x) {
      length(x$three_step_cycles)
    }, integer(1)),
    three_step_cycles = vapply(records, function(x) {
      paste(x$three_step_cycles, collapse = ", ")
    }, character(1)),
    fourth_order_depends = vapply(records, function(x) {
      paste(x$fourth_order_depends, collapse = ", ")
    }, character(1)),
    four_step_cycle_count = vapply(records, function(x) {
      length(x$four_step_cycles)
    }, integer(1)),
    four_step_cycles = vapply(records, function(x) {
      paste(x$four_step_cycles, collapse = ", ")
    }, character(1)),
    resolved_depends = vapply(records, function(x) {
      paste(x$resolved_depends, collapse = ", ")
    }, character(1)),
    remaining_depends_count = vapply(records, function(x) {
      length(x$missing_depends)
    }, integer(1)),
    missing_depends = vapply(records, function(x) {
      paste(x$missing_depends, collapse = ", ")
    }, character(1)),
    includes = vapply(records, function(x) paste(x$includes, collapse = ", "),
                      character(1)),
    provides = vapply(records, function(x) paste(x$provides, collapse = ", "),
                      character(1)),
    stringsAsFactors = FALSE
  )
}


dependency_neighborhood <- function(record, records) {
  depends <- intersect(record$depends, names(records))
  depends_of_depends <- unique(unlist(lapply(depends, function(dep) {
    records[[dep]]$depends
  }), use.names = FALSE))
  depends_of_depends <- depends_of_depends[nzchar(depends_of_depends)]

  cycle_partners <- depends[vapply(depends, function(dep) {
    record$file %in% records[[dep]]$depends
  }, logical(1))]

  third_order_depends <- unique(unlist(lapply(
    intersect(depends_of_depends, names(records)),
    function(dep) records[[dep]]$depends
  ), use.names = FALSE))
  third_order_depends <- third_order_depends[nzchar(third_order_depends)]

  fourth_order_depends <- unique(unlist(lapply(
    intersect(third_order_depends, names(records)),
    function(dep) records[[dep]]$depends
  ), use.names = FALSE))
  fourth_order_depends <- fourth_order_depends[nzchar(fourth_order_depends)]

  three_step_cycles <- character()
  for (dep1 in depends) {
    for (dep2 in intersect(records[[dep1]]$depends, names(records))) {
      if (record$file %in% records[[dep2]]$depends) {
        three_step_cycles <- c(
          three_step_cycles,
          paste(record$file, dep1, dep2, record$file, sep = " -> ")
        )
      }
    }
  }

  four_step_cycles <- character()
  for (dep1 in depends) {
    dep1_depends <- intersect(records[[dep1]]$depends, names(records))
    for (dep2 in dep1_depends) {
      dep2_depends <- intersect(records[[dep2]]$depends, names(records))
      for (dep3 in dep2_depends) {
        # Require a true 4-node loop; avoid reporting repeated 2-step loops
        # as artificial 4-step cycles (e.g., A -> B -> A -> B -> A).
        if (length(unique(c(record$file, dep1, dep2, dep3))) < 4) {
          next
        }
        if (record$file %in% records[[dep3]]$depends) {
          four_step_cycles <- c(
            four_step_cycles,
            paste(record$file, dep1, dep2, dep3, record$file, sep = " -> ")
          )
        }
      }
    }
  }

  list(
    depends_of_depends = depends_of_depends,
    two_step_cycles = if (length(cycle_partners) == 0) {
      character()
    } else {
      paste0(record$file, " <-> ", cycle_partners)
    },
    third_order_depends = third_order_depends,
    three_step_cycles = unique(three_step_cycles),
    fourth_order_depends = fourth_order_depends,
    four_step_cycles = unique(four_step_cycles)
  )
}


parse_port_annotation <- function(lines, tag) {
  pattern <- paste0("^\\s*//\\s*@", escape_regex(tag), "(?=\\s|:)\\s*:?[[:space:]]*(.*)$")
  matches <- grep(pattern, lines, value = TRUE, perl = TRUE)
  if (length(matches) == 0) {
    return(character())
  }
  values <- sub(pattern, "\\1", matches, perl = TRUE)
  tokens <- trimws(unlist(strsplit(values, ",", fixed = TRUE), use.names = FALSE))
  unique(tokens[nzchar(tokens)])
}


parse_port_scalar_annotation <- function(lines, tag) {
  values <- parse_port_annotation(lines, tag)
  if (length(values) == 0) "" else values[[1]]
}


transitive_depends_for_file <- function(file, records) {
  seen <- character()
  stack <- intersect(records[[file]]$depends, names(records))

  while (length(stack) > 0) {
    current <- stack[[1]]
    stack <- stack[-1]
    if (current %in% seen) {
      next
    }
    seen <- c(seen, current)
    next_dep <- intersect(records[[current]]$depends, names(records))
    stack <- c(next_dep, stack)
  }
  unique(seen)
}


sort_by_order <- function(files, order_index) {
  files <- files[files %in% names(order_index)]
  if (length(files) == 0) {
    return(character())
  }
  files[order(order_index[files])]
}


cycle_report_from_unresolved <- function(records) {
  entries <- list()
  for (record in records) {
    add_entries <- function(cycle_type, cycle_values) {
      cycle_values <- unique(cycle_values[nzchar(cycle_values)])
      if (length(cycle_values) == 0) {
        return(NULL)
      }
      data.frame(
        file = rep(record$file, length(cycle_values)),
        cycle_type = rep(cycle_type, length(cycle_values)),
        cycle_path = cycle_values,
        stringsAsFactors = FALSE
      )
    }
    entries[[length(entries) + 1L]] <- add_entries("two_step", record$two_step_cycles)
    entries[[length(entries) + 1L]] <- add_entries("three_step", record$three_step_cycles)
    entries[[length(entries) + 1L]] <- add_entries("four_step", record$four_step_cycles)
  }
  entries <- entries[!vapply(entries, is.null, logical(1))]
  if (length(entries) == 0) {
    return(data.frame())
  }
  out <- do.call(rbind, entries)
  if (nrow(out) == 0) {
    return(data.frame())
  }
  out <- unique(out)
  rownames(out) <- NULL
  out$key <- vapply(out$cycle_path, cycle_path_canonical_key, character(1))
  out <- out[!duplicated(out$key), c("cycle_type", "cycle_path"), drop = FALSE]
  out[order(out$cycle_type, out$cycle_path), , drop = FALSE]
}


cycle_path_canonical_key <- function(path) {
  if (grepl("<->", path, fixed = TRUE)) {
    parts <- trimws(strsplit(path, "<->", fixed = TRUE)[[1]])
    if (length(parts) != 2) {
      return(path)
    }
    nodes <- c(parts[[1]], parts[[2]])
  } else if (grepl("->", path, fixed = TRUE)) {
    parts <- trimws(strsplit(path, "->", fixed = TRUE)[[1]])
    if (length(parts) < 3) {
      return(path)
    }
    nodes <- parts
    if (nodes[[length(nodes)]] == nodes[[1]]) {
      nodes <- nodes[-length(nodes)]
    }
  } else {
    return(path)
  }

  if (length(nodes) <= 1) {
    return(path)
  }
  cycle_min_rotation_key(nodes)
}


cycle_min_rotation_key <- function(nodes) {
  n <- length(nodes)
  rotations <- vapply(seq_len(n), function(i) {
    rotated <- c(nodes[i:n], nodes[seq_len(i - 1L)])
    paste(rotated, collapse = " -> ")
  }, character(1))

  rev_nodes <- rev(nodes)
  rev_rotations <- vapply(seq_len(n), function(i) {
    rotated <- c(rev_nodes[i:n], rev_nodes[seq_len(i - 1L)])
    paste(rotated, collapse = " -> ")
  }, character(1))

  min(c(rotations, rev_rotations))
}


set_port_annotation <- function(lines, tag, values) {
  pattern <- paste0("^\\s*//\\s*@", tag, "(?=\\s|:)\\s*:?.*$")
  lines <- lines[!grepl(pattern, lines, perl = TRUE)]

  values <- unique(values[nzchar(values)])
  if (length(values) == 0) {
    return(lines)
  }

  new_line <- paste0("// @", tag, ": ", paste(values, collapse = ", "))
  insert_after <- shim_inference_tag_insert_anchor(lines)
  append(lines, new_line, after = insert_after)
}


shim_inference_tag_insert_anchor <- function(lines) {
  cls_hit <- grep(shim_classification_tag_pattern(), lines, perl = TRUE)
  if (length(cls_hit) > 0L) {
    return(as.integer(min(cls_hit) - 1L))
  }
  annotation_insert_after_shim_core_metadata(lines)
}


annotation_insert_position <- function(lines) {
  annotation_idx <- which(grepl("^\\s*//\\s*@", lines))
  if (length(annotation_idx) == 0) {
    return(0L)
  }

  origin_idx <- grep("^\\s*//\\s*@source_origin(?=\\s|:)", lines, perl = TRUE)
  if (length(origin_idx) > 0) {
    return(max(origin_idx))
  }

  source_type_idx <- grep("^\\s*//\\s*@source_type(?=\\s|:)", lines, perl = TRUE)
  if (length(source_type_idx) > 0) {
    return(max(source_type_idx))
  }

  max(annotation_idx)
}


`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0 || is.na(x)) y else x
}

