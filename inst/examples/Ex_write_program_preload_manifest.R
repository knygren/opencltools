## write_program_preload_manifest example

manifest <- read_program_preload_manifest(source_package = "opencltools")
obj <- write_program_preload_manifest(
  manifest = manifest,
  source_package = "opencltools",
  write = FALSE
)
names(obj)
nrow(obj$entries)

## End
