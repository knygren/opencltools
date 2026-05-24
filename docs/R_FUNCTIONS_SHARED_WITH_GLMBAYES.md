# R functions overlapping **glmbayes** and **nmathopencl**

**Scope:** **`export`** names that appear **verbatim in both packages’ `NAMESPACE`** (same identifier string). C++ / header overlap is catalogued separately in **`docs/CPP_SHARED_WITH_GLMBAYES.md`**.  
**Snapshot:** Derived from **`NAMESPACE`** intersections between **`glmbayes`** and this repo (**`nmathopencl`**). Long-form maintainer narrative for these **duplicate** names lives in **`.Rd`**; **`docs/EXPORTED_ADDITIONAL.md`** omits them **by design** (see that file’s scope).  
**Purpose:** Coordinate edits when façade code exists in duplicate across packages.

Sandbox **`Ex_*`** teaching wrappers (*different* exported symbols from **`glmbayes`**) are planned for the sibling **`nmathopencl`** package—**not** in this verbatim-name intersect list and **not** in **`docs/EXPORTED_ADDITIONAL.md`**.

---

## Exact same exported name (both packages)

These **14** identifiers are **`export(...)`’d by both packages**—typically thin R wrappers duplicated into **nmathopencl** while **glmbayes** retains the originals for modelling workflows.

| Function | `nmathopencl` **`R/`** source | Typical role |
|----------|------------------------------|----------------|
| `add_to_libpath_linux` · `add_to_path_linux` · `add_to_path_windows` | `R/add_to_path.R` | PATH / LD_LIBRARY‑style diagnostics |
| `check_runtime_env` · `detect_compute_runtimes` · `detect_environment_and_gpus` · `detect_or_install_gpu_drivers` · `diagnose_glmbayes` · `gpu_names` · `has_opencl` · `verify_opencl_runtime` | `R/gpu_diagnostics.R` | Hardware / ICD / sanity orchestration |
| `get_opencl_core_count` | `R/get_opencl_core_count.R` | Compute‑unit probe |
| `load_kernel_library` · `load_kernel_source` | `R/load_kernel_library.R` | Assemble concatenated kernel source for device compilation |

Implementations may diverge over time—`diff` the paired **`R/*.R`** files across clones.

---

## Suggested upkeep

- Prefer **single source of truth** for shared diagnostics/loaders … *or* consciously document divergence in **README**/developer notes.
- When renaming on either side, grep both repos for the symbol.
