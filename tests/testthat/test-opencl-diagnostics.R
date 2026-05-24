test_that("has_opencl returns logical", {
  expect_type(opencltools::has_opencl(), "logical")
})

test_that("OpenCL fp64 probe when available", {
  skip_if_no_opencl()
  skip_on_cran() # avoids CPU vs elapsed NOTE on CRAN OpenCL builders
  expect_type(opencltools::opencl_fp64_available(), "logical")
})
