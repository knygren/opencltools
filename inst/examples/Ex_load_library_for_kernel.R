############################ Start of load_library_for_kernel example ########################

\donttest{
lib_dir <- system.file("cl/nmath", package = "opencltools")
kpath <- system.file(
  "cl/ex_glmbayes_src/f2_f3_binomial_logit.cl",
  package = "opencltools"
)
src <- load_library_for_kernel(
  kpath, lib_dir,
  depends_tag = "all_depends_nmath"
)
print(src)
nzchar(src)
}

###############################################################################
## End of load_library_for_kernel example
###############################################################################
