# CRAN submission comments — opencltools 0.8.0

## Summary

This is the first submission of **opencltools** (0.8.0), a library-agnostic
runtime toolkit for R package developers who ship optional OpenCL acceleration.
The package probes hardware and drivers, loads and assembles annotated `.cl`
kernel libraries, and provides diagnostics helpers. OpenCL is **optional** at
build and run time: without OpenCL headers/runtime the package builds and runs
on CPU; GPU paths are used when available.

## Test environments

Local checks (Windows, `R CMD check --as-cran` / `devtools::check(cran = TRUE)`):
0 errors | 0 warnings | 0 notes.

* **win-builder** (R-release): 0 errors | 0 warnings | 0 notes on the check
  itself. CRAN *incoming* NOTE only (see below).
* **mac-builder** (R-release): 0 errors | 0 warnings | 0 notes.
* **R-hub** (`rhub::rhub_check()`): clean on the platforms exercised (Linux,
  Windows, macOS, and selected compiler/sanitizer/rchk configurations).
* **R-universe** (`https://knygren.r-universe.dev/opencltools`): builds and
  checks successfully.

Additional GPU/OpenCL smoke testing on a rented Linux VM (Vast.ai) is planned
but was **not** completed for this submission because instance scheduling was
delayed. Maintainer scripts for that workflow are in `scripts/` (excluded from
the tarball via `.Rbuildignore`).

## CRAN incoming NOTE (win-builder)

Win-builder reported a *Possibly misspelled words in DESCRIPTION* NOTE for
`Nygren`, `subgradient`, and `re-implementing`. These are intentional:

* **Nygren** — author surname in the cited reference (same citation wording as
  my CRAN package **glmbayes**).
* **subgradient** — standard term in the envelope/likelihood methodology
  referenced in the Description (also used in **glmbayes**).
* **re-implementing** — hyphenated verb in the Description.

Software name **OpenCL** is single-quoted in the Title, Description, and
SystemRequirements fields, consistent with **glmbayes**.

## Optional OpenCL / CRAN-safe behaviour

* `SystemRequirements` documents optional OpenCL; `configure` falls back to a
  CPU-only build when OpenCL is absent.
* Examples that compile or probe OpenCL devices are wrapped in
  `if (has_opencl()) { ... }` inside `\donttest{}`.
* OpenCL compile/probe tests use `skip_if_no_opencl()` and `skip_on_cran()` to
  avoid failures on CPU-only builders and to reduce the risk of a
  “CPU time vs elapsed” NOTE.

## Check duration

Vignette build can take about 1–2 minutes on remote builders; total check time
was within normal limits on the platforms above.

---
_Archive of optional comments for the initial 0.8.0 submission (May 2026).
Not included in the source tarball._
