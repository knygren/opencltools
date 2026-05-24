# C++ / headers overlapping **glmbayes** and **opencltools**

**Scope:** Translation units and headers under **`src/`** in this repo (**`opencltools`**) compared with the sibling clone at **`C:\Rpackages\glmbayes`**.  
**Companion:** Verbatim **R** export overlap is in **`docs/R_FUNCTIONS_SHARED_WITH_GLMBAYES.md`**.  
**Purpose:** Coordinate edits when the OpenCL runtime layer is duplicated across packages after the **nmathopencl** / **opencltools** split.

**Snapshot:** Inventory taken from **`opencltools/src/*.{cpp,h}`** (10 files) vs **`glmbayes/src/*.{cpp,h}`** (48 files). **`RcppExports.cpp`** is generated per package and is not treated as hand-maintained shared source.

---

## At a glance (files)

| Category | Count | Basenames |
|----------|------:|-----------|
| Same basename, **byte-identical** today | 2 | `cuda_probe.cpp`, `opencl_detect.cpp` |
| Same basename, **shared lineage / forked** | 6 | `openclPort.h`, `kernel_loader.cpp`, `OpenCL_helper.cpp`, `export_wrappers.cpp`, `glmbayes_getRegisteredNamespace.{cpp,h}` |
| **`opencltools` only** | 2 | `opencl_device_selection.cpp`, `configure_OpenCL.cpp` |
| **`glmbayes` only** (OpenCL runtime neighbours) | many | `configure_OpenCL.cpp`, `opencl.h`, `kernel_runners.cpp`, `kernel_wrappers.cpp`, envelope / famfuncs / host `*.c`, … |

---

## Function inventory — shared **`openclPort::`** symbols

All symbols below live in **`namespace openclPort`**. Default **`package`** for loaders is **`"opencltools"`** here vs **`"glmbayes"`** in the sibling clone.

| Function | Signature (abbrev.) | **opencltools** `.cpp` | **glmbayes** `.cpp` | Parity |
|----------|---------------------|------------------------|---------------------|--------|
| **`gpu_names`** | `Rcpp::CharacterVector gpu_names()` | `cuda_probe.cpp` | `cuda_probe.cpp` | **Identical** |
| **`detect_num_gpus_internal`** | `int detect_num_gpus_internal()` | `opencl_detect.cpp` | `opencl_detect.cpp` | **Identical** (`#ifdef USE_OPENCL` only) |
| **`has_opencl`** | `bool has_opencl()` | `OpenCL_helper.cpp` | `OpenCL_helper.cpp` | **Identical** |
| **`get_opencl_core_count`** | `int get_opencl_core_count()` | `kernel_loader.cpp` | `kernel_loader.cpp` | **Same logic** (`max(1, detect_num_gpus_internal())` or `1`) |
| **`flattenMatrix`** | `std::vector<double> flattenMatrix(const Rcpp::NumericMatrix& mat)` | `OpenCL_helper.cpp` | `OpenCL_helper.cpp` | **Identical** (ported from **glmbayes**) |
| **`copyVector`** | `std::vector<double> copyVector(const Rcpp::NumericVector& vec)` | `OpenCL_helper.cpp` | `OpenCL_helper.cpp` | **Identical** (ported from **glmbayes**) |
| **`configureOpenCL`** | `OpenCLConfig configureOpenCL(cl_context, cl_device_id)` | `configure_OpenCL.cpp` | `configure_OpenCL.cpp` | **Identical** (ported from **glmbayes**) |
| **`load_library_for_kernel`** | `std::string load_library_for_kernel(...)` | `kernel_loader.cpp` | `kernel_loader.cpp` | **Identical** (ported from **glmbayes**; declared in **`openclPort.h`**) |
| **`load_kernel_source`** | `std::string load_kernel_source(relative_path, package)` | `kernel_loader.cpp` | `kernel_loader.cpp` | **Forked** — same `system.file` + read; **opencltools** adds empty-string stubs when **`!USE_OPENCL`** |
| **`load_kernel_library`** | `std::string load_kernel_library(subdir, package, verbose)` | `kernel_loader.cpp` | `kernel_loader.cpp` | **Forked** — shared **`@provides` / `@depends`** topological sort (~lines 44–173); **opencltools** stubs when **`!USE_OPENCL`** |
| **`load_kernel_source_wrapper`** | `std::string load_kernel_source_wrapper(relative_path, package)` | `kernel_loader.cpp` | `kernel_loader.cpp` | **Forked** — **`Rcpp::stop`** text names package (`opencltools` vs `glmbayes`) |
| **`load_kernel_library_wrapper`** | `std::string load_kernel_library_wrapper(subdir, package, verbose)` | `kernel_loader.cpp` | `kernel_loader.cpp` | **Forked** — same as above |

**Declared in both `openclPort.h` files** (signatures match aside from default **`package`**):

```cpp
Rcpp::CharacterVector gpu_names();
int detect_num_gpus_internal();
bool has_opencl();
int get_opencl_core_count();
std::string load_kernel_source(const std::string& relative_path,
                               const std::string& package = "…");
std::string load_kernel_library(const std::string& subdir,
                                const std::string& package = "…",
                                bool verbose = false);
std::string load_kernel_source_wrapper(std::string relative_path,
                                       std::string package = "…");
std::string load_kernel_library_wrapper(std::string subdir,
                                        std::string package = "…",
                                        bool verbose = false);
```

---

## Function inventory — shared **`[[Rcpp::export]]`** entry points

Same **C++ symbol names** in both packages; **`.Call`** registration is **`_opencltools_*`** vs **`_glmbayes_*`**. Each export is a one-line forward to **`openclPort`** (see **`export_wrappers.cpp`**).

| C++ export | Forwards to | User-facing R |
|------------|-------------|---------------|
| **`load_kernel_source_wrapper_cpp_export(relative_path, package)`** | **`load_kernel_source_wrapper`** | **`load_kernel_source`** |
| **`load_kernel_library_wrapper_cpp_export(subdir, package, verbose)`** | **`load_kernel_library_wrapper`** | **`load_kernel_library`** |
| **`has_opencl_cpp_export()`** | **`has_opencl()`** | **`has_opencl`** |
| **`get_opencl_core_count_cpp_export()`** | **`get_opencl_core_count()`** | **`get_opencl_core_count`** |
| **`gpu_names_cpp_export()`** | **`gpu_names()`** | **`gpu_names`** |

In **`glmbayes`**, these five sit in **`export_wrappers.cpp`** “Tier 5: OpenCL / GPU”. In **`opencltools`**, they share the file with the fp64 trio below.

---

## Function inventory — **`opencltools`-only** (runtime extensions)

### `openclPort::` (fp64 cache — not in **glmbayes**)

| Function | Signature (abbrev.) | `.cpp` | R export (via **`export_wrappers.cpp`**) |
|----------|---------------------|--------|------------------------------------------|
| **`opencl_ensure_fp64_selection`** | `bool opencl_ensure_fp64_selection(bool force)` | `opencl_device_selection.cpp` | (internal; used by other probes) |
| **`opencl_fp64_selection`** | `const OpenCLFp64DeviceCache& opencl_fp64_selection()` | `opencl_device_selection.cpp` | — |
| **`opencl_reset_fp64_selection`** | `void opencl_reset_fp64_selection()` | `opencl_device_selection.cpp` | **`opencl_reset_device_selection`** |
| **`opencl_fp64_available_impl`** | `bool opencl_fp64_available_impl(bool force = false)` | `opencl_device_selection.cpp` | **`opencl_fp64_available`** |
| **`opencl_device_info_rcpp`** | `Rcpp::List opencl_device_info_rcpp(bool force, bool details)` | `opencl_device_selection.cpp` | **`opencl_device_info`** |
| **`opencl_read_platform_info_str`** | inline, **`cl_platform_id`** | `openclPort.h` | — |
| **`opencl_read_device_info_str`** | inline, **`cl_device_id`** | `openclPort.h` | — |

Supporting **file-local** helpers in **`opencl_device_selection.cpp`** (not exported): **`clear_cache_to_invalid`**, **`extension_has_token`**, **`device_type_label`**, **`probe_fp64_kernel`**, **`env_int`**, **`refresh_selection_unlocked`**, **`details_table`**.

### Rcpp exports (**`opencltools`** only)

| C++ export | Forwards to |
|------------|-------------|
| **`opencl_device_info_cpp_export(force, details)`** | **`opencl_device_info_rcpp`** |
| **`opencl_fp64_available_cpp_export(force)`** | **`opencl_fp64_available_impl`** |
| **`opencl_reset_device_selection_cpp_export()`** | **`opencl_reset_fp64_selection`** |

---

### Internal helpers (**`kernel_loader.cpp`**, not in header)

| Function | Role |
|----------|------|
| **`parse_cl_tag(lines, tag)`** | Parse **`@tag:`** annotation lines (same logic as **glmbayes**) |
| **`read_tsv_index(tsv_path)`** | Read **`kernel_dependency_index.tsv`** |

---

## Function inventory — **`glmbayes`-only** (shared-lineage files)

Symbols **not** ported into **opencltools** (modelling / execution stay downstream):

### Still in **`openclPort`** namespace (**`glmbayes`** only today — now also in **opencltools**)

| Function | Notes |
|----------|-------|
| **`flattenMatrix`**, **`copyVector`**, **`configureOpenCL`**, **`load_library_for_kernel`** | **Now in opencltools**; **glmbayes** can drop its copies after **`LinkingTo: opencltools`**. |

### **`glmbayes`** modelling / execution (unchanged)

| Function | Role |
|----------|------|
| **`resolve_kernel_path(family, link)`** | Map GLM family/link → **`src/f2_f3_*.cl`** path |
| **`load_likelihood_subgradient_program(family, link, package)`** | Assemble full OpenCL program: **`OPENCL.cl`**, shim libs, **`nmath`** subset, family kernel |

### Build shim (not **`openclPort`**)

| Symbol | File | Role |
|--------|------|------|
| **`glmbayes_getRegisteredNamespace(name)`** | `glmbayes_getRegisteredNamespace.cpp` | **`extern "C"`** R namespace lookup when **`GLMBAYES_NEED_GETREGISTEREDNAMESPACE_SHIM`** |

Same shim source in both packages (logic equivalent; line endings may differ).

---

## File-level map (quick reference)

| File | Functions |
|------|-----------|
| **`cuda_probe.cpp`** | **`gpu_names`** |
| **`opencl_detect.cpp`** | **`detect_num_gpus_internal`** |
| **`OpenCL_helper.cpp`** | **`has_opencl`**, **`flattenMatrix`**, **`copyVector`** |
| **`kernel_loader.cpp`** | **`load_kernel_*`**, **`load_library_for_kernel`**, **`get_opencl_core_count`**, wrappers |
| **`opencl_device_selection.cpp`** | **opencltools** fp64 cache API only |
| **`export_wrappers.cpp`** | **`*_cpp_export`** shims (5 shared + 3 **opencltools**-only) |
| **`configure_OpenCL.cpp`** | **`configureOpenCL`** |
| **`inst/include/opencltools/openclPort.h`** | Public header for **`LinkingTo: opencltools`** (mirror of **`src/openclPort.h`**) |

When fixing loader bugs, **`diff`** **`kernel_loader.cpp`** — the shared prefix through **`load_kernel_library`** (~lines 23–173 in **opencltools**, ~30–190 in **glmbayes**) is still largely parallel.

---

## **`glmbayes`-only C++ (broader stack, not in `opencltools`)

These files consume **`openclPort`** but were **not** carried into **`opencltools`** after the runtime / stats split:

| Area | Files | Notes |
|------|-------|-------|
| OpenCL build options | **`configure_OpenCL.cpp`** | Implements **`openclPort::configureOpenCL`**. |
| GLM GPU execution | **`opencl.h`**, **`kernel_runners.cpp`**, **`kernel_wrappers.cpp`** | f2/f3 device runners. |
| Envelope / simulation | **`Envelope*.cpp`**, **`famfuncs_*.cpp`**, **`rNormal*.cpp`**, … | Call **`get_opencl_core_count`**, **`flattenMatrix`**, OpenCL wrappers. |
| Host numerics | **`src/nmath/`**, **`*.c`**, **`progress_utils.*`**, **`rng_utils.*`** | CPU / hybrid paths. |

Planned home for restored stats / **`Ex_*`** / **`r_check_*`** C++ is the sibling **`nmathopencl`** package, not **`opencltools`**.

---

## Build / include notes

- Both packages compile with **`USE_OPENCL`** when OpenCL is detected; **`has_opencl()`** is **`true`** only in those builds.
- **`glmbayes_getRegisteredNamespace.h`** is included from **`Makevars`** / **`Makevars.win`** in both clones so **`Rcpp::Function("system.file", …)`** namespace lookup works on older R toolchains.
- **`opencltools`** **`src/`** lists only runtime **`.cpp`** objects; **`glmbayes`** links the full modelling stack above.

---

## Suggested upkeep

1. **Identical twins** — patch **`cuda_probe.cpp`** and **`opencl_detect.cpp`** in both repos (or extract to a shared vendored copy later).
2. **Shared `openclPort::` API** — the **8** functions in the first inventory table are the contract duplicated across packages; grep both repos before renaming.
3. **Loader core** — when changing **`@depends`** sorting or **`system.file`** paths, **`diff`** **`kernel_loader.cpp`**; port fixes to the shared prefix before divergent tails.
4. **Header drift** — new symbols belong in **`opencltools`** **`openclPort.h`** only if **`opencltools`** implements them; do not re-add **`flattenMatrix`** / **`configureOpenCL`** here without a deliberate merge.
5. **Exports** — after C++ edits run **`Rcpp::compileAttributes()`** and **`roxygen2::roxygenise()`** in **each** package; never hand-edit **`NAMESPACE`** / **`RcppExports.*`**.
6. **Cross-package grep** — when renaming a **`openclPort::`** function or **`*_cpp_export`**, search **`C:\Rpackages\glmbayes`**, **`opencltools`**, and (when it exists) **`nmathopencl`**.
