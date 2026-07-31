# `tools/` (**opencltools**)

Maintainer helpers kept in the repository only (not installed with the package; see **`.Rbuildignore`**).

This directory may hold optional maintainer scripts. Native builds use standard
**`LinkingTo: Rcpp`** via **`configure`** / **`configure.win`** (OpenCL detection
only; no custom Rcpp header probing).

For OpenCL / nmath port orchestration, see the **`openclport`** package.
