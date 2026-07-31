# Invoked by configure / configure.win. Stdout: line1 = Rcpp version<TAB>library,
# line2 = -I"…/Rcpp/include", line3 = Function.h namespace ctor branch (1/2/3) for PKG_CXXFLAGS -D.
# Messages and warnings go to stderr.
#
# GLMBAYES_RCPP_LIB — optional: explicit library directory that contains Rcpp/ (e.g. CI user library).
# If unset and several libraries contain Rcpp, the newest packageVersion("Rcpp") wins.

ov <- Sys.getenv("GLMBAYES_RCPP_LIB", "")
lp <- .libPaths()
hits <- Filter(function(L) file.exists(file.path(L, "Rcpp", "DESCRIPTION")), lp)

if (!length(hits)) {
  writeLines("configure: no Rcpp under .libPaths(); install Rcpp before building", con = stderr())
  quit(status = 1L)
}

pick_lib <- function() {
  if (nzchar(ov)) {
    d <- ov
    if (!file.exists(file.path(d, "Rcpp", "DESCRIPTION"))) {
      writeLines(sprintf("configure: GLMBAYES_RCPP_LIB=%s does not contain Rcpp", ov), con = stderr())
      quit(status = 1L)
    }
    writeLines(sprintf("configure: Rcpp include from GLMBAYES_RCPP_LIB=%s", d), con = stderr())
    return(d)
  }
  if (length(hits) == 1L) {
    writeLines(sprintf("configure: single Rcpp installation: %s", hits[[1L]]), con = stderr())
    return(hits[[1L]])
  }
  best <- hits[[1L]]
  bv <- packageVersion("Rcpp", lib.loc = best)
  for (i in 2L:length(hits)) {
    v <- packageVersion("Rcpp", lib.loc = hits[[i]])
    if (v > bv) {
      best <- hits[[i]]
      bv <- v
    }
  }
  writeLines(sprintf("configure: multiple Rcpp — using newest (%s): %s", as.character(bv), best), con = stderr())
  for (L in hits) {
    if (!identical(L, best)) {
      writeLines(
        sprintf("configure:   (other) %s @ %s", L, as.character(packageVersion("Rcpp", lib.loc = L))),
        con = stderr()
      )
    }
  }
  best
}

parse_rcpp_minimum_version <- function() {
  if (!file.exists("DESCRIPTION")) {
    return(NULL)
  }
  imp <- tryCatch(
    read.dcf("DESCRIPTION", fields = "Imports")[[1L]],
    error = function(e) ""
  )
  imp <- gsub("[\n\r]", " ", imp, perl = TRUE)
  m <- regexec("Rcpp\\s*\\(>=\\s*([0-9.]+)\\)", imp, perl = TRUE)
  r <- regmatches(imp, m)[[1L]]
  if (length(r) < 2L) {
    return(NULL)
  }
  tryCatch(package_version(r[[2L]]), warning = function(w) NULL, error = function(e) NULL)
}

rcpp_configure_version_info <- function(lib) {
  # Version + library are echoed by configure / configure.win from stdout line 1 (see below).
  rv <- getRversion()
  r_svn <- tryCatch({
    v <- R.version
    s <- if (!is.null(v[["svn.rev"]])) v[["svn.rev"]] else v[["svn rev"]]
    s <- as.character(s)
    if (!length(s) || !nzchar(s)) "unknown" else s
  }, error = function(e) "unknown")
  writeLines(
    sprintf("configure: R version: %s (svn: %s)", as.character(rv), r_svn),
    con = stderr()
  )

  pd <- tryCatch(
    suppressWarnings(packageDescription("Rcpp", lib.loc = lib)),
    error = function(e) NULL
  )
  if (is.list(pd) && !identical(pd, NA)) {
    rs <- pd[["RemoteSha"]]
    if (!is.null(rs) && length(rs) && nzchar(as.character(rs)[1L])) {
      writeLines(sprintf("configure: Rcpp RemoteSha: %s", as.character(rs)[1L]), con = stderr())
    }
    gr <- pd[["GithubRepo"]]
    gu <- pd[["GithubUsername"]]
    if (!is.null(gr) && nzchar(as.character(gr)) && !is.null(gu) && nzchar(as.character(gu))) {
      writeLines(sprintf("configure: Rcpp source: %s/%s", as.character(gu)[1L], as.character(gr)[1L]), con = stderr())
    }
    rp <- pd[["Repository"]]
    if (!is.null(rp) && nzchar(as.character(rp))) {
      writeLines(sprintf("configure: Rcpp Repository: %s", as.character(rp)[1L]), con = stderr())
    }
  }
  fh <- file.path(lib, "Rcpp", "include", "Rcpp", "Function.h")
  if (file.exists(fh)) {
    h <- readLines(fh, warn = FALSE)
    has_ub <- any(grepl("R_getVarEx", h, fixed = TRUE) & grepl("R_UnboundValue", h, fixed = TRUE))
    writeLines(
      sprintf(
        "configure: Rcpp Function.h: line with R_getVarEx + R_UnboundValue present = %s",
        has_ub
      ),
      con = stderr()
    )
  }
  invisible()
}

read_r_svn_revision_h <- function() {
  rh <- file.path(R.home("include"), "Rversion.h")
  if (!file.exists(rh)) {
    return(NA_integer_)
  }
  z <- readLines(rh, warn = FALSE, encoding = "UTF-8")
  m <- grep("^#define[[:space:]]+R_SVN_REVISION[[:space:]]+", z, value = TRUE)
  if (!length(m)) {
    return(NA_integer_)
  }
  rest <- sub("^#define[[:space:]]+R_SVN_REVISION[[:space:]]+", "", m[1L])
  rest <- sub("/\\*.*$", "", rest) # strip C comments on same line
  rest <- gsub("^[[:space:]]+|[[:space:]]+$", "", rest)
  suppressWarnings(as.integer(rest))
}

# Mirrors Rcpp/include/Rcpp/Function.h: Function_Impl(const string&, const string& ns) body.
rcpp_function_h_branch <- function() {
  rv <- getRversion()
  svn_h <- read_r_svn_revision_h()
  v <- R.version
  s <- if (!is.null(v[["svn.rev"]])) v[["svn.rev"]] else v[["svn rev"]]
  r_svn_r <- suppressWarnings(as.integer(as.character(s)))
  if (length(r_svn_r) != 1L || is.na(r_svn_r)) {
    r_svn_r <- NA_integer_
  }
  c1 <- rv < "4.5.0"
  c2a <- rv < "4.6.0"
  c2b <- !is.na(svn_h) && svn_h < 89746L
  c2 <- c2a || c2b
  if (c1) {
    b <- 1L
  } else if (c2) {
    b <- 2L
  } else {
    b <- 3L
  }
  name <- c("Rf_findVarInFrame / R_NamespaceRegistry", "R_getVarEx", "R_getRegisteredNamespace")[b]
  writeLines("configure: Rcpp Function.h - `Function(const string& name, const string& ns)` C preprocessor path:", con = stderr())
  writeLines(sprintf("configure:   branch %d: %s", b, name), con = stderr())
  writeLines(sprintf("configure:   (R_VERSION < 4,5,0) => %s", c1), con = stderr())
  writeLines(
    sprintf(
      "configure:   (R_VERSION < 4,6,0 || R_SVN_REVISION < 89746) => %s  [parts: R_VERSION < 4,6,0 = %s; R_SVN_REVISION < 89746 = %s]",
      c2, c2a, c2b
    ),
    con = stderr()
  )
  if (is.na(svn_h)) {
    writeLines("configure:   R_SVN_REVISION: not read from R_HOME/include/Rversion.h (missing or unparsed)", con = stderr())
  } else {
    writeLines(sprintf("configure:   R_SVN_REVISION (from Rversion.h) = %d", svn_h), con = stderr())
  }
  if (is.na(r_svn_r)) {
    writeLines("configure:   R session svn.rev: (unavailable)", con = stderr())
  } else {
    writeLines(sprintf("configure:   R session svn (R.version) = %d (should match Rversion.h for same R install)", r_svn_r), con = stderr())
  }
  if (!is.na(svn_h) && !is.na(r_svn_r) && svn_h != r_svn_r) {
    writeLines(
      "configure: WARNING: R_SVN_REVISION in Rversion.h differs from R session svn; compile may not match this R.",
      con = stderr()
    )
  }
  writeLines(
    "configure:   (Branch 3 uses R_getRegisteredNamespace: undefined symbol usually means R headers are older than Rcpp expects, or a mismatched R/lib.)",
    con = stderr()
  )
  b
}

rcpp_configure_warnings <- function(lib) {
  rv <- getRversion()
  r_svn <- tryCatch({
    v <- R.version
    s <- if (!is.null(v[["svn.rev"]])) v[["svn.rev"]] else v[["svn rev"]]
    as.integer(as.character(s))
  }, error = function(e) NA_integer_)

  v_inst <- tryCatch(packageVersion("Rcpp", lib.loc = lib), error = function(e) NULL)
  if (!is.null(v_inst)) {
    vmin <- parse_rcpp_minimum_version()
    if (!is.null(vmin) && v_inst < vmin) {
      writeLines(sprintf(
        "configure: WARNING: installed Rcpp %s is older than DESCRIPTION Imports (>= %s).",
        as.character(v_inst), as.character(vmin)
      ), con = stderr())
    }
  }

  if (identical(as.character(rv), "4.6.0") && !is.na(r_svn) && r_svn < 89746L) {
    writeLines(
      sprintf(
        "configure: WARNING: R 4.6.0 snapshot r%d is older than the Rcpp 1.1.1-1 compatibility cutoff (r89746).",
        r_svn
      ),
      con = stderr()
    )
    writeLines(
      "configure: WARNING: Recommendation: update R to >= 4.6.0 r89746 (or current release) before building with recent Rcpp.",
      con = stderr()
    )
  }

  fh <- file.path(lib, "Rcpp", "include", "Rcpp", "Function.h")
  if (file.exists(fh)) {
    txt <- paste(readLines(fh, warn = FALSE), collapse = "\n")
    if (grepl("R_getVarEx\\([^)]*R_NamespaceRegistry[^)]*R_UnboundValue", txt, perl = TRUE)) {
      writeLines(
        paste0(
          "configure: WARNING: Rcpp Function.h matches CRAN-style R_UnboundValue line. ",
          "If compilation fails with R_NamespaceRegistry, ensure Rcpp meets DESCRIPTION Imports ",
          "or apply tools/patch_rcpp_function_h.R."
        ),
        con = stderr()
      )
    }
  }
  invisible()
}

lib <- pick_lib()
rcpp_configure_version_info(lib)
rcpp_configure_warnings(lib)
fh_branch <- rcpp_function_h_branch()

ver <- tryCatch(as.character(packageVersion("Rcpp", lib.loc = lib)), error = function(e) "unknown")
# Line 1 for configure / configure.win: version TAB library (no tabs in path assumed).
cat(sprintf("%s\t%s\n", ver, lib))
inc <- normalizePath(
  system.file("include", package = "Rcpp", lib.loc = lib),
  winslash = "/",
  mustWork = TRUE
)
p <- gsub("\\\\", "/", inc)
# Line 2: PKG_CPPFLAGS fragment for Makevars (single line).
cat(sprintf('-I"%s"\n', p))
# Line 3: mirror of Function.h branch id for -DGLMBAYES_RCPP_FH_SIM= in Makevars
cat(fh_branch, "\n", sep = "")
