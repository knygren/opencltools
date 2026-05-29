// @source_type: c
// @source_origin: stirlerr_cycle_free.c
// @includes: nmath.h
// @depends: nmath
// @provides: stirlerr_cycle_free
// @all_depends_count: 2
// @all_depends: Rmath, nmath
// @load_order: 21
// @local_macros: S0, S1, S2, S3, S4, S5, S6, S7, S8, S9, S10, S11, S12, S13, S14, S15, S16

// openclport: macro hygiene pre-clean for concatenated translation units.
#ifdef S0
# undef S0
#endif
#ifdef S1
# undef S1
#endif
#ifdef S2
# undef S2
#endif
#ifdef S3
# undef S3
#endif
#ifdef S4
# undef S4
#endif
#ifdef S5
# undef S5
#endif
#ifdef S6
# undef S6
#endif
#ifdef S7
# undef S7
#endif
#ifdef S8
# undef S8
#endif
#ifdef S9
# undef S9
#endif
#ifdef S10
# undef S10
#endif
#ifdef S11
# undef S11
#endif
#ifdef S12
# undef S12
#endif
#ifdef S13
# undef S13
#endif
#ifdef S14
# undef S14
#endif
#ifdef S15
# undef S15
#endif
#ifdef S16
# undef S16
#endif

// openclport: include directives disabled for OpenCL C compilation.
// openclport: preload equivalent ported headers/shims in program assembly.
// openclport-disabled-include: #include "nmath.h"

#define S0 0.083333333333333333333       /* 1/12 */
#define S1 0.00277777777777777777778     /* 1/360 */
#define S2 0.00079365079365079365079365  /* 1/1260 */
#define S3 0.000595238095238095238095238 /* 1/1680 */
#define S4 0.0008417508417508417508417508/* 1/1188 */
#define S5 0.0019175269175269175269175262
#define S6 0.0064102564102564102564102561
#define S7 0.029550653594771241830065352
#define S8 0.17964437236883057316493850
#define S9 1.3924322169059011164274315
#define S10 13.402864044168391994478957
#define S11 156.84828462600201730636509
#define S12 2193.1033333333333333333333
#define S13 36108.771253724989357173269
#define S14 691472.26885131306710839498
#define S15 15238221.539407416192283370
#define S16 382900751.39141414141414141

static const double sferr_halves[31] = {
    0.0,
    0.1534264097200273452913848, 0.0810614667953272582196702,
    0.0548141210519176538961390, 0.0413406959554092940938221,
    0.03316287351993628748511048, 0.02767792568499833914878929,
    0.02374616365629749597132920, 0.02079067210376509311152277,
    0.01848845053267318523077934, 0.01664469118982119216319487,
    0.01513497322191737887351255, 0.01387612882307074799874573,
    0.01281046524292022692424986, 0.01189670994589177009505572,
    0.01110455975820691732662991, 0.010411265261972096497478567,
    0.009799416126158803298389475, 0.009255462182712732917728637,
    0.008768700134139385462952823, 0.008330563433362871256469318,
    0.007934114564314020547248100, 0.007573675487951840794972024,
    0.007244554301320383179543912, 0.006942840107209529865664152,
    0.006665247032707682442354394, 0.006408994188004207068439631,
    0.006171712263039457647532867, 0.005951370112758847735624416,
    0.005746216513010115682023589, 0.005554733551962801371038690
};

attribute_hidden double stirlerr_cycle_free(double n)
{
    double nn;

    if (n <= 23.5) {
        nn = n + n;
        if (n <= 15. && (nn == (int)nn)) return sferr_halves[(int)nn];
        if (n <= 5.25) {
            if (n >= 1.) {
                double l_n = log(n);
                return lgamma(n) + n * (1 - l_n) + ldexp(l_n - M_LN_2PI, -1);
            }
            /* For n < 1, wrapper routes to cycle_dependent branch. */
            return lgamma(n + 1.) - (n + 0.5) * log(n) + n - M_LN_SQRT_2PI;
        }
        nn = n * n;
        if (n > 12.8) return (S0-(S1-(S2-(S3-(S4-(S5 -S6/nn)/nn)/nn)/nn)/nn)/nn)/n;
        if (n > 12.3) return (S0-(S1-(S2-(S3-(S4-(S5-(S6 -S7/nn)/nn)/nn)/nn)/nn)/nn)/nn)/n;
        if (n > 8.9) return (S0-(S1-(S2-(S3-(S4-(S5-(S6-(S7 -S8/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/n;
        if (n > 7.3) return (S0-(S1-(S2-(S3-(S4-(S5-(S6-(S7-(S8-(S9-S10/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/n;
        if (n > 6.6) return (S0-(S1-(S2-(S3-(S4-(S5-(S6-(S7-(S8-(S9-(S10-(S11-S12/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/n;
        if (n > 6.1) return (S0-(S1-(S2-(S3-(S4-(S5-(S6-(S7-(S8-(S9-(S10-(S11-(S12-(S13-S14/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/n;
        return (S0-(S1-(S2-(S3-(S4-(S5-(S6-(S7-(S8-(S9-(S10-(S11-(S12-(S13-(S14-(S15-S16/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/nn)/n;
    }

    nn = n * n;
    if (n > 15.7e6) return S0 / n;
    if (n > 6180) return (S0 - S1 / nn) / n;
    if (n > 205) return (S0 - (S1 - S2 / nn) / nn) / n;
    if (n > 86) return (S0 - (S1 - (S2 - S3 / nn) / nn) / nn) / n;
    if (n > 27) return (S0 - (S1 - (S2 - (S3 - S4 / nn) / nn) / nn) / nn) / n;
    return (S0 - (S1 - (S2 - (S3 - (S4 - S5 / nn) / nn) / nn) / nn) / nn) / n;
}

// openclport: macro hygiene post-clean for concatenated translation units.
#undef S0
#undef S1
#undef S2
#undef S3
#undef S4
#undef S5
#undef S6
#undef S7
#undef S8
#undef S9
#undef S10
#undef S11
#undef S12
#undef S13
#undef S14
#undef S15
#undef S16
