# opencltools 0.8.2

Patch release after CRAN **0.8.1**, enabling downstream integration in
**`nmathopencl`** and **`glmbayes`**.

* **Program preload manifest (R):** New **`read_program_preload_manifest()`**,
  **`load_program_preload()`**, and **`write_program_preload_manifest()`**
  wrap the C++ manifest loader shipped in step 4. A companion
  **`program_preload_manifest.rds`** can be written beside the **`.tsv`** for
  fast R-side reuse (same pattern as **`kernel_dependency_index.rds`**).
* **Cross-package library subsetting (R):** New
  **`load_library_for_kernel_cross_package()`** mirrors
  **`openclPort::load_library_for_kernel_cross_package()`** for interactive
  and test code (launcher kernel and **`nmath/`** tree in different packages).
* **`nmathopencl`** and **`glmbayes`** on CRAN now link against **`opencltools`**
  (`LinkingTo` / runtime integration); development continues on git and
  R-universe at this version.
* **Citation metadata:** **`inst/CITATION`** now cites this package and Stone
  et al. (2010) only (removed leftover **`glmbayes`** and JASA 2006 entries from
  the package split). **`inst/COPYRIGHTS`** and **`inst/REFERENCES.bib`** retargeted
  to **opencltools**; package-level **`@references`** aligned.
* **Examples and tests:** program-preload and cross-package loader examples use
  **opencltools** `inst/cl/` only (no **nmathopencl** / **glmbayes** in runnable
  examples). Added teaching **`program_preload_manifest.tsv`** under **`inst/cl/`**.
  **`write_program_preload_manifest`** is demonstrated with **`write = FALSE`**
  (no disk writes during **`R CMD check`**); round-trip I/O remains in **testthat**.

# opencltools 0.8.1

CRAN resubmission addressing reviewer feedback on **0.8.0**.

## Configure-script tooling

* Add **`inst/configure-templates/`** (`configure`, `configure.win`, README) and
  exports **`use_opencl_configure()`**, **`port_to_opencl_configure()`** for
  CRAN-safe optional OpenCL builds in downstream packages.
* **`nmathopencl`** re-exports both helpers; templates resolve from the
  **opencltools** installation.

## CRAN / packaging

* Add **`glmbayes (>= 0.9.3)`** to **`Suggests`** (reference downstream application on CRAN).
* Add **`\value`** documentation for **`kernel_lib_subset_printing`** S3 methods
  (`print.nmathopencl_concatenated_lib`, `print.nmathopencl_lib_extract_df`):
  side-effect printing with invisible return of `x`, and description of output
  classes.

## Kernel loading (all builds)

* **`load_kernel_source()`**, **`load_kernel_library()`**, and
  **`load_library_for_kernel()`** C++ implementations are compiled on every
  build (not only when **`USE_OPENCL`** is defined): reading and concatenating
  **`.cl`** files is file I/O, not OpenCL API use.
* Removed **`has_opencl()`** checks and **`stop()`** from the R wrappers; empty
  reads return **`""`** with a **`message()`** instead of failing on CPU-only
  binaries.
* **`has_opencl()`** remains the signal for whether **this binary** can run
  downstream GPU code; downstream packages should gate **dispatch**, not
  loading kernel text.

## Examples (`R CMD check`)

* Unwrap **`\donttest{}`** and remove **`if (has_opencl())`** from examples that
  do not need a GPU at run time: **`load_kernel_source`**, **`gpu_diagnostics`**
  (host block always; OpenCL probes use stubs on CPU-only builds), tagging and
  indexing on **`nmath_small`**, path helpers, and fast subsetting blocks.
* Add **`inst/cl/nmath_small/`**: **`ex_glmbayes_nmath`** shards plus six decoy
  stems from full **`nmath`** (`bessel`, `nmath2`, `qDiscrete_search`, `sunif`,
  `pcauchy`, `punif`) so subset examples exclude files present in the library
  directory but not named on the launcher kernel.
* **`load_library_for_kernel`**, **`extract_library_subset`**,
  **`kernel_lib_subset_printing`**, and step 2 of the tagging workflow run a
  **fast block** on **`nmath_small`** during the check; only the slow
  full-**`nmath`** index rebuild (~137 shards) stays inside **`\donttest{}`**.
* No package example uses **`if (has_opencl())`**; use it in **downstream**
  code before **`clBuildProgram`** / kernel dispatch, not before loading
  **`.cl`** sources.

## Bug fixes

* **`gpu_diagnostics` / `get_opencl_core_count` examples** — On CRAN builders with
  OpenCL enabled, skip slow device enumeration unless **`NOT_CRAN=true`** (avoids
  **>5s elapsed** example NOTE); CPU-only builds still run full stub path.

* **`diagnose_glmbayes()`** no longer errors on headless CI when no GPU vendor is
  detected (avoided accidental use of base **`diag`**; PATH prompts only in
  **`interactive()`** sessions).

## Headers (`LinkingTo`)

* Remove incomplete bundled **`inst/include/CL/`** (`cl.h` without **`cl_version.h`**).
  **`LinkingTo: opencltools`** supplies **`opencltools/openclPort.h`** only; each
  package locates **`CL/cl.h`** via its own **`configure`** / OpenCL SDK.
* New **`opencltoolsLdFlags()`** export: **`PKG_LIBS`** fragment (`-L... -lopencltools`)
  for downstream packages linking against **`openclPort::`** symbols.

## Maintainer

* **`CRAN-SUBMISSION`** added to **`.gitignore`** (local `devtools::submit_cran()` log).

# opencltools 0.8.0

First CRAN release. Version **0.8.0** (rather than 0.1.0) signals that the
runtime toolkit is substantially complete and ready for downstream packages
(`nmathopencl`, `glmbayes`, and others) to link against, while leaving
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
  annotating, indexing, sorting, and shipping `.cl` library subsets.
* Curated **`opencl_known_failures.json`** with warnings when loading stems
  with known portability issues.

## Documentation and examples

* Three vignettes: OpenCL setup (**Chapter-01**), loading and assembling kernel
  programs (**Chapter-02**), and the kernel-runner / wrapper pattern
  (**Chapter-03**), using `glmbayes` / envelope-gradient methodology as a
  reference application.
* **`README`**: refocused as library-agnostic; ecosystem table for
  `opencltools`, `nmathopencl`, and `glmbayes`; structured
  references including Nygren and Nygren (2006) and Stone et al. (2010).
* **`inst/CITATION`**: package manual, JASA (2006), OpenCL survey, and
  **`glmbayes`** reference-application entry.
* **`inst/examples/`**: runnable examples for diagnostics, kernel loading,
  tagging workflow, and library subsetting (OpenCL-heavy examples guarded with
  **`if (has_opencl())`** inside `\donttest{}`).

## CRAN / optional OpenCL behavior

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
