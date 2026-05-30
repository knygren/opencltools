############################ Start of use_opencl_configure example ########################

tmp <- tempfile("use_opencl_pkg")
dir.create(tmp)
on.exit(unlink(tmp, recursive = TRUE), add = TRUE)

written <- use_opencl_configure(path = tmp)
written
file.exists(file.path(tmp, "configure"))
file.exists(file.path(tmp, "configure.win"))

## Overwrite path (same temp tree; safe when run.dontest = TRUE)
written2 <- use_opencl_configure(path = tmp, overwrite = TRUE)
length(written2)

###############################################################################
## End of use_opencl_configure example
###############################################################################
