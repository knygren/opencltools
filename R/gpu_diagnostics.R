#' GPU and OpenCL Diagnostics for \pkg{glmbayes}
#'
#' @description
#' A collection of tools for detecting GPU hardware, verifying OpenCL
#' availability, checking driver installation, validating environment
#' configuration, and diagnosing whether \pkg{glmbayes} can use GPU
#' acceleration. These functions provide both high-level diagnostic
#' summaries and low-level checks of system components such as PATH,
#' library directories, OpenCL headers, and the ICD loader.
#'
#' The diagnostic workflow is centered around
#' \code{diagnose_glmbayes()}, which orchestrates all other checks and
#' prints a detailed, human-readable report. Lower-level helpers can be
#' called individually for programmatic inspection or automated testing.
#' @param info A list returned by `detect_environment_and_gpus()`. The list must
#'   contain the following elements:
#'   \describe{
#'     \item{environment}{One of "windows", "msys2", "linux", "wsl", or "unknown".}
#'     \item{nvidia}{A list with elements `present` (logical) and `names` (character).}
#'     \item{amd}{A list with elements `present` (logical) and `names` (character).}
#'     \item{intel}{A list with elements `present` (logical) and `names` (character).}
#'   }
#' @param lib_dirs A list of OpenCL directories
#' @param runtime_info The structured list returned by \code{detect_compute_runtimes()}.
#' @section High-level diagnostic:
#' \itemize{
#'   \item \code{diagnose_glmbayes()} --- full GPU/OpenCL diagnostic report.
#' }
#'
#' @section Environment and hardware detection:
#' \itemize{
#'   \item \code{detect_environment_and_gpus()} --- detect OS and GPU vendor.
#'   \item \code{gpu_names()} --- enumerate available GPU device names.
#'   \item \code{detect_compute_runtimes()} --- detect CUDA/OpenCL runtimes.
#' }
#'
#' @section OpenCL availability and runtime checks:
#' \itemize{
#'   \item \code{has_opencl()} --- quick check for OpenCL support.
#'   \item \code{opencl_fp64_available()}, \code{opencl_device_info()} ---
#'     double-precision OpenCL device selection (cached probe).
#'   \item \code{verify_opencl_runtime()} --- probe OpenCL platform/device availability.
#'   \item \code{check_runtime_env()} --- validate PATH and library directories.
#' }
#'
#' @section Driver installation helpers:
#' \itemize{
#'   \item \code{detect_or_install_gpu_drivers()} --- detect driver presence and issues.
#' }
#'
#' @section PATH and library path utilities:
#' These are optional helpers used by the diagnostic pipeline.
#' \itemize{
#'   \item \code{add_to_path_windows()}
#'   \item \code{add_to_path_linux()}
#'   \item \code{add_to_libpath_linux()}
#' }
#'
#' @details
#' GPU acceleration speeds up embarrassingly parallel kernel workloads when a
#' downstream package passes \code{use_opencl = TRUE} to its own OpenCL-backed
#' entry points (for example envelope evaluation in \pkg{glmbayes}). OpenCL is
#' **vendor-neutral** (NVIDIA, AMD, Intel); CPU-only builds remain valid when
#' no OpenCL stack is present.
#'
#' **Practical setup (summary).** Prebuilt binaries from CRAN or R-universe
#' are often built **without** OpenCL GPU support; enabling the GPU path
#' usually requires installing the consuming package **from source** on a machine
#' with OpenCL **headers**, a linkable **OpenCL library / ICD loader**, and
#' a working **vendor runtime** (GPU driver).
#'
#' **What this help page checks.** A usable OpenCL environment requires:
#' \enumerate{
#'   \item OpenCL headers (e.g., \code{CL/cl.h}) at compile time,
#'   \item the OpenCL ICD loader (e.g., \code{libOpenCL.so.1}) at runtime,
#'   \item correct PATH and library search paths (especially on Linux/WSL),
#'   \item a functional OpenCL platform and device (driver installed).
#' }
#' The functions here inspect these pieces. On Linux and WSL,
#' \code{verify_opencl_runtime()} tries to create a platform, device, context,
#' queue, and compile a minimal kernel. On Windows, that probe is skipped
#' because platform-creation failures are often uninformative; rely on
#' \code{diagnose_glmbayes()} and driver/runtime detection instead.
#'
#' Start with \code{\link{diagnose_glmbayes}()} for a single readable report;
#' use \code{\link{has_opencl}()} for a quick boolean when scripting.
#'
#' @return
#' \describe{
#'   \item{\code{diagnose_glmbayes()}}{
#'     Called for side effects (prints a report). Invisibly returns a named
#'     \code{list} with \code{environment_info}, \code{driver_status},
#'     \code{runtime_status}, \code{env_diag}, \code{opencl_runtime_probe}
#'     (logical or \code{NA}), and \code{opencl_enabled} (logical or \code{NA}).
#'   }
#'   \item{\code{detect_environment_and_gpus()}}{
#'     Named \code{list}: \code{environment} (character: \code{windows},
#'     \code{linux}, \code{wsl}, \code{msys2}, or \code{unknown}); \code{nvidia},
#'     \code{amd}, and \code{intel} each a \code{list(present, names)}.
#'   }
#'   \item{\code{gpu_names()}}{
#'     \code{character} GPU name(s) from \code{nvidia-smi} on Linux; on other
#'     platforms a one-element informational character vector.
#'   }
#'   \item{\code{detect_or_install_gpu_drivers(info)}}{
#'     \code{list(environment, drivers)} with per-vendor \code{installed},
#'     \code{issues}, and \code{actions} character vectors.
#'   }
#'   \item{\code{detect_compute_runtimes(info)}}{
#'     \code{list(environment, runtimes)} with nested CUDA/OpenCL path lists and
#'     \code{headers_present}, \code{runtime_present}, and \code{installed}
#'     flags per vendor.
#'   }
#'   \item{\code{check_runtime_env(runtime_info)}}{
#'     \code{list(environment, diagnostics)} comparing detected bin/lib dirs to
#'     current \code{PATH} and \code{LD_LIBRARY_PATH}: \code{found_path_dirs},
#'     \code{missing_path_dirs}, \code{found_lib_dirs}, \code{missing_lib_dirs},
#'     and \code{include_dirs} per vendor/runtime.
#'   }
#'   \item{\code{has_opencl()}}{
#'     Logical scalar: \code{TRUE} if this \strong{build} of \pkg{opencltools}
#'     was compiled with OpenCL (\code{USE_OPENCL}), not whether a GPU is usable.
#'   }
#'   \item{\code{opencl_device_info(force, details)}}{
#'     \code{list} with \code{ok}, \code{reason}, platform/device indices and
#'     name strings, \code{extension_cl_khr_fp64}, \code{probe_fp64_ok},
#'     \code{selection_policy}; optional \code{candidates} if \code{details = TRUE}.
#'     On CPU-only builds, \code{ok = FALSE} with reason
#'     \code{"OpenCL not compiled in"}.
#'   }
#'   \item{\code{opencl_fp64_available(force)}}{
#'     Logical scalar: \code{TRUE} if the cached device passes the
#'     \code{cl_khr_fp64} extension and compile probe.
#'   }
#'   \item{\code{opencl_reset_device_selection()}}{
#'     No return value, called for side effects (clears the device-selection
#'     cache). Invisibly returns \code{NULL}.
#'   }
#'   \item{\code{verify_opencl_runtime(lib_dirs)}}{
#'     Logical scalar: \code{TRUE} if a temporary program linked against
#'     \code{libOpenCL} and \code{clGetPlatformIDs} succeeded;
#'     \code{FALSE} if libraries or compile/run failed.
#'   }
#'   \item{\code{get_opencl_core_count()}}{
#'     Integer scalar: total GPU compute units across platforms when OpenCL is
#'     compiled in; \code{1} on CPU-only builds (stub).
#'   }
#' }
#'
#' @seealso
#' \code{\link{diagnose_glmbayes}},
#' \code{\link{detect_environment_and_gpus}},
#' \code{\link{detect_compute_runtimes}},
#' \code{\link{verify_opencl_runtime}},
#' \code{\link{has_opencl}}.
#'
#' @keywords diagnostics gpu opencl environment
#' @example inst/examples/Ex_gpu_diagnostics.R
#' @name gpu_diagnostics
NULL



#' @export
#' @rdname gpu_diagnostics
#' @order 1
diagnose_glmbayes <- function() {
  cat("=== glmbayes Diagnostic Report ===\n")
  
  # Step 1: Environment + GPU detection
  info     <- detect_environment_and_gpus()
  drivers  <- detect_or_install_gpu_drivers(info)
  runtimes <- detect_compute_runtimes(info)
  env_diag <- check_runtime_env(runtimes)
  vendor_env_diag <- NULL
  runtime_ok <- NA
  
  cat("Environment:", info$environment, "\n\n")
  
  # Step 2: Preference order (NVIDIA > AMD > Intel)
  gpu_vendor <- if (info$nvidia$present) "nvidia"
  else if (info$amd$present) "amd"
  else if (info$intel$present) "intel"
  else NULL
  
  if (!is.null(gpu_vendor)) {
    cat("GPU:", toupper(gpu_vendor), "\n")
    drv  <- drivers$drivers[[gpu_vendor]]
    rt   <- runtimes$runtimes[[gpu_vendor]]
    vendor_env_diag <- env_diag$diagnostics[[gpu_vendor]]
    
    # 1. Driver check
    if (drv$installed) {
      cat("  [OK] Driver installed\n")
    } else {
      cat("  [FAIL] Driver not installed\n")
      if (length(drv$issues) > 0)
        cat("    Issues:", paste(drv$issues, collapse=", "), "\n")
    }
    
    # 2. OpenCL header/runtime presence (NEW LOGIC)
    hdr <- rt$opencl$headers_present
    rtm <- rt$opencl$runtime_present
    inst <- rt$opencl$installed   # AND of both
    
    if (hdr) {
      cat("  [OK] OpenCL headers found (CL/cl.h)\n")
    } else {
      cat("  [FAIL] OpenCL headers not found (CL/cl.h missing)\n")
    }
    
    if (rtm) {
      cat("  [OK] OpenCL runtime found (OpenCL.dll / ICD)\n")
    } else {
      cat("  [FAIL] OpenCL runtime not found\n")
    }
    
    if (inst) {
      cat("  [OK] OpenCL fully available (headers + runtime)\n")
    } else {
      cat("  [FAIL] OpenCL incomplete (missing headers or runtime)\n")
    }
    
    # 3. PATH/lib environment validation
    paths_ok <- (length(vendor_env_diag$opencl$missing_path_dirs) == 0 &&
                   length(vendor_env_diag$opencl$missing_lib_dirs) == 0)
    
    if (paths_ok) {
      cat("  [OK] Required PATH and library dirs present\n")
    } else {
      if (length(vendor_env_diag$opencl$missing_path_dirs) > 0)
        cat("  [WARN] Missing PATH entries:",
            paste(vendor_env_diag$opencl$missing_path_dirs, collapse=", "), "\n")
      if (length(vendor_env_diag$opencl$missing_lib_dirs) > 0)
        cat("  [WARN] Missing library dirs:",
            paste(vendor_env_diag$opencl$missing_lib_dirs, collapse=", "), "\n")
    }
    
    # 4. Runtime probe (Linux/WSL only)
    runtime_ok <- NA
    if (paths_ok && tolower(info$environment) %in% c("linux", "wsl")) {
      runtime_ok <- verify_opencl_runtime(rt$opencl$lib_dirs)
      if (runtime_ok) {
        cat("  [OK] OpenCL runtime probe succeeded (platform available)\n")
      } else {
        cat("  [FAIL] OpenCL runtime probe failed (no usable platform)\n")
      }
    } else if (!paths_ok) {
      cat("  [SKIP] Runtime probe skipped (missing PATH/lib dirs)\n")
    } else {
      cat("  [SKIP] Runtime probe skipped on Windows\n")
    }
    
  } else {
    cat("[FAIL] No supported GPU detected. glmbayes will run in CPU-only mode.\n")
  }
  
  # Step 3: Report compile-time OpenCL status
  opencl_enabled <- NA
  if (exists("has_opencl") && is.function(has_opencl)) {
    opencl_enabled <- has_opencl()
    if (opencl_enabled) {
      cat("\n[OK] glmbayes was compiled with OpenCL support.\n")
    } else {
      cat("\n[FAIL] glmbayes was compiled without OpenCL support.\n")
    }
  }
  
  # Step 4: Interactive PATH/lib fixes (only when a GPU vendor was identified)
  if (!is.null(vendor_env_diag) && !is.null(vendor_env_diag$opencl)) {
    missing_items <- (length(vendor_env_diag$opencl$missing_path_dirs) > 0 ||
                        length(vendor_env_diag$opencl$missing_lib_dirs) > 0)
    
    if (missing_items && !isTRUE(opencl_enabled) && interactive()) {
      cat("\n[INFO] Missing PATH/lib entries detected and OpenCL is not enabled.\n")
      
      if (length(vendor_env_diag$opencl$missing_path_dirs) > 0) {
        cat("  Missing PATH entries:\n")
        cat("   -", paste(vendor_env_diag$opencl$missing_path_dirs, collapse="\n   - "), "\n")
        ans <- readline("Would you like to permanently add missing PATH dirs? [y/N]: ")
        if (tolower(ans) == "y") {
          if (tolower(info$environment) == "windows") {
            add_to_path_windows(vendor_env_diag$opencl$missing_path_dirs)
          } else {
            add_to_path_linux(vendor_env_diag$opencl$missing_path_dirs)
          }
        }
      }
      
      if (length(vendor_env_diag$opencl$missing_lib_dirs) > 0 &&
          tolower(info$environment) %in% c("linux", "wsl")) {
        cat("  Missing library dirs:\n")
        cat("   -", paste(vendor_env_diag$opencl$missing_lib_dirs, collapse="\n   - "), "\n")
        ans_lib <- readline("Would you like to permanently add missing library dirs to LD_LIBRARY_PATH? [y/N]: ")
        if (tolower(ans_lib) == "y") {
          add_to_libpath_linux(vendor_env_diag$opencl$missing_lib_dirs)
        }
      }
    }
  }
  
  cat("\n=== End of Diagnostic Report ===\n")
  
  invisible(list(
    environment_info      = info,
    driver_status         = drivers,
    runtime_status        = runtimes,
    env_diag              = env_diag,
    opencl_runtime_probe  = runtime_ok,
    opencl_enabled        = opencl_enabled
  ))
}


#' @export
#' @rdname gpu_diagnostics
#' @order 2

detect_environment_and_gpus <- function() {
  
  # -------------------------------
  # 1. Detect environment
  # -------------------------------
  sysname <- Sys.info()[["sysname"]]
  
  uname_s <- try(system("uname -s", intern = TRUE), silent = TRUE)
  if (inherits(uname_s, "try-error")) {
    uname_s <- ""
  }
  
  if (grepl("MINGW", uname_s)) {
    env <- "msys2"
  } else if (identical(sysname, "Windows")) {
    env <- "windows"
  } else {
    if (file.exists("/proc/version")) {
      v <- readLines("/proc/version", warn = FALSE)
      if (any(grepl("Microsoft", v, ignore.case = TRUE))) {
        env <- "wsl"
      } else {
        env <- "linux"
      }
    } else {
      env <- "unknown"
    }
  }
  
  # -------------------------------
  # 2. Detect NVIDIA GPU
  # -------------------------------
  has_nvidia   <- FALSE
  nvidia_names <- NULL
  
  if (env %in% c("windows", "msys2")) {
    
    nvidia_path <- suppressWarnings(
      try(system("where.exe nvidia-smi", intern = TRUE), silent = TRUE)
    )
    
    has_nvidia <- !inherits(nvidia_path, "try-error") &&
      length(nvidia_path) > 0L &&
      any(nzchar(nvidia_path))
    
    if (has_nvidia) {
      nvidia_names <- try(
        system("nvidia-smi --query-gpu=name --format=csv,noheader", intern = TRUE),
        silent = TRUE
      )
      if (inherits(nvidia_names, "try-error")) {
        nvidia_names <- NULL
      }
    }
    
  } else {
    
    has_nvidia <- (system("command -v nvidia-smi >/dev/null 2>&1",
                          intern = FALSE) == 0L)
    
    if (has_nvidia) {
      nvidia_names <- try(
        system("env LD_LIBRARY_PATH=/usr/lib/wsl/lib:$LD_LIBRARY_PATH /usr/bin/nvidia-smi --query-gpu=name --format=csv,noheader", intern = TRUE),
        silent = TRUE
      )
      if (inherits(nvidia_names, "try-error")) {
        nvidia_names <- NULL
      }
    }
  }
  
  # -------------------------------
  # 3. Detect AMD + Intel on Windows/MSYS2
  # -------------------------------
  amd_names   <- NULL
  intel_names <- NULL
  has_amd     <- FALSE
  has_intel   <- FALSE
  
  if (env %in% c("windows", "msys2")) {
    
    gpu_list <- suppressWarnings(
      try(
        system(
          'powershell -Command "Get-CimInstance Win32_VideoController | Select-Object -ExpandProperty Name"',
          intern = TRUE
        ),
        silent = TRUE
      )
    )
    
    if (!inherits(gpu_list, "try-error") && length(gpu_list) > 0L) {
      
      amd_names   <- grep("AMD|Radeon", gpu_list, value = TRUE, ignore.case = TRUE)
      intel_names <- grep("Intel", gpu_list, value = TRUE, ignore.case = TRUE)
      
      has_amd   <- length(amd_names)   > 0L
      has_intel <- length(intel_names) > 0L
    }
  }
  
  # -------------------------------
  # 4. Detect AMD + Intel on Linux (NOT WSL)
  # -------------------------------
  if (env == "linux") {
    
    if (system("command -v lspci >/dev/null 2>&1", intern = FALSE) == 0L) {
      
      pci <- try(system("lspci", intern = TRUE), silent = TRUE)
      
      if (!inherits(pci, "try-error") && length(pci) > 0L) {
        
        controller_lines <- grep("VGA compatible controller|3D controller",
                                 pci, value = TRUE, ignore.case = TRUE)
        
        amd_names_linux <- grep("(AMD|ATI)", controller_lines,
                                value = TRUE, ignore.case = TRUE)
        
        intel_names_linux <- grep("Intel", controller_lines,
                                  value = TRUE, ignore.case = TRUE)
        
        if (length(amd_names_linux) > 0L) {
          amd_names <- amd_names_linux
          has_amd <- TRUE
        }
        
        if (length(intel_names_linux) > 0L) {
          intel_names <- intel_names_linux
          has_intel <- TRUE
        }
      }
    }
  }
  
  # -------------------------------
  # 5. WSL: force AMD/Intel to FALSE
  # -------------------------------
  if (env == "wsl") {
    has_amd <- FALSE
    has_intel <- FALSE
    amd_names <- NULL
    intel_names <- NULL
  }
  
  # -------------------------------
  # Return structured result
  # -------------------------------
  list(
    environment = env,
    nvidia = list(
      present = isTRUE(has_nvidia),
      names   = nvidia_names
    ),
    amd = list(
      present = isTRUE(has_amd),
      names   = amd_names
    ),
    intel = list(
      present = isTRUE(has_intel),
      names   = intel_names
    )
  )
}


#' @export
#' @rdname gpu_diagnostics
#' @order 3
gpu_names <- function() {
  .gpu_names_cpp()
}





#' @export
#' @rdname gpu_diagnostics
#' @order 4
detect_or_install_gpu_drivers <- function(info) {
  env <- info$environment
  
  result <- list(
    environment = env,
    drivers = list(
      nvidia = list(installed = FALSE, issues = character(), actions = character()),
      amd    = list(installed = FALSE, issues = character(), actions = character()),
      intel  = list(installed = FALSE, issues = character(), actions = character())
    )
  )
  
  # ------------------------------------------------------------------
  # NVIDIA DRIVER CHECK
  # ------------------------------------------------------------------
  if (isTRUE(info$nvidia$present)) {
    
    if (env %in% c("windows", "msys2")) {
      
      if (nzchar(Sys.which("nvidia-smi"))) {
        result$drivers$nvidia$installed <- TRUE
      } else {
        result$drivers$nvidia$issues <- c("NVIDIA driver not detected on Windows")
        result$drivers$nvidia$actions <- c(
          "Install NVIDIA Studio Driver from https://www.nvidia.com/Download"
        )
      }
      
    } else if (env == "linux") {
      
      if (nzchar(Sys.which("nvidia-smi"))) {
        result$drivers$nvidia$installed <- TRUE
      } else {
        result$drivers$nvidia$issues <- c("NVIDIA driver not detected on Linux")
        result$drivers$nvidia$actions <- c(
          "Install NVIDIA driver: sudo ubuntu-drivers autoinstall",
          "Or manually: sudo apt install nvidia-driver-550"
        )
      }
      
    } else if (env == "wsl") {
      
      if (!file.exists("/dev/dxg")) {
        result$drivers$nvidia$issues <- c(
          "WSL GPU virtualization not available (/dev/dxg missing)"
        )
        result$drivers$nvidia$actions <- c(
          "Your GPU cannot be exposed to WSL. Use Windows-native GPU compute instead."
        )
      } else if (!nzchar(Sys.which("nvidia-smi"))) {
        result$drivers$nvidia$issues <- c(
          "NVIDIA driver not detected inside WSL"
        )
        result$drivers$nvidia$actions <- c(
          "Install NVIDIA Studio Driver in Windows. WSL does not use Linux NVIDIA drivers."
        )
      } else {
        result$drivers$nvidia$installed <- TRUE
      }
    }
  }
  
  # ------------------------------------------------------------------
  # AMD DRIVER CHECK
  # ------------------------------------------------------------------
  if (isTRUE(info$amd$present)) {
    
    if (env %in% c("windows", "msys2")) {
      
      result$drivers$amd$installed <- TRUE
      
    } else if (env == "linux") {
      
      icd_files <- character()
      if (dir.exists("/etc/OpenCL/vendors")) {
        icd_files <- list.files("/etc/OpenCL/vendors", full.names = TRUE)
      }
      
      if (any(grepl("amdocl", icd_files))) {
        result$drivers$amd$installed <- TRUE
      } else {
        result$drivers$amd$issues <- c("AMD OpenCL ICD not detected")
        result$drivers$amd$actions <- c(
          "Install AMD OpenCL or ROCm packages (distribution specific)"
        )
      }
      
    } else if (env == "wsl") {
      
      result$drivers$amd$issues <- c(
        "AMD GPUs cannot be exposed to WSL. WSL GPU compute requires NVIDIA."
      )
      result$drivers$amd$actions <- c(
        "Use Windows-native GPU compute instead."
      )
    }
  }
  
  # ------------------------------------------------------------------
  # INTEL DRIVER CHECK
  # ------------------------------------------------------------------
  if (isTRUE(info$intel$present)) {
    
    if (env %in% c("windows", "msys2")) {
      
      result$drivers$intel$installed <- TRUE
      
    } else if (env == "linux") {
      
      icd_files <- character()
      if (dir.exists("/etc/OpenCL/vendors")) {
        icd_files <- list.files("/etc/OpenCL/vendors", full.names = TRUE)
      }
      
      if (any(grepl("intel", icd_files, ignore.case = TRUE))) {
        result$drivers$intel$installed <- TRUE
      } else {
        result$drivers$intel$issues <- c("Intel OpenCL ICD not detected")
        result$drivers$intel$actions <- c(
          "Install Intel OpenCL runtime (package name varies by distribution)"
        )
      }
      
    } else if (env == "wsl") {
      
      result$drivers$intel$issues <- c(
        "Intel GPUs cannot be exposed to WSL. WSL GPU compute requires NVIDIA."
      )
      result$drivers$intel$actions <- c(
        "Use Windows-native GPU compute instead."
      )
    }
  }
  
  return(result)
}



#' @export
#' @rdname gpu_diagnostics
#' @order 5

detect_compute_runtimes <- function(info) {
  env <- info$environment
  
  result <- list(
    environment = env,
    runtimes = list(
      nvidia = list(
        cuda   = list(
          installed      = FALSE,
          bin_dirs       = character(),
          include_dirs   = character(),
          lib_dirs       = character()
        ),
        opencl = list(
          installed        = FALSE,
          headers_present  = FALSE,
          runtime_present  = FALSE,
          bin_dirs         = character(),
          include_dirs     = character(),
          lib_dirs         = character()
        )
      ),
      amd = list(
        opencl = list(
          installed        = FALSE,
          headers_present  = FALSE,
          runtime_present  = FALSE,
          bin_dirs         = character(),
          include_dirs     = character(),
          lib_dirs         = character()
        )
      ),
      intel = list(
        opencl = list(
          installed        = FALSE,
          headers_present  = FALSE,
          runtime_present  = FALSE,
          bin_dirs         = character(),
          include_dirs     = character(),
          lib_dirs         = character()
        )
      )
    )
  )
  
  # -------------------------------
  # Linux / WSL logic
  # -------------------------------
  if (env %in% c("linux", "wsl")) {
    # ---- Header detection via GCC include paths ----
    inc_dirs <- try(
      system("echo | gcc -E -x c++ - -v 2>&1 | grep '^ /' | sed 's/^ //'", intern = TRUE),
      silent = TRUE
    )
    if (!inherits(inc_dirs, "try-error")) {
      for (d in inc_dirs) {
        if (file.exists(file.path(d, "CL", "cl.h"))) {
          result$runtimes$nvidia$opencl$include_dirs <- unique(
            c(result$runtimes$nvidia$opencl$include_dirs, d)
          )
        }
      }
    }
    
    # ---- Library detection via GCC link search paths ----
    raw_lib_dirs <- try(
      system("gcc -Xlinker --verbose 2>&1 | grep SEARCH_DIR | sed 's/SEARCH_DIR(\"=*\\([^\\\"]*\\)\").*/\\1/'", 
             intern = TRUE),
      silent = TRUE
    )
    if (!inherits(raw_lib_dirs, "try-error")) {
      alt_lib_dirs <- gsub("/usr/local", "/usr", raw_lib_dirs)
      system_lib_dirs <- sort(unique(c(raw_lib_dirs, alt_lib_dirs)))
      
      ## Changes to try to detect the true path
      for (d in system_lib_dirs) {
        hits <- Sys.glob(file.path(d, "libOpenCL.so*"))
        if (length(hits) > 0) {
          result$runtimes$nvidia$opencl$lib_dirs <- unique(
            c(result$runtimes$nvidia$opencl$lib_dirs, d)
          )
        }
      }
      
      
      
    }
    
    # ---- Derive headers/runtime/installed flags (Linux/WSL) ----
    nvidia_oc <- result$runtimes$nvidia$opencl
    headers_present <- length(nvidia_oc$include_dirs) > 0
    runtime_present <- length(nvidia_oc$lib_dirs)     > 0
    
    result$runtimes$nvidia$opencl$headers_present <- headers_present
    result$runtimes$nvidia$opencl$runtime_present <- runtime_present
    result$runtimes$nvidia$opencl$installed       <- headers_present && runtime_present
    
    # CUDA detection (unchanged logic, but explicit)
    nvcc_path <- Sys.which("nvcc")
    if (nzchar(nvcc_path)) {
      nvcc_path  <- normalizePath(nvcc_path, winslash = "/", mustWork = TRUE)
      cuda_root  <- normalizePath(file.path(dirname(nvcc_path), ".."), winslash = "/", mustWork = TRUE)
      cuda_include <- file.path(cuda_root, "include")
      cuda_lib     <- file.path(cuda_root, "lib64")
      
      result$runtimes$nvidia$cuda$installed  <- TRUE
      result$runtimes$nvidia$cuda$bin_dirs   <- dirname(nvcc_path)
      if (dir.exists(cuda_include)) result$runtimes$nvidia$cuda$include_dirs <- cuda_include
      if (dir.exists(cuda_lib))     result$runtimes$nvidia$cuda$lib_dirs     <- cuda_lib
    }
    
    # NOTE: You could extend analogous logic for AMD/Intel on Linux if needed
  }
  
  # -------------------------------
  # Windows / MSYS2 logic
  # -------------------------------
  if (env %in% c("windows", "msys2")) {
    search_paths <- character()
    
    # 1. PATH expansion
    path_dirs <- strsplit(Sys.getenv("PATH"), ";")[[1]]
    path_dirs <- path_dirs[nzchar(path_dirs)]
    search_paths <- c(search_paths, path_dirs)
    
    # 2. Environment variables
    for (var in c("OPENCL_HOME", "OPENCL_SDK")) {
      val <- Sys.getenv(var, unset = "")
      if (nzchar(val)) {
        for (sub in c("", "bin", "lib", "include", file.path("include", "CL"))) {
          path <- file.path(val, sub)
          if (dir.exists(path)) search_paths <- c(search_paths, path)
        }
      }
    }
    
    # 3. Known SDK roots
    sdk_roots <- c(
      "C:/Program Files/NVIDIA GPU Computing Toolkit/CUDA",
      "C:/Program Files (x86)/IntelSWTools/OpenCL SDK",
      "C:/Program Files (x86)/AMD APP SDK",
      "C:/Program Files (x86)/Intel/oneAPI"
    )
    for (root in sdk_roots) {
      if (dir.exists(root)) {
        search_paths <- c(
          search_paths,
          root,
          list.dirs(root, recursive = TRUE, full.names = TRUE)
        )
      }
    }
    
    # 4. Static fallbacks
    static_paths <- c("C:/OpenCL-SDK", "C:/opt", "C:/Program Files (x86)")
    for (path in static_paths) {
      if (dir.exists(path)) search_paths <- c(search_paths, path)
    }
    
    # -------------------------------
    # OpenCL header detection (Windows)
    # -------------------------------
    cl_header <- NULL
    for (dir in search_paths) {
      if (file.exists(file.path(dir, "CL", "cl.h"))) {
        cl_header <- file.path(dir, "CL", "cl.h")
        break
      }
    }
    
    if (!is.null(cl_header)) {
      cl_base     <- dirname(cl_header)
      opencl_home <- gsub("\\\\", "/", sub("[/\\\\]include[/\\\\]CL$", "", cl_base))
      include_flag <- file.path(opencl_home, "include")
      lib_flag     <- file.path(opencl_home, "lib", "x64")
      
      result$runtimes$nvidia$opencl$include_dirs <- 
        unique(c(result$runtimes$nvidia$opencl$include_dirs, include_flag))
      
      if (dir.exists(lib_flag)) {
        result$runtimes$nvidia$opencl$lib_dirs <- 
          unique(c(result$runtimes$nvidia$opencl$lib_dirs, lib_flag))
      }
    }
    
    # -------------------------------
    # OpenCL ICD runtime detection (Windows)
    # -------------------------------
    system32    <- file.path(Sys.getenv("SystemRoot"), "System32")
    syswow64    <- file.path(Sys.getenv("SystemRoot"), "SysWOW64")
    driverstore <- file.path(system32, "DriverStore", "FileRepository")
    
    icd_names <- c("nvopencl64.dll", "amdocl64.dll", "intelocl64.dll", "igdrcl64.dll", "pocl.dll")
    icd_found <- FALSE
    
    # Search System32 + SysWOW64 for ICDs (any vendor)
    for (d in c(system32, syswow64)) {
      for (nm in icd_names) {
        if (file.exists(file.path(d, nm))) icd_found <- TRUE
      }
    }
    
    # Search DriverStore recursively
    if (dir.exists(driverstore)) {
      hits <- list.files(
        driverstore,
        pattern  = paste(icd_names, collapse = "|"),
        recursive = TRUE,
        full.names = TRUE
      )
      if (length(hits) > 0) icd_found <- TRUE
    }
    
    # Registry search (Khronos OpenCL Vendors)
    reg_paths <- character()
    for (key in c(
      "HKEY_LOCAL_MACHINE\\SOFTWARE\\Khronos\\OpenCL\\Vendors",
      "HKEY_LOCAL_MACHINE\\SOFTWARE\\WOW6432Node\\Khronos\\OpenCL\\Vendors"
    )) {
      try({
        entries  <- suppressWarnings(utils::readRegistry(key, maxdepth = 1))
        reg_paths <- c(reg_paths, names(entries))
      }, silent = TRUE)
    }
    for (p in reg_paths) {
      if (file.exists(p)) {
        if (basename(p) %in% icd_names) icd_found <- TRUE
      }
    }
    
    # Loader path
    loader_path   <- file.path(Sys.getenv("SystemRoot"), "System32", "OpenCL.dll")
    loader_exists <- file.exists(loader_path)
    
    # Populate bin_dirs ONLY if loader + ICD exist
    if (loader_exists && icd_found) {
      loader_dir <- normalizePath(dirname(loader_path), winslash = "/", mustWork = FALSE)
      result$runtimes$nvidia$opencl$bin_dirs <- loader_dir
    }
    
    # -------------------------------
    # Derive headers/runtime/installed flags (Windows)
    # -------------------------------
    headers_present <- !is.null(cl_header)
    runtime_present <- loader_exists && icd_found
    
    result$runtimes$nvidia$opencl$headers_present <- headers_present
    result$runtimes$nvidia$opencl$runtime_present <- runtime_present
    result$runtimes$nvidia$opencl$installed       <- headers_present && runtime_present
    
    # NOTE: If you want AMD/Intel to be tracked separately on Windows,
    # you could inspect which ICD DLL was found and set their runtimes
    # accordingly. For now, everything is funneled under nvidia$opencl.
    
    # -------------------------------
    # CUDA detection (Windows, unchanged logic)
    # -------------------------------
    nvcc_path <- Sys.which("nvcc.exe")
    if (nzchar(nvcc_path)) {
      nvcc_path   <- normalizePath(nvcc_path, winslash = "/", mustWork = TRUE)
      cuda_root   <- normalizePath(file.path(dirname(nvcc_path), ".."), winslash = "/", mustWork = TRUE)
      cuda_include <- file.path(cuda_root, "include")
      cuda_lib     <- file.path(cuda_root, "lib", "x64")
      
      result$runtimes$nvidia$cuda$installed  <- TRUE
      result$runtimes$nvidia$cuda$bin_dirs   <- dirname(nvcc_path)
      if (dir.exists(cuda_include)) result$runtimes$nvidia$cuda$include_dirs <- cuda_include
      if (dir.exists(cuda_lib))     result$runtimes$nvidia$cuda$lib_dirs     <- cuda_lib
    }
  }
  
  return(result)
}



#' @export
#' @rdname gpu_diagnostics
#' @order 6
has_opencl <- function() {
  .has_opencl_cpp()  # call the registered C++ routine directly
}

#' @describeIn gpu_diagnostics Cached OpenCL device selection for double-precision
#'   (\code{cl_khr_fp64}) kernels: enumerates platforms and devices, prefers GPU,
#'   checks the extension token, then verifies with a tiny \code{clBuildProgram}
#'   probe. Override with environment variables \code{NMATHOPENCL_PLATFORM_INDEX}
#'   and/or \code{NMATHOPENCL_DEVICE_INDEX} (0-based; device index is within the
#'   platform's device list). Use \code{\link{opencl_reset_device_selection}()}
#'   to clear the cache (e.g. after driver changes).
#'
#' @param force If \code{TRUE}, rerun discovery even when a previous selection is cached.
#' @param details If \code{TRUE}, include a \code{candidates} list describing every
#'   platform/device pair (extension flag and probe result per device).
#'
#' @export
#' @order 7
opencl_device_info <- function(force = FALSE, details = FALSE) {
  opencl_device_info_cpp_export(as.logical(force)[[1L]], as.logical(details)[[1L]])
}

#' @describeIn gpu_diagnostics Returns \code{TRUE} if a cached OpenCL device passes
#'   the \code{cl_khr_fp64} extension check and build probe used for double kernels.
#'
#' @export
#' @order 8
opencl_fp64_available <- function(force = FALSE) {
  opencl_fp64_available_cpp_export(as.logical(force)[[1L]])
}

#' @describeIn gpu_diagnostics Clears the process-local OpenCL device selection cache
#'   so the next kernel or \code{\link{opencl_device_info}()} run re-enumerates devices.
#'
#' @export
#' @order 9
opencl_reset_device_selection <- function() {
  invisible(opencl_reset_device_selection_cpp_export())
}


#' @export
#' @rdname gpu_diagnostics
#' @order 10
verify_opencl_runtime <- function(lib_dirs = NULL) {
  code <- '
  #define CL_TARGET_OPENCL_VERSION 300
  #include <CL/cl.h>
  int main() {
    cl_uint n = 0;
    cl_int status = clGetPlatformIDs(0, NULL, &n);
    if (status != CL_SUCCESS || n == 0) return 1;
    return 0;
  }'
  
  tf_c  <- tempfile(fileext = ".c")
  tf_exe <- tempfile("ocltest")
  writeLines(code, tf_c)
  
  # -----------------------------------------
  # 1. Locate actual libOpenCL.so* file
  # -----------------------------------------
  lib_path <- NULL
  
  if (!is.null(lib_dirs) && length(lib_dirs) > 0) {
    for (d in lib_dirs) {
      hits <- Sys.glob(file.path(d, "libOpenCL.so*"))
      if (length(hits) > 0) {
        lib_path <- hits[1]   # use first match
        break
      }
    }
  }
  
  # If still not found, try ldconfig
  if (is.null(lib_path)) {
    ld_hits <- try(
      system("ldconfig -p | grep -i opencl | awk '{print $NF}'", intern = TRUE),
      silent = TRUE
    )
    if (!inherits(ld_hits, "try-error") && length(ld_hits) > 0) {
      lib_path <- ld_hits[1]
    }
  }
  
  # If still not found, runtime probe cannot proceed
  if (is.null(lib_path)) {
    unlink(c(tf_c, tf_exe))
    return(FALSE)
  }
  
  lib_dir <- dirname(lib_path)
  
  # -----------------------------------------
  # 2. Attempt to compile using detected lib
  # -----------------------------------------
  compile_status <- suppressWarnings(
    system2("gcc", c(tf_c, paste0("-L", lib_dir), "-lOpenCL", "-o", tf_exe))
  )
  
  if (!is.numeric(compile_status) || compile_status != 0) {
    unlink(c(tf_c, tf_exe))
    return(FALSE)
  }
  
  # -----------------------------------------
  # 3. Attempt to run the test executable
  # -----------------------------------------
  run_status <- suppressWarnings(system2(tf_exe))
  unlink(c(tf_c, tf_exe))
  
  return(is.numeric(run_status) && run_status == 0)
}



#' @export
#' @rdname gpu_diagnostics
#' @order 11
check_runtime_env <- function(runtime_info) {
  # Helper: normalize paths for comparison
  normalize_for_compare <- function(p) {
    if (length(p) == 0) return(character(0))
    vapply(p, function(x) {
      tryCatch(
        tolower(normalizePath(x, winslash = "/", mustWork = FALSE)),
        error = function(e) tolower(gsub("\\\\", "/", x))
      )
    }, character(1))
  }
  
  env <- runtime_info$environment
  
  # Current environment variables
  current_path <- strsplit(Sys.getenv("PATH"),
                           ifelse(.Platform$OS.type == "windows", ";", ":"))[[1]]
  current_path <- normalize_for_compare(current_path)
  
  current_lib <- strsplit(Sys.getenv("LD_LIBRARY_PATH", unset=""), ":")[[1]]
  current_lib <- normalize_for_compare(current_lib)
  
  results <- list(environment = env, diagnostics = list())
  
  for (vendor in names(runtime_info$runtimes)) {
    vendor_info <- runtime_info$runtimes[[vendor]]
    results$diagnostics[[vendor]] <- list()
    
    for (runtime in names(vendor_info)) {
      rt <- vendor_info[[runtime]]
      
      expected_bin <- normalize_for_compare(rt$bin_dirs)
      expected_lib <- normalize_for_compare(rt$lib_dirs)
      
      # PATH comparison
      found_path <- intersect(expected_bin, current_path)
      missing_path <- setdiff(expected_bin, current_path)
      
      # Library comparison depends on environment
      if (env %in% c("windows", "msys2")) {
        # On Windows/MSYS2, LD_LIBRARY_PATH is not used; check existence
        found_lib <- Filter(dir.exists, rt$lib_dirs)
        missing_lib <- setdiff(rt$lib_dirs, found_lib)
      } else {
        # On Linux/WSL/macOS, compare against LD_LIBRARY_PATH
        found_lib <- intersect(expected_lib, current_lib)
        missing_lib <- setdiff(expected_lib, current_lib)
      }
      
      rt_result <- list(
        installed = rt$installed,
        found_path_dirs   = found_path,
        missing_path_dirs = missing_path,
        found_lib_dirs    = found_lib,
        missing_lib_dirs  = missing_lib,
        include_dirs      = rt$include_dirs
      )
      
      results$diagnostics[[vendor]][[runtime]] <- rt_result
    }
  }
  
  return(results)
}
