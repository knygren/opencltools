############################### Start of load_kernel_source example ####################

\donttest{
if (has_opencl()) {
  src <- load_kernel_source("nmath/bd0.cl")
  lib <- load_kernel_library("nmath")
  nchar(src)
  nchar(lib)
  nchar(load_kernel_library("libR_shims"))
}
}

###############################################################################
## End of load_kernel_source example
###############################################################################
