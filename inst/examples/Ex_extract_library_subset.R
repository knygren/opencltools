############################ Start of extract_library_subset example #########################

\donttest{
lib_dir <- system.file("cl/nmath", package = "opencltools")
src_dir <- system.file("cl/ex_glmbayes_src", package = "opencltools")
kernel_paths <- sort(Sys.glob(file.path(src_dir, "*.cl")))
dest_dir <- tempfile("exglmbsubset")
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

