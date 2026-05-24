# nmathopencl

![License: GPL-2](https://img.shields.io/badge/license-GPL--2-blue.svg)
[![R-universe](https://knygren.r-universe.dev/badges/nmathopencl)](https://knygren.r-universe.dev/nmathopencl)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/knygren/nmathopencl?label=version)

`nmathopencl` is an OpenCL port of R's Mathlib (`nmath`) --- the C library
that powers the statistical and mathematical functions in R. Its primary
purpose is to serve as a **reusable backend library** for developers who want
to write GPU-accelerated R code that calls nmath functions from within their
own custom OpenCL kernels.

---

## Why does this exist?

### The problem: you want GPU acceleration, but your math is R's math

Suppose you are writing an R package that benefits from GPU computation. Your
algorithm is embarrassingly parallel --- many independent evaluations, no
data dependency between them --- and you want to dispatch that work to an
OpenCL device. So far, so good.

The problem arises when the computation you need to parallelize is not just
arithmetic, but statistical math: log-likelihoods that call `lgamma` or
`lbeta`, sampling routines that call `rgamma` or `rnorm`, acceptance criteria
that evaluate `pbeta` or `pnorm`. These functions exist in R and in R's C
library, but they are designed for sequential host execution. They are not
available inside an OpenCL kernel. A GPU kernel cannot call `stats::dgamma`.

Before `nmathopencl`, a developer wanting GPU-accelerated statistical math had
two options: find a third-party GPU math library and translate their algorithm
into that library's API, or port the required nmath functions themselves. Both
options are substantial engineering work, and neither produces something that
other R developers can reuse.

`nmathopencl` solves this by providing the ported sources as a **distributable
R package**. Install `nmathopencl`, and the ported OpenCL C files are available
on disk at `system.file("cl", package = "opencltools")`. Any R package that
lists `nmathopencl` as a dependency can find those files at runtime and include
them in its own OpenCL program builds.

---

## Audience and workflow (draft kernels to a downstream package)

Downstream developers typically **port or rewrite kernels** from legacy CPU-oriented
sources, keep **`*.cl` launchers inside their own package**, annotate them with structured
dependency tags (`@depends_nmath`, `@all_depends_nmath`, broader `@depends`/`@provides`
where applicable), then:

1. **Validate** --- **`load_library_for_kernel(..., depends_tag = "all_depends_nmath")`** concatenates
   the inferred minimal set of ported `inst/cl/nmath/` shards for a launcher from transitive
   **`@all_depends_nmath`** annotations (optional **`warning()` hints** mirror
   **`inst/extdata/opencl_known_failures.json`** for curated fragile subgraphs).

2. **Optional materialisation** --- **`extract_library_subset()`** writes that subset (and index companions)
   next to kernels you intend to vendor; regenerate **`kernel_dependency_index.rds`** alongside the library
   with **`write_kernel_dependency_index()`** after substantive port edits.

3. **Integrate** --- either (**a**) remain linked to **`nmathopencl`** via **`system.file(..., package =
   "nmathopencl")`** and concatenate prelude + shim layers + `nmath` + your kernels yourself, or (**b**) ship only
   the extracted shards. **`glmbayes`** shows the reference **runner + caches + host plumbing** atop that stack;
   most authors still own compilation lifetimes and R exports until richer automation arrives for trivial launchers.

---

## Diagnostics and runtime checks

Cheap probes before assembling large sources or diagnosing workstation issues:

| Concern | R entry points |
|---------|----------------|
| Device present / built with OpenCL | **`has_opencl()`** |
| Double-precision & device bookkeeping for fp64-heavy nmath kernels | **`opencl_fp64_available()`**, **`opencl_device_info()`**, **`opencl_reset_device_selection()`** |
| Session sanity / environment | **`verify_opencl_runtime`**, **`check_runtime_env`** |

Optional onboarding / inventory helpers (**`detect_compute_runtimes`**, **`detect_environment_and_gpus`**, **`detect_or_install_gpu_drivers`**, **`get_opencl_core_count`**, **`gpu_names`**).

---

## The canonical example: glmbayes and EnvelopeEval

The R helpers above let you sanity-check **`@all_depends_nmath` closures locally** before mirroring the
full-layer OpenCL compilation pattern below (`load_kernel_library` / `load_kernel_source` stacking prelude,
shims, and `nmath`).

The most direct illustration of how `nmathopencl` is meant to be used is
`glmbayes`. Bayesian GLM sampling via accept-reject methods requires evaluating
likelihood envelope functions for every posterior draw. This construction is
embarrassingly parallel --- each candidate can be evaluated independently --- but
the inner computation involves distribution functions and special functions
from nmath: `lgamma`, `lbeta`, `pgamma`, `dnorm`, and related routines.

To accelerate this step on a GPU, `glmbayes` builds an OpenCL program at
runtime that includes the relevant ported nmath sources from `nmathopencl` and
adds its own kernel logic on top. The program compilation happens once; all
subsequent envelope evaluations within a session are dispatched to the GPU.
The speedup grows with model dimension, because a larger parameter space means
more independent envelope evaluations per draw.

### EnvelopeEval: the concrete case

`EnvelopeEval()` in `glmbayes` is the function that evaluates the negative
log-likelihood and its gradients across a full grid of parameter values --- the
step that feeds the rejection sampler. For a Bayesian binomial logit model
with, say, fourteen predictors, this grid can contain thousands of points, and
each point requires evaluating the binomial log-likelihood and its gradient
vector using nmath routines.

When `use_opencl = TRUE`, `EnvelopeEval` dispatches to its GPU backend
(`f2_f3_opencl`). That function assembles a complete OpenCL program at
runtime by concatenating source layers in a fixed dependency order:

1. A global configuration header (`OPENCL.cl`) that enables double-precision
   arithmetic and defines IEEE constants.
2. The full `nmathopencl` layer --- `libR_shims`, `R_ext_types`, `R_shims`,
   `R_ext_runtime`, `R_ext_internals`, `System`, and `nmath` --- loaded in that
   order via `load_kernel_library(..., package = "opencltools")`. This makes
   functions like `lgamma`, `lbeta`, `dbinom`, and `dpois` available as
   device-side functions.
3. The model- and link-specific kernel (e.g. `f2_f3_binomial_logit.cl`), which
   contains the actual `__kernel` entry point and calls freely into the nmath
   layer above it.

This assembled source is compiled once by the OpenCL driver and then
dispatched as a single kernel invocation. All grid points are evaluated
simultaneously on the GPU; the results come back as the `NegLL` vector and
`cbars` gradient matrix that the rejection sampler consumes.

Without `nmathopencl`, writing `f2_f3_binomial_logit.cl` would require either
re-implementing `lgamma`, `lbeta`, and `dbinom` from scratch inside the kernel
or finding a compatible GPU math library --- a significant engineering effort
that would also be package-specific and non-reusable. With `nmathopencl`, the
nmath layer is already there, annotated for dependency resolution, and
available to any package that lists `nmathopencl` as a dependency.

For a detailed walkthrough of the `EnvelopeEval` workflow --- including the
full program assembly sequence, the CPU and GPU backends, and the role of the
computed values in the rejection sampler --- see:

- `?EnvelopeEval` in `glmbayes`
- `example("EnvelopeEval")` for a runnable isolated demonstration
- [Chapter A10 --- Accelerated EnvelopeBuild Implementation using OpenCL](https://knygren.r-universe.dev/articles/glmbayes/Chapter-A10.html)
- [Chapter 12 --- Large Models: GPU Acceleration using OpenCL](https://knygren.r-universe.dev/articles/glmbayes/Chapter-12.html)

This pattern --- borrow the nmath layer from `nmathopencl`, write your own
kernel logic that calls into it --- is exactly what this package is designed to
enable. `glmbayes` provides the reference implementation, but the same approach
applies to any package that needs statistical math inside an OpenCL kernel.

---

## What "using nmathopencl as a backend" looks like

The assembly of an OpenCL program is done in **C++** using **`load_kernel_source()`**
and **`load_kernel_library()`**. **`glmbayes`** ships reference call sites (`f2_f3_opencl`, etc.);
**`nmathopencl`** also exports **`load_kernel_library()`** / **`load_kernel_source()`**
so sibling packages can **Import** **`nmathopencl`** directly while **`glmbayes` gradually
drops duplicate loaders. Together they resolve file discovery under **`system.file("cl/", package = "opencltools")`**,
parse **`@provides`** / **`@depends`**, and concatenate each requested subtree in dependency order ---
you nominate a subdirectory name (**`nmath`**, **`System`**, …), not every filename.

The full load order that `glmbayes` uses (reflected in `f2_f3_opencl`) is:

```cpp
// 1. Global OpenCL configuration header (extensions, IEEE constants, macros)
std::string OPENCL_source          = load_kernel_source("OPENCL.cl");

// 2-7. The nmathopencl layer, loaded in dependency order from nmathopencl's inst/cl/
std::string libr_shims_source      = load_kernel_library("libR_shims",     "opencltools", false);
std::string r_ext_types_source     = load_kernel_library("R_ext_types",    "opencltools", false);
std::string r_shims_source         = load_kernel_library("R_shims",        "opencltools", false);
std::string r_ext_runtime_source   = load_kernel_library("R_ext_runtime",  "opencltools", false);
std::string r_ext_internals_source = load_kernel_library("R_ext_internals","opencltools", false);
std::string system_source          = load_kernel_library("System",         "opencltools", false);
std::string nmath_source           = load_kernel_library("nmath",          "opencltools", false);

// 8. Your model-specific kernel source
std::string ksrc = load_kernel_source("src/my_kernel.cl");

// Concatenate into a single program string and compile
std::string all_src = OPENCL_source
  + "\n" + libr_shims_source
  + "\n" + r_ext_types_source
  + "\n" + r_shims_source
  + "\n" + r_ext_runtime_source
  + "\n" + r_ext_internals_source
  + "\n" + system_source
  + "\n" + nmath_source
  + "\n" + ksrc;
```

The key point is steps 2-7: these are the layers from `nmathopencl`, loaded
via the `package = "opencltools"` argument so that `load_kernel_library`
finds them at `system.file("cl/<subdir>", package = "opencltools")`. Together
they satisfy all of nmath's type, macro, and runtime dependencies.
Step 8 is entirely your own code. Inside `my_kernel.cl` you can call any
nmath function --- `lgamma`, `lbeta`, `pbeta`, `dnorm`, `rgamma`, and so on ---
exactly as you would in regular C, because the nmath layer above has already
defined them as inline OpenCL device functions.

`load_kernel_library` performs a topological sort based on `@provides` and
`@depends` annotations in each `.cl` file, so the files within each
subdirectory are concatenated in the correct dependency order. You do not need
to enumerate individual files.

The result is that you can write kernel logic that looks essentially identical
to what you would write in R --- using the same functions, the same parameter
conventions, the same numeric behavior --- but executes on the GPU.

---

## What is actually ported

The `inst/cl` directory of `nmathopencl` is the distributable library tree.
It is organized into dependency layers that mirror how R itself structures
these components:

```
inst/cl/
  R_ext_types/       --- type definitions (SEXP, Rboolean, etc.)
  R_ext_runtime/     --- memory, error, and I/O interface shims
  R_ext_internals/   --- internal R extension definitions
  libR_shims/        --- host runtime compatibility shims (R_pow, R_pow_di, etc.)
  R_shims/           --- additional R API shims
  System/            --- system-level OpenCL prelude
  nmath/             --- the ported Mathlib sources (~137 .cl files)
  src/               --- kernel entry points for the included R wrappers
```

The `nmath/` directory contains the translated sources for the following
function families:

| Category | Functions |
|----------|-----------|
| Normal | `dnorm`, `pnorm`, `qnorm`, `rnorm` |
| Uniform | `dunif`, `punif`, `qunif`, `runif` |
| Gamma | `dgamma`, `pgamma`, `qgamma`, `rgamma` |
| Beta | `dbeta`, `pbeta`, `qbeta`, `rbeta`, `lbeta` |
| Log-Normal | `dlnorm`, `plnorm`, `qlnorm`, `rlnorm` |
| Chi-squared | `dchisq`, `pchisq`, `qchisq`, `rchisq` |
| Non-central Chi-squared | `dnchisq`, `pnchisq`, `qnchisq`, `rnchisq` |
| F | `df`, `pf`, `qf` |
| Non-central F | `dnf`, `pnf`, `qnf` |
| Student t | `dt`, `pt`, `qt`, `rt` |
| Non-central t | `dnt`, `pnt`, `qnt` |
| Binomial | `dbinom`, `pbinom`, `qbinom`, `rbinom`, `dbinom_raw` |
| Negative Binomial | `dnbinom`, `pnbinom`, `qnbinom`, `rnbinom` (and `_mu` variants) |
| Poisson | `dpois`, `ppois`, `qpois`, `rpois`, `dpois_raw` |
| Exponential | `dexp`, `pexp`, `qexp`, `rexp` |
| Weibull | `dweibull`, `pweibull`, `qweibull`, `rweibull` |
| Logistic | `dlogis`, `plogis`, `qlogis`, `rlogis` |
| Cauchy | `dcauchy`, `pcauchy`, `qcauchy`, `rcauchy` |
| Geometric | `dgeom`, `pgeom`, `qgeom`, `rgeom` |
| Hypergeometric | `dhyper`, `phyper`, `qhyper`, `rhyper` |
| Non-central Beta | `dnbeta`, `pnbeta`, `qnbeta` |
| Studentized Range | `ptukey`, `qtukey` |
| Wilcoxon Rank Sum | `dwilcox`, `pwilcox`, `qwilcox`, `rwilcox` |
| Wilcoxon Signed Rank | `dsignrank`, `psignrank`, `qsignrank`, `rsignrank` |
| Multinomial | `rmultinom` |
| Gamma/special | `gammafn`, `lgammafn`, `psigamma`, `digamma`, `trigamma`, `tetragamma`, `pentagamma` |
| Beta/choose | `beta`, `lbeta`, `choose`, `lchoose` |
| Bessel | `bessel_i`, `bessel_j`, `bessel_k`, `bessel_y` (and `_ex` variants) |
| Math support | `fmax2`, `fmin2`, `imax2`, `imin2`, `sign`, `fprec`, `fround`, `fsign`, `ftrunc` |
| Runtime math | `log1pmx`, `log1pexp`, `log1mexp`, `lgamma1p`, `pow1p`, `logspace_add`, `logspace_sub`, `logspace_sum` |
| RNG core | `exp_rand`, `norm_rand`, `unif_rand` |

Each `.cl` file is the translated equivalent of the corresponding nmath `.c`
source. Where the upstream source depends on host-only R runtime behaviors
(macros, inline utility functions, type aliases), those dependencies are
satisfied by the layered shim files in the other subdirectories.

---

## R helpers exported for kernel authors (`nmathopencl` vs duplication)

Grouped by typical need for someone following **§ Audience and workflow**. Companion package
**`openclport`** ultimately owns generic kernel-string assembly tooling; **`nmathopencl`**
currently exports the overlapping entry points so kernel authors need not wait on every
satellite hitting CRAN. **`glmbayes`** still ships parallel helpers for transitional
compatibility --- target **`Imports: nmathopencl`** rather than sustaining duplicate loaders.

### Tier A --- Subset authoring (primary CRAN-facing story)

| Function | Purpose |
|----------|---------|
| **`load_library_for_kernel()`** | Minimal concatenated text for **one launcher** respecting **`@all_depends_nmath`**, assembler notes, curated warnings. |
| **`extract_library_subset()`** | Materialise shards + indexes into another directory for vendoring subset trees. |
| **`write_kernel_dependency_index()`** | Regenerate RDS/TSV index beside `inst/cl/nmath/` after substantive port tooling runs. |

### Tier B --- Full-program stacking (mirror `glmbayes`/OpenCL prelude)

| Function | Purpose |
|----------|---------|
| **`load_kernel_library()`** | Recursive dependency-aware concatenation of an `inst/cl/<subdir>/` subtree. |
| **`load_kernel_source()`** | Load a standalone header/device file (often `OPENCL.cl`-style prelude). |

### Tier C --- Device / fp64 utilities (stay with `nmathopencl`)

| Function | Purpose |
|----------|---------|
| **`has_opencl()`**, **`opencl_fp64_available()`**, **`opencl_device_info()`**, **`opencl_reset_device_selection()`** | Host-side capability & fp64 probing tied to kernels shipped here. |

### Tier D --- Optional environment / onboarding

| Functions | Purpose |
|-----------|---------|
| **`verify_opencl_runtime`**, **`check_runtime_env`**, **`detect_compute_runtimes`**, **`detect_environment_and_gpus`**, **`detect_or_install_gpu_drivers`**, **`get_opencl_core_count`**, **`gpu_names`**, **`diagnose_glmbayes`** | Diagnostics and workstation inventory; overlaps generic tooling slated for tighter consolidation alongside **`openclport`**. |

### Tier E --- Maintainer-only port plumbing

Less common once bundles are annotated; prefer **`openclport`** internals when authoring new subgraphs.

| Function | Purpose |
|----------|---------|
| **`stage_kernel_dependency_sort()`** | Offline ordering passes for regenerated trees. |
| **`attach_kernel_dependency_tags()`**, **`attach_cross_library_tags()`** | Batch annotation tooling. |

### Tier F --- POSIX/PATH ergonomics (`glmbayes` overlap)

Developer helpers (**`add_to_path_linux()`**, **`add_to_path_windows()`**, **`add_to_libpath_linux()`**) for workstation PATH / library-path tweaks tied to GPU driver workflows; overlaps **`glmbayes`** until loaders consolidate.

---

## Secondary feature: bundled `*_opencl` wrappers (parity testing)

Aside from authoring custom kernels (**§ Audience and workflow**), `nmathopencl` exposes
many **`distribution_opencl()`**-style helpers that enqueue pre-built GPU launchers wrapping
individual Mathlib calls. Treat them foremost as **numeric regression harnesses** verifying
parity with `stats`/base before you trust inlined device code.

```r
library(nmathopencl)

# Gamma PDF sanity check on device
dgamma_opencl(n = 1e5, x = 2.5, shape = 3, scale = 1)

# RNG smoke on device
rnorm_opencl(n = 1e6, mean = 0, sd = 1)

# Poisson log-probability grid
dpois_opencl(n = 5e4, x = 3, lambda = 2.5, log = TRUE)
```

They double as turnkey batched calculators when GPU dispatch already matches your bottleneck,
yet the curated workflow remains **assemble your kernel + stitched nmath subgraph**.

Each wrapper honours **`fallback`**, default **`FALSE`** --- GPU faults surface loudly.
**`fallback = TRUE`** masks recoverable failures with CPU `stats` analogues whenever OpenCL
appears available (see **`has_opencl()`**). Machines **without OpenCL support** always follow
CPU paths regardless of **`fallback`**. Begin runtime probing with **§ Diagnostics and runtime checks**.

---

## What had to be refactored to make this work

Porting R's Mathlib to OpenCL C is not a mechanical find-and-replace. The
upstream nmath code was written for a C compiler with access to a full host
runtime, POSIX headers, and R's own infrastructure. OpenCL device code has
none of these. Making the port work required:

- **Dependency isolation.** Each `.cl` file specifies the other `.cl` files it
  depends on. The shim layers must be loaded in an order that satisfies all
  declarations before any definitions reference them. The package includes
  tooling for managing and validating this ordering.

- **Macro and type hygiene.** R's headers define macros like `ML_ERR_return_NAN`,
  `MATHLIB_ERROR`, `R_FINITE`, and many others. These assume a host C
  environment. The ported shim files replace them with OpenCL-compatible
  equivalents.

- **Runtime symbol replacement.** Host-only R runtime symbols ---
  `R_pow`, `R_pow_di`, `R_CheckUserInterrupt`, and others --- are replaced by
  inline device implementations in the `libR_shims` layer.

- **Linkage model differences.** OpenCL C's compilation model differs from
  standard C in how it handles `static inline` versus external function
  definitions. Some upstream nmath functions required linkage adjustments
  to avoid "unresolved extern" failures during GPU program build.

---

## Performance: first call versus subsequent calls

When an OpenCL program is first built --- whether from `nmathopencl`'s own
wrappers or from a downstream package like `glmbayes` --- the driver performs a
JIT compilation of the program source for your specific GPU hardware. This step
can take several seconds for programs that include substantial portions of the
nmath library. It happens once per program, per session.

On subsequent calls, the compiled kernel is cached by the driver. The overhead
drops to kernel dispatch and buffer transfer costs, which for large batches are
small relative to the computation.

The practical takeaway: build your OpenCL programs once and reuse them across
calls. Packages like `glmbayes` do this by caching the compiled program state
for the duration of a session. If you build your own package on `nmathopencl`,
the same strategy applies.

---

## Known limitations

The port is active and expanding. Not every ported function runs on every GPU
stack without caveats. The two main limitation classes are:

### Host-runtime allocation dependencies

Some nmath routines maintain dynamic allocation caches that assume a host C
runtime. These cannot be trivially shimmed for GPU device code:

- **Wilcoxon rank sum / signed rank** (`wilcox.cl`, `signrank.cl`): both
  routines allocate and cache coefficient arrays using `calloc`/`free` or
  `R_chk_calloc`. These patterns have no direct GPU equivalent. The `.cl`
  sources are included in the library tree but result in link failures when
  used directly as GPU kernels without a device-side allocator solution. CPU
  fallback works correctly.

- **Bessel functions** (`bessel_i.cl` etc.): upstream code uses `R_alloc`
  for temporary workspace. A shim returning a null pointer is in place but
  insufficient for production use; the runtime fails when the workspace is
  dereferenced.

### Resource-intensive iterative routines

Several noncentral quantile and CDF inversion routines involve deep iterative
loops with nested distribution calls. On some GPU stacks, these hit driver
watchdog limits or register pressure:

- `qf`, `qnbeta`, `qnchisq`, `qnt`, `pnf` in some parameter regions

These functions work correctly via the CPU fallback path. Whether they run
successfully as GPU kernels depends on the hardware and driver.

### Minimal program assembly

The current kernel runner assembles a conservative superset of source files
for each kernel call. A planned dependency-analysis layer will allow building
only the minimal set of source fragments actually needed by a given kernel,
which will reduce first-call compilation time.

---

## Installation

### R-universe and CRAN-style repos

Browsing [the package dashboard on **R-universe**](https://knygren.r-universe.dev/nmathopencl) lists **binaries**, **DESCRIPTION**, **exported objects**, rendered **manual** pages, **vignettes**, and dependency graphs---useful both for users and for ongoing development visibility.

Pick your mirror order (prefer R-universe first if you rely on nightly builds):

```r
opts <- options(
  repos = c(
    knygren        = "https://knygren.r-universe.dev",
    CRAN           = "https://cloud.r-project.org"
  )
)

install.packages("nmathopencl")
options(opts) # restore prior repos if desired
```

For a minimal one-off install combining both:

```r
install.packages(
  "nmathopencl",
  repos = c("https://knygren.r-universe.dev",
            "https://cloud.r-project.org")
)
```

Maintainers: registering the GitHub source repo in your universe and what to expect from automated builds are summarized in **`R-UNIVERSE.md`** at the package root.

OpenCL support requires a GPU with an installed OpenCL runtime (NVIDIA CUDA,
AMD ROCm/OpenCL, Intel OpenCL, or Apple Metal via OpenCL compatibility). The
package installs and functions without a GPU; the ported `.cl` files are
available regardless, and all R wrappers fall back to CPU computation
automatically if OpenCL is unavailable.

---

## Future plans

- **Consolidated loader ownership.** Migrate overlapping `load_kernel_*` tooling to **`openclport`**
  on CRAN while **`nmathopencl`** re-exports or thin-wraps until downstream packages switch imports.
- **Minimal program assembly.** Dependency analysis to include only the
  source files actually required for each kernel, reducing JIT compilation
  cost on first call.
- **Vectorized parameter API.** Allow passing a vector of distinct parameter
  values to a single kernel dispatch, enabling more general parallelism
  patterns in the R wrappers.
- **Rescue of allocation-dependent families.** Device-side allocator shims
  or algorithmic rework for Wilcoxon and Bessel paths.
- **Broader numeric validation.** Systematic accuracy testing across
  distributions and parameter regions.
- **Additional nmath coverage.** Remaining nmath functions not yet ported.

---

## nmath dependencies for the glmbayes `f2_f3` kernels

The `f2_f3_*.cl` kernels are the core of the `glmbayes` GPU backend. Each one
evaluates the negative log-posterior and its gradient for a specific GLM family
and link function. Understanding exactly which nmath functions they require
is useful for auditing the dependency graph, validating the port, and reasoning
about the minimal OpenCL program needed for any given model.

### Direct calls from the six `f2_f3_*.cl` kernels

| Kernel | nmath function(s) called |
|---|---|
| `f2_f3_binomial_logit.cl` | `dbinom_raw` |
| `f2_f3_binomial_probit.cl` | `dbinom_raw`, `pnorm5`, `dnorm4` |
| `f2_f3_binomial_cloglog.cl` | `dbinom_raw` |
| `f2_f3_gamma.cl` | `dgamma` |
| `f2_f3_gaussian.cl` | `dnorm4` |
| `f2_f3_poisson.cl` | `lgamma` (OpenCL built-in --- no nmath file required) |

The Poisson kernel is the simplest case: it evaluates the log-likelihood
entirely inline as `-mu + y*log(mu) - lgamma(y+1)`, where `lgamma` is a
standard OpenCL double-precision built-in. It pulls in no ported nmath files.

### Complete set of nmath `.cl` files --- including transitive dependencies

The `@all_depends` metadata embedded in each `.cl` file records the full
transitive closure of its dependencies. Taking the union across `dbinom.cl`,
`pnorm.cl`, `dnorm.cl`, and `dgamma.cl` yields the minimal set required by
all six kernels.

| CPU source (`.c`) | GPU port (`.cl`) | Provides / Description | In `glmbayes/src/nmath/`? |
|---|---|---|---|
| `dbinom.c` | `dbinom.cl` | `dbinom_raw`, `dbinom` --- binomial density | ? |
| `pnorm.c` | `pnorm.cl` | `pnorm5`, `pnorm_both` --- normal CDF | ? |
| `dnorm.c` | `dnorm.cl` | `dnorm4` --- normal density | ? |
| `dgamma.c` | `dgamma.cl` | `dgamma` --- gamma density | ? |
| `dpois.c` | `dpois.cl` | `dpois_raw`, `dpois` --- Poisson density (called by `dgamma`) | ? |
| `bd0.c` | `bd0.cl` | `bd0`, `ebd0` --- binomial deviance (called by `dbinom`, `dpois`) | ? |
| `stirlerr.c` | `stirlerr.cl` | `stirlerr` --- Stirling error term; dispatches to the two fragments below | ? |
| `stirlerr.c` (split) | `stirlerr_cycle_free.cl` | `stirlerr_cycle_free` --- table-lookup path for small arguments | ? split artifact |
| `stirlerr.c` (split) | `stirlerr_cycle_dependent.cl` | `stirlerr_cycle_dependent` --- series path for large arguments | ? split artifact |
| `pgamma.c` (extracted) | `pgamma_utils.cl` | `log1pmx`, `lgamma1p` --- utilities called by `bd0` | ? split artifact |
| `lgamma.c` | `lgamma.cl` | `lgammafn_sign`, `lgammafn` --- log-gamma function | ? |
| `gamma.c` | `gamma.cl` | `gammafn` --- gamma function | ? |
| `lgammacor.c` | `lgammacor.cl` | `lgammacor` --- series correction for large arguments | ? |
| `chebyshev.c` | `chebyshev.cl` | `chebyshev_init`, `chebyshev_eval` --- called by `lgammacor` | ? |
| `cospi.c` | `cospi.cl` | `cospi`, `sinpi`, `tanpi` --- `sinpi` called by `gammafn` for the negative-argument reflection formula | ? |
| `fmax2.c` | `fmax2.cl` | `fmax2` --- max of two doubles, called by `gammalims` | ? |
| `gammalims.c` | `gammalims.cl` | `gammalims` --- gamma function overflow/underflow bounds | ? |
| `refactored.h` | `refactored.cl` | Forward declarations for cycle-broken functions | N/A (header) |

### Key observations

**`pnorm.cl` and `dnorm.cl` are self-contained.** Their only dependencies are
the `nmath.cl` infrastructure shim and `dpq`-style macros. No additional math
function files are pulled in --- the algorithms (Cody's rational approximation for
`pnorm`, the standard Gaussian density formula for `dnorm`) close entirely on
primitive arithmetic.

**`dbinom.cl` and `dgamma.cl` share almost the entire gamma function stack.**
Both require `lgamma`, `gamma`, `lgammacor`, `chebyshev`, `cospi`, `gammalims`,
`fmax2`, `pgamma_utils`, `stirlerr`, and `bd0`. The only addition from
`dgamma.cl` is `dpois.cl`, because `dgamma` delegates to `dpois_raw` when the
shape parameter is less than 1.

**Three `.cl` files have no direct `.c` counterpart in R's nmath.**
`stirlerr_cycle_free.cl`, `stirlerr_cycle_dependent.cl`, and `pgamma_utils.cl`
are fragments split out of `stirlerr.c` and `pgamma.c` respectively. The split
is required to break mutual call cycles: OpenCL's single-translation-unit
compilation model requires that every symbol be defined before any reference to
it. Cycles that a standard C linker resolves at link time must instead be broken
structurally in OpenCL C.

**The Poisson kernel requires no nmath `.cl` files.** It expresses the entire
log-likelihood using OpenCL built-ins (`exp`, `log`, `lgamma`). This is both
the simplest kernel and the one with zero nmath dependency footprint.

---

## References

Nygren, K.N. and Nygren, A. (2006), Likelihood Subgradient Densities. *Journal
of the American Statistical Association*, 101, 1144-1156.
DOI: [10.1198/016214506000000357](https://doi.org/10.1198/016214506000000357)
