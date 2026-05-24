// configure_OpenCL.cpp
#ifdef USE_OPENCL
#include "openclPort.h"
// #include <iostream>   // removed: no direct stdout/stderr
#include <sstream>
#include <R.h>          // for Rprintf and Rf_error

// Utility to compile a tiny kernel calling `funcName(type(0))`.
// Returns true if compile succeeds under OpenCL C 1.2 (so expm1/log1p are defined).
static bool probeFunction(cl_context        context,
                          cl_device_id      device,
                          const std::string &funcName,
                          const std::string &typeDecl,
                          const std::string &extraPragma = "")
{
  // Build the tiny test kernel source
  std::ostringstream src;
  src << "__kernel void test_probe() {\n"
      << "  " << typeDecl
      << " x = " << funcName
      << "((" << typeDecl << ")0);\n"
      << "  (void)x;\n"
      << "}\n";

  const std::string code = src.str();
  const char *cstr      = code.c_str();
  cl_int err;

  // Create program from source
  cl_program prog = clCreateProgramWithSource(
    context,
    1,
    &cstr,
    nullptr,
    &err
  );
  if (err != CL_SUCCESS) {
    Rprintf("clCreateProgramWithSource failed: %d\n", err);
    clReleaseProgram(prog);
    return false;
  }

  // Build under OpenCL C 1.2 so that `double`, `expm1`, `log1p`, etc. exist
  err = clBuildProgram(
    prog,
    1,
    &device,
    "-cl-std=CL1.2",
    nullptr,
    nullptr
  );
  if (err != CL_SUCCESS) {
    // Print build log for debugging
    size_t logSize = 0;
    clGetProgramBuildInfo(
      prog,
      device,
      CL_PROGRAM_BUILD_LOG,
      0,
      nullptr,
      &logSize
    );
    std::string log(logSize, '\0');
    clGetProgramBuildInfo(
      prog,
      device,
      CL_PROGRAM_BUILD_LOG,
      logSize,
      &log[0],
          nullptr
    );
    Rprintf("Probe for %s failed:\n%s\n", funcName.c_str(), log.c_str());
  }

  clReleaseProgram(prog);
  return (err == CL_SUCCESS);
}

namespace openclPort {

OpenCLConfig configureOpenCL(cl_context   context,
                             cl_device_id device)
{
  OpenCLConfig cfg;

  // Enable double-precision functions for our probes
  const std::string pragmaFP64 =
    "#pragma OPENCL EXTENSION cl_khr_fp64 : enable";

  // Probe for native expm1(double) and log1p(double)
  cfg.have_expm1 = probeFunction(
    context,
    device,
    "expm1",
    "double",
    pragmaFP64
  );
  cfg.have_log1p = probeFunction(
    context,
    device,
    "log1p",
    "double",
    pragmaFP64
  );

  // Compose build-options string:
  // only the HAVE_EXPM1/HAVE_LOG1P macros, nothing else.
  std::ostringstream opts;
  opts << "-DHAVE_EXPM1=" << (cfg.have_expm1 ? "1" : "0") << " ";
  opts << "-DHAVE_LOG1P=" << (cfg.have_log1p ? "1" : "0");
  cfg.buildOptions = opts.str();

  return cfg;
}
}
#endif // USE_OPENCL
