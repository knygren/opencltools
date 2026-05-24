#include "openclPort.h"
#include <Rcpp.h>

using namespace Rcpp;

namespace openclPort {

std::vector<double> flattenMatrix(const Rcpp::NumericMatrix& mat) {
  int nrow = mat.nrow();
  int ncol = mat.ncol();
  std::vector<double> out;
  out.reserve(static_cast<size_t>(nrow) * ncol);

  // Column-major traversal
  for (int j = 0; j < ncol; ++j) {
    for (int i = 0; i < nrow; ++i) {
      out.push_back(mat(i, j));
    }
  }

  return out;
}

std::vector<double> copyVector(const Rcpp::NumericVector& vec) {
  return std::vector<double>(vec.begin(), vec.end());
}

bool has_opencl() {
#ifdef USE_OPENCL
  return true;
#else
  return false;
#endif
}

}
