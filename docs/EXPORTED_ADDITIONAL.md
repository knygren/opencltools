# **opencltools**-specific exports (non–**`glmbayes`**-shared)

**Scope:** **`export()`** / **`exportS3method()`** symbols in **`opencltools`** that are **not** among the **verbatim duplicate** **`export`** names shared with **`glmbayes`** (see **`docs/R_FUNCTIONS_SHARED_WITH_GLMBAYES.md`**).

Those shared identifiers (**`has_opencl`**, **`load_kernel_source`**, **`load_kernel_library`**, **`gpu_names`**, **`get_opencl_core_count`**, **`verify_opencl_runtime`**, **`diagnose_glmbayes`**, **`detect_*`**, **`check_runtime_env`**, **`add_to_path_*`**, …) are **intentionally omitted** here—they are documented in **`docs/R_FUNCTIONS_SHARED_WITH_GLMBAYES.md`** and in **`.Rd`** (e.g. **`?gpu_diagnostics`**, **`?load_kernel_library`**).

**This file** covers APIs **unique to the opencltools runtime story**: cached OpenCL device / fp64 probes, RDS-backed **`.cl`** subset loaders, the maintainer dependency-index pipeline, and **`S3`** printers for subset objects.

**Not in `opencltools` (planned for sibling package **`nmathopencl`**):**

- Stats/math **`*_opencl`** mirrors
- Pedagogical **`Ex_*`** sandbox exports
- **`r_check_*_opencl`** linkage smoke

**Authority:** Signatures and **`examples`** live in **`.Rd`**; run **`devtools::document()`** after **`@export`** edits.

*(Ignore **`docs/articles/`**, **`reference/`**, …—**`pkgdown`** artefacts from the pre-split monolith.)*

---

## 1 · **`glmbayes`**-shared helpers (not duplicated here)

Use this **only** as a **workflow breadcrumb**—for **Brief / Why / Details** prose on **`has_opencl()`**, **`verify_opencl_runtime()`**, diagnostics, **`load_kernel_*`**, PATH utilities, etc., see **`docs/R_FUNCTIONS_SHARED_WITH_GLMBAYES.md`** plus the relevant **`.Rd`** topics.

Typical order when **debugging OpenCL on a workstation** ( **`opencltools`** or a downstream kernel package): **`has_opencl()`** → **`verify_opencl_runtime()`** → **`detect_environment_and_gpus()`** / **`detect_compute_runtimes()`** → **`check_runtime_env()`** → **`diagnose_glmbayes()`**; use **`load_kernel_source` / `load_kernel_library`** when you need raw **`.cl`** strings from **`inst/cl`**. **RDS-aware** subset loading (**`load_library_for_kernel`**, **§3**) **builds on** the same kernel text and is documented below.

---

## 2 · OpenCL device cache & precision (**not** verbatim **`glmbayes`** exports)

### `opencl_device_info(force = FALSE, details = FALSE)`

**Brief.** Returns **cached OpenCL device/driver** metadata (optional **force** re-probe / **details** verbosity).

**Why opencltools (vs `openclport`).** Amortises expensive device enumeration in **`C++`** for diagnostics and for downstream packages that compile OpenCL programs; **`openclport`** has no parallel runtime cache surface.

**Details.** Use after shared diagnostics prove OpenCL is present but kernel builds fail (platform selection, **`clBuildProgram`** errors). See **`?opencl_device_info`** / **`?gpu_diagnostics`**.

### `opencl_fp64_available(force = FALSE)`

**Brief.** **Boolean** probe (cached) whether **double-precision** (**`cl_khr_fp64`**) works on the chosen device.

**Why opencltools (vs `openclport`).** Guardrail for **`inst/cl/nmath`** and other fp64-oriented shader trees shipped or subsetted via this package.

**Details.** Pair with **`OPENCL.cl`** / kernel extension docs. **`?opencl_fp64_available`** carries exact semantics.

### `opencl_reset_device_selection()`

**Brief.** Clears **package-local** device / precision cache so the next probe starts clean.

**Why opencltools (vs `openclport`).** Only meaningful where **`opencltools`** persists device choice in **`C++`** between **R** calls in the same session.

**Details.** Use after driver reinstalls, ICD changes, or A/B GPU tests in one **R** session.

---

## 3 · RDS-backed library subsets

### `load_library_for_kernel(kernel_path, library_dir, depends_tag = "all_depends", index = NULL)`

**Brief.** Reads a launcher **`.cl`**’s **`@{depends_tag}`** stem list, walks **`kernel_dependency_index.rds`**, concatenates transitive library sources in **load order**.

**Why opencltools (vs `openclport`).** **Runtime** subsetting for fat **`inst/cl/nmath`** (and similar) installs; **`openclport`** focuses on **generating** annotated sources, not shipping this **RDS** consumer.

**Details.** Pass **`index`** to skip repeated **`readRDS`**. **`warning`** when **`opencl_known_failures.json`** fires. Returns **`nmathopencl_concatenated_lib`** (**`print`** §5). **`?load_library_for_kernel`** has runnable examples.

### `extract_library_subset(kernel_paths, library_dir, ...)`

**Brief.** **Bulk** union of subset dependencies across many launchers plus per-kernel attribution metadata.

**Why opencltools (vs `openclport`).** Batch/CI flows for maintainers and downstream packages; not part of **`openclport`**’s exported **R** surface.

**Details.** Often follows **`attach_cross_library_tags`**. Full argument list in **`.Rd`**.

---

## 4 · Maintainer pipeline: tags, indices, offline sort

### `attach_kernel_dependency_tags(library_dir, dry_run = FALSE)`

**Brief.** Topologically sorts **one** annotated library tree and **optionally rewrites** **`//@load_order`**, **`//@all_depends`**, **`//@all_depends_count`** on each **`.cl`**.

**Why opencltools (vs `openclport`).** **`opencltools`** **exports** the maintainer entry point bound to **`inst/cl`** release practice; **`openclport`** carries reference logic, not this **RDS**-indexed product.

**Details.** Failure payload includes **`cycles`**. Internals: **`docs/UNEXPORTED_HELPERS.md`**. **`print`** §5.

### `write_kernel_dependency_index(library_dir = NULL, tags = NULL, output_path = NULL, write = TRUE, verbose = FALSE)`

**Brief.** Writes **`kernel_dependency_index.{rds,tsv}`** used by **§3** loaders.

**Why opencltools (vs `openclport`).** The **version-1** RDS schema is part of the **`inst/cl`** contract consumed by **`load_library_for_kernel`**.

**Details.** Can re-run **`attach_kernel_dependency_tags`** internally when **`tags`** is **`NULL`**. Regenerate after **`@depends`** churn.

### `stage_kernel_dependency_sort(library_dir, output_dir, overwrite = FALSE)`

**Brief.** **Offline** copy-out: **sorted** / **unresolved** / **CSV** reports—**never** mutates **`library_dir`**.

**Why opencltools (vs `openclport`).** QA diffs for **`inst/cl`** maintainers; no **`openclport`** twin export.

**Details.** Same sort core as **`attach_*`**, safer for **before/after** cycle surgery.

### `attach_cross_library_tags(kernel_paths, library_dir, depends_tag, index = NULL, dry_run = FALSE)`

**Brief.** Expands cross-library **`@{depends_tag}`** (e.g. **`depends_nmath`**) into **`@all_depends_*`** annotations on launcher **`.cl`** files.

**Why opencltools (vs `openclport`).** **`inst/cl/src`** launchers depend on **`cl/nmath`**; this **bridge** is part of the packaged kernel layout.

**Details.** **`?attach_cross_library_tags`** example (**`readRDS`** + **`list.files`**).

---

## 5 · **`S3`** printers (subset / tagging objects)

### `print.opencl_dependency_tags(x, max_rows = 50, ...)`

**Brief.** Pretty **`attach_kernel_dependency_tags`** results (success tables or **failure** **`cycles`** / **`unresolved`**).

**Why opencltools (vs `openclport`).** Tied to the **`opencltools`** tagging workflow only.

**Details.** Tune **`max_rows`** for long cycle listings.

### `print.nmathopencl_concatenated_lib(x, ...)`

**Brief.** Summarises **`load_library_for_kernel`** (**and whole-library loader** subclass) objects—stems, sizes, metadata—without dumping full sources.

**Why opencltools (vs `openclport`).** Class is defined for **§3** / **RDS** flows here (legacy class name retained for compatibility).

**Details.** Whole-library concatenation may come from **shared** **`load_kernel_library`** (**§1**) or **`load_library_for_kernel`** (**§3**).

### `print.nmathopencl_lib_extract_df(x, ...)`

**Brief.** **`data.frame`** view for **`extract_library_subset()`** outputs.

**Why opencltools (vs `openclport`).** Batch subset UX for **`opencltools`** exports.

**Details.** **`?kernel_lib_subset_printing`** if linked from **`.Rd`**.

---

## Maintainer sync

1. **`devtools::document()`** on **`@export`** changes.
2. **This file:** **`opencltools`** exports **not** in **`R_FUNCTIONS_SHARED_WITH_GLMBAYES.md`**.
3. **`R_FUNCTIONS_SHARED_WITH_GLMBAYES.md`:** matrix for **`glmbayes`** duplicate names (still relevant where **`opencltools`** shares API).
4. Stats mirrors, **`Ex_*`**, and **`r_check_*`** live in the future **`nmathopencl`** package—not documented here.
