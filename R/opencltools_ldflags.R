#' Linker flags for downstream \code{LinkingTo: opencltools} packages
#'
#' Returns a \code{PKG_LIBS} fragment so a downstream package can resolve
#' \code{openclPort::} symbols from this package's shared library instead of
#' duplicating C++ sources such as \file{kernel_loader.cpp}.
#'
#' Use together with \code{\link{opencltools}} headers
#' (\code{#include <opencltools/openclPort.h>}) and your own \file{configure}
#' logic for OpenCL SDK \code{-I} paths when \code{USE_OPENCL} is defined.
#'
#' Typical \file{src/Makevars} usage (Unix):
#' \preformatted{
#' OPENCLTOOLS_LIBS = $(shell $(R_HOME)/bin/Rscript -e "opencltools::opencltoolsLdFlags()")
#' PKG_LIBS = $(OPENCLTOOLS_LIBS) $(PKG_LIBS)
#' }
#'
#' On Windows, add the same \code{OPENCLTOOLS_LIBS} line to \file{src/Makevars.win}
#' (or merge into the \file{Makevars} block written by \file{configure.win}).
#'
#' @return A character scalar of linker flags (\code{-L... -lopencltools}).
#' @export
#'
#' @example inst/examples/Ex_opencltools_ldflags.R
opencltoolsLdFlags <- function() {
  root <- Sys.getenv("R_PACKAGE_DIR", unset = "")
  if (!nzchar(root)) {
    root <- tryCatch(
      find.package("opencltools"),
      error = function(e) {
        stop("installed 'opencltools' package not found", call. = FALSE)
      }
    )
  }

  libdir <- if (.Platform$OS.type == "windows") {
    file.path(root, "libs", .Platform$r_arch)
  } else {
    file.path(root, "libs")
  }

  if (!dir.exists(libdir)) {
    stop(
      "opencltools library directory not found: ", libdir,
      "\nInstall or load a binary build of opencltools first.",
      call. = FALSE
    )
  }

  paste0(
    "-L", shQuote(normalizePath(libdir, winslash = "/", mustWork = TRUE)),
    " -lopencltools"
  )
}
