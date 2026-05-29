############################ Start of attach_kernel_dependency_tags example ########################

lib_dir <- system.file("cl/ex_glmbayes_nmath", package = "opencltools")
res <- attach_kernel_dependency_tags(lib_dir, dry_run = TRUE)
res$ok
print(res)

###############################################################################
## End of attach_kernel_dependency_tags example
###############################################################################
