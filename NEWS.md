# opencltools 0.8.0

First CRAN release. Version **0.8.0** (rather than 0.1.0) signals that the
runtime toolkit is substantially complete and ready for downstream packages
(**nmathopencl**, **glmbayes**, and others) to link against, while leaving
room for integration-driven patch releases (planned **0.8.x**) and developer
feedback before a **1.0.0** API freeze.

**opencltools** is a library-agnostic runtime toolkit for R package developers
who ship optional OpenCL acceleration: device probing, kernel source loading,
dependency-annotated library assembly, subsetting, and maintainer-side
annotation helpers.

## Runtime and diagnostics

* **`has_opencl()`**, **`opencl_fp64_available()`**, **`opencl_device_info()`**,
  **`get_opencl_core_count()`**, and related helpers for probing devices and
  drivers before building or dispatching kernels.
* **`load_kernel_source()`** and **`load_kernel_library()`** load individual
  `.cl` files or annotated subdirectories from any installed package into
  concatenated source strings (R API and C++ **`openclPort`** via
  **`LinkingTo: opencltools`**).
* **`load_library_for_kernel()`** reads kernel dependency annotations and
  concatenates only the library shards a launcher kernel needs.
* **`verify_opencl_runtime()`**, **`detect_compute_runtimes()`**,
  **`check_runtime_env()`**, **`gpu_names()`**, and **`diagnose_glmbayes()`**
  for workstation- and package-level environment diagnosis.

## Kernel annotation and library maintenance

* **`attach_kernel_call_tags()`** (new): scan kernel source against a
  library's `@provides` list and write `@calls_<tag>`, `@depends_<tag>`, and
  `@calls_opencl_builtin` automatically.
* **`attach_cross_library_tags()`**: expand direct dependencies to a full
  transitive closure and write `@all_depends_<tag>`.
* **`attach_kernel_dependency_tags()`**, **`write_kernel_dependency_index()`**,
  **`stage_kernel_dependency_sort()`**, and **`extract_library_subset()`** for
  annotating, indexing, sorting, and vendoring `.cl` library trees.
* Curated **`opencl_known_failures.json`** with warnings when loading stems
  with known portability issues.

## Documentation and examples

* Three vignettes: OpenCL setup (**Chapter-01**), loading and assembling kernel
  programs (**Chapter-02**), and the kernel-runner / wrapper pattern
  (**Chapter-03**), using **`glmbayes`** / envelope-gradient methodology as a
  reference application.
* **`README`**: repositioned as library-agnostic; ecosystem table for
  **`opencltools`**, **`nmathopencl`**, and **`glmbayes`**; structured
  references including Nygren and Nygren (2006) and Stone et al. (2010).
* **`inst/CITATION`**: package manual, JASA (2006), OpenCL survey, and
  **`glmbayes`** reference-application entry.
* **`inst/examples/`**: runnable examples for diagnostics, kernel loading,
  tagging workflow, and library subsetting (OpenCL-heavy examples guarded with
  **`if (has_opencl())`** inside `\donttest{}`).

## CRAN / optional OpenCL behaviour

* **`configure`**: optional OpenCL at build time; CPU-only fallback when
  headers or runtime are absent.
* Examples and tests that compile or probe OpenCL devices use
  **`if (has_opencl())`** / **`skip_if_no_opencl()`** and
  **`skip_on_cran()`** where appropriate.

## Distribution

* Builds and checks on **R-universe**
  (<https://knygren.r-universe.dev/opencltools>).
* Maintainer CRAN / remote-check scripts under **`scripts/`** (excluded from
  the source tarball via **`.Rbuildignore`**).
