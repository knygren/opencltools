############################ Start of stage_kernel_dependency_sort example ########################

lib_dir    <- system.file("cl/nmath_small", package = "opencltools")
output_dir <- tempfile("stage_sort")
on.exit(unlink(output_dir, recursive = TRUE), add = TRUE)

res <- stage_kernel_dependency_sort(lib_dir, output_dir, overwrite = TRUE)
nrow(res$sorted)
length(list.files(output_dir, recursive = TRUE))

###############################################################################
## End of stage_kernel_dependency_sort example
###############################################################################
