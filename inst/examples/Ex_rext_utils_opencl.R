\donttest{
if (has_opencl()) {
  n <- 5L

  r_check_user_interrupt_opencl(n, fallback = TRUE, verbose = TRUE)

  # Known linkage/runtime gap on some setups (stack hook symbol availability):
  # r_check_stack_opencl(n, fallback = TRUE, verbose = TRUE)
} else {
  message("OpenCL unavailable; skipping GPU-only example.")
}
}
