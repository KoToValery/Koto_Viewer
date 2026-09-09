/* Manually generated opj_config_private.h for openjpeg 2.5.x */
/* Platform-specific settings — Windows x64 / Linux arm64/x64 / Android arm64 */

#define OPJ_PACKAGE_VERSION "2.5.3"

/* Large file support */
/* #undef _LARGEFILE_SOURCE */
/* #undef _LARGE_FILES */
/* #undef _FILE_OFFSET_BITS */
/* #undef OPJ_HAVE_FSEEKO */

/* Memory alignment — Windows uses _aligned_malloc, Linux/Android use posix_memalign */
#if defined(_WIN32)
#  define OPJ_HAVE_MALLOC_H
#  define OPJ_HAVE__ALIGNED_MALLOC
/* #undef OPJ_HAVE_ALIGNED_ALLOC */
/* #undef OPJ_HAVE_MEMALIGN */
/* #undef OPJ_HAVE_POSIX_MEMALIGN */
#else
/* Linux / Android */
#  define OPJ_HAVE_POSIX_MEMALIGN
/* #undef OPJ_HAVE__ALIGNED_MALLOC */
/* #undef OPJ_HAVE_ALIGNED_ALLOC */
/* #undef OPJ_HAVE_MEMALIGN */
/* #undef OPJ_HAVE_MALLOC_H */
#endif

/* Endianness — all targets we support are little-endian */
/* #undef OPJ_BIG_ENDIAN */
