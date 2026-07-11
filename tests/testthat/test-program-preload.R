skip_if_not_installed <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    skip(paste("requires", pkg))
  }
}

test_that("read_program_preload_manifest reads nmathopencl manifest", {
  skip_if_not_installed("nmathopencl")

  manifest <- read_program_preload_manifest(source_package = "nmathopencl")
  expect_s3_class(manifest, "data.frame")
  expect_true(all(c("rank", "kind", "rel_path") %in% names(manifest)))
  expect_gt(nrow(manifest), 0L)
  expect_true(all(manifest$kind %in% c("file", "library")))
  expect_equal(manifest$rank, sort(manifest$rank))
})

test_that("load_program_preload returns non-empty prelude text", {
  skip_if_not_installed("nmathopencl")

  preload <- load_program_preload(source_package = "nmathopencl")
  expect_s3_class(preload, "opencltools_program_preload")
  expect_type(preload, "character")
  expect_gt(nchar(preload[[1L]], type = "bytes"), 1000L)
})

test_that("load_program_preload(manifest=) matches C++ loader", {
  skip_if_not_installed("nmathopencl")

  manifest <- read_program_preload_manifest(source_package = "nmathopencl")
  r_path <- load_program_preload(
    source_package = "nmathopencl",
    manifest = manifest
  )
  cpp_path <- load_program_preload(source_package = "nmathopencl")
  expect_equal(as.character(r_path), as.character(cpp_path))
  expect_equal(attr(r_path, "n_entries"), attr(cpp_path, "n_entries"))
})

test_that("write_program_preload_manifest round-trips", {
  skip_if_not_installed("nmathopencl")

  orig <- read_program_preload_manifest(source_package = "nmathopencl")
  td <- tempfile("preload_manifest")
  dir.create(td, showWarnings = FALSE)
  on.exit(unlink(td, recursive = TRUE), add = TRUE)

  tsv_out <- file.path(td, "program_preload_manifest.tsv")
  obj <- write_program_preload_manifest(
    manifest = orig,
    manifest_path = tsv_out,
    source_package = "nmathopencl",
    write = TRUE
  )
  expect_true(file.exists(tsv_out))
  expect_true(file.exists(sub("\\.tsv$", ".rds", tsv_out, ignore.case = TRUE)))

  again <- read_program_preload_manifest(
    source_package = "nmathopencl",
    manifest_path = tsv_out
  )
  expect_equal(again, orig)
  expect_equal(obj$entries, orig)
})

test_that("load_library_for_kernel_cross_package loads nmath subset", {
  skip_if_not_installed("nmathopencl")
  skip_if_not_installed("glmbayes")

  kernel_rel <- "src/f2_f3_gaussian.cl"
  kpath <- system.file("cl", kernel_rel, package = "glmbayes")
  skip_if_not(nzchar(kpath), "glmbayes gaussian kernel not installed")

  src <- load_library_for_kernel_cross_package(
    kernel_relative_path = kernel_rel,
    kernel_package = "glmbayes",
    library_subdir = "nmath",
    library_package = "nmathopencl",
    depends_tag = "all_depends_nmath"
  )
  expect_s3_class(src, "nmathopencl_concatenated_lib")
  expect_gt(nchar(src[[1L]], type = "bytes"), 100L)
})

test_that("load_library_for_kernel_cross_package returns empty when no tag", {
  skip_if_not_installed("nmathopencl")
  skip_if_not_installed("glmbayes")

  kernel_rel <- "src/f2_f3_poisson.cl"
  kpath <- system.file("cl", kernel_rel, package = "glmbayes")
  skip_if_not(nzchar(kpath), "glmbayes poisson kernel not installed")

  src <- load_library_for_kernel_cross_package(
    kernel_relative_path = kernel_rel,
    kernel_package = "glmbayes",
    library_subdir = "nmath",
    library_package = "nmathopencl",
    depends_tag = "all_depends_nmath"
  )
  expect_s3_class(src, "nmathopencl_concatenated_lib")
  expect_equal(nchar(src[[1L]], type = "bytes"), 0L)
})
