############################ Start of gpu_diagnostics example ########################

## Host-side inventory (no package USE_OPENCL .cpp)
info <- detect_environment_and_gpus()
info$environment
gpu_names()

runtime <- detect_compute_runtimes(info)
check_runtime_env(runtime)

\donttest{
## OpenCL device probes (package USE_OPENCL .cpp; skip when unavailable)
if (has_opencl()) {
  has_opencl()
  opencl_fp64_available()
  opencl_device_info()
  get_opencl_core_count()
  verify_opencl_runtime()

  # Full diagnostic report (prints; returns list invisibly)
  diag <- diagnose_glmbayes()
  names(diag)
}
}

###############################################################################
## End of gpu_diagnostics example
###############################################################################
