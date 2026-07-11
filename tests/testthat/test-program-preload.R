test_that("read_program_preload_manifest reads opencltools manifest", {
  manifest <- read_program_preload_manifest(source_package = "opencltools")
  expect_s3_class(manifest, "data.frame")
  expect_true(all(c("rank", "kind", "rel_path") %in% names(manifest)))
  expect_gt(nrow(manifest), 0L)
  expect_true(all(manifest$kind %in% c("file", "library")))
  expect_equal(manifest$rank, sort(manifest$rank))
})

test_that("load_program_preload returns non-empty prelude text", {
  preload <- load_program_preload(source_package = "opencltools")
  expect_s3_class(preload, "opencltools_program_preload")
  expect_type(preload, "character")
  expect_gt(nchar(preload[[1L]], type = "bytes"), 100L)
})

test_that("load_program_preload(manifest=) matches C++ loader", {
  manifest <- read_program_preload_manifest(source_package = "opencltools")
  r_path <- load_program_preload(
    source_package = "opencltools",
    manifest = manifest
  )
  cpp_path <- load_program_preload(source_package = "opencltools")
  expect_equal(as.character(r_path), as.character(cpp_path))
  expect_equal(attr(r_path, "n_entries"), attr(cpp_path, "n_entries"))
})

test_that("write_program_preload_manifest round-trips", {
  orig <- read_program_preload_manifest(source_package = "opencltools")
  td <- tempfile("preload_manifest")
  dir.create(td, showWarnings = FALSE)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)

  tsv_out <- file.path(td, "program_preload_manifest.tsv")
  obj <- write_program_preload_manifest(
    manifest = orig,
    manifest_path = tsv_out,
    source_package = "opencltools",
    write = TRUE
  )
  expect_true(file.exists(tsv_out))
  expect_true(file.exists(sub("\\.tsv$", ".rds", tsv_out, ignore.case = TRUE)))

  again <- read_program_preload_manifest(
    source_package = "opencltools",
    manifest_path = tsv_out
  )
  expect_equal(again, orig)
  expect_equal(obj$entries, orig)
})

test_that("load_library_for_kernel_cross_package loads nmath subset", {
  src <- load_library_for_kernel_cross_package(
    kernel_relative_path = "src/dnorm_kernel.cl",
    kernel_package = "opencltools",
    library_subdir = "nmath_small",
    library_package = "opencltools",
    depends_tag = "all_depends_nmath"
  )
  expect_s3_class(src, "nmathopencl_concatenated_lib")
  expect_gt(nchar(src[[1L]], type = "bytes"), 100L)
})

test_that("load_library_for_kernel_cross_package returns empty when no tag", {
  src <- load_library_for_kernel_cross_package(
    kernel_relative_path = "src/r_check_stack_kernel.cl",
    kernel_package = "opencltools",
    library_subdir = "nmath_small",
    library_package = "opencltools",
    depends_tag = "all_depends_nmath"
  )
  expect_s3_class(src, "nmathopencl_concatenated_lib")
  expect_equal(nchar(src[[1L]], type = "bytes"), 0L)
})
