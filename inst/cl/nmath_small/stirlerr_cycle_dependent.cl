// @source_type: c
// @source_origin: stirlerr_cycle_dependent.c
// @includes: nmath.h
// @depends: pgamma_utils, nmath
// @provides: stirlerr_cycle_dependent
// @all_depends_count: 13
// @all_depends: refactored, Rmath, nmath, stirlerr_cycle_free, chebyshev, cospi, fmax2, gammalims, lgammacor, log1p, gamma, lgamma, pgamma_utils
// @load_order: 75

// openclport: include directives disabled for OpenCL C compilation.
// openclport: preload equivalent ported headers/shims in program assembly.
// openclport-disabled-include: #include "nmath.h"

/* Branch isolated for cycle diagnostics:
 * this is the only stirlerr split file that depends on lgamma1p().
 */
attribute_hidden double stirlerr_cycle_dependent(double n)
{
    if (n <= 0.) {
        ML_WARN_return_NAN;
    }
    return lgamma1p(n) - (n + 0.5) * log(n) + n - M_LN_SQRT_2PI;
}
