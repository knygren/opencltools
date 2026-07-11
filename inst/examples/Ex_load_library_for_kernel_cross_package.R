############################ Start of cross-package loader example ########################

if (!requireNamespace("nmathopencl", quietly = TRUE)) {
  stop("Example requires installed nmathopencl.")
}
if (!requireNamespace("glmbayes", quietly = TRUE)) {
  stop("Example requires installed glmbayes.")
}

src <- load_library_for_kernel_cross_package(
  kernel_relative_path = "src/f2_f3_gaussian.cl",
  kernel_package = "glmbayes",
  library_subdir = "nmath",
  library_package = "nmathopencl",
  depends_tag = "all_depends_nmath"
)
print(src)

## End of cross-package loader example
