############################ Start of load_program_preload example ########################

if (!requireNamespace("nmathopencl", quietly = TRUE)) {
  stop("Example requires installed nmathopencl.")
}

manifest <- read_program_preload_manifest(source_package = "nmathopencl")
print(manifest)

preload <- load_program_preload(source_package = "nmathopencl")
cat("Preload bytes:", attr(preload, "nbytes_concatenated"), "\n")

## End of load_program_preload example
