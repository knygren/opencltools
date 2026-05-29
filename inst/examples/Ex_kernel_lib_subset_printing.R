############################ Start of kernel_lib_subset_printing example ########################

## Small library (fast; runs on CRAN check)
lib_small <- system.file("cl/nmath_small", package = "opencltools")
kpath     <- system.file("cl/src/dnorm_kernel.cl", package = "opencltools")
idx_small <- write_kernel_dependency_index(library_dir = lib_small, write = FALSE)
src_small <- load_library_for_kernel(
  kpath, lib_small,
  depends_tag = "all_depends_nmath",
  index       = idx_small
)
length(attr(src_small, "stems_loaded"))

\donttest{
## Full nmath (slow; verbose print)
lib_dir <- system.file("cl/nmath", package = "opencltools")
idx     <- write_kernel_dependency_index(library_dir = lib_dir, write = FALSE)

src <- load_library_for_kernel(
  kpath, lib_dir,
  depends_tag = "all_depends_nmath",
  index       = idx
)
print(src)

dest_dir <- file.path(tempdir(), "opencltools_subset_print_example")
if (dir.exists(dest_dir)) unlink(dest_dir, recursive = TRUE)
dir.create(dest_dir, recursive = TRUE)
on.exit(unlink(dest_dir, recursive = TRUE), add = TRUE)
df <- extract_library_subset(
  kpath, lib_dir, dest_dir,
  depends_tag = "all_depends_nmath",
  index       = idx
)
print(df)
}

###############################################################################
## End of kernel_lib_subset_printing example
###############################################################################
