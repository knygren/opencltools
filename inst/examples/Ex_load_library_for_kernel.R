############################ Start of load_library_for_kernel example ########################

\donttest{
lib_dir <- system.file("cl/nmath", package = "opencltools")
kpath <- system.file("cl/src/dnorm_kernel.cl", package = "opencltools")
idx   <- write_kernel_dependency_index(library_dir = lib_dir, write = FALSE)
src <- load_library_for_kernel(
  kpath, lib_dir,
  depends_tag = "all_depends_nmath",
  index       = idx
)
print(src)
nzchar(src)
}

###############################################################################
## End of load_library_for_kernel example
###############################################################################
