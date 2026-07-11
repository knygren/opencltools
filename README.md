# opencltools

![License: GPL-2](https://img.shields.io/badge/license-GPL--2-blue.svg)
[![R-universe](https://knygren.r-universe.dev/badges/opencltools)](https://knygren.r-universe.dev/opencltools)

`opencltools` is a developer toolkit for R packages that want to accelerate
embarrassingly parallel computations using OpenCL-capable GPUs. It provides
the runtime plumbing --- device probing, kernel source loading, library
subsetting, program assembly helpers, and `fp64` capability management --- so
package authors can focus on writing their GPU kernels rather than
re-implementing the same infrastructure layer each time.

`opencltools` is **library-agnostic**. It works with any collection of
OpenCL-ready `.cl` source files, whether those are a full port of an existing
C library, a partial port of selected routines, or kernels written from
scratch. There is no dependency on any particular ported library.

[`nmathopencl`](https://knygren.r-universe.dev/nmathopencl) is the first
first packaged example of such a library: an OpenCL-C port of R's Mathlib
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
applies to any package where a C library bottleneck can be parallelized:
port the library once, distribute it, and use `opencltools` to assemble
programs that consume it.

---

## Packages in the ecosystem

| Package | Role |
|---------|------|
| **`opencltools`** | Runtime plumbing: device probing, kernel loading, library subsetting, program build helpers. Library-agnostic — works with any ported `.cl` library. |
| **`nmathopencl`** | *Example ported library.* OpenCL-C ports of R's nmath (>130 statistical functions), distributed as `.cl` files with dependency annotations (shipped with the package). The first of potentially many such libraries. |
| **`glmbayes`** | *Reference downstream package.* Bayesian GLM sampling with optional GPU acceleration of envelope gradient evaluation via `f2_f3_opencl`, using `nmathopencl` as its ported library and `opencltools` as the loader layer. |

Any other ported C library can occupy the role that [`nmathopencl`](https://knygren.r-universe.dev/nmathopencl) plays here.
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

has_opencl()               # TRUE if this build was compiled with OpenCL
opencl_fp64_available()    # Is double-precision (cl_khr_fp64) working?
opencl_device_info()       # Cached device/driver metadata
gpu_names()                # NVIDIA GPU names via nvidia-smi (Linux)
get_opencl_core_count()    # Total compute units across GPU devices

verify_opencl_runtime()    # Broader sanity check (ICD, driver, …)
check_runtime_env()        # Workstation-level environment diagnosis
detect_compute_runtimes()  # Enumerate CUDA, ROCm, OpenCL runtimes
```

**Host-side checks** (`detect_environment_and_gpus()`, `gpu_names()`,
`detect_compute_runtimes()`, `check_runtime_env()`) do not require OpenCL to
be compiled into the package or present on the machine.

**Before GPU dispatch**, call `has_opencl()` and `opencl_fp64_available()` at
session start. `has_opencl()` is `TRUE` only when this **build** of
`opencltools` was compiled with OpenCL support (`USE_OPENCL`), not merely when
a GPU is attached. If either returns `FALSE`, diagnose with
`verify_opencl_runtime()` or `detect_compute_runtimes()` before
`clBuildProgram`. Driver issues caught early are easier to fix than failures
buried inside kernel compilation.

### Kernel source loading (R and C++)

Load individual `.cl` files or entire annotated subdirectories into strings
ready for `clCreateProgramWithSource`. This step is **file I/O only** --- it
does not call the OpenCL driver or GPU. It works on **every** build of
`opencltools`, including CPU-only CRAN binaries. The `package` argument
names whichever installed package ships the `.cl` tree (`opencltools`,
[`nmathopencl`](https://knygren.r-universe.dev/nmathopencl), your own package, etc.):

```r
# Single shard (example from opencltools inst/cl)
src <- load_kernel_source("nmath/bd0.cl", package = "opencltools")

# Full annotated library in dependency order
lib_src <- load_kernel_library("nmath", package = "opencltools")
```

If no text could be read, the functions return `""` and emit a `message()`.
Missing paths still raise an error. Use `has_opencl()` when you need to know
whether this **binary** can run downstream GPU code, not to gate loading.

The C++ equivalents (`openclPort::load_kernel_source`,
`openclPort::load_kernel_library`, `openclPort::load_library_for_kernel`) are
declared in `opencltools/openclPort.h` via `LinkingTo: opencltools`. Add
`opencltools::opencltoolsLdFlags()` to `PKG_LIBS` so symbols resolve from this
package's shared library. OpenCL C API headers (`CL/cl.h`, etc.) are **not**
bundled here; use your own `configure` / SDK paths when compiling with
`USE_OPENCL` (see `inst/include/README.md`).

### Minimal library subsetting for a specific kernel

`load_library_for_kernel()` reads the dependency annotation on your launcher
`.cl` file and concatenates only the library shards that kernel actually
needs, rather than the entire library. This reduces first-call just-in-time (JIT)
compilation time and keeps the program source small. It works with any
annotated `.cl` library --- not just `nmath`:

```r
lib_dir     <- system.file("cl/mylib", package = "my_ported_lib")
kernel_path <- "path/to/my_kernel.cl"

src <- load_library_for_kernel(
  kernel_path, lib_dir,
  depends_tag = "all_depends_mylib"
)
print(src)   # S3: nmathopencl_concatenated_lib (stems, size; not full source)
```

Returns a `character` vector with class `nmathopencl_concatenated_lib` and
attributes listing requested/loaded stems. `extract_library_subset()` yields
`nmathopencl_lib_extract_df` for shipping a copied subset.

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
| `load_library_for_kernel_cross_package()` | Same as above when the launcher kernel and annotated library live in different installed packages (paths relative to `inst/cl/`). |
| `load_program_preload()` | Read `program_preload_manifest.tsv` (or RDS companion) and concatenate the fixed OpenCL prelude in manifest order. |
| `read_program_preload_manifest()` / `write_program_preload_manifest()` | Inspect or regenerate manifest TSV/RDS companions under `inst/cl/`. |
| `extract_library_subset()` | Materialize a kernel-specific subset into a local directory (for packages that want to ship their own copy of the needed shards) |
| `write_kernel_dependency_index()` | Regenerate `kernel_dependency_index.rds` / `.tsv` after updating a library tree |

### Documentation

Exported functions and S3 print methods document **return types and meaning** in
help pages (`?load_kernel_source`, `?gpu_diagnostics`, `?kernel_lib_subset_printing`,
etc.): list structure for diagnostics, plain `character` vs `nmathopencl_*` classes
for loaders, and explicit **side-effect-only** wording for `print()` methods and
`opencl_reset_device_selection()`.

### Examples and `R CMD check`

Package examples are written so **CRAN checks exercise real code** without
requiring a GPU (see also the [CRAN cookbook on examples](https://contributor.r-project.org/cran-cookbook/general_issues.html#structuring-of-examples)):

| Runs on every check | Stays in `\donttest{}` (slow full `nmath` only) |
|---------------------|--------------------------------------------------|
| Host diagnostics (`detect_*`, `check_runtime_env`) | Re-indexing all ~137 shards in `cl/nmath` |
| `load_kernel_source()` / `load_kernel_library()` | Full-library demos in subset/tagging examples |
| OpenCL probes in `gpu_diagnostics` (stubs on CPU-only builds) | |
| Tagging, indexing, subsetting on `inst/cl/nmath_small/` | |

Loaders and host checks do **not** use `if (has_opencl())` in examples. Optional
OpenCL at compile time is probed with `has_opencl()` in **your** package before
GPU dispatch, not before reading `.cl` files.

Interactive demos of the full `nmath` library:

```r
example(load_library_for_kernel, run.dontest = TRUE)
devtools::run_examples(run_donttest = TRUE)
```

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
argument. When OpenCL is unavailable (no ICD, no `fp64`, driver fault), the
code transparently routes to the CPU path. Machines without a GPU install and
run the package without any changes to user code.

```cpp
// in EnvelopeEval.cpp (simplified from `glmbayes`)
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

### Program assembly in `glmbayes`

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

The first call to `f2_f3_opencl` in a session triggers just-in-time (JIT) compilation of the
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

The package **installs on CPU-only systems**. Reading and assembling `.cl`
sources works without OpenCL headers at build time. Optional OpenCL at
compile time enables `has_opencl() == TRUE`, device probes, and `fp64` selection
for packages that compile and run kernels on a GPU (NVIDIA, AMD, Intel, etc.).
Downstream code should use a `use_opencl` flag (or equivalent) and probe
`has_opencl()` / `opencl_fp64_available()` before dispatch, not before loading
kernel text.

---

## Vignettes

Vignettes are numbered so they appear in the correct order in the package
index, following the `Chapter-NN` convention used by `glmbayes`.

| Vignette file | Status | Title |
|---------------|--------|-------|
| `Chapter-01` | ✓ | **Getting started** — Setting up OpenCL, verifying the runtime, first kernel load |
| `Chapter-02` | ✓ | **Using a ported library** — Annotating kernels, assembling programs, subsetting a `.cl` library ([`nmathopencl`](https://knygren.r-universe.dev/nmathopencl) as the worked example) |
| `Chapter-03` | ✓ | **Kernel runners and wrappers** — The runner/wrapper pattern from [`glmbayes`](https://github.com/knygren/glmbayes), graceful fallback |
| `Chapter-00` | planned | **Introduction** — What opencltools is and when to use it |
| `Chapter-04` | planned | **Testing and parity validation** — Verifying numerical accuracy of ported device code before production use |
| `Chapter-A01` | planned | **Appendix: Kernel annotation in depth** — `attach_kernel_call_tags`, `attach_cross_library_tags`, dependency closure, `@depends` vs `@all_depends`, index format |
| `Chapter-A02` | planned | **Appendix: Shipping a library subset** — Using `extract_library_subset` and `write_kernel_dependency_index` to ship a minimal shard tree with your package |

---

## References

### Citing this package

Nygren, K. N. (2026). *opencltools: OpenCL Tools for R Package Developers*.
R package. Use `citation("opencltools")` for BibTeX and a layered set of
related entries (methodology, OpenCL, `glmbayes`).

### Methodology in the worked example (`f2_f3_*` kernels)

The vignettes and `ex_glmbayes_*` example kernels evaluate **likelihood
subgradient** quantities used in envelope-based accept–reject sampling. That
statistical construction is from:

Nygren, K. N., & Nygren, L. M. (2006). Likelihood subgradient densities.
*Journal of the American Statistical Association*, 101(475), 1144–1156.
<https://doi.org/10.1198/016214506000000357>

Cite this paper when your work uses that envelope/subgradient computation,
not when you only use the generic OpenCL loading and annotation tools.

### OpenCL runtime

Stone, J. E., Gohara, D., & Shi, G. (2010). OpenCL: A Parallel Programming
Standard for Heterogeneous Computing Systems. *IEEE Computing in Science &
Engineering*, 12(3), 66–72. <https://doi.org/10.1109/MCSE.2010.69>

Khronos OpenCL Working Group. *The OpenCL Specification* and *The OpenCL C
Specification*. <https://www.khronos.org/opencl/>

OpenCL and the OpenCL logo are trademarks of Apple Inc. used by permission by
Khronos.

### Related R packages

- [`nmathopencl`](https://knygren.r-universe.dev/nmathopencl) — example ported statistical library used in vignettes
- [`glmbayes`](https://github.com/knygren/glmbayes) — reference downstream application and source of the
  runner/wrapper pattern; portions of the runtime layer were adapted during
  the split from `glmbayes`
