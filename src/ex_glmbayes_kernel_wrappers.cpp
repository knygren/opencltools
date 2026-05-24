//#include <Rcpp.h>
#include <vector>
#include <string>
#include "openclPort.h"
#include <RcppArmadillo.h>
#include "ex_glmbayes_famfuncs.h"
#include "nmathopencl.h"
#include "ex_glmbayes_opencl.h"

using namespace Rcpp;

using namespace openclPort;
using namespace ex_glmbayes::opencl;

namespace ex_glmbayes {

namespace opencl {

Rcpp::List f2_f3_opencl(
    std::string family,
    std::string link,
    Rcpp::NumericMatrix  b,
    Rcpp::NumericVector  y,
    Rcpp::NumericMatrix  x,
    Rcpp::NumericMatrix  mu,
    Rcpp::NumericMatrix  P,
    Rcpp::NumericVector  alpha,
    Rcpp::NumericVector  wt,
    int                  progbar
) {
  
  [[maybe_unused]] int l1 = x.nrow();
  [[maybe_unused]] int l2 = x.ncol();
  int m1 = b.ncol();
  
//  int l1 = x.nrow(), l2 = x.ncol(), m1 = b.ncol();
  
  
  
  // flatten inputs
  
  auto X_flat     = flattenMatrix(x);
  
  auto B_flat     = flattenMatrix(b);
  auto mu_flat    = flattenMatrix(mu);
  auto P_flat     = flattenMatrix(P);
  auto alpha_flat = copyVector(alpha);
  auto y_flat     = copyVector(y);
  auto wt_flat    = copyVector(wt);
  
  
  
  // allocate outputs
  std::vector<double> qf_flat(m1);
  std::vector<double> grad_flat(static_cast<size_t>(m1) * l2);
  
  
  Rcpp::NumericVector qf(m1);
  
  
  // Dispatch kernel name and source
  std::string kernel_name;
  std::string kernel_file;
  std::string all_src;
  
  
#ifdef USE_OPENCL
  
  std::string OPENCL_source           = load_kernel_source("OPENCL.cl");
  std::string libr_shims_source       = load_kernel_library("libR_shims", "opencltools", false);
  std::string r_ext_types_source      = load_kernel_library("R_ext_types", "opencltools", false);
  std::string r_shims_source          = load_kernel_library("R_shims", "opencltools", false);
  std::string r_ext_runtime_source    = load_kernel_library("R_ext_runtime", "opencltools", false);
  std::string r_ext_internals_source  = load_kernel_library("R_ext_internals", "opencltools", false);
  std::string system_source           = load_kernel_library("System", "opencltools", false);
  // Old approach — loads all 137 nmath files with full topological sort:
  // std::string nmath_source = load_kernel_library("nmath", "opencltools", false);
  // Old sequence retained for reference during migration:
  // std::string rmath_source = load_kernel_library("rmath","opencltools", false);
  // std::string dpq_source   = load_kernel_library("dpq","opencltools", false);
  
  
  if (family == "binomial"||family == "quasibinomial") {
    if (link == "logit") {
      kernel_name = "f2_f3_binomial_logit";
      kernel_file = "ex_glmbayes_src/f2_f3_binomial_logit.cl";
    } 
    else if (link == "probit") {
      kernel_name = "f2_f3_binomial_probit";
      kernel_file = "ex_glmbayes_src/f2_f3_binomial_probit.cl";
      
    }
    else if (link == "cloglog") {
      
      kernel_name = "f2_f3_binomial_cloglog";
      kernel_file = "ex_glmbayes_src/f2_f3_binomial_cloglog.cl";
      
    }
    else {
      Rcpp::stop("Unsupported link function for binomial family: " + link);
    }
  }
  
  else if (family =="poisson"||family =="quasipoisson"){
    kernel_name = "f2_f3_poisson";
    kernel_file  = "ex_glmbayes_src/f2_f3_poisson.cl";
    
  }
  
  else if (family=="Gamma"){
    
    kernel_name = "f2_f3_gamma";
    kernel_file  = "ex_glmbayes_src/f2_f3_gamma.cl";
  }
  
  else if (family=="gaussian"){
    
    kernel_name = "f2_f3_gaussian";
    kernel_file  = "ex_glmbayes_src/f2_f3_gaussian.cl";
  }
  
  else {
    Rcpp::stop("Unsupported family: " + family);
  }

  // New approach — reads @all_depends_nmath from the kernel file (full
  // pre-computed transitive list) and loads those files in index order:
  std::string nmath_source = load_library_for_kernel(
      kernel_file, "ex_glmbayes_nmath", "opencltools", "all_depends_nmath");
  
  
  // load & call kernel runner
  std::string ksrc    = load_kernel_source(kernel_file);
  
  
  /// Updated to use same "Program" logic for all models
  
  // Old program assembly sequence (kept as comment):
  // all_src = OPENCL_source +
  //   "\n" + r_shims_source +
  //   "\n" + rext_source +
  //   "\n" + system_source +
  //   "\n" + rmath_source +
  //   "\n" + dpq_source +
  //   "\n" + nmath_source +
  //   "\n" + ksrc;

  all_src = OPENCL_source +
    "\n" + libr_shims_source +
    "\n" + r_ext_types_source +
    "\n" + r_shims_source +
    "\n" + r_ext_runtime_source +
    "\n" + r_ext_internals_source +
    "\n" + system_source +
    "\n" + nmath_source +
    "\n" + ksrc;
  
  // Rcpp::Rcout << "Entering f2_f3_kernel runner \n";
  
  
  f2_f3_kernel_runner(
    all_src,
    kernel_name.c_str(),  // ✅ convert to const char*
    l1, l2, m1,
    X_flat, B_flat, mu_flat, P_flat, alpha_flat,
    y_flat, wt_flat,
    qf_flat, 
    // xb_flat,
    grad_flat,
    progbar
  );
  
  // Rcpp::Rcout << "Exiting f2_f3_kernel runner \n";
  
  
  // rebuild xb, qf exactly as before
  for (int j = 0; j < m1; ++j) {
    qf[j] = qf_flat[j];
    // for (int i = 0; i < l1; ++i) {
    //   xb(i, j) = xb_flat[static_cast<size_t>(j) * l1 + i];
    // }
  }
  
#else
  
  Rcpp::Rcout << "[INFO] OpenCL not available — returning zero vector/matrices.\n";
  
#endif
  
  // wrap gradient directly as arma::mat (m1 rows × l2 cols),
  // no copies, column-major data matches Armadillo & R
  arma::mat grad_arma(
      grad_flat.data(),  // pointer to your flat array
      m1,                // n_rows - dimensions
      l2,                // n_cols - grid points
      false,             // don't copy memory
      false              // strict = false
  );
  
  return Rcpp::List::create(
    // Rcpp::Named("xb")   = xb,
    Rcpp::Named("qf")   = qf,
    Rcpp::Named("grad") = grad_arma
  );
}

} // namespace opencl
} // namespace ex_glmbayes
