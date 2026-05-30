# configure-templates

Generic OpenCL `configure` scripts for R packages.

These templates are the minimal versions of the configure scripts used by
**`glmbayes`**, **`nmathopencl`**, and **`opencltools`** — stripped of
package-specific flags (Rcpp compatibility shims, RcppParallel detection,
package identity macros) while retaining the core OpenCL detection logic
that makes those packages CRAN-safe.

---

## Contents

| File | Platform | What it does |
|------|----------|-------------|
| `configure` | Linux / macOS | Detects `CL/cl.h` + `libOpenCL`, runs a live platform probe, writes `src/Makevars` |
| `configure.win` | Windows (Rtools) | Scans PATH and known SDK roots for `CL\cl.h`, writes `src/Makevars.win` |

Both scripts **always succeed**.  When the OpenCL SDK is absent they produce
a CPU-only `Makevars` with no `-lOpenCL` and no `-DUSE_OPENCL`.  All
OpenCL-specific C++ code must be guarded by `#ifdef USE_OPENCL` so the
package compiles cleanly in either case.

---

## Quick start

```r
# Copy both scripts to the root of your package:
opencltools::use_opencl_configure()
```

Or manually:

```r
file.copy(
  system.file("configure-templates", "configure",     package = "opencltools"),
  "configure"
)
file.copy(
  system.file("configure-templates", "configure.win", package = "opencltools"),
  "configure.win"
)
# Make configure executable on Linux / macOS:
Sys.chmod("configure", mode = "0755")
```

Add the generated files to `.gitignore` (they are build artifacts, not
source files):

```
src/Makevars
src/Makevars.win
```

---

## What the scripts produce

**OpenCL-enabled build** (SDK found; Linux runtime probe succeeded):

```makefile
PKG_CXXFLAGS = -DUSE_OPENCL -I"/path/to/sdk/include"
PKG_LIBS     = -L"/path/to/sdk/lib" -lOpenCL $(LAPACK_LIBS) $(BLAS_LIBS) $(FLIBS)
```

**CPU-only build** (no SDK, CRAN build machines, or failed runtime probe):

```makefile
PKG_CXXFLAGS =
PKG_LIBS     = $(LAPACK_LIBS) $(BLAS_LIBS) $(FLIBS)
```

The `has_opencl()` R function (see `opencltools::has_opencl` and
`?opencltools::gpu_diagnostics`) is the runtime-visible mirror of this
compile-time decision: it returns `TRUE` only if `-DUSE_OPENCL` was set when
the package was built.

---

## Customising the output

The templates emit only `-DUSE_OPENCL` and the OpenCL `-I`/`-L` flags.
Add package-specific compile flags **after** the template's `PKG_CXXFLAGS`
line in the generated Makevars, or append them in the configure script
before the final `cat > src/Makevars` block.

If your package also uses **RcppParallel**, you will need to add TBB
detection.  Use the full `configure` / `configure.win` from `glmbayes` or
`nmathopencl` (available in those packages' source trees) as a reference;
they include RcppParallel path resolution and a Rcpp Function.h
compatibility workaround.

For packages that already have a static committed `src/Makevars`, use
`opencltools::port_to_opencl_configure()` to migrate to the `src/Makevars.in`
workflow.

---

## Environment variables

Both scripts honour two optional environment variables that let a developer
point to a non-standard SDK location without modifying system paths:

| Variable | Effect |
|----------|--------|
| `OPENCL_HOME` | Root of the OpenCL SDK (e.g. `/opt/opencl-sdk`) |
| `OPENCL_SDK`  | Alias for `OPENCL_HOME` |

Set before running `R CMD INSTALL` or `devtools::install()`:

```sh
# Linux / macOS
OPENCL_HOME=/opt/my-sdk R CMD INSTALL mypkg

# Windows (PowerShell, before installing)
$env:OPENCL_HOME = "C:/my-sdk"
```

---

## Why is this needed? The CRAN-safety story

The old `OpenCL` package on CRAN has no Windows binaries because its build
configuration unconditionally references `-lOpenCL` and `CL/cl.h`.  'CRAN'
Windows build machines have no GPU SDK, the build fails, and no binary is
produced.

The configure scripts here avoid this by **never hardcoding OpenCL as
required**.  They probe for the SDK, then write whichever Makevars is
appropriate.  'CRAN' builders take the CPU-only branch silently; a
developer's machine with CUDA or another SDK installed takes the
OpenCL-enabled branch.

The Linux `configure` goes one step further with a **runtime probe**
(`clGetPlatformIDs`): even if headers and `libOpenCL` are installed,
`USE_OPENCL` is only set if at least one vendor platform actually registers.
This prevents broken builds on machines where the ICD loader is present but
no vendor runtime has been configured.

---

## Linking to opencltools from downstream C++

Packages that use `LinkingTo: opencltools` should merge OpenCL SDK paths from
their own configure script and add linker flags for the shared library:

```makefile
OPENCLTOOLS_LIBS = $(shell $(R_HOME)/bin/Rscript -e "opencltools::opencltoolsLdFlags()")
PKG_LIBS = $(OPENCLTOOLS_LIBS) $(PKG_LIBS)
```

See `?opencltools::opencltoolsLdFlags` and `inst/include/opencltools/` for
the C-callable API.

---

## Re-export from nmathopencl

**`nmathopencl`** re-exports `use_opencl_configure()` and
`port_to_opencl_configure()` for convenience.  The templates always resolve
from the **`opencltools`** installation via `system.file("configure-templates",
package = "opencltools")`.

---

## See also

- `?opencltools::use_opencl_configure`, `?opencltools::port_to_opencl_configure`
- `opencltools` vignette **Chapter-01** — platform-specific OpenCL installation
- `nmathopencl` vignette **Chapter-02** — full downstream package checklist
  when building on the ported nmath kernel library
