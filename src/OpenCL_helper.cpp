#include "openclPort.h"
#include <Rcpp.h>

namespace openclPort {

bool has_opencl() {
#ifdef USE_OPENCL
  return true;
#else
  return false;
#endif
}

}
