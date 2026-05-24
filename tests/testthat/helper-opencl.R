skip_if_no_opencl <- function() {
  skip_if(!opencltools::has_opencl(),
          "OpenCL not enabled in this build of opencltools")
}
