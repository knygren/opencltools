############################ Start of extract_library_subset example #########################

\donttest{
lib_dir <- system.file("cl/nmath", package = "opencltools")
kernel_paths <- system.file(
  c("cl/src/dnorm_kernel.cl", "cl/src/pnorm_kernel.cl"),
  package = "opencltools"
)
dest_dir <- tempfile("exsubset")
dir.create(dest_dir)
on.exit(unlink(dest_dir, recursive = TRUE), add = TRUE)
df <- extract_library_subset(
  kernel_paths, lib_dir, dest_dir,
  depends_tag = "all_depends_nmath"
)
print(df)
sum(df$copied)
}

###############################################################################
## End of extract_library_subset example
###############################################################################
