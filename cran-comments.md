# CRAN submission comments — opencltools 0.8.1

## Summary

Resubmission of **opencltools** **0.8.1** addressing reviewer feedback on
**0.8.0** (missing **`\value`** sections; examples effectively untested because
they were largely inside **`\donttest{}`**). Details below and in **NEWS.md**.

## Response to CRAN feedback

1. **`\value` sections** — All exported functions and relevant S3 `print()` methods
   now document return types and meaning (including `gpu_diagnostics`,
   `load_kernel_source` / `load_kernel_library`, and
   `kernel_lib_subset_printing`).

2. **Examples run on check** — Unwrapped **`\donttest{}`** and removed
   **`if (has_opencl())`** where no GPU is needed at example time:
   * Host diagnostics; **`load_kernel_source()`** / **`load_kernel_library()`**
     (file I/O only, all builds).
   * **`gpu_diagnostics`** (host block always; on CRAN builders with OpenCL
     compiled in, device enumeration is skipped unless **`NOT_CRAN=true`** to
     avoid **>5s elapsed** example NOTE — same idea as **`skip_on_cran()`** in
     tests).
   * Tagging, indexing, subsetting on **`inst/cl/nmath_small/`**.
   * Only the slow full-**`nmath`** index rebuild (~137 shards) stays in
     **`\donttest{}`** (runtime, not OpenCL).

3. **Kernel loaders on all builds** — C++ loaders always compiled; R wrappers no
   longer **`stop()`** on **`has_opencl()`**. Empty reads return **`""`** with a
   **`message()`**. **`has_opencl()`** is for downstream **GPU dispatch**, not for
   gating **`.cl`** reads.

4. **`Suggests: glmbayes (>= 0.9.3)`** — Reference downstream package on CRAN
   (not required for check).

## Test environments (0.8.1)

`R CMD check --as-cran` / `devtools::check(cran = TRUE)`: 0 errors | 0 warnings
| 0 notes (local Windows; win-builder; mac-builder; R-hub platforms exercised).

## Optional comments for unchanged items

Spelling NOTE on win-builder (**Nygren**, **subgradient**, **re-implementing**),
quoted **OpenCL** in DESCRIPTION, optional OpenCL **`configure`**, and
**testthat** `skip_on_cran()` / `skip_if_no_opencl()` are unchanged from **0.8.0**
(see maintainer archive **`cran-comments-v0.8.0.md`** if needed).

---
_This file is listed in `.Rbuildignore` and is not included in the built source
tarball. When submitting, paste the content above (from Summary through Optional
comments for unchanged items) into the “Optional comments” field on the CRAN
submission form at_ https://cran.r-project.org/submit.html
