// @source_type: h
// @source_origin: refactored.h
// @provides: bessel_j_cycle_dependent, bessel_j_cycle_dependent_ex, bessel_j_cycle_free, bessel_j_cycle_free_ex, bessel_y_cycle_dependent, bessel_y_cycle_dependent_ex, bessel_y_cycle_free, bessel_y_cycle_free_ex, NMATH_REFACTORED_INTERNALS_H, stirlerr_cycle_dependent, stirlerr_cycle_free
// @all_depends_count: 0
// @load_order: 4

#ifndef NMATH_REFACTORED_INTERNALS_H
#define NMATH_REFACTORED_INTERNALS_H

/*
 * Internal declarations introduced by cycle-breaking refactors.
 * These are implementation details, not public API entry points.
 */

/* Stirlerr split internals */
attribute_hidden double stirlerr_cycle_free(double);
attribute_hidden double stirlerr_cycle_dependent(double);

/* Bessel split internals */
attribute_hidden double bessel_j_cycle_free(double, double);
attribute_hidden double bessel_j_cycle_free_ex(double, double, double *);
attribute_hidden double bessel_j_cycle_dependent(double, double);
attribute_hidden double bessel_j_cycle_dependent_ex(double, double, double *);

attribute_hidden double bessel_y_cycle_free(double, double);
attribute_hidden double bessel_y_cycle_free_ex(double, double, double *);
attribute_hidden double bessel_y_cycle_dependent(double, double);
attribute_hidden double bessel_y_cycle_dependent_ex(double, double, double *);

#endif /* NMATH_REFACTORED_INTERNALS_H */
