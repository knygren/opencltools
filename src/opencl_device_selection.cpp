#include "openclPort.h"
#include <sstream>

#ifdef USE_OPENCL

#include <CL/cl.h>
#include <algorithm>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <sstream>
#include <vector>

namespace openclPort {

namespace {

std::mutex g_fp64_sel_mutex;
bool g_fp64_sel_initialized = false;
OpenCLFp64DeviceCache g_cache;

static void clear_cache_to_invalid(const char* reason) {
  g_cache = OpenCLFp64DeviceCache();
  g_cache.valid = false;
  g_cache.reason = reason ? reason : "unknown";
}

static bool extension_has_token(const std::string& exts, const char* token) {
  if (exts.empty() || !token) return false;
  const size_t tlen = std::strlen(token);
  size_t i = 0;
  while (i < exts.size()) {
    while (i < exts.size() && (exts[i] == ' ' || exts[i] == '\t')) ++i;
    size_t j = i;
    while (j < exts.size() && exts[j] != ' ' && exts[j] != '\t') ++j;
    if (j > i) {
      size_t len = j - i;
      if (len == tlen && exts.compare(i, len, token) == 0)
        return true;
    }
    i = j + 1;
  }
  return false;
}

static std::string device_type_label(cl_device_type t) {
  if (t & CL_DEVICE_TYPE_GPU) return "GPU";
  if (t & CL_DEVICE_TYPE_CPU) return "CPU";
  if (t & CL_DEVICE_TYPE_ACCELERATOR) return "ACCELERATOR";
  return "OTHER";
}

static bool probe_fp64_kernel(cl_device_id device, std::string& build_log_out) {
  build_log_out.clear();
  const char* src =
      "#pragma OPENCL EXTENSION cl_khr_fp64 : enable\n"
      "__kernel void nmath_fp64_probe() {\n"
      "  volatile double x = (double)(1);\n"
      "  x = x + (double)(2);\n"
      "}\n";
  cl_int err = CL_SUCCESS;
  cl_context ctx = clCreateContext(nullptr, 1, &device, nullptr, nullptr, &err);
  if (err != CL_SUCCESS || ctx == nullptr) {
    build_log_out = "clCreateContext failed";
    return false;
  }

  cl_program prog = nullptr;
  bool ok = false;
  do {
    prog = clCreateProgramWithSource(ctx, 1, &src, nullptr, &err);
    if (err != CL_SUCCESS || prog == nullptr) {
      build_log_out = "clCreateProgramWithSource failed";
      break;
    }
    err = clBuildProgram(prog, 1, &device, "-cl-std=CL1.2", nullptr, nullptr);
    if (err == CL_SUCCESS) {
      ok = true;
      break;
    }
    size_t log_size = 0;
    cl_int g0 = clGetProgramBuildInfo(prog, device, CL_PROGRAM_BUILD_LOG, 0, nullptr, &log_size);
    if (g0 == CL_SUCCESS && log_size > 0) {
      std::string log(log_size, '\0');
      clGetProgramBuildInfo(prog, device, CL_PROGRAM_BUILD_LOG, log_size, &log[0], nullptr);
      while (!log.empty() && log.back() == '\0') log.pop_back();
      build_log_out = log;
    } else {
      build_log_out = "clBuildProgram failed (no log)";
    }
  } while (false);

  if (prog) clReleaseProgram(prog);
  clReleaseContext(ctx);
  return ok;
}

struct DeviceCandidate {
  int platform_index = -1;
  int device_index = -1;
  cl_platform_id platform = nullptr;
  cl_device_id device = nullptr;
  cl_device_type dtype = 0;
  bool is_gpu = false;
};

static int env_int(const char* name, int dflt) {
  const char* e = std::getenv(name);
  if (!e || !*e) return dflt;
  char* end = nullptr;
  long v = std::strtol(e, &end, 10);
  if (end == e) return dflt;
  return static_cast<int>(v);
}

static bool refresh_selection_unlocked() {
  clear_cache_to_invalid("uninitialized");

  cl_uint nplat = 0;
  cl_int st = clGetPlatformIDs(0, nullptr, &nplat);
  if (st != CL_SUCCESS || nplat == 0) {
    clear_cache_to_invalid("no_opencl_platforms");
    return false;
  }

  std::vector<cl_platform_id> platforms(static_cast<size_t>(nplat));
  st = clGetPlatformIDs(nplat, platforms.data(), nullptr);
  if (st != CL_SUCCESS) {
    clear_cache_to_invalid("clGetPlatformIDs_failed");
    return false;
  }

  const int env_pi = env_int("NMATHOPENCL_PLATFORM_INDEX", -1);
  const int env_di = env_int("NMATHOPENCL_DEVICE_INDEX", -1);

  std::vector<DeviceCandidate> cands;
  cands.reserve(32);

  for (cl_uint pi = 0; pi < nplat; ++pi) {
    if (env_pi >= 0 && static_cast<int>(pi) != env_pi)
      continue;

    cl_platform_id plat = platforms[static_cast<size_t>(pi)];
    cl_uint ndev = 0;
    st = clGetDeviceIDs(plat, CL_DEVICE_TYPE_ALL, 0, nullptr, &ndev);
    if (st != CL_SUCCESS || ndev == 0)
      continue;

    std::vector<cl_device_id> devs(static_cast<size_t>(ndev));
    st = clGetDeviceIDs(plat, CL_DEVICE_TYPE_ALL, ndev, devs.data(), nullptr);
    if (st != CL_SUCCESS)
      continue;

    for (cl_uint di = 0; di < ndev; ++di) {
      if (env_di >= 0 && static_cast<int>(di) != env_di)
        continue;

      cl_device_id dev = devs[static_cast<size_t>(di)];
      cl_device_type dt = 0;
      if (clGetDeviceInfo(dev, CL_DEVICE_TYPE, sizeof(dt), &dt, nullptr) != CL_SUCCESS)
        continue;

      DeviceCandidate c;
      c.platform_index = static_cast<int>(pi);
      c.device_index = static_cast<int>(di);
      c.platform = plat;
      c.device = dev;
      c.dtype = dt;
      c.is_gpu = (dt & CL_DEVICE_TYPE_GPU) != 0;
      cands.push_back(c);
    }
  }

  if (cands.empty()) {
    if (env_pi >= 0 || env_di >= 0)
      clear_cache_to_invalid("no_devices_match_NMATHOPENCL_*_INDEX");
    else
      clear_cache_to_invalid("no_opencl_devices");
    return false;
  }

  std::stable_sort(cands.begin(), cands.end(),
                   [](const DeviceCandidate& a, const DeviceCandidate& b) {
                     return a.is_gpu > b.is_gpu;
                   });

  const std::string policy =
      (env_pi >= 0 || env_di >= 0)
          ? std::string("fp64_first_gpu_preferred_with_env_override")
          : std::string("fp64_first_gpu_preferred");

  for (const DeviceCandidate& c : cands) {
    std::string exts = opencl_read_device_info_str(c.device, CL_DEVICE_EXTENSIONS);
    const bool has_ext = extension_has_token(exts, "cl_khr_fp64");

    std::string blog;
    bool probe_ok = false;
    if (has_ext)
      probe_ok = probe_fp64_kernel(c.device, blog);

    if (!has_ext || !probe_ok)
      continue;

    g_cache.valid = true;
    g_cache.reason.clear();
    g_cache.extension_cl_khr_fp64 = true;
    g_cache.probe_fp64_ok = true;
    g_cache.platform_index = c.platform_index;
    g_cache.device_index = c.device_index;
    g_cache.platform = (void*)c.platform;
    g_cache.device = (void*)c.device;
    g_cache.platform_vendor = opencl_read_platform_info_str(c.platform, CL_PLATFORM_VENDOR);
    g_cache.platform_name = opencl_read_platform_info_str(c.platform, CL_PLATFORM_NAME);
    g_cache.device_vendor = opencl_read_device_info_str(c.device, CL_DEVICE_VENDOR);
    g_cache.device_name = opencl_read_device_info_str(c.device, CL_DEVICE_NAME);
    g_cache.device_version = opencl_read_device_info_str(c.device, CL_DEVICE_VERSION);
    g_cache.driver_version = opencl_read_device_info_str(c.device, CL_DRIVER_VERSION);
    g_cache.device_type_label = device_type_label(c.dtype);
    g_cache.selection_policy = policy;
    g_cache.probe_failure_log.clear();
    return true;
  }

  clear_cache_to_invalid("no_fp64_capable_device");
  return false;
}

} // namespace

bool opencl_ensure_fp64_selection(bool force) {
  std::lock_guard<std::mutex> lock(g_fp64_sel_mutex);
  if (g_fp64_sel_initialized && !force)
    return g_cache.valid;
  const bool ok = refresh_selection_unlocked();
  g_fp64_sel_initialized = true;
  return ok;
}

const OpenCLFp64DeviceCache& opencl_fp64_selection() {
  std::lock_guard<std::mutex> lock(g_fp64_sel_mutex);
  if (!g_fp64_sel_initialized) {
    (void)refresh_selection_unlocked();
    g_fp64_sel_initialized = true;
  }
  return g_cache;
}

void opencl_reset_fp64_selection() {
  std::lock_guard<std::mutex> lock(g_fp64_sel_mutex);
  g_fp64_sel_initialized = false;
  clear_cache_to_invalid("reset");
}

bool opencl_fp64_available_impl(bool force) {
  return opencl_ensure_fp64_selection(force);
}

static Rcpp::List details_table() {
  cl_uint nplat = 0;
  cl_int st = clGetPlatformIDs(0, nullptr, &nplat);
  if (st != CL_SUCCESS || nplat == 0) {
    return Rcpp::List();
  }
  std::vector<cl_platform_id> platforms(static_cast<size_t>(nplat));
  clGetPlatformIDs(nplat, platforms.data(), nullptr);

  const int env_pi = env_int("NMATHOPENCL_PLATFORM_INDEX", -1);

  std::vector<int> v_pi, v_di, v_ext, v_prb;
  Rcpp::CharacterVector v_plv, v_pln, v_dv, v_dn, v_dtyp;

  for (cl_uint pi = 0; pi < nplat; ++pi) {
    if (env_pi >= 0 && static_cast<int>(pi) != env_pi)
      continue;
    cl_platform_id plat = platforms[static_cast<size_t>(pi)];
    cl_uint ndev = 0;
    st = clGetDeviceIDs(plat, CL_DEVICE_TYPE_ALL, 0, nullptr, &ndev);
    if (st != CL_SUCCESS || ndev == 0)
      continue;
    std::vector<cl_device_id> devs(static_cast<size_t>(ndev));
    clGetDeviceIDs(plat, CL_DEVICE_TYPE_ALL, ndev, devs.data(), nullptr);

    for (cl_uint di = 0; di < ndev; ++di) {
      cl_device_id dev = devs[static_cast<size_t>(di)];
      cl_device_type dt = 0;
      clGetDeviceInfo(dev, CL_DEVICE_TYPE, sizeof(dt), &dt, nullptr);
      std::string exts = opencl_read_device_info_str(dev, CL_DEVICE_EXTENSIONS);
      bool has_ext = extension_has_token(exts, "cl_khr_fp64");
      std::string blog;
      bool prb = false;
      if (has_ext)
        prb = probe_fp64_kernel(dev, blog);
      v_pi.push_back(static_cast<int>(pi));
      v_di.push_back(static_cast<int>(di));
      v_ext.push_back(has_ext ? 1 : 0);
      v_prb.push_back(prb ? 1 : 0);
      v_plv.push_back(opencl_read_platform_info_str(plat, CL_PLATFORM_VENDOR));
      v_pln.push_back(opencl_read_platform_info_str(plat, CL_PLATFORM_NAME));
      v_dv.push_back(opencl_read_device_info_str(dev, CL_DEVICE_VENDOR));
      v_dn.push_back(opencl_read_device_info_str(dev, CL_DEVICE_NAME));
      v_dtyp.push_back(device_type_label(dt));
    }
  }

  return Rcpp::List::create(
      Rcpp::Named("platform_index") = v_pi,
      Rcpp::Named("device_index") = v_di,
      Rcpp::Named("platform_vendor") = v_plv,
      Rcpp::Named("platform_name") = v_pln,
      Rcpp::Named("device_vendor") = v_dv,
      Rcpp::Named("device_name") = v_dn,
      Rcpp::Named("device_type") = v_dtyp,
      Rcpp::Named("extension_cl_khr_fp64") = v_ext,
      Rcpp::Named("probe_fp64_ok") = v_prb);
}

Rcpp::List opencl_device_info_rcpp(bool force, bool details) {
  (void)opencl_ensure_fp64_selection(force);
  const OpenCLFp64DeviceCache& c = opencl_fp64_selection();

  Rcpp::List L =
      Rcpp::List::create(Rcpp::Named("ok") = c.valid,
                         Rcpp::Named("reason") = c.reason,
                         Rcpp::Named("platform_index") = c.platform_index,
                         Rcpp::Named("device_index") = c.device_index,
                         Rcpp::Named("platform_vendor") = c.platform_vendor,
                         Rcpp::Named("platform_name") = c.platform_name,
                         Rcpp::Named("device_vendor") = c.device_vendor,
                         Rcpp::Named("device_name") = c.device_name,
                         Rcpp::Named("device_version") = c.device_version,
                         Rcpp::Named("driver_version") = c.driver_version,
                         Rcpp::Named("device_type") = c.device_type_label,
                         Rcpp::Named("extension_cl_khr_fp64") = c.extension_cl_khr_fp64,
                         Rcpp::Named("probe_fp64_ok") = c.probe_fp64_ok,
                         Rcpp::Named("selection_policy") = c.selection_policy,
                         Rcpp::Named("probe_failure_log") = c.probe_failure_log);

  if (details) {
    L["candidates"] = details_table();
  }
  return L;
}

} // namespace openclPort

#else // !USE_OPENCL

namespace openclPort {

bool opencl_ensure_fp64_selection(bool) {
  return false;
}

static OpenCLFp64DeviceCache g_stub;

const OpenCLFp64DeviceCache& opencl_fp64_selection() {
  g_stub = OpenCLFp64DeviceCache();
  g_stub.valid = false;
  g_stub.reason = "OpenCL not compiled in";
  return g_stub;
}

void opencl_reset_fp64_selection() {
}

bool opencl_fp64_available_impl(bool) {
  return false;
}

Rcpp::List opencl_device_info_rcpp(bool, bool details) {
  Rcpp::List L = Rcpp::List::create(
      Rcpp::Named("ok") = false,
      Rcpp::Named("reason") = std::string("OpenCL not compiled in"),
      Rcpp::Named("platform_index") = -1,
      Rcpp::Named("device_index") = -1,
      Rcpp::Named("platform_vendor") = NA_STRING,
      Rcpp::Named("platform_name") = NA_STRING,
      Rcpp::Named("device_vendor") = NA_STRING,
      Rcpp::Named("device_name") = NA_STRING,
      Rcpp::Named("device_version") = NA_STRING,
      Rcpp::Named("driver_version") = NA_STRING,
      Rcpp::Named("device_type") = NA_STRING,
      Rcpp::Named("extension_cl_khr_fp64") = false,
      Rcpp::Named("probe_fp64_ok") = false,
      Rcpp::Named("selection_policy") = std::string("none"),
      Rcpp::Named("probe_failure_log") = NA_STRING);
  if (details)
    L["candidates"] = Rcpp::List();
  return L;
}

} // namespace openclPort

#endif
