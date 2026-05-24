#include "RcppArmadillo.h"
#include "openclPort.h"
#include "nmathopencl.h"

using namespace openclPort;


// -----------------------------------------------------------------------------
// Wrapper organization mirrors R/rcpp_wrappers.R:
//   Tier 5: OpenCL/GPU - nmath function runners, kernel loading, diagnostics
//
// Example-specific wrappers (EnvelopeSize, EnvelopeEval, glmb_Standardize_Model)
// have been moved to ex_glmbayes_export_wrappers.cpp.
// -----------------------------------------------------------------------------



// =============================================================================
// Tier 5: OpenCL / GPU
// Callers: load_kernel_source, load_kernel_library, has_opencl,
//          get_opencl_core_count, gpu_names
// User:    Advanced users - GPU diagnostics, kernel loading for use_opencl
// =============================================================================

// [[Rcpp::export]]
Rcpp::NumericVector dnorm_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& mean,
    const Rcpp::NumericVector& sd,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(mean.size()) != x.size()
      || static_cast<int>(sd.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, mean, sd, give_log must have identical length.");
  }
  return nmathopencl::dnorm_opencl(
      x,
      mean,
      sd,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector runif_opencl_cpp_export(
    int n,
    double a = 0.0,
    double b = 1.0,
    bool verbose = false
) {
  return nmathopencl::runif_opencl(n, a, b, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rnorm_opencl_cpp_export(
    int n,
    double mu = 0.0,
    double sigma = 1.0,
    bool verbose = false
) {
  return nmathopencl::rnorm_opencl(n, mu, sigma, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rexp_opencl_cpp_export(
    int n,
    double scale = 1.0,
    bool verbose = false
) {
  return nmathopencl::rexp_opencl(n, scale, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rwilcox_opencl_cpp_export(
    int n,
    double m,
    double n2,
    bool verbose = false
) {
  return nmathopencl::rwilcox_opencl(n, m, n2, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rbinom_opencl_cpp_export(
    int n,
    double size,
    double prob,
    bool verbose = false
) {
  return nmathopencl::rbinom_opencl(n, size, prob, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector r_pow_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& y,
    bool verbose = false
) {
  if (static_cast<int>(y.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x and y must have identical length.");
  }
  return nmathopencl::r_pow_opencl(x, y, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector r_pow_di_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::IntegerVector& n_exp,
    bool verbose = false
) {
  if (static_cast<int>(n_exp.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x and n_exp must have identical length.");
  }
  return nmathopencl::r_pow_di_opencl(x, n_exp, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector log1pmx_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    bool verbose = false
) {
  return nmathopencl::log1pmx_opencl(x, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector log1pexp_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    bool verbose = false
) {
  return nmathopencl::log1pexp_opencl(x, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector log1mexp_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    bool verbose = false
) {
  return nmathopencl::log1mexp_opencl(x, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector lgamma1p_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    bool verbose = false
) {
  return nmathopencl::lgamma1p_opencl(x, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector pow1p_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& y,
    bool verbose = false
) {
  if (static_cast<int>(y.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x and y must have identical length.");
  }
  return nmathopencl::pow1p_opencl(x, y, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector logspace_add_opencl_cpp_export(
    const Rcpp::NumericVector& logx,
    const Rcpp::NumericVector& logy,
    bool verbose = false
) {
  if (static_cast<int>(logy.size()) != logx.size()) {
    Rcpp::stop("INTERNAL: logx and logy must have identical length.");
  }
  return nmathopencl::logspace_add_opencl(logx, logy, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector logspace_sub_opencl_cpp_export(
    const Rcpp::NumericVector& logx,
    const Rcpp::NumericVector& logy,
    bool verbose = false
) {
  if (static_cast<int>(logy.size()) != logx.size()) {
    Rcpp::stop("INTERNAL: logx and logy must have identical length.");
  }
  return nmathopencl::logspace_sub_opencl(logx, logy, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector logspace_sum_opencl_cpp_export(
    const Rcpp::NumericVector& logx,
    const Rcpp::NumericVector& logy,
    bool verbose = false
) {
  if (static_cast<int>(logy.size()) != logx.size()) {
    Rcpp::stop("INTERNAL: logx and logy must have identical length.");
  }
  return nmathopencl::logspace_sum_opencl(logx, logy, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector norm_rand_opencl_cpp_export(
    int n,
    bool verbose = false
) {
  return nmathopencl::norm_rand_opencl(n, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector unif_rand_opencl_cpp_export(
    int n,
    bool verbose = false
) {
  return nmathopencl::unif_rand_opencl(n, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector r_unif_index_opencl_cpp_export(
    int n,
    double dn,
    bool verbose = false
) {
  return nmathopencl::r_unif_index_opencl(n, dn, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector exp_rand_opencl_cpp_export(
    int n,
    bool verbose = false
) {
  return nmathopencl::exp_rand_opencl(n, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector pnorm_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& mean,
    const Rcpp::NumericVector& sd,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int opencl_parallel_code,
    bool verbose = false
) {
  if (static_cast<int>(mean.size()) != q.size()
      || static_cast<int>(sd.size()) != q.size()
      || static_cast<int>(lower_tail.size()) != q.size()
      || static_cast<int>(log_p.size()) != q.size()) {
    Rcpp::stop("INTERNAL: q, mean, sd, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::pnorm_opencl(
      q,
      mean,
      sd,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qnorm_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& mean,
    const Rcpp::NumericVector& sd,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(mean.size()) != p.size()
      || static_cast<int>(sd.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, mean, sd, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qnorm_opencl(
      p,
      mean,
      sd,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dunif_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& min,
    const Rcpp::NumericVector& max,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(min.size()) != x.size()
      || static_cast<int>(max.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, min, max, give_log must have identical length.");
  }
  return nmathopencl::dunif_opencl(
      x,
      min,
      max,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector punif_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& min,
    const Rcpp::NumericVector& max,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::punif_opencl(
      q,
      min,
      max,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qunif_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& min,
    const Rcpp::NumericVector& max,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(min.size()) != p.size()
      || static_cast<int>(max.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, min, max, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qunif_opencl(
      p,
      min,
      max,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dgamma_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& shape,
    const Rcpp::NumericVector& scale,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(shape.size()) != x.size()
      || static_cast<int>(scale.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, shape, scale, give_log must have identical length.");
  }
  return nmathopencl::dgamma_opencl(
      x,
      shape,
      scale,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector pgamma_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& shape,
    const Rcpp::NumericVector& scale,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::pgamma_opencl(
      q,
      shape,
      scale,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qgamma_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& shape,
    const Rcpp::NumericVector& scale,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(shape.size()) != p.size()
      || static_cast<int>(scale.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, shape, scale, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qgamma_opencl(
      p,
      shape,
      scale,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rgamma_opencl_cpp_export(
    int n,
    double shape,
    double scale,
    bool verbose = false
) {
  return nmathopencl::rgamma_opencl(n, shape, scale, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dbeta_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& shape1,
    const Rcpp::NumericVector& shape2,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(shape1.size()) != x.size()
      || static_cast<int>(shape2.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, shape1, shape2, give_log must have identical length.");
  }
  return nmathopencl::dbeta_opencl(
      x,
      shape1,
      shape2,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector pbeta_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& shape1,
    const Rcpp::NumericVector& shape2,
    const Rcpp::NumericVector& ncp,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::pbeta_opencl(
      q,
      shape1,
      shape2,
      ncp,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qbeta_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& shape1,
    const Rcpp::NumericVector& shape2,
    const Rcpp::NumericVector& ncp,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(shape1.size()) != p.size()
      || static_cast<int>(shape2.size()) != p.size()
      || static_cast<int>(ncp.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, shape1, shape2, ncp, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qbeta_opencl(
      p,
      shape1,
      shape2,
      ncp,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rbeta_opencl_cpp_export(
    int n,
    double a,
    double b,
    bool verbose = false
) {
  return nmathopencl::rbeta_opencl(n, a, b, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dlnorm_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& meanlog,
    const Rcpp::NumericVector& sdlog,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(meanlog.size()) != x.size()
      || static_cast<int>(sdlog.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, meanlog, sdlog, give_log must have identical length.");
  }
  return nmathopencl::dlnorm_opencl(
      x,
      meanlog,
      sdlog,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector plnorm_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& meanlog,
    const Rcpp::NumericVector& sdlog,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::plnorm_opencl(
      q,
      meanlog,
      sdlog,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qlnorm_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& meanlog,
    const Rcpp::NumericVector& sdlog,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(meanlog.size()) != p.size()
      || static_cast<int>(sdlog.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, meanlog, sdlog, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qlnorm_opencl(
      p,
      meanlog,
      sdlog,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rlnorm_opencl_cpp_export(
    int n,
    double meanlog,
    double sdlog,
    bool verbose = false
) {
  return nmathopencl::rlnorm_opencl(n, meanlog, sdlog, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dchisq_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& df,
    const Rcpp::NumericVector& ncp,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(df.size()) != x.size()
      || static_cast<int>(ncp.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, df, ncp, give_log must have identical length.");
  }
  return nmathopencl::dchisq_opencl(
      x,
      df,
      ncp,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector pchisq_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& df,
    const Rcpp::NumericVector& ncp,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::pchisq_opencl(
      q,
      df,
      ncp,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qchisq_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& df,
    const Rcpp::NumericVector& ncp,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(df.size()) != p.size()
      || static_cast<int>(ncp.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, df, ncp, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qchisq_opencl(
      p,
      df,
      ncp,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rchisq_opencl_cpp_export(
    int n,
    double df,
    bool verbose = false
) {
  return nmathopencl::rchisq_opencl(n, df, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rnchisq_opencl_cpp_export(
    int n,
    double df,
    double ncp,
    bool verbose = false
) {
  return nmathopencl::rnchisq_opencl(n, df, ncp, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector df_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& df1,
    const Rcpp::NumericVector& df2,
    const Rcpp::NumericVector& ncp,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(df1.size()) != x.size()
      || static_cast<int>(df2.size()) != x.size()
      || static_cast<int>(ncp.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, df1, df2, ncp, give_log must have identical length.");
  }
  return nmathopencl::df_opencl(
      x,
      df1,
      df2,
      ncp,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector pf_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& df1,
    const Rcpp::NumericVector& df2,
    const Rcpp::NumericVector& ncp,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::pf_opencl(
      q,
      df1,
      df2,
      ncp,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qf_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& df1,
    const Rcpp::NumericVector& df2,
    const Rcpp::NumericVector& ncp,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(df1.size()) != p.size()
      || static_cast<int>(df2.size()) != p.size()
      || static_cast<int>(ncp.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, df1, df2, ncp, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qf_opencl(
      p,
      df1,
      df2,
      ncp,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rf_opencl_cpp_export(
    int n,
    double df1,
    double df2,
    bool verbose = false
) {
  return nmathopencl::rf_opencl(n, df1, df2, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dt_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& df,
    const Rcpp::NumericVector& ncp,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(df.size()) != x.size()
      || static_cast<int>(ncp.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, df, ncp, give_log must have identical length.");
  }
  return nmathopencl::dt_opencl(
      x,
      df,
      ncp,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector pt_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& df,
    const Rcpp::NumericVector& ncp,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::pt_opencl(
      q,
      df,
      ncp,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qt_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& df,
    const Rcpp::NumericVector& ncp,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(df.size()) != p.size()
      || static_cast<int>(ncp.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, df, ncp, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qt_opencl(
      p,
      df,
      ncp,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rt_opencl_cpp_export(
    int n,
    double df,
    bool verbose = false
) {
  return nmathopencl::rt_opencl(n, df, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dbinom_raw_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& n_size,
    const Rcpp::NumericVector& prob,
    const Rcpp::NumericVector& qprob,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(n_size.size()) != x.size()
      || static_cast<int>(prob.size()) != x.size()
      || static_cast<int>(qprob.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, n_size, prob, qprob, give_log must have identical length.");
  }
  return nmathopencl::dbinom_raw_opencl(
      x,
      n_size,
      prob,
      qprob,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dbinom_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& size,
    const Rcpp::NumericVector& prob,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(size.size()) != x.size()
      || static_cast<int>(prob.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, size, prob, give_log must have identical length.");
  }
  return nmathopencl::dbinom_opencl(
      x,
      size,
      prob,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector pbinom_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& size,
    const Rcpp::NumericVector& prob,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::pbinom_opencl(
      q,
      size,
      prob,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dnbinom_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& size,
    const Rcpp::NumericVector& prob,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(size.size()) != x.size()
      || static_cast<int>(prob.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, size, prob, give_log must have identical length.");
  }
  return nmathopencl::dnbinom_opencl(
      x,
      size,
      prob,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector pnbinom_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& size,
    const Rcpp::NumericVector& prob,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::pnbinom_opencl(
      q,
      size,
      prob,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qnbinom_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& size,
    const Rcpp::NumericVector& prob,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(size.size()) != p.size()
      || static_cast<int>(prob.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, size, prob, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qnbinom_opencl(
      p,
      size,
      prob,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rnbinom_opencl_cpp_export(
    int n,
    double size,
    double prob,
    bool verbose = false
) {
  return nmathopencl::rnbinom_opencl(n, size, prob, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dnbinom_mu_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& size,
    const Rcpp::NumericVector& mu,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(size.size()) != x.size()
      || static_cast<int>(mu.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, size, mu, give_log must have identical length.");
  }
  return nmathopencl::dnbinom_mu_opencl(
      x,
      size,
      mu,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector pnbinom_mu_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& size,
    const Rcpp::NumericVector& mu,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::pnbinom_mu_opencl(
      q,
      size,
      mu,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rmultinom_opencl_cpp_export(
    int n,
    double size,
    double prob,
    bool verbose = false
) {
  return nmathopencl::rmultinom_opencl(n, size, prob, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dcauchy_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& location,
    const Rcpp::NumericVector& scale,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(location.size()) != x.size()
      || static_cast<int>(scale.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, location, scale, give_log must have identical length.");
  }
  return nmathopencl::dcauchy_opencl(
      x,
      location,
      scale,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector pcauchy_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& location,
    const Rcpp::NumericVector& scale,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::pcauchy_opencl(
      q,
      location,
      scale,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qcauchy_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& location,
    const Rcpp::NumericVector& scale,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(location.size()) != p.size()
      || static_cast<int>(scale.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, location, scale, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qcauchy_opencl(
      p,
      location,
      scale,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rcauchy_opencl_cpp_export(
    int n,
    double location,
    double scale,
    bool verbose = false
) {
  return nmathopencl::rcauchy_opencl(n, location, scale, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dexp_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& rate,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(rate.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, rate, give_log must have identical length.");
  }
  return nmathopencl::dexp_opencl(
      x,
      rate,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector pexp_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& rate,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::pexp_opencl(
      q,
      rate,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qexp_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& rate,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(rate.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, rate, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qexp_opencl(
      p,
      rate,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dgeom_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& prob,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(prob.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, prob, give_log must have identical length.");
  }
  return nmathopencl::dgeom_opencl(
      x,
      prob,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector pgeom_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& prob,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::pgeom_opencl(
      q,
      prob,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qgeom_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& prob,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(prob.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, prob, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qgeom_opencl(
      p,
      prob,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rgeom_opencl_cpp_export(
    int n,
    double prob,
    bool verbose = false
) {
  return nmathopencl::rgeom_opencl(n, prob, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dhyper_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& r,
    const Rcpp::NumericVector& b,
    const Rcpp::NumericVector& n1,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(r.size()) != x.size()
      || static_cast<int>(b.size()) != x.size()
      || static_cast<int>(n1.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, r, b, n1, give_log must have identical length.");
  }
  return nmathopencl::dhyper_opencl(
      x,
      r,
      b,
      n1,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector phyper_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& m,
    const Rcpp::NumericVector& n_black,
    const Rcpp::NumericVector& k,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::phyper_opencl(
      q,
      m,
      n_black,
      k,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qhyper_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& r,
    const Rcpp::NumericVector& b,
    const Rcpp::NumericVector& n1,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(r.size()) != p.size()
      || static_cast<int>(b.size()) != p.size()
      || static_cast<int>(n1.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, r, b, n1, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qhyper_opencl(
      p,
      r,
      b,
      n1,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rhyper_opencl_cpp_export(
    int n,
    double r,
    double b,
    double n1,
    bool verbose = false
) {
  return nmathopencl::rhyper_opencl(n, r, b, n1, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qbinom_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& size,
    const Rcpp::NumericVector& prob,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(size.size()) != p.size()
      || static_cast<int>(prob.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, size, prob, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qbinom_opencl(
      p,
      size,
      prob,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qpois_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& lambda,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(lambda.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, lambda, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qpois_opencl(
      p,
      lambda,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dpois_raw_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& lambda,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(lambda.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, lambda, give_log must have identical length.");
  }
  return nmathopencl::dpois_raw_opencl(
      x,
      lambda,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dpois_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& lambda,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(lambda.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, lambda, give_log must have identical length.");
  }
  return nmathopencl::dpois_opencl(
      x,
      lambda,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector ppois_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& lambda,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::ppois_opencl(
      q,
      lambda,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qnbinom_mu_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& size,
    const Rcpp::NumericVector& mu,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(size.size()) != p.size()
      || static_cast<int>(mu.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, size, mu, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qnbinom_mu_opencl(
      p,
      size,
      mu,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rpois_opencl_cpp_export(
    int n,
    double lambda,
    bool verbose = false
) {
  return nmathopencl::rpois_opencl(n, lambda, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rnbinom_mu_opencl_cpp_export(
    int n,
    double size,
    double mu,
    bool verbose = false
) {
  return nmathopencl::rnbinom_mu_opencl(n, size, mu, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dweibull_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& shape,
    const Rcpp::NumericVector& scale,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(shape.size()) != x.size()
      || static_cast<int>(scale.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, shape, scale, give_log must have identical length.");
  }
  return nmathopencl::dweibull_opencl(
      x,
      shape,
      scale,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector pweibull_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& shape,
    const Rcpp::NumericVector& scale,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::pweibull_opencl(
      q,
      shape,
      scale,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qweibull_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& shape,
    const Rcpp::NumericVector& scale,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(shape.size()) != p.size()
      || static_cast<int>(scale.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, shape, scale, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qweibull_opencl(
      p,
      shape,
      scale,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rweibull_opencl_cpp_export(
    int n,
    double shape,
    double scale,
    bool verbose = false
) {
  return nmathopencl::rweibull_opencl(n, shape, scale, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dlogis_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& location,
    const Rcpp::NumericVector& scale,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(location.size()) != x.size()
      || static_cast<int>(scale.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, location, scale, give_log must have identical length.");
  }
  return nmathopencl::dlogis_opencl(
      x,
      location,
      scale,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector plogis_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& location,
    const Rcpp::NumericVector& scale,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::plogis_opencl(
      q,
      location,
      scale,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qlogis_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& location,
    const Rcpp::NumericVector& scale,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(location.size()) != p.size()
      || static_cast<int>(scale.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, location, scale, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qlogis_opencl(
      p,
      location,
      scale,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rlogis_opencl_cpp_export(
    int n,
    double location,
    double scale,
    bool verbose = false
) {
  return nmathopencl::rlogis_opencl(n, location, scale, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dnbeta_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& shape1,
    const Rcpp::NumericVector& shape2,
    const Rcpp::NumericVector& ncp,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(shape1.size()) != x.size()
      || static_cast<int>(shape2.size()) != x.size()
      || static_cast<int>(ncp.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, shape1, shape2, ncp, give_log must have identical length.");
  }
  return nmathopencl::dnbeta_opencl(
      x,
      shape1,
      shape2,
      ncp,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector ptukey_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& nmeans,
    const Rcpp::NumericVector& df,
    const Rcpp::NumericVector& nranges,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::ptukey_opencl(
      q,
      nmeans,
      df,
      nranges,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qtukey_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& nmeans,
    const Rcpp::NumericVector& df,
    const Rcpp::NumericVector& nranges,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(nmeans.size()) != p.size()
      || static_cast<int>(df.size()) != p.size()
      || static_cast<int>(nranges.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop(
        "INTERNAL: p, nmeans, df, nranges, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qtukey_opencl(
      p,
      nmeans,
      df,
      nranges,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dwilcox_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& m,
    const Rcpp::NumericVector& n2,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(m.size()) != x.size()
      || static_cast<int>(n2.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, m, n2, give_log must have identical length.");
  }
  return nmathopencl::dwilcox_opencl(
      x,
      m,
      n2,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector pwilcox_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& m,
    const Rcpp::NumericVector& n2,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::pwilcox_opencl(
      q,
      m,
      n2,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qwilcox_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& m,
    const Rcpp::NumericVector& n2,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(m.size()) != p.size()
      || static_cast<int>(n2.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, m, n2, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qwilcox_opencl(
      p,
      m,
      n2,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dsignrank_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& nsize,
    const Rcpp::IntegerVector& give_log,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(nsize.size()) != x.size()
      || static_cast<int>(give_log.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x, nsize, give_log must have identical length.");
  }
  return nmathopencl::dsignrank_opencl(
      x,
      nsize,
      give_log,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector psignrank_opencl_cpp_export(
    const Rcpp::NumericVector& q,
    const Rcpp::NumericVector& nsize,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  return nmathopencl::psignrank_opencl(
      q,
      nsize,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector qsignrank_opencl_cpp_export(
    const Rcpp::NumericVector& p,
    const Rcpp::NumericVector& nsize,
    const Rcpp::IntegerVector& lower_tail,
    const Rcpp::IntegerVector& log_p,
    int                          opencl_parallel_code,
    bool                         verbose = false
) {
  if (static_cast<int>(nsize.size()) != p.size()
      || static_cast<int>(lower_tail.size()) != p.size()
      || static_cast<int>(log_p.size()) != p.size()) {
    Rcpp::stop("INTERNAL: p, nsize, lower_tail, log_p must have identical length.");
  }
  return nmathopencl::qsignrank_opencl(
      p,
      nsize,
      lower_tail,
      log_p,
      opencl_parallel_code,
      verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector rsignrank_opencl_cpp_export(
    int n,
    double nsize,
    bool verbose = false
) {
  return nmathopencl::rsignrank_opencl(n, nsize, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector gammafn_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    bool verbose = false
) {
  return nmathopencl::gammafn_opencl(x, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector lgammafn_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    bool verbose = false
) {
  return nmathopencl::lgammafn_opencl(x, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector lgammafn_sign_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    bool verbose = false
) {
  return nmathopencl::lgammafn_sign_opencl(x, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector dpsifn_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& n_deriv,
    const Rcpp::NumericVector& kode,
    const Rcpp::NumericVector& m,
    bool verbose = false
) {
  const int len = x.size();
  if (static_cast<int>(n_deriv.size()) != len || static_cast<int>(kode.size()) != len ||
      static_cast<int>(m.size()) != len) {
    Rcpp::stop("INTERNAL: x, n_deriv, kode, m must have identical length.");
  }
  return nmathopencl::dpsifn_opencl(x, n_deriv, kode, m, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector psigamma_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& deriv,
    bool verbose = false
) {
  if (static_cast<int>(deriv.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x and deriv must have identical length.");
  }
  return nmathopencl::psigamma_opencl(x, deriv, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector digamma_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    bool verbose = false
) {
  return nmathopencl::digamma_opencl(x, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector trigamma_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    bool verbose = false
) {
  return nmathopencl::trigamma_opencl(x, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector tetragamma_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    bool verbose = false
) {
  return nmathopencl::tetragamma_opencl(x, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector pentagamma_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    bool verbose = false
) {
  return nmathopencl::pentagamma_opencl(x, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector beta_opencl_cpp_export(
    const Rcpp::NumericVector& a,
    const Rcpp::NumericVector& b,
    bool verbose = false
) {
  if (static_cast<int>(b.size()) != a.size()) {
    Rcpp::stop("INTERNAL: a and b must have identical length.");
  }
  return nmathopencl::beta_opencl(a, b, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector lbeta_opencl_cpp_export(
    const Rcpp::NumericVector& a,
    const Rcpp::NumericVector& b,
    bool verbose = false
) {
  if (static_cast<int>(b.size()) != a.size()) {
    Rcpp::stop("INTERNAL: a and b must have identical length.");
  }
  return nmathopencl::lbeta_opencl(a, b, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector choose_opencl_cpp_export(
    const Rcpp::NumericVector& n_val,
    const Rcpp::NumericVector& k,
    bool verbose = false
) {
  if (static_cast<int>(k.size()) != n_val.size()) {
    Rcpp::stop("INTERNAL: n_val and k must have identical length.");
  }
  return nmathopencl::choose_opencl(n_val, k, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector lchoose_opencl_cpp_export(
    const Rcpp::NumericVector& n_val,
    const Rcpp::NumericVector& k,
    bool verbose = false
) {
  if (static_cast<int>(k.size()) != n_val.size()) {
    Rcpp::stop("INTERNAL: n_val and k must have identical length.");
  }
  return nmathopencl::lchoose_opencl(n_val, k, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector bessel_i_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& nu,
    const Rcpp::NumericVector& expo_scaled,
    bool verbose = false
) {
  const int len = x.size();
  if (static_cast<int>(nu.size()) != len || static_cast<int>(expo_scaled.size()) != len) {
    Rcpp::stop("INTERNAL: x, nu, expo_scaled must have identical length.");
  }
  return nmathopencl::bessel_i_opencl(x, nu, expo_scaled, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector bessel_j_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& nu,
    bool verbose = false
) {
  if (static_cast<int>(nu.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x and nu must have identical length.");
  }
  return nmathopencl::bessel_j_opencl(x, nu, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector bessel_k_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& nu,
    const Rcpp::NumericVector& expo_scaled,
    bool verbose = false
) {
  const int len = x.size();
  if (static_cast<int>(nu.size()) != len || static_cast<int>(expo_scaled.size()) != len) {
    Rcpp::stop("INTERNAL: x, nu, expo_scaled must have identical length.");
  }
  return nmathopencl::bessel_k_opencl(x, nu, expo_scaled, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector bessel_y_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& nu,
    bool verbose = false
) {
  if (static_cast<int>(nu.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x and nu must have identical length.");
  }
  return nmathopencl::bessel_y_opencl(x, nu, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector bessel_i_ex_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& nu,
    const Rcpp::NumericVector& expo,
    bool verbose = false
) {
  const int len = x.size();
  if (static_cast<int>(nu.size()) != len || static_cast<int>(expo.size()) != len) {
    Rcpp::stop("INTERNAL: x, nu, expo must have identical length.");
  }
  return nmathopencl::bessel_i_ex_opencl(x, nu, expo, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector bessel_j_ex_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& nu,
    bool verbose = false
) {
  if (static_cast<int>(nu.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x and nu must have identical length.");
  }
  return nmathopencl::bessel_j_ex_opencl(x, nu, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector bessel_k_ex_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& nu,
    const Rcpp::NumericVector& expo,
    bool verbose = false
) {
  const int len = x.size();
  if (static_cast<int>(nu.size()) != len || static_cast<int>(expo.size()) != len) {
    Rcpp::stop("INTERNAL: x, nu, expo must have identical length.");
  }
  return nmathopencl::bessel_k_ex_opencl(x, nu, expo, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector bessel_y_ex_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& nu,
    bool verbose = false
) {
  if (static_cast<int>(nu.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x and nu must have identical length.");
  }
  return nmathopencl::bessel_y_ex_opencl(x, nu, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector imax2_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& y,
    bool verbose = false
) {
  if (static_cast<int>(y.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x and y must have identical length.");
  }
  return nmathopencl::imax2_opencl(x, y, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector imin2_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& y,
    bool verbose = false
) {
  if (static_cast<int>(y.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x and y must have identical length.");
  }
  return nmathopencl::imin2_opencl(x, y, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector fmax2_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& y,
    bool verbose = false
) {
  if (static_cast<int>(y.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x and y must have identical length.");
  }
  return nmathopencl::fmax2_opencl(x, y, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector fmin2_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& y,
    bool verbose = false
) {
  if (static_cast<int>(y.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x and y must have identical length.");
  }
  return nmathopencl::fmin2_opencl(x, y, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector sign_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    bool verbose = false
) {
  return nmathopencl::sign_opencl(x, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector fprec_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& digits,
    bool verbose = false
) {
  if (static_cast<int>(digits.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x and digits must have identical length.");
  }
  return nmathopencl::fprec_opencl(x, digits, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector fround_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& digits,
    bool verbose = false
) {
  if (static_cast<int>(digits.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x and digits must have identical length.");
  }
  return nmathopencl::fround_opencl(x, digits, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector fsign_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    const Rcpp::NumericVector& y,
    bool verbose = false
) {
  if (static_cast<int>(y.size()) != x.size()) {
    Rcpp::stop("INTERNAL: x and y must have identical length.");
  }
  return nmathopencl::fsign_opencl(x, y, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector ftrunc_opencl_cpp_export(
    const Rcpp::NumericVector& x,
    bool verbose = false
) {
  return nmathopencl::ftrunc_opencl(x, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector r_check_user_interrupt_opencl_cpp_export(
    int n,
    bool verbose = false
) {
  return nmathopencl::r_check_user_interrupt_opencl(n, verbose);
}

// [[Rcpp::export]]
Rcpp::NumericVector r_check_stack_opencl_cpp_export(
    int n,
    bool verbose = false
) {
  return nmathopencl::r_check_stack_opencl(n, verbose);
}

// [[Rcpp::export]]
std::string load_kernel_source_wrapper_cpp_export(
    const std::string& relative_path,
    const std::string& package = "opencltools"
) {
  return load_kernel_source_wrapper(relative_path, package);
}

// [[Rcpp::export]]
std::string load_kernel_library_wrapper_cpp_export(
    const std::string& subdir,
    const std::string& package = "opencltools",
    bool verbose = false
) {
  return load_kernel_library_wrapper(subdir, package, verbose);
}

// [[Rcpp::export]]
bool has_opencl_cpp_export() {
  return has_opencl();
}

// [[Rcpp::export]]
int get_opencl_core_count_cpp_export() {
  return get_opencl_core_count();
}

// [[Rcpp::export]]
Rcpp::CharacterVector gpu_names_cpp_export() {
  return gpu_names();
}

// [[Rcpp::export]]
Rcpp::List opencl_device_info_cpp_export(bool force = false, bool details = false) {
  return opencl_device_info_rcpp(force, details);
}

// [[Rcpp::export]]
bool opencl_fp64_available_cpp_export(bool force = false) {
  return opencl_fp64_available_impl(force);
}

// [[Rcpp::export]]
void opencl_reset_device_selection_cpp_export() {
  opencl_reset_fp64_selection();
}
