#ifndef OPENCLTOOLS_CAPI_H
#define OPENCLTOOLS_CAPI_H

#include <R_ext/Rdynload.h>
#include <R_ext/Error.h>
#include <stddef.h>

/*
 * opencltools C-callable API
 *
 * Usage:
 *   #include <opencltools/opencltools_capi.h>
 *   int ok = opencltools_has_opencl();
 *
 * Notes:
 * - All boolean-ish return values are int (0/1) for C ABI portability.
 * - String-returning APIs allocate memory in opencltools; caller must free
 *   via opencltools_free_cstr().
 * - Use opencltools_api_version() for compatibility checks.
 *
 * Why this header has four layers (plain language):
 *
 * 1) function pointer typedefs
 *    R stores C-callable entries as generic pointers. Generic pointers cannot
 *    be called directly with type safety. The typedefs say "this callable has
 *    exactly this argument list and return type", so each call is cast
 *    correctly and consistently.
 *
 * 2) internal resolver
 *    This is the one place that asks R for a callable by name. If the symbol
 *    is missing (wrong version, package not loaded, typo), this helper throws
 *    one clear error message instead of failing silently in many places.
 *
 * 3) typed accessors
 *    Wrappers need an actual function pointer to call. Typed accessors fetch
 *    that pointer once, store it, and return it on future calls. Without this,
 *    every wrapper call would repeat lookup/cast work and duplicate boilerplate.
 *
 * 4) convenience wrappers (the part downstream users call)
 *    These are normal-looking functions such as opencltools_has_opencl().
 *    They keep downstream code simple; callers do not need to know anything
 *    about R_GetCCallable(), DL_FUNC, or pointer casting.
 *
 * How they work together:
 *   downstream calls wrapper
 *   -> wrapper asks typed accessor for function pointer
 *   -> accessor resolves once via internal resolver (first call only)
 *   -> pointer is cached
 *   -> wrapper invokes pointer and returns result
 */

#ifdef __cplusplus
extern "C" {
#endif
  
  /* -------- function pointer typedefs -------- */
  
  typedef int (*opencltools_api_version_t)(void);
  
  typedef int (*opencltools_has_opencl_t)(void);
  typedef int (*opencltools_get_opencl_core_count_t)(void);
  
  typedef int  (*opencltools_opencl_ensure_fp64_selection_t)(int force);
  typedef void (*opencltools_opencl_reset_fp64_selection_t)(void);
  typedef int  (*opencltools_opencl_fp64_available_t)(int force);
  
  typedef const char* (*opencltools_load_kernel_source_t)(
      const char* relative_path,
      const char* package);
  
  typedef const char* (*opencltools_load_kernel_library_t)(
      const char* subdir,
      const char* package,
      int verbose);
  
  typedef const char* (*opencltools_load_library_for_kernel_t)(
      const char* kernel_relative_path,
      const char* library_subdir,
      const char* package,
      const char* depends_tag);
  
  typedef void (*opencltools_free_cstr_t)(const char* p);
  
  /* -------- internal resolver -------- */
  
  static inline DL_FUNC opencltools_capi_resolve_(const char* name) {
    DL_FUNC p = R_GetCCallable("opencltools", name);
    if (!p) {
      Rf_error(
        "opencltools C-callable '%s' not found; check package version/load order.",
        name
      );
    }
    return p;
  }
  
  /* -------- typed accessors -------- */
  
  static inline opencltools_api_version_t opencltools_api_version_fn(void) {
    static opencltools_api_version_t fn = NULL;
    if (!fn) fn = (opencltools_api_version_t) opencltools_capi_resolve_("opencltools_api_version");
    return fn;
  }
  
  static inline opencltools_has_opencl_t opencltools_has_opencl_fn(void) {
    static opencltools_has_opencl_t fn = NULL;
    if (!fn) fn = (opencltools_has_opencl_t) opencltools_capi_resolve_("opencltools_has_opencl");
    return fn;
  }
  
  static inline opencltools_get_opencl_core_count_t opencltools_get_opencl_core_count_fn(void) {
    static opencltools_get_opencl_core_count_t fn = NULL;
    if (!fn) fn = (opencltools_get_opencl_core_count_t) opencltools_capi_resolve_("opencltools_get_opencl_core_count");
    return fn;
  }
  
  static inline opencltools_opencl_ensure_fp64_selection_t opencltools_opencl_ensure_fp64_selection_fn(void) {
    static opencltools_opencl_ensure_fp64_selection_t fn = NULL;
    if (!fn) fn = (opencltools_opencl_ensure_fp64_selection_t) opencltools_capi_resolve_("opencltools_opencl_ensure_fp64_selection");
    return fn;
  }
  
  static inline opencltools_opencl_reset_fp64_selection_t opencltools_opencl_reset_fp64_selection_fn(void) {
    static opencltools_opencl_reset_fp64_selection_t fn = NULL;
    if (!fn) fn = (opencltools_opencl_reset_fp64_selection_t) opencltools_capi_resolve_("opencltools_opencl_reset_fp64_selection");
    return fn;
  }
  
  static inline opencltools_opencl_fp64_available_t opencltools_opencl_fp64_available_fn(void) {
    static opencltools_opencl_fp64_available_t fn = NULL;
    if (!fn) fn = (opencltools_opencl_fp64_available_t) opencltools_capi_resolve_("opencltools_opencl_fp64_available");
    return fn;
  }
  
  static inline opencltools_load_kernel_source_t opencltools_load_kernel_source_fn(void) {
    static opencltools_load_kernel_source_t fn = NULL;
    if (!fn) fn = (opencltools_load_kernel_source_t) opencltools_capi_resolve_("opencltools_load_kernel_source");
    return fn;
  }
  
  static inline opencltools_load_kernel_library_t opencltools_load_kernel_library_fn(void) {
    static opencltools_load_kernel_library_t fn = NULL;
    if (!fn) fn = (opencltools_load_kernel_library_t) opencltools_capi_resolve_("opencltools_load_kernel_library");
    return fn;
  }
  
  static inline opencltools_load_library_for_kernel_t opencltools_load_library_for_kernel_fn(void) {
    static opencltools_load_library_for_kernel_t fn = NULL;
    if (!fn) fn = (opencltools_load_library_for_kernel_t) opencltools_capi_resolve_("opencltools_load_library_for_kernel");
    return fn;
  }
  
  static inline opencltools_free_cstr_t opencltools_free_cstr_fn(void) {
    static opencltools_free_cstr_t fn = NULL;
    if (!fn) fn = (opencltools_free_cstr_t) opencltools_capi_resolve_("opencltools_free_cstr");
    return fn;
  }
  
  /* -------- convenience wrappers -------- */
  
  static inline int opencltools_api_version(void) {
    return opencltools_api_version_fn()();
  }
  
  static inline int opencltools_has_opencl(void) {
    return opencltools_has_opencl_fn()();
  }
  
  static inline int opencltools_get_opencl_core_count(void) {
    return opencltools_get_opencl_core_count_fn()();
  }
  
  static inline int opencltools_opencl_ensure_fp64_selection(int force) {
    return opencltools_opencl_ensure_fp64_selection_fn()(force);
  }
  
  static inline void opencltools_opencl_reset_fp64_selection(void) {
    opencltools_opencl_reset_fp64_selection_fn()();
  }
  
  static inline int opencltools_opencl_fp64_available(int force) {
    return opencltools_opencl_fp64_available_fn()(force);
  }
  
  static inline const char* opencltools_load_kernel_source(
      const char* relative_path,
      const char* package) {
    return opencltools_load_kernel_source_fn()(relative_path, package);
  }
  
  static inline const char* opencltools_load_kernel_library(
      const char* subdir,
      const char* package,
      int verbose) {
    return opencltools_load_kernel_library_fn()(subdir, package, verbose);
  }
  
  static inline const char* opencltools_load_library_for_kernel(
      const char* kernel_relative_path,
      const char* library_subdir,
      const char* package,
      const char* depends_tag) {
    return opencltools_load_library_for_kernel_fn()(
        kernel_relative_path, library_subdir, package, depends_tag);
  }
  
  static inline void opencltools_free_cstr(const char* p) {
    opencltools_free_cstr_fn()(p);
  }
  
#ifdef __cplusplus
}
#endif

#endif /* OPENCLTOOLS_CAPI_H */