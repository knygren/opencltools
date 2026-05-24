############################ Start of write_kernel_dependency_index example ########################

\donttest{
lib_dir <- system.file("cl/ex_glmbayes_nmath", package = "opencltools")
idx <- write_kernel_dependency_index(library_dir = lib_dir, write = FALSE)
names(idx)
length(idx$stems_ordered)
idx$n_files
}

###############################################################################
## End of write_kernel_dependency_index example
###############################################################################
