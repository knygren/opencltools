// @source_type: c
// @source_origin: stirlerr.c
// @includes: nmath.h, refactored.h
// @depends: stirlerr_cycle_dependent, stirlerr_cycle_free, nmath, refactored
// @provides: stirlerr
// @all_depends_count: 14
// @all_depends: refactored, Rmath, nmath, stirlerr_cycle_free, chebyshev, cospi, fmax2, gammalims, lgammacor, log1p, gamma, lgamma, pgamma_utils, stirlerr_cycle_dependent
// @load_order: 87

// openclport: include directives disabled for OpenCL C compilation.
// openclport: preload equivalent ported headers/shims in program assembly.
// openclport-disabled-include: #include "nmath.h"
// openclport-disabled-include: #include "refactored.h"

/* Wrapper split for cycle refactor:
 * - stirlerr_cycle_free handles n >= 1 without lgamma1p
 * - stirlerr_cycle_dependent handles n < 1 using lgamma1p
 */
attribute_hidden double stirlerr(double n)
{
    if (n < 1.) {
        return stirlerr_cycle_dependent(n);
    }
    return stirlerr_cycle_free(n);
}
