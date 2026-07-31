# CRAN submission comments — opencltools 0.8.3

Patch release following CRAN **0.8.2**.

## Summary

* **`tools/rcpp_include.R`:** Removed configure warnings that recommended
  installing **Rcpp** from GitHub for certain version of R (ensure CRAN policy compliance)

* **`Suggests`:** Removed **`glmbayes`** while that package is off CRAN.

* **`.Rbuildignore`:** Added **`^\.cursor$`** (hidden directory NOTE).

## Test environments

**`R CMD check --as-cran`**: (to be run before submit)

---
_This file is listed in **`.Rbuildignore`** and is not included in the built
source tarball. When submitting, paste the content above into the “Optional
comments” field on the CRAN submission form at_
https://cran.r-project.org/submit.html
