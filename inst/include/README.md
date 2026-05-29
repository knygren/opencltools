# Headers for `LinkingTo: opencltools`

This directory is installed as `include/` in the package root when **opencltools**
is installed. Downstream packages that use **`LinkingTo: opencltools`** should
include:

```cpp
#include <opencltools/openclPort.h>
```

## OpenCL C API headers (`CL/cl.h`)

**opencltools does not ship Khronos OpenCL headers** under `include/CL/`.
Each package must locate an OpenCL SDK or ICD headers via its own **`configure`**
/ **`SystemRequirements: OpenCL`** (same as building **opencltools** itself).

When **`USE_OPENCL`** is defined, `openclPort.h` includes `<CL/cl.h>` from those
system/SDK paths. Do not rely on a bundled copy from this package.

## Sync

Keep `opencltools/openclPort.h` in sync with `src/openclPort.h` in the source tree.
