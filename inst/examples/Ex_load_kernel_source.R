############################### Start of load_kernel_source example ####################

src <- load_kernel_source("nmath/bd0.cl")
lib <- load_kernel_library("nmath")
nchar(src)
nchar(lib)
nchar(load_kernel_library("libR_shims"))

###############################################################################
## End of load_kernel_source example
###############################################################################
