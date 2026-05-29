// @source_type: h
// @source_origin: nmath.h
// @includes: config.h, math.h, float.h, Rconfig.h, Rmath.h, RS.h, Print.h, Error.h, Arith.h, libintl.h
// @depends: Rmath
// @provides: MATHLIB_PRIVATE_H, LDOUBLE, __STDC_WANT_IEC_60559_FUNCS_EXT__, R_forceint, R_nonint, MATHLIB_ERROR, MATHLIB_WARNING, MATHLIB_WARNING2, MATHLIB_WARNING3, MATHLIB_WARNING4, MATHLIB_WARNING5, MATHLIB_WARNING6, ML_POSINF, ML_NEGINF, ML_NAN, calloc, free, _, ML_VALID, ME_NONE, ME_DOMAIN, ME_RANGE, ME_NOCONV, ME_PRECISION, ME_UNDERFLOW, ML_WARNING, ML_WARN_return_NAN, WILCOX_MAX, attribute_hidden, bd0, ebd0, chebyshev_eval, chebyshev_init, gammalims, lfastchoose, lgammacor, stirlerr, pnchisq_raw, pgamma_raw, pnbeta_raw, pnbeta2, bratio, Rf_d1mach, Rf_gamma_cody, R_CheckUserInterrupt, lgammacor , stirlerr  , log1pmx, lgamma1p, pbeta_raw, qchisq_appr, Rf_i1mach
// @all_depends_count: 1
// @all_depends: Rmath
// @load_order: 7

/*
 *  Mathlib : A C Library of Special Functions
 *  Copyright (C) 1998-2025  The R Core Team
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
 */

/* Private header file for use during compilation of Mathlib */
#ifndef MATHLIB_PRIVATE_H
#define MATHLIB_PRIVATE_H

#ifdef HAVE_CONFIG_H
// openclport: include directives disabled for OpenCL C compilation.
// openclport: preload equivalent ported headers/shims in program assembly.
// openclport-disabled-include: #  include <config.h>
#endif

/* Required by C99 but might be slow */
#ifdef HAVE_LONG_DOUBLE
#  define LDOUBLE long double
#else
#  define LDOUBLE double
#endif

/* To ensure atanpi, cospi,  sinpi, tanpi are defined */
# ifndef __STDC_WANT_IEC_60559_FUNCS_EXT__
#  define __STDC_WANT_IEC_60559_FUNCS_EXT__ 1
# endif

// openclport-disabled-include: #include <math.h>
// openclport-disabled-include: #include <float.h> /* DBL_MIN etc */

// openclport-disabled-include: #include <Rconfig.h>
// openclport-disabled-include: #include <Rmath.h>

/* Used internally only */
double  Rf_d1mach(int);
double	Rf_gamma_cody(double);

// openclport-disabled-include: #include <R_ext/RS.h>

/* possibly needed for debugging */
// openclport-disabled-include: #include <R_ext/Print.h>

/* moved from dpq.h */
#if defined(__OPENCL_VERSION__) || defined(__OPENCL_C_VERSION__)
# define R_forceint(x)   rint(x)
#elif defined(HAVE_NEARBYINT)
# define R_forceint(x)   nearbyint(x)
#else
# define R_forceint(x)   round(x)
#endif
//R >= 3.1.0; previously: (fabs((x) - R_forceint(x)) > 1e-7)
//R >= 4.4.0; previously: (fabs((x) - R_forceint(x)) > 1e-7 * fmax2(1., fabs(x)))
# define R_nonint(x) 	  (fabs((x) - R_forceint(x)) > 1e-9 * fmax2(1., fabs(x)))
/*						       .... maybe change even to ~ 1e-11 or 12 */

// openclport-disabled-include: #include <R_ext/Error.h>
# define MATHLIB_ERROR(fmt,x)		error(fmt,x);
# define MATHLIB_WARNING(fmt,x)		warning(fmt,x)
# define MATHLIB_WARNING2(fmt,x,x2)	warning(fmt,x,x2)
# define MATHLIB_WARNING3(fmt,x,x2,x3)	warning(fmt,x,x2,x3)
# define MATHLIB_WARNING4(fmt,x,x2,x3,x4) warning(fmt,x,x2,x3,x4)
# define MATHLIB_WARNING5(fmt,x,x2,x3,x4,x5) warning(fmt,x,x2,x3,x4,x5)
# define MATHLIB_WARNING6(fmt,x,x2,x3,x4,x5,x6) warning(fmt,x,x2,x3,x4,x5,x6)

// openclport-disabled-include: #include <R_ext/Arith.h>
#ifndef ML_POSINF
#define ML_POSINF	R_PosInf
#endif
#ifndef ML_NEGINF
#define ML_NEGINF	R_NegInf
#endif
#ifndef ML_NAN
#define ML_NAN		R_NaN
#endif


void R_CheckUserInterrupt(void);
/* Ei-ji Nakama reported that AIX 5.2 has calloc as a macro and objected
   to redefining it.  Tests added for 2.2.1 */
#ifdef calloc
# undef calloc
#endif
#define calloc R_chk_calloc
#ifdef free
# undef free
#endif
#define free R_chk_free

#ifdef ENABLE_NLS
// openclport-disabled-include: #include <libintl.h>
#define _(String) gettext (String)
#else
#define _(String) (String)
#endif

#define ML_VALID(x)	(!ISNAN(x))

#define ME_NONE		0
/*	no error */
#define ME_DOMAIN	1
/*	argument out of domain */
#define ME_RANGE	2
/*	value out of range */
#define ME_NOCONV	4
/*	process did not converge */
#define ME_PRECISION	8
/*	does not have "full" precision */
#define ME_UNDERFLOW	16
/*	and underflow occurred (important for IEEE)*/


/* Device-only ports: string literals live in __constant address space, so the
 * host nmath.h pattern (char *msg = _("...")) is ill-formed in OpenCL C.  Some
 * implementations also compile device programs without defining
 * __OPENCL_VERSION__ / __OPENCL_C_VERSION__, which would incorrectly select the
 * host branch—always use no-op warnings here (matching R's ML_WARNING for
 * ME_DOMAIN anyway). */
#define ML_WARNING(x, s) ((void)0)
#define ML_WARN_return_NAN { return ML_NAN; }

/* Wilcoxon Rank Sum Distribution */

#define WILCOX_MAX 50

#ifdef HAVE_VISIBILITY_ATTRIBUTE
# define attribute_hidden __attribute__ ((visibility ("hidden")))
#else
# define attribute_hidden
#endif

/* Formerly private part of Mathlib.h */

/* always remap internal functions */
#define bd0       	Rf_bd0
#define ebd0       	Rf_ebd0
#define chebyshev_eval	Rf_chebyshev_eval
#define chebyshev_init	Rf_chebyshev_init
#define gammalims	Rf_gammalims
#define lfastchoose	Rf_lfastchoose
#define lgammacor	Rf_lgammacor
#define stirlerr       	Rf_stirlerr
#define pnchisq_raw   	Rf_pnchisq_raw
#define pgamma_raw   	Rf_pgamma_raw
#define pnbeta_raw   	Rf_pnbeta_raw
#define pnbeta2       	Rf_pnbeta2
#define bratio       	Rf_bratio

	/* Chebyshev Series */

attribute_hidden int chebyshev_init(double*, int, double);
attribute_hidden double chebyshev_eval(double, const double *, const int);

	/* Gamma and Related Functions */

attribute_hidden void gammalims(double*, double*);
attribute_hidden double lgammacor(double); /* log(gamma) correction */
attribute_hidden double stirlerr(double);  /* Stirling expansion "error" */

attribute_hidden double lfastchoose(double, double);

attribute_hidden double bd0(double, double);
attribute_hidden void ebd0(double, double, double*, double*);
attribute_hidden double log1pmx(double);
attribute_hidden double lgamma1p(double);

attribute_hidden double pnchisq_raw(double, double, double, double, double,
				     int, Rboolean, Rboolean);
attribute_hidden double pgamma_raw(double, double, int, int);
attribute_hidden double pbeta_raw(double, double, double, int, int);
attribute_hidden double qchisq_appr(double, double, double, int, int, double tol);
attribute_hidden LDOUBLE pnbeta_raw(double, double, double, double, double);
attribute_hidden double pnbeta2(double, double, double, double, double, int, int);

int	Rf_i1mach(int);

/* From toms708.c */
attribute_hidden void bratio(double a, double b, double x, double y,
	    		     double *w, double *w1, int *ierr, int log_p);


#endif /* MATHLIB_PRIVATE_H */
