# CRAN submission comments — opencltools 0.8.3

Patch release following CRAN **0.8.2**.

## Summary

* **Configure:** Removed Rcpp header probing / Function.h workaround tooling
  (`tools/rcpp_include.R`, `tools/patch_rcpp_function_h.R`,
  `glmbayes_getRegisteredNamespace` shim). Builds use standard **`LinkingTo:
  Rcpp`**.

* **`Suggests`:** Removed **`glmbayes`** while that package is off CRAN.

* **`.Rbuildignore`:** Added **`^\.cursor$`** (hidden directory NOTE).

No other functional or API changes.

## Test environments

**`R CMD check --as-cran`**: (to be run before submit)

---
_This file is listed in **`.Rbuildignore`** and is not included in the built
source tarball. When submitting, paste the content above into the “Optional
comments” field on the CRAN submission form at_
https://cran.r-project.org/submit.html
