#' Port an existing static src/Makevars to use OpenCL configure scripts
#'
#' @description
#' Migrates a package that already has a static committed \code{src/Makevars}
#' (and optionally \code{src/Makevars.win}) to the configure-script pattern
#' required for CRAN-safe OpenCL support.
#'
#' The function renames the existing \code{src/Makevars} to
#' \code{src/Makevars.in} (the maintained source template) and generates
#' \code{configure} (Linux/macOS) and \code{configure.win} (Windows) scripts
#' that read \code{src/Makevars.in} at \code{R CMD INSTALL} time, run OpenCL
#' detection, and write the final \code{src/Makevars} with OpenCL flags merged
#' in -- or copied verbatim from \code{src/Makevars.in} for CPU-only builds.
#'
#' The generated scripts \strong{always succeed}: if no OpenCL SDK is found
#' the package installs cleanly as CPU-only.  This is the property that makes
#' packages safe for CRAN submission on build machines without a GPU SDK.
#'
#' For packages with no existing \code{src/Makevars}, use
#' \code{\link{use_opencl_configure}} instead.  This function is for
#' \emph{migrating} an existing static Makevars.
#'
#' @section src/Makevars.in workflow:
#' After porting, \strong{maintain \code{src/Makevars.in}} for your base build
#' flags (\code{OpenMP}, \pkg{RcppParallel}, LAPACK, etc.).  The configure script reads it
#' at install time and appends (or omits) the OpenCL flags.  The generated
#' \code{src/Makevars} is a build artifact -- add it to \code{.gitignore} and
#' never commit it.  To update base flags, edit \code{src/Makevars.in} and
#' reinstall.
#'
#' @section configure → USE_OPENCL → has_opencl():
#' \preformatted{
#'   configure / configure.win
#'     -> reads src/Makevars.in for base flags
#'     -> detects CL/cl.h + libOpenCL (+ runtime probe on Linux)
#'     -> writes -DUSE_OPENCL into Makevars  (or copies .in verbatim)
#'
#'   #ifdef USE_OPENCL in C++ source
#'     -> guards all GPU code; package compiles cleanly either way
#'
#'   has_opencl() in R
#'     -> mirrors the compile-time flag; TRUE only if USE_OPENCL was set
#' }
#'
#' @section Limitations:
#' \itemize{
#'   \item \code{+=} (append) assignments in \code{src/Makevars} are detected
#'     and trigger a warning; review the generated configure carefully.
#'   \item If \code{src/Makevars} looks like a generated file (contains
#'     absolute paths, \code{-lOpenCL}, or \code{-DUSE_OPENCL}), the function
#'     warns.  Run on the static committed file, not a build artifact.
#'   \item Packages that already have \code{configure} or \code{configure.win}
#'     are refused unless \code{overwrite = TRUE}.  Users with existing
#'     configure scripts should integrate the OpenCL block manually; see
#'     \code{system.file("configure-templates", "README.md",
#'     package = "opencltools")}.
#' }
#'
#' @param path     Character.  Root directory of the target package.  Defaults
#'   to the current working directory (\code{"."}).
#' @param backup   Logical.  If \code{TRUE} (default), rename
#'   \code{src/Makevars} to \code{src/Makevars.in} before writing the
#'   configure scripts.  If \code{FALSE}, only the configure scripts are
#'   written (the existing \code{src/Makevars} is left in place).
#' @param overwrite Logical.  If \code{TRUE}, overwrite existing configure
#'   scripts.  Defaults to \code{FALSE}.
#'
#' @return Invisibly returns a character vector of the file paths written.
#'
#' @seealso
#' \code{\link{use_opencl_configure}} for packages without an existing
#' \code{src/Makevars}.
#' \code{vignette("Chapter-02", package = "nmathopencl")} in \pkg{nmathopencl} for a
#' full guide when building on the ported nmath kernel library.
#'
#' @example inst/examples/Ex_port_to_opencl_configure.R
#'
#' @export
port_to_opencl_configure <- function(path = ".", backup = TRUE,
                                     overwrite = FALSE) {
  mv_path    <- file.path(path, "src", "Makevars")
  mv_in_path <- file.path(path, "src", "Makevars.in")
  mw_path    <- file.path(path, "src", "Makevars.win")
  mw_in_path <- file.path(path, "src", "Makevars.win.in")
  cfg_path   <- file.path(path, "configure")
  cfw_path   <- file.path(path, "configure.win")

  # ---- Guard: existing configure script ----------------------------------------
  if (file.exists(cfg_path) && !overwrite) {
    stop(
      "An existing configure script was found at '", cfg_path, "'.\n",
      "Users with existing configure scripts should integrate the OpenCL\n",
      "detection block manually.  See:\n",
      "  system.file(\"configure-templates\", \"README.md\",\n",
      "              package = \"opencltools\")\n",
      "Use overwrite = TRUE to force replacement."
    )
  }

  # ---- No Makevars: delegate to use_opencl_configure --------------------------
  if (!file.exists(mv_path)) {
    message("No src/Makevars found -- delegating to use_opencl_configure().")
    return(use_opencl_configure(path = path, overwrite = overwrite))
  }

  # ---- Read and validate src/Makevars -----------------------------------------
  mv_lines    <- readLines(mv_path, warn = FALSE)
  all_content <- paste(mv_lines, collapse = "\n")

  if (grepl("(?:-lOpenCL|-DUSE_OPENCL|/home/|/Users/|C:/Users/|C:/Program Files)",
            all_content, perl = TRUE)) {
    warning(
      "src/Makevars looks like a generated file (absolute paths, -lOpenCL, or\n",
      "-DUSE_OPENCL detected).  port_to_opencl_configure() is intended for\n",
      "the static committed Makevars, not a build artifact.  Proceeding anyway."
    )
  }

  if (any(grepl("^PKG_[A-Z]+\\s*\\+=", mv_lines, perl = TRUE))) {
    warning(
      "src/Makevars uses += (append) assignments.  These lines are preserved\n",
      "verbatim but the merged OpenCL output may need manual review."
    )
  }

  # ---- Extract key variable values --------------------------------------------
  base_cppflags <- .extract_makevars_var(mv_lines, "PKG_CPPFLAGS")
  base_cxxflags <- .extract_makevars_var(mv_lines, "PKG_CXXFLAGS")
  base_cflags   <- .extract_makevars_var(mv_lines, "PKG_CFLAGS")
  base_libs     <- .extract_makevars_var(mv_lines, "PKG_LIBS")

  # ---- Locate template directory ----------------------------------------------
  tmpl_dir <- system.file("configure-templates", package = "opencltools")
  if (!nzchar(tmpl_dir) || !dir.exists(tmpl_dir)) {
    stop("configure-templates directory not found in opencltools installation.")
  }

  written <- character(0L)

  # ---- Generate and write configure (Linux/macOS) -----------------------------
  cfg_text <- .build_ported_configure(
    tmpl_dir      = tmpl_dir,
    base_cppflags = base_cppflags,
    base_cxxflags = base_cxxflags,
    base_cflags   = base_cflags,
    base_libs     = base_libs
  )
  writeLines(cfg_text, cfg_path)
  if (.Platform$OS.type != "windows") {
    Sys.chmod(cfg_path, mode = "0755")
  }
  message("Wrote ", cfg_path)
  written <- c(written, cfg_path)

  # ---- Create src/Makevars.in -------------------------------------------------
  if (backup) {
    if (!file.exists(mv_in_path)) {
      file.copy(mv_path, mv_in_path)
      message("Created ", mv_in_path,
              "\n  Maintain this file for your base build flags.",
              "\n  Re-run port_to_opencl_configure(overwrite = TRUE) after changes.")
    } else {
      message("Skipped creating ", mv_in_path, " (already exists)")
    }
  }

  # ---- Handle configure.win + src/Makevars.win --------------------------------
  has_mw <- file.exists(mw_path)

  if (has_mw) {
    mw_lines <- readLines(mw_path, warn = FALSE)

    cfw_text <- .build_ported_configure_win(
      tmpl_dir      = tmpl_dir,
      base_cppflags = .extract_makevars_var(mw_lines, "PKG_CPPFLAGS"),
      base_cxxflags = .extract_makevars_var(mw_lines, "PKG_CXXFLAGS"),
      base_cflags   = .extract_makevars_var(mw_lines, "PKG_CFLAGS"),
      base_libs     = .extract_makevars_var(mw_lines, "PKG_LIBS")
    )
    writeLines(cfw_text, cfw_path)
    message("Wrote ", cfw_path)
    written <- c(written, cfw_path)

    if (backup && !file.exists(mw_in_path)) {
      file.copy(mw_path, mw_in_path)
      message("Created ", mw_in_path)
    }
  } else {
    src_cfw <- file.path(tmpl_dir, "configure.win")
    if (file.exists(src_cfw)) {
      ok <- file.copy(src_cfw, cfw_path, overwrite = overwrite)
      if (ok) {
        message("Wrote generic ", cfw_path, " (no src/Makevars.win found)")
        written <- c(written, cfw_path)
      } else {
        warning("Could not write ", cfw_path)
      }
    }
  }

  # ---- .gitignore suggestions -------------------------------------------------
  gitignore_entries <- c("src/Makevars", "src/Makevars.win")
  gitignore_path    <- file.path(path, ".gitignore")

  if (file.exists(gitignore_path)) {
    existing <- readLines(gitignore_path, warn = FALSE)
    missing  <- setdiff(gitignore_entries, trimws(existing))
    if (length(missing) > 0L) {
      message("\nConsider adding these generated files to .gitignore:")
      message(paste0("  ", missing, collapse = "\n"))
    }
  } else {
    message("\nConsider creating .gitignore with:")
    message(paste0("  ", gitignore_entries, collapse = "\n"))
  }

  # ---- Checklist --------------------------------------------------------------
  message(
    "\nNext steps:",
    "\n  1. Guard all OpenCL C++ code with #ifdef USE_OPENCL ... #endif",
    "\n  2. Add has_opencl() in R via a .Call() to a compiled-in bool",
    "\n     (see opencltools::has_opencl for the pattern)",
    "\n  3. Commit configure, configure.win, src/Makevars.in",
    "\n     Add src/Makevars and src/Makevars.win to .gitignore",
    "\n  4. Test CPU-only: rename configure, run R CMD INSTALL --preclean .",
    "\n     verify has_opencl() returns FALSE, then restore configure",
    "\n  5. See ?opencltools::port_to_opencl_configure and inst/configure-templates/README.md"
  )

  invisible(written)
}

# --- Internal helpers ---------------------------------------------------------

#' Extract the value of a PKG_* variable from Makevars lines
#' @noRd
.extract_makevars_var <- function(lines, varname) {
  pattern <- paste0("^", varname, "\\s*=\\s*")
  matches <- grep(pattern, lines, value = TRUE, perl = TRUE)
  if (length(matches) == 0L) return("")
  trimws(sub(pattern, "", matches[length(matches)], perl = TRUE))
}

#' Build a ported configure script (Linux/macOS) from the template
#'
#' Takes the OpenCL detection portion of the standard configure template and
#' appends a Makevars-writing section that reads base flags from
#' src/Makevars.in at install time.
#' @noRd
.build_ported_configure <- function(tmpl_dir, base_cppflags, base_cxxflags,
                                    base_cflags, base_libs) {
  tmpl_path <- file.path(tmpl_dir, "configure")
  tmpl      <- readLines(tmpl_path, warn = FALSE)

  # Update header lines (lines 3-4 in template: source attribution)
  tmpl[3] <- "# Ported from src/Makevars.in by opencltools::port_to_opencl_configure()."
  tmpl[4] <- "# See ?opencltools::port_to_opencl_configure for usage guidance."

  # Update the outcome comments to reflect the Makevars.in pattern
  tmpl[13] <- "# Outcome A -- OpenCL headers, library, AND runtime platform all found:"
  tmpl[14] <- "#   PKG_CXXFLAGS = <base> -DUSE_OPENCL -I\"<sdk>/include\""
  tmpl[15] <- "#   PKG_LIBS     = -L\"<sdk>/lib\" -lOpenCL <base>"
  tmpl[16] <- "#"
  tmpl[17] <- "# Outcome B -- SDK absent, headers missing, or runtime probe fails:"
  tmpl[18] <- "#   src/Makevars.in copied verbatim to src/Makevars (original flags preserved)"
  tmpl[19] <- "#"
  # Clear the old outcome B lines that no longer apply
  tmpl[20] <- "# Guard all OpenCL C++ code with:"
  tmpl[21] <- "#   #ifdef USE_OPENCL"
  tmpl[22] <- "#   ...your OpenCL code..."
  tmpl[23] <- "#   #endif"

  # Find where section 8 (Makevars writing) starts and truncate
  sec8_start <- grep("^# ---- 8\\. Write src/Makevars", tmpl)
  if (length(sec8_start) == 0L) {
    stop("Could not locate section 8 marker in configure template.")
  }
  detection_part <- tmpl[seq_len(sec8_start - 1L)]

  # Build the new Makevars-writing section
  new_sec8 <- c(
    "# ---- 8. Write src/Makevars ---------------------------------------------------",
    "# Read base flags from src/Makevars.in (the committed source template).",
    "# To update base flags, edit src/Makevars.in and reinstall.",
    sprintf("BASE_CPPFLAGS=$(grep '^PKG_CPPFLAGS[[:space:]]*=' src/Makevars.in 2>/dev/null | head -1 | sed 's/^PKG_CPPFLAGS[[:space:]]*=[[:space:]]*//')"),
    sprintf("BASE_CXXFLAGS=$(grep '^PKG_CXXFLAGS[[:space:]]*=' src/Makevars.in 2>/dev/null | head -1 | sed 's/^PKG_CXXFLAGS[[:space:]]*=[[:space:]]*//')"),
    sprintf("BASE_CFLAGS=$(grep '^PKG_CFLAGS[[:space:]]*=' src/Makevars.in 2>/dev/null | head -1 | sed 's/^PKG_CFLAGS[[:space:]]*=[[:space:]]*//')"),
    sprintf("BASE_LIBS=$(grep '^PKG_LIBS[[:space:]]*=' src/Makevars.in 2>/dev/null | head -1 | sed 's/^PKG_LIBS[[:space:]]*=[[:space:]]*//')"),
    "",
    "if [ \"${OPENCL_INCLUDE_FOUND}\" = \"yes\" ] && \\",
    "   [ \"${OPENCL_LIB_FOUND}\"     = \"yes\" ] && \\",
    "   [ \"${OPENCL_RUNTIME_FOUND}\" = \"yes\" ]; then",
    "",
    "  echo \"configure: writing OpenCL-enabled src/Makevars\"",
    "  grep -v '^PKG_CPPFLAGS\\|^PKG_CXXFLAGS\\|^PKG_CFLAGS\\|^PKG_LIBS' src/Makevars.in > src/Makevars",
    "  [ -n \"${BASE_CPPFLAGS}\" ] && printf 'PKG_CPPFLAGS = %s\\n' \"${BASE_CPPFLAGS}\" >> src/Makevars",
    "  printf 'PKG_CXXFLAGS = %s -DUSE_OPENCL %s\\n' \"${BASE_CXXFLAGS}\" \"${OPENCL_INCLUDE}\" >> src/Makevars",
    "  [ -n \"${BASE_CFLAGS}\" ]   && printf 'PKG_CFLAGS   = %s\\n' \"${BASE_CFLAGS}\"   >> src/Makevars",
    "  printf 'PKG_LIBS     = %s %s\\n' \"${OPENCL_LIB}\" \"${BASE_LIBS}\" >> src/Makevars",
    "",
    "else",
    "  echo \"configure: writing CPU-only src/Makevars (from src/Makevars.in)\"",
    "  cp src/Makevars.in src/Makevars",
    "fi",
    "",
    "echo \"configure: done\""
  )

  c(detection_part, new_sec8)
}

#' Build a ported configure.win script (Windows) from the template
#'
#' Takes the OpenCL detection portion of the standard configure.win template
#' and appends a Makevars.win-writing section that reads base flags from
#' src/Makevars.win.in at install time.
#' @noRd
.build_ported_configure_win <- function(tmpl_dir, base_cppflags, base_cxxflags,
                                        base_cflags, base_libs) {
  tmpl_path <- file.path(tmpl_dir, "configure.win")
  tmpl      <- readLines(tmpl_path, warn = FALSE)

  # Update header
  tmpl[3] <- "# Ported from src/Makevars.win.in by opencltools::port_to_opencl_configure()."
  tmpl[4] <- "# See ?opencltools::port_to_opencl_configure for usage guidance."

  # Update outcome comments
  tmpl[13] <- "# Outcome A -- CL/cl.h found:"
  tmpl[14] <- "#   PKG_CXXFLAGS = <base> -DUSE_OPENCL -I\"<sdk>/include\""
  tmpl[15] <- "#   PKG_LIBS     = -L\"<sdk>/lib/x64\" -lOpenCL <base>"
  tmpl[16] <- "#"
  tmpl[17] <- "# Outcome B -- CL/cl.h not found:"
  tmpl[18] <- "#   src/Makevars.win.in copied verbatim to src/Makevars.win"

  # Find where section 6 (Makevars.win writing) starts and truncate
  sec6_start <- grep("^# ---- 6\\. Write src/Makevars\\.win", tmpl)
  if (length(sec6_start) == 0L) {
    stop("Could not locate section 6 marker in configure.win template.")
  }
  detection_part <- tmpl[seq_len(sec6_start - 1L)]

  new_sec6 <- c(
    "# ---- 6. Write src/Makevars.win ----------------------------------------------",
    "# Read base flags from src/Makevars.win.in (the committed source template).",
    "BASE_CPPFLAGS=$(grep '^PKG_CPPFLAGS[[:space:]]*=' src/Makevars.win.in 2>/dev/null | head -1 | sed 's/^PKG_CPPFLAGS[[:space:]]*=[[:space:]]*//')",
    "BASE_CXXFLAGS=$(grep '^PKG_CXXFLAGS[[:space:]]*=' src/Makevars.win.in 2>/dev/null | head -1 | sed 's/^PKG_CXXFLAGS[[:space:]]*=[[:space:]]*//')",
    "BASE_CFLAGS=$(grep '^PKG_CFLAGS[[:space:]]*=' src/Makevars.win.in 2>/dev/null | head -1 | sed 's/^PKG_CFLAGS[[:space:]]*=[[:space:]]*//')",
    "BASE_LIBS=$(grep '^PKG_LIBS[[:space:]]*=' src/Makevars.win.in 2>/dev/null | head -1 | sed 's/^PKG_LIBS[[:space:]]*=[[:space:]]*//')",
    "",
    "if [ -n \"${CL_HEADER}\" ]; then",
    "  CL_BASE=$(dirname \"${CL_HEADER}\")",
    "  OPENCL_HOME_NORM=$(echo \"${CL_BASE}\" \\",
    "    | sed 's:[/\\\\]include[/\\\\]CL$::' \\",
    "    | sed 's:\\\\\\\\:/:g')",
    "",
    "  INCLUDE_FLAG=\"-I\\\"${OPENCL_HOME_NORM}/include\\\"\"",
    "  LIB_FLAG=\"-L\\\"${OPENCL_HOME_NORM}/lib/x64\\\"\"",
    "",
    "  echo \"configure.win: writing OpenCL-enabled src/Makevars.win\"",
    "  grep -v '^PKG_CPPFLAGS\\|^PKG_CXXFLAGS\\|^PKG_CFLAGS\\|^PKG_LIBS' src/Makevars.win.in > src/Makevars.win",
    "  [ -n \"${BASE_CPPFLAGS}\" ] && printf 'PKG_CPPFLAGS = %s\\n' \"${BASE_CPPFLAGS}\" >> src/Makevars.win",
    "  printf 'PKG_CXXFLAGS = %s -DUSE_OPENCL %s\\n' \"${BASE_CXXFLAGS}\" \"${INCLUDE_FLAG}\" >> src/Makevars.win",
    "  [ -n \"${BASE_CFLAGS}\" ]   && printf 'PKG_CFLAGS   = %s\\n' \"${BASE_CFLAGS}\"   >> src/Makevars.win",
    "  printf 'PKG_LIBS     = %s -lOpenCL %s\\n' \"${LIB_FLAG}\" \"${BASE_LIBS}\" >> src/Makevars.win",
    "",
    "else",
    "  echo \"configure.win: writing CPU-only src/Makevars.win (from src/Makevars.win.in)\"",
    "  cp src/Makevars.win.in src/Makevars.win",
    "fi",
    "",
    "echo \"configure.win: done\""
  )

  c(detection_part, new_sec6)
}
