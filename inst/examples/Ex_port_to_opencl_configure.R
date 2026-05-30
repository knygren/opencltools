############################ Start of port_to_opencl_configure example ########################

tmp <- tempfile("port_opencl_pkg")
dir.create(tmp)
dir.create(file.path(tmp, "src"))
on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

writeLines(
  c(
    "PKG_CXXFLAGS = $(SHLIB_OPENMP_CXXFLAGS)",
    "PKG_LIBS = $(LAPACK_LIBS) $(BLAS_LIBS) $(FLIBS)"
  ),
  file.path(tmp, "src", "Makevars")
)

written <- port_to_opencl_configure(path = tmp, backup = TRUE)
written
file.exists(file.path(tmp, "configure"))
file.exists(file.path(tmp, "src", "Makevars.in"))

## Regenerate configure scripts after editing Makevars.in (same temp tree)
written2 <- port_to_opencl_configure(path = tmp, backup = FALSE, overwrite = TRUE)
length(written2)

###############################################################################
## End of port_to_opencl_configure example
###############################################################################
