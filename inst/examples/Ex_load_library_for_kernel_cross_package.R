############################ Start of cross-package loader example ########################

## Launcher kernel and library tree both live in opencltools (same API as
## cross-package use in downstream packages).
src <- load_library_for_kernel_cross_package(
  kernel_relative_path = "src/dnorm_kernel.cl",
  kernel_package = "opencltools",
  library_subdir = "nmath_small",
  library_package = "opencltools",
  depends_tag = "all_depends_nmath"
)
print(src)

## End of cross-package loader example
