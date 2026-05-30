############################ Start of gpu_diagnostics example ########################

## Host-side inventory (no package USE_OPENCL .cpp)
info <- detect_environment_and_gpus()
info$environment
gpu_names()

runtime <- detect_compute_runtimes(info)
check_runtime_env(runtime)

## OpenCL device probes (stubs when !has_opencl(); full probes when NOT_CRAN)
## Inlined for CheckExEnv (unexported helpers are not visible during R CMD check).
if (!has_opencl() || identical(Sys.getenv("NOT_CRAN"), "true")) {
  opencl_fp64_available()
  opencl_device_info()
  get_opencl_core_count()
  verify_opencl_runtime()
} else {
  has_opencl()
}

# Full diagnostic report (prints; returns list invisibly)
diag <- diagnose_glmbayes()
names(diag)

###############################################################################
## End of gpu_diagnostics example
###############################################################################
