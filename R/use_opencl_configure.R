#' Set up OpenCL configure scripts in a downstream R package
#'
#' @description
#' Copies generic OpenCL \code{configure} and \code{configure.win} scripts to
#' the root directory of a package.  The scripts detect \code{CL/cl.h} and
#' \code{libOpenCL} at compile time and generate \code{src/Makevars} (Linux /
#' macOS) or \code{src/Makevars.win} (Windows) with or without
#' \code{-DUSE_OPENCL}, depending on what is found.
#'
#' The scripts \strong{always succeed}.  When no OpenCL SDK is present they
#' produce a CPU-only Makevars with no \code{-lOpenCL}.  This is the key
#' property that makes packages safe for CRAN submission without requiring a
#' GPU SDK on the build machine.
#'
#' @section Why configure scripts are necessary:
#' A package that references \code{-lOpenCL} or \code{CL/cl.h} in a static
#' \code{src/Makevars} will \strong{fail to compile} on \code{'CRAN'} build machines
#' (which have no GPU SDK installed), and no binary will be produced.  The
#' configure scripts here avoid this by probing for the SDK at install time and
#' falling back to a CPU-only build when it is absent.  The relationship is:
#' \preformatted{
#'   configure / configure.win
#'     -> detects CL/cl.h + libOpenCL
#'     -> writes -DUSE_OPENCL into Makevars   (or omits it)
#'
#'   #ifdef USE_OPENCL in C++ source
#'     -> guards all GPU code; package compiles cleanly either way
#'
#'   has_opencl() in R
#'     -> mirrors the compile-time flag; returns TRUE only if USE_OPENCL was set
#' }
#'
#' @param path Character.  Root directory of the target package.  Defaults to
#'   the current working directory (\code{"."}).
#' @param overwrite Logical.  If \code{TRUE}, overwrite existing configure
#'   scripts.  Defaults to \code{FALSE} to avoid accidentally replacing a
#'   customized script.
#'
#' @return Invisibly returns a character vector of the file paths that were
#'   written (empty if all files were skipped).
#'
#' @seealso
#' \code{\link{port_to_opencl_configure}} for packages with an existing static
#' \code{src/Makevars}.
#' \code{\link{opencltoolsLdFlags}} for linking against this package from C++.
#' \code{vignette("Chapter-02", package = "nmathopencl")} in \pkg{nmathopencl} for a
#' full downstream package guide when using the ported nmath kernel library.
#' Template source: \code{system.file("configure-templates", package = "opencltools")}.
#'
#' @example inst/examples/Ex_use_opencl_configure.R
#'
#' @export
use_opencl_configure <- function(path = ".", overwrite = FALSE) {
  template_dir <- system.file("configure-templates", package = "opencltools")
  if (!nzchar(template_dir) || !dir.exists(template_dir)) {
    stop("configure-templates directory not found in opencltools installation.")
  }

  templates <- c("configure", "configure.win")
  written   <- character(0L)

  for (tmpl in templates) {
    src  <- file.path(template_dir, tmpl)
    dest <- file.path(path, tmpl)

    if (!file.exists(src)) {
      warning("Template not found: ", src)
      next
    }

    if (file.exists(dest) && !overwrite) {
      message("Skipping ", tmpl,
              " (already exists; use overwrite = TRUE to replace)")
      next
    }

    ok <- file.copy(src, dest, overwrite = overwrite)
    if (!ok) {
      warning("Could not write ", dest)
      next
    }

    # configure must be executable on Unix for R CMD INSTALL to run it
    if (tmpl == "configure" && .Platform$OS.type != "windows") {
      Sys.chmod(dest, mode = "0755")
    }

    message("Wrote ", dest)
    written <- c(written, dest)
  }

  # Suggest .gitignore entries for generated Makevars files
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

  # Checklist for the developer
  message(
    "\nNext steps:",
    "\n  1. Guard all OpenCL C++ code with #ifdef USE_OPENCL ... #endif",
    "\n  2. Expose has_opencl() in R via a .Call() to a compiled-in bool",
    "\n     (see opencltools::has_opencl for the pattern)",
    "\n  3. For LinkingTo: opencltools, add opencltools::opencltoolsLdFlags()",
    "\n     to PKG_LIBS and locate CL/cl.h via your configure script",
    "\n  4. Test CPU-only build: R CMD INSTALL --preclean .",
    "\n     (or temporarily rename configure to simulate a no-SDK machine)",
    "\n  5. See ?opencltools::use_opencl_configure and inst/configure-templates/README.md"
  )

  invisible(written)
}
