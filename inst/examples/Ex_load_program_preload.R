############################ Start of load_program_preload example ########################

manifest <- read_program_preload_manifest(source_package = "opencltools")
print(manifest)

preload <- load_program_preload(source_package = "opencltools")
cat("Preload bytes:", attr(preload, "nbytes_concatenated"), "\n")

## End of load_program_preload example
