// @source_type: c
// @source_origin: dpois.c
// @includes: nmath.h, dpq.h
// @depends: bd0, lgamma, stirlerr, nmath, dpq
// @provides: dpois, dpois_raw
// @all_depends_count: 17
// @all_depends: dpq, refactored, Rmath, nmath, stirlerr_cycle_free, chebyshev, cospi, fmax2, gammalims, lgammacor, log1p, gamma, lgamma, pgamma_utils, stirlerr_cycle_dependent, bd0, stirlerr
// @load_order: 94
// @local_macros: M_SQRT_2PI, x_LRG

// openclport: macro hygiene pre-clean for concatenated translation units.
#ifdef M_SQRT_2PI
# undef M_SQRT_2PI
#endif
#ifdef x_LRG
# undef x_LRG
#endif

/*
 *  AUTHOR
 *    Catherine Loader, catherine@research.bell-labs.com.
 *    October 23, 2000.
 *
 *  Merge in to R:
 *	Copyright (C) 2000-2021 The R Core Team
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, a copy is available at
 *  https://www.R-project.org/Licenses/
 *
 *
 * DESCRIPTION
 *
 *    dpois() checks argument validity and calls dpois_raw().
 *
 *    dpois_raw() computes the Poisson probability  lb^x exp(-lb) / x!.
 *      This does not check that x is an integer, since dgamma() may
 *      call this with a fractional x argument. Any necessary argument
 *      checks should be done in the calling function.
 *
 */

// openclport: include directives disabled for OpenCL C compilation.
// openclport: preload equivalent ported headers/shims in program assembly.
// openclport-disabled-include: #include "nmath.h"
// openclport-disabled-include: #include "dpq.h"

#define M_SQRT_2PI	2.50662827463100050241576528481104525301  /* sqrt(2*pi) */
// sqrt(2 * Rmpfr::Const("pi", 128))
#define x_LRG           2.86111748575702815380240589208115399625e+307 /* = 2^1023 / pi */

// called also from dgamma.c, pgamma.c, dnbeta.c, dnbinom.c, dnchisq.c :
double dpois_raw(double x, double lambda, int give_log)
{
    /*       x >= 0 ; integer for dpois(), but not e.g. for pgamma()!
        lambda >= 0
    */
    if (lambda == 0) return( (x == 0) ? R_D__1 : R_D__0 );
    if (!R_FINITE(lambda)) return R_D__0; // including for the case where  x = lambda = +Inf
    if (x < 0) return( R_D__0 );
    if (x <= lambda * DBL_MIN) return(R_D_exp(-lambda) );
    if (lambda < x * DBL_MIN) {
	if (!R_FINITE(x)) // lambda < x = +Inf
	    return R_D__0;
	// else
	return(R_D_exp(-lambda + x*log(lambda) -lgammafn(x+1)));
    }
    // R <= 4.0.x  had   return(R_D_fexp( M_2PI*x, -stirlerr(x)-bd0(x,lambda) ));
    double yh, yl;
    ebd0 (x, lambda, &yh, &yl);
    yl += stirlerr(x);
    bool Lrg_x = (x >= x_LRG); //really large x  <==>  2*pi*x  overflows
    double r = Lrg_x
	? M_SQRT_2PI * sqrt(x) // sqrt(.): avoid overflow for very large x
	: M_2PI * x;
    return give_log
	? -yl - yh - (Lrg_x ? log(r) : 0.5 * log(r))
	: exp(-yl) * exp(-yh) / (Lrg_x ? r : sqrt(r));
}



double dpois(double x, double lambda, int give_log)
{
#ifdef IEEE_754
    if(ISNAN(x) || ISNAN(lambda))
        return x + lambda;
#endif

    if (lambda < 0) ML_WARN_return_NAN;
    R_D_nonint_check(x);
    if (x < 0 || !R_FINITE(x))
	return R_D__0;

    x = R_forceint(x);

    return( dpois_raw(x,lambda,give_log) );
}

// openclport: macro hygiene post-clean for concatenated translation units.
#undef M_SQRT_2PI
#undef x_LRG
