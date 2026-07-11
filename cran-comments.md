# CRAN submission comments — opencltools 0.8.2

## Summary

Update release of **opencltools** **0.8.2** following CRAN **0.8.1**. Adds
program preload manifest helpers, cross-package library subsetting (R API),
and integration updates for downstream **`nmathopencl`** and **`glmbayes`**.

## Test environments

**`R CMD check --as-cran`**: 0 errors | 0 warnings | 0 notes (local Windows;
win-builder; R-hub on standard Linux and Windows configurations).

## Optional comments for unchanged items

Spelling NOTE on win-builder (**Nygren**, **subgradient**),
quoted **OpenCL** in DESCRIPTION, optional OpenCL **`configure`**, and
**testthat** **`skip_on_cran()`** / **`skip_if_no_opencl()`** are unchanged
from **0.8.1** (see maintainer archive **`cran-comments-v0.8.0.md`** for the
initial **0.8.0** submission if needed).

---
_This file is listed in **`.Rbuildignore`** and is not included in the built
source tarball. When submitting, paste the content above (from Summary through
Optional comments for unchanged items) into the “Optional comments” field on
the CRAN submission form at_
https://cran.r-project.org/submit.html
