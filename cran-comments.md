# CRAN submission comments — opencltools 0.8.1

## Summary

Resubmission of **opencltools** **0.8.1** addressing reviewer feedback on
**0.8.0**: missing **`\value`** sections in documentation, and examples that
did not run during **`R CMD check`** because they were largely inside
**`\donttest{}`**.

## Response to CRAN feedback

1. **`\value` sections** — Added or completed **`\value`** for exported
   functions and relevant S3 methods, including **`kernel_lib_subset_printing`**
   (the file named in the review). Documentation describes return type and
   structure (class), what the output means, or states that a function is
   called for side effects only, as appropriate.

2. **Examples run on check** — Removed **`\donttest{}`** from examples that can
   run in under 5 seconds per help page (host diagnostics, kernel source
   loading, tagging/indexing/subsetting). On CRAN builders where OpenCL is
   compiled in, slow device enumeration in **`gpu_diagnostics`** examples is
   skipped unless **`NOT_CRAN=true`**, to stay within the 5 second guideline.
   Where a help page still has a longer workflow, a **toy version** of the
   same steps runs **outside** **`\donttest{}`** (using **`inst/cl/nmath_small/`**
   and dry-run indexing), so **`R CMD check`** exercises the API automatically.
   **`\donttest{}`** now wraps only the slow tail of those examples—the full
   **`nmath`** library index rebuild (~137 shards)—which exceeds 5 seconds.

## Test environments

**`R CMD check --as-cran`**: 0 errors | 0 warnings | 0 notes (local Windows;
win-builder; R-hub on standard Linux and Windows configurations).

## Optional comments for unchanged items

Spelling NOTE on win-builder (**Nygren**, **subgradient**),
quoted **OpenCL** in DESCRIPTION, optional OpenCL **`configure`**, and
**testthat** **`skip_on_cran()`** / **`skip_if_no_opencl()`** are unchanged
from **0.8.0** (see maintainer archive **`cran-comments-v0.8.0.md`** if needed).

---
_This file is listed in **`.Rbuildignore`** and is not included in the built
source tarball. When submitting, paste the content above (from Summary through
Optional comments for unchanged items) into the “Optional comments” field on
the CRAN submission form at_
https://cran.r-project.org/submit.html
