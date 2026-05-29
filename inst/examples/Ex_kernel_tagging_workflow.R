############################ Start of kernel_tagging_workflow example ########################

lib_dir <- system.file("cl/ex_glmbayes_nmath", package = "opencltools")
kernels <- list.files(
  system.file("cl/ex_glmbayes_draft_src", package = "opencltools"),
  pattern = "\\.cl$", full.names = TRUE
)

# Step 1: scan draft kernels for library calls (read-only dry run)
step1 <- attach_kernel_call_tags(
  kernel_paths = kernels,
  library_dir  = lib_dir,
  library_tag  = "nmath",
  dry_run      = TRUE
)
step1

# Step 2: expand transitive closure (small nmath library; runs on CRAN check)
nmath_small <- system.file("cl/nmath_small", package = "opencltools")
tagged      <- system.file("cl/src/dnorm_kernel.cl", package = "opencltools")
idx_small   <- write_kernel_dependency_index(library_dir = nmath_small, write = FALSE)

step2_small <- attach_cross_library_tags(
  kernel_paths = tagged,
  library_dir  = nmath_small,
  depends_tag  = "depends_nmath",
  index        = idx_small,
  dry_run      = TRUE
)
nrow(step2_small)

\donttest{
# Step 2: full nmath (slow)
nmath_dir <- system.file("cl/nmath", package = "opencltools")
idx       <- write_kernel_dependency_index(library_dir = nmath_dir, write = FALSE)

step2 <- attach_cross_library_tags(
  kernel_paths = tagged,
  library_dir  = nmath_dir,
  depends_tag  = "depends_nmath",
  index        = idx,
  dry_run      = TRUE
)
step2
}

###############################################################################
## End of kernel_tagging_workflow example
###############################################################################
