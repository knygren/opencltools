// @source_type: c
// @source_origin: pgamma_utils.c
// @includes: nmath.h
// @depends: lgamma, log1p, nmath
// @provides: lgamma1p, log1pmx
// @all_depends_count: 12
// @all_depends: refactored, Rmath, nmath, stirlerr_cycle_free, chebyshev, cospi, fmax2, gammalims, lgammacor, log1p, gamma, lgamma
// @load_order: 63
// @local_macros: SQR

// openclport: macro hygiene pre-clean for concatenated translation units.
#ifdef SQR
# undef SQR
#endif

/*
 * Utility helpers extracted from pgamma.c during cycle refactor:
 * - log1pmx()
 * - lgamma1p()
 *
 * This keeps these reusable numerical helpers separate from pgamma()
 * distribution-flow logic so callers such as bd0.c and stirlerr.c do not
 * depend on full pgamma.c.
 */

// openclport: include directives disabled for OpenCL C compilation.
// openclport: preload equivalent ported headers/shims in program assembly.
// openclport-disabled-include: #include "nmath.h"

#define SQR(x) ((x) * (x))
static const double scalefactor = SQR(SQR(SQR(4294967296.0)));
#undef SQR

/* Continued fraction for calculation of
 *    1/i + x/(i+d) + x^2/(i+2*d) + x^3/(i+3*d) + ... = sum_{k=0}^Inf x^k/(i+k*d)
 *
 * auxiliary in log1pmx() and lgamma1p()
 */
static double
logcf(double x, double i, double d,
      double eps /* ~ relative tolerance */)
{
    double c1 = 2 * d;
    double c2 = i + d;
    double c4 = c2 + d;
    double a1 = c2;
    double b1 = i * (c2 - i * x);
    double b2 = d * d * x;
    double a2 = c4 * c2 - b2;

#if 0
    assert (i > 0);
    assert (d >= 0);
#endif

    b2 = c4 * b1 - i * b2;

    while (fabs(a2 * b1 - a1 * b2) > fabs(eps * b1 * b2)) {
        double c3 = c2 * c2 * x;
        c2 += d;
        c4 += d;
        a1 = c4 * a2 - c3 * a1;
        b1 = c4 * b2 - c3 * b1;

        c3 = c1 * c1 * x;
        c1 += d;
        c4 += d;
        a2 = c4 * a1 - c3 * a2;
        b2 = c4 * b1 - c3 * b2;

        if (fabs(b2) > scalefactor) {
            a1 /= scalefactor;
            b1 /= scalefactor;
            a2 /= scalefactor;
            b2 /= scalefactor;
        } else if (fabs(b2) < 1 / scalefactor) {
            a1 *= scalefactor;
            b1 *= scalefactor;
            a2 *= scalefactor;
            b2 *= scalefactor;
        }
    }

    return a2 / b2;
}

/* Accurate calculation of log(1+x)-x, particularly for small x.  */
double log1pmx(double x)
{
    static const double minLog1Value = -0.79149064;

    if (x > 1 || x < minLog1Value)
        return log1p(x) - x;
    else { /* -.791 <=  x <= 1  -- expand in  [x/(2+x)]^2 =: y :
            * log(1+x) - x =  x/(2+x) * [ 2 * y * S(y) - x],  with
            * ---------------------------------------------
            * S(y) = 1/3 + y/5 + y^2/7 + ... = \sum_{k=0}^\infty  y^k / (2k + 3)
           */
        double r = x / (2 + x), y = r * r;
        if (fabs(x) < 1e-2) {
            static const double two = 2;
            return r * ((((two / 9 * y + two / 7) * y + two / 5) * y +
                         two / 3) *
                            y -
                        x);
        } else {
            static const double tol_logcf = 1e-14;
            return r * (2 * y * logcf(y, 3, 2, tol_logcf) - x);
        }
    }
}

/* Compute  log(gamma(a+1))  accurately also for small a (0 < a < 0.5). */
double lgamma1p(double a)
{
    if (fabs(a) >= 0.5)
        return lgammafn(a + 1);

    const double eulers_const = 0.5772156649015328606065120900824024;

    /* coeffs[i] holds (zeta(i+2)-1)/(i+2) , i = 0:(N-1), N = 40 : */
    const int N = 40;
    static const double coeffs[40] = {
        0.3224670334241132182362075833230126e-0, /* = (zeta(2)-1)/2 */
        0.6735230105319809513324605383715000e-1, /* = (zeta(3)-1)/3 */
        0.2058080842778454787900092413529198e-1,
        0.7385551028673985266273097291406834e-2,
        0.2890510330741523285752988298486755e-2,
        0.1192753911703260977113935692828109e-2,
        0.5096695247430424223356548135815582e-3,
        0.2231547584535793797614188036013401e-3,
        0.9945751278180853371459589003190170e-4,
        0.4492623673813314170020750240635786e-4,
        0.2050721277567069155316650397830591e-4,
        0.9439488275268395903987425104415055e-5,
        0.4374866789907487804181793223952411e-5,
        0.2039215753801366236781900709670839e-5,
        0.9551412130407419832857179772951265e-6,
        0.4492469198764566043294290331193655e-6,
        0.2120718480555466586923135901077628e-6,
        0.1004322482396809960872083050053344e-6,
        0.4769810169363980565760193417246730e-7,
        0.2271109460894316491031998116062124e-7,
        0.1083865921489695409107491757968159e-7,
        0.5183475041970046655121248647057669e-8,
        0.2483674543802478317185008663991718e-8,
        0.1192140140586091207442548202774640e-8,
        0.5731367241678862013330194857961011e-9,
        0.2759522885124233145178149692816341e-9,
        0.1330476437424448948149715720858008e-9,
        0.6422964563838100022082448087644648e-10,
        0.3104424774732227276239215783404066e-10,
        0.1502138408075414217093301048780668e-10,
        0.7275974480239079662504549924814047e-11,
        0.3527742476575915083615072228655483e-11,
        0.1711991790559617908601084114443031e-11,
        0.8315385841420284819798357793954418e-12,
        0.4042200525289440065536008957032895e-12,
        0.1966475631096616490411045679010286e-12,
        0.9573630387838555763782200936508615e-13,
        0.4664076026428374224576492565974577e-13,
        0.2273736960065972320633279596737272e-13,
        0.1109139947083452201658320007192334e-13 /* = (zeta(40+1)-1)/(40+1) */
    };

    const double c = 0.2273736845824652515226821577978691e-12; /* zeta(N+2)-1 */
    const double tol_logcf = 1e-14;

    /* Abramowitz & Stegun 6.1.33 : for |x| < 2,
     * <==> log(gamma(1+x)) = -(log(1+x) - x) - gamma*x + x^2 * \sum_{n=0}^\infty c_n (-x)^n
     * where c_n := (Zeta(n+2) - 1)/(n+2)  = coeffs[n]
     *
     * Here, another convergence acceleration trick is used to compute
     * lgam(x) :=  sum_{n=0..Inf} c_n (-x)^n
     */
    double lgam = c * logcf(-a / 2, N + 2, 1, tol_logcf);
    for (int i = N - 1; i >= 0; i--)
        lgam = coeffs[i] - a * lgam;

    return (a * lgam - eulers_const) * a - log1pmx(a);
} /* lgamma1p */

// openclport: macro hygiene post-clean for concatenated translation units.
#undef SQR
