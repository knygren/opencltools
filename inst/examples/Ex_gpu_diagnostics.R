############################ Start of gpu_diagnostics example ########################

\donttest{
has_opencl()

## Host-side inventory (no OpenCL runtime required)
info <- detect_environment_and_gpus()
info$environment
gpu_names()

runtime <- detect_compute_runtimes(info)
check_runtime_env(runtime)

## OpenCL device probes (compile tiny programs; skip when unavailable)
if (has_opencl()) {
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
