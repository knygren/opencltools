# opencltools

![License: GPL-2](https://img.shields.io/badge/license-GPL--2-blue.svg)
[![R-universe](https://knygren.r-universe.dev/badges/opencltools)](https://knygren.r-universe.dev/opencltools)

`opencltools` is a developer toolkit for R packages that want to accelerate
embarrassingly parallel computations using OpenCL-capable GPUs. It provides
the runtime plumbing --- device probing, kernel source loading, library
subsetting, program assembly helpers, and fp64 capability management --- so
package authors can focus on writing their GPU kernels rather than
reimplementing the same infrastructure layer each time.

`opencltools` is **library-agnostic**. It works with any collection of
OpenCL-ready `.cl` source files, whether those are a full port of an existing
C library, a partial port of selected routines, or kernels written from
scratch. There is no dependency on any particular ported library.

[`nmathopencl`](https://knygren.r-universe.dev/nmathopencl) is the first
distributable example of such a library: an OpenCL-C port of R's Mathlib
(`nmath`) packaged for reuse. It is a natural companion when your kernel
needs statistical functions, but it is one instance of a pattern that applies
equally to any other C library you choose to port --- numerical linear
algebra, signal processing, simulation, or domain-specific code. The
`opencltools` infrastructure is the same regardless of what library is on the
other end.

---

## The problem this solves

Many algorithms are **embarrassingly parallel**: hundreds or thousands of
independent evaluations with no data dependency between them. The evaluations
are bottlenecks not because the math is hard, but because CPU-sequential code
cannot saturate modern hardware when the workload is large. OpenCL lets you
dispatch that work to a GPU, evaluating all points simultaneously.

The obstacle is that the computation inside each parallel evaluation often
depends on an existing C library --- R's statistical math (`nmath`), a
linear algebra routine, a domain-specific simulation function --- that was
written for host-sequential execution. A GPU kernel cannot call a host
library directly.

The general solution is to **port the required library** to OpenCL C,
distribute the ported sources as a package, and load them at runtime alongside
your own kernel code. `opencltools` provides the infrastructure for that
runtime step: loading, ordering, subsetting, and assembling `.cl` source
files from any such ported library into a complete OpenCL program.

The canonical example is **Bayesian GLM sampling via likelihood-subgradient
envelopes** in `glmbayes`, where the bottleneck is gradient evaluation across
a large parameter grid. The inner math requires statistical functions from
R's `nmath`, ported to OpenCL C by `nmathopencl`. But the same pattern
applies to any package where a C library bottleneck can be parallelised:
port the library once, distribute it, and use `opencltools` to assemble
programs that consume it.

---

## Packages in the ecosystem

| Package | Role |
|---------|------|
| **`opencltools`** | Runtime plumbing: device probing, kernel loading, library subsetting, program build helpers. Library-agnostic — works with any ported `.cl` library. |
| **`nmathopencl`** | *Example ported library.* OpenCL-C ports of R's nmath (>130 statistical functions), distributed as installable `.cl` files with dependency annotations. The first of potentially many such libraries. Also ships parity-testing R wrappers (`dnorm_opencl`, `dgamma_opencl`, …). |
| **`glmbayes`** | *Reference downstream package.* Bayesian GLM sampling with optional GPU acceleration of envelope gradient evaluation via `f2_f3_opencl`, using `nmathopencl` as its ported library and `opencltools` as the loader layer. |

Any other ported C library can occupy the role that `nmathopencl` plays here.
The `opencltools` infrastructure does not know or care what library it is
loading — it reads annotated `.cl` files, resolves dependency order, and
returns concatenated source strings.

---

## What opencltools provides

### Device and runtime probing

Before assembling and compiling an OpenCL program, confirm the runtime
environment:

```r
library(opencltools)

has_opencl()               # TRUE/FALSE — is an OpenCL ICD present?
opencl_fp64_available()    # Is double-precision (cl_khr_fp64) working?
opencl_device_info()       # Cached device/driver metadata
gpu_names()                # NVIDIA GPU names via nvidia-smi (Linux)
get_opencl_core_count()    # Total compute units across GPU devices

verify_opencl_runtime()    # Broader sanity check (ICD, driver, …)
check_runtime_env()        # Workstation-level environment diagnosis
detect_compute_runtimes()  # Enumerate CUDA, ROCm, OpenCL runtimes
```

**Set up OpenCL before starting work.** Call `has_opencl()` and
`opencl_fp64_available()` at the start of any session that will dispatch to a
GPU. If either returns `FALSE`, diagnose with `verify_opencl_runtime()` or
`detect_compute_runtimes()` before attempting to build or run kernels. Driver
issues that are detected early are much easier to resolve than failures buried
inside `clBuildProgram`.

### Kernel source loading (R and C++)

Load individual `.cl` files or entire annotated subdirectories into strings
that can be assembled into an OpenCL program source. The `package` argument
points to whichever package ships the `.cl` files you want --- `nmathopencl`,
your own package, or any other ported library installed on the system:

```r
# Load a single configuration header from any package
src <- load_kernel_source("OPENCL.cl", package = "my_ported_lib")

# Load an entire annotated subdirectory in dependency order
lib_src <- load_kernel_library("mylib", package = "my_ported_lib")
```

The C++ equivalents (`openclPort::load_kernel_source`,
`openclPort::load_kernel_library`) are also available for use inside your
package's `.cpp` files via `LinkingTo: opencltools`.

### Minimal library subsetting for a specific kernel

`load_library_for_kernel()` reads the dependency annotation on your launcher
`.cl` file and concatenates only the library shards that kernel actually
needs, rather than the entire library. This reduces first-call JIT
compilation time and keeps the program source small. It works with any
annotated `.cl` library --- not just `nmath`:

```r
lib_dir     <- system.file("cl/mylib", package = "my_ported_lib")
kernel_path <- "path/to/my_kernel.cl"

src <- load_library_for_kernel(
  kernel_path, lib_dir,
  depends_tag = "all_depends_mylib"
)
```

The C++ equivalent `openclPort::load_library_for_kernel(...)` is provided for
use inside kernel runner code where calling back into R from C++ is
undesirable (see **§ Kernel runners and wrappers** below).

### Build option probing

`configureOpenCL()` (C++ only) compiles tiny test kernels against a live
device to determine whether `expm1` and `log1p` are available as native
device built-ins, and returns a `buildOptions` string (`-DHAVE_EXPM1=1
-DHAVE_LOG1P=1`) to pass to `clBuildProgram`. This is useful for any ported
library whose code uses platform-specific fast-path branches for those
functions.

### Kernel annotation and subset tools

For downstream developers annotating their own kernels against a pre-annotated
library:

| Function | Purpose |
|----------|---------|
| `attach_kernel_call_tags()` | **Step 1** — scan your kernel source, match calls against a library's `@provides` list, write `@calls_<tag>` and `@depends_<tag>` into the kernel files. No manual tagging needed. |
| `attach_cross_library_tags()` | **Step 2** — read `@depends_<tag>`, compute the full transitive closure against the library index, write `@all_depends_<tag>` back into the kernel files |
| `load_library_for_kernel()` | At runtime (or interactively), read `@all_depends_<tag>` from a kernel file and concatenate only the library shards it needs, in dependency order. Emits warnings for known-problematic stems. |
| `extract_library_subset()` | Materialise a kernel-specific subset into a vendored directory (for packages that want to ship their own copy of the needed shards) |
| `write_kernel_dependency_index()` | Regenerate `kernel_dependency_index.rds` / `.tsv` after updating a library tree |

---

## How to use opencltools in a downstream package

The general workflow for adding optional GPU acceleration to an R package:

### 1. Probe the device at session start

```r
if (!opencltools::has_opencl() || !opencltools::opencl_fp64_available()) {
  message("OpenCL not available — using CPU path.")
  use_opencl <- FALSE
} else {
  use_opencl <- TRUE
}
```

### 2. Write your kernel — zero manual tagging required

Pre-annotated libraries like `nmathopencl` already carry full dependency
metadata. You do not need to annotate the library or manually declare which
functions you call. Just write your kernel:

```c
// @library_deps: nmath
__kernel void my_kernel(__global double* x, ...) {
  double v = dgamma(x[get_global_id(0)], shape, scale, 0);
  ...
}
```

The only line you add is `// @library_deps: nmath` to tell the tooling which
library to scan against. Two calls then handle everything else.

**Step 1 — scan source and tag direct calls:**
`attach_kernel_call_tags` reads the library's `@provides` annotations, scans
your kernel source for matching function calls, and writes
`@calls_nmath`, `@depends_nmath`, and `@calls_opencl_builtin` automatically:

```r
nmath_dir <- system.file("cl/nmath", package = "nmathopencl")

attach_kernel_call_tags(
  kernel_paths = list.files("inst/cl/src", "\\.cl$", full.names = TRUE),
  library_dir  = nmath_dir,
  library_tag  = "nmath"
)
# writes @calls_nmath and @depends_nmath by scanning your source
```

**Step 2 — expand to full transitive closure:**
`attach_cross_library_tags` reads the `@depends_nmath` written in step 1,
walks the pre-built library index, and writes `@all_depends_nmath` — the
complete ordered list of every library shard the kernel needs:

```r
attach_cross_library_tags(
  kernel_paths = list.files("inst/cl/src", "\\.cl$", full.names = TRUE),
  library_dir  = nmath_dir,
  depends_tag  = "depends_nmath"
)
# writes @all_depends_nmath — nothing else to do
```

Re-run both steps whenever you edit your kernel and add or remove library
calls. Both functions accept any pre-annotated library: change `library_dir`,
`library_tag`, and `depends_tag` to match the library's conventions.

Before wiring the kernel into production code, verify that the functions it
needs have been ported and are likely to work. `opencltools` maintains a
curated `opencl_known_failures.json` and surfaces warnings automatically when
you call `load_library_for_kernel`:

```r
src <- load_library_for_kernel(
  kernel_path, nmath_dir,
  depends_tag = "all_depends_nmath"
)
# warnings fire automatically for any stems with known portability issues
```

Once the warnings are clean, `load_library_for_kernel` is ready to use in
your C++ runner (see step 3).

### 3. Assemble the program source in C++

Inside your kernel runner (a `.cpp` file in your package's `src/`). The
`package` argument to each loader call names whichever installed package
ships the `.cl` files --- substitute your own ported library for
`"nmathopencl"` below:

```cpp
#include <opencltools/openclPort.h>  // via LinkingTo: opencltools

// One-time program assembly (cache the result across calls)
std::string build_my_program(const std::string& package) {
  using namespace openclPort;

  // Load layers from your ported library package
  // (shown here using nmathopencl as an example)
  return
    load_kernel_source("OPENCL.cl",        "nmathopencl")  + "\n" +
    load_kernel_library("libR_shims",      "nmathopencl")  + "\n" +
    load_kernel_library("R_ext_types",     "nmathopencl")  + "\n" +
    load_kernel_library("R_shims",         "nmathopencl")  + "\n" +
    load_kernel_library("R_ext_runtime",   "nmathopencl")  + "\n" +
    load_kernel_library("R_ext_internals", "nmathopencl")  + "\n" +
    load_kernel_library("System",          "nmathopencl")  + "\n" +
    // Subset only the shards this kernel needs
    load_library_for_kernel(
      "src/my_kernel.cl", "nmath", "nmathopencl", "all_depends_nmath") + "\n" +
    // Your own kernel entry point
    load_kernel_source("src/my_kernel.cl", package);
}
```

Pass `build_my_program(...)` to `clCreateProgramWithSource` and compile once.
The loader calls are entirely symmetrical for any other ported library ---
just change the package names and subdirectory paths.

### 4. Kernel runners and wrappers

The **kernel runner** handles the raw OpenCL API calls: create context,
compile program, set arguments, dispatch, read back results. Keep it in C++.
The **kernel wrapper** is the Rcpp-exported entry point that R code calls; it
receives standard R objects, flattens them to vectors (using
`openclPort::flattenMatrix` / `openclPort::copyVector`), invokes the runner,
and returns results as Rcpp objects.

`glmbayes` demonstrates this pattern cleanly:

- `kernel_runners.cpp` — `f2_f3_kernel_runner(...)`: raw OpenCL dispatch,
  no R objects
- `kernel_wrappers.cpp` — `f2_f3_opencl(...)`: Rcpp-facing wrapper that
  calls the runner, exported via `[[Rcpp::export]]`
- `EnvelopeEval.cpp` — calls `f2_f3_opencl(family, link, G4, ...)` when
  `use_opencl = TRUE`, and `f2_f3_non_opencl(...)` otherwise

### 5. Fail gracefully

The `use_opencl` flag is the key to graceful degradation. Every entry point
that dispatches to a GPU should have a CPU fallback and accept a `use_opencl`
argument. When OpenCL is unavailable (no ICD, no fp64, driver fault), the
code transparently routes to the CPU path. Machines without a GPU install and
run the package without any changes to user code.

```cpp
// in EnvelopeEval.cpp (simplified from glmbayes)
if (use_opencl) {
  prepGrad = f2_f3_opencl(family, link, G4, y, x, mu, P, alpha, wt, progbar);
} else {
  prepGrad = f2_f3_non_opencl(family, link, G4, y, x, mu, P, alpha, wt, progbar);
}
```

---

## The glmbayes reference implementation

`glmbayes` provides the most complete example of `opencltools` + `nmathopencl`
in production use. Its GPU acceleration path for Bayesian GLM sampling
illustrates every step described above.

### The embarrassingly parallel bottleneck: envelope gradient evaluation

Bayesian posterior sampling via likelihood-subgradient envelopes requires
constructing a piecewise-linear bound on the log-posterior. That construction
involves evaluating the negative log-posterior and its gradient vector at
every point of a grid over parameter space. For a model with `p` predictors,
the grid can have `O(3^p)` faces; for `p = 14` that is thousands of
independent evaluations per MCMC draw.

Each evaluation is entirely independent of the others --- exactly the
structure that makes GPU dispatch valuable. The inner math requires
`lgamma`, `lbeta`, `dbinom_raw`, `dgamma`, and `pnorm5` depending on the
GLM family and link. `glmbayes` sources these from `nmathopencl` via
`opencltools` loaders.

### Program assembly in glmbayes

`load_likelihood_subgradient_program(family, link, package)` in
`glmbayes/src/kernel_loader.cpp` assembles the complete OpenCL program source
for a given GLM family and link function in this fixed layer order:

```
1. OPENCL.cl               — fp64 extension, IEEE constants, INLINE macro
2. libR_shims/             — R_pow, R_pow_di, R_CheckUserInterrupt shims
3. R_ext_types/            — SEXP, Rboolean, type aliases
4. R_shims/                — additional R API shims
5. R_ext_runtime/          — memory / error / I/O interface
6. R_ext_internals/        — R internal extension definitions
7. System/                 — system-level OpenCL prelude
8. nmath/ (subset only)    — only the stems needed by this kernel
9. src/f2_f3_<family>.cl   — the __kernel entry point
```

Steps 1–8 are sourced from `nmathopencl` via `openclPort::load_kernel_source`
and `openclPort::load_library_for_kernel`. Step 9 is `glmbayes`-specific.

### Fail-graceful dispatch

`EnvelopeEval()` accepts a `use_opencl` flag. When `TRUE`, it dispatches via
the GPU runner; when `FALSE` (or when OpenCL is not present), it calls the
equivalent CPU path `f2_f3_non_opencl()`. The calling code in `EnvelopeBuild`
checks `has_opencl()` and `opencl_fp64_available()` before setting the flag.
Users on machines without a GPU experience no difference in API surface.

### Performance notes

The first call to `f2_f3_opencl` in a session triggers JIT compilation of the
assembled source by the OpenCL driver. For a program that includes substantial
nmath content, this can take several seconds. Subsequent calls reuse the
compiled kernel; the marginal overhead drops to context setup, buffer
transfer, and dispatch --- small relative to the computation for large grids.
The speedup over the CPU path grows with model dimension because more grid
points are evaluated simultaneously.

---

## Installation

```r
install.packages(
  "opencltools",
  repos = c("https://knygren.r-universe.dev",
            "https://cloud.r-project.org")
)
```

OpenCL support requires a GPU with an installed OpenCL runtime (NVIDIA CUDA,
AMD ROCm/OpenCL, Intel OpenCL, or Apple Metal via OpenCL compatibility layer).
The package installs and all non-GPU functions work without a GPU. All
GPU-dispatching functions degrade gracefully when OpenCL is unavailable.

---

## Vignettes (planned)

Deeper worked examples are planned as vignettes, numbered so they appear
in the correct order in the package index (following the `Chapter-NN` convention
used by `glmbayes`):

| Vignette file | Title |
|---------------|-------|
| `Chapter-00` | **Introduction** — What opencltools is and when to use it |
| `Chapter-01` | **Getting started** — Setting up OpenCL, verifying the runtime, first kernel load |
| `Chapter-02` | **Using a ported library** — Annotating kernels, assembling programs, subsetting a `.cl` library (`nmathopencl` as the worked example) |
| `Chapter-03` | **Kernel runners and wrappers** — The runner/wrapper pattern from `glmbayes`, graceful fallback |
| `Chapter-04` | **Testing and parity validation** — Using `nmathopencl`'s `*_opencl` wrappers to verify numerical accuracy before relying on device code |
| `Chapter-A01` | **Appendix: Kernel annotation in depth** — `attach_kernel_call_tags`, `attach_cross_library_tags`, dependency closure, `@depends` vs `@all_depends`, index format |
| `Chapter-A02` | **Appendix: Vendoring a library subset** — Using `extract_library_subset` and `write_kernel_dependency_index` to ship a minimal shard tree with your package |

---

## References

Nygren, K. N., & Nygren, L. M. (2006). Likelihood subgradient densities.
*Journal of the American Statistical Association*, 101(475), 1144–1156.
<https://doi.org/10.1198/016214506000000357>

Nygren, K. N. (2025). *glmbayes: Bayesian Generalized Linear Models (IID
Samples)*. R package version 0.9.6.
<https://CRAN.R-project.org/package=glmbayes>
