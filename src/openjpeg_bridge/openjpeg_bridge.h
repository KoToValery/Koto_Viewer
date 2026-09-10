/**
 * openjpeg_bridge.h — Public API for openjpeg_bridge shared library.
 * Used by dart_ffigen to generate Dart FFI bindings.
 */

#ifndef OPENJPEG_BRIDGE_H
#define OPENJPEG_BRIDGE_H

#include <stdint.h>

#ifdef _WIN32
#  define OPJ_BRIDGE_EXPORT __declspec(dllexport)
#elif defined(__GNUC__) && __GNUC__ >= 4
#  define OPJ_BRIDGE_EXPORT __attribute__((visibility("default")))
#else
#  define OPJ_BRIDGE_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Decode a JPEG 2000 buffer (J2K codestream or JP2 container) to RGBA pixels.
 *
 * @param data        Pointer to the compressed bytes.
 * @param length      Number of compressed bytes.
 * @param out_width   Output: decoded image width.
 * @param out_height  Output: decoded image height.
 * @param out_rgba    Output: malloc'd RGBA buffer (width*height*4 bytes).
 *                    Must be freed with opj_free_buffer() after use.
 * @return 1 on success, 0 on failure.
 */
OPJ_BRIDGE_EXPORT int opj_decode_to_rgba(
    const uint8_t *data,
    int length,
    int *out_width,
    int *out_height,
    uint8_t **out_rgba
);

/**
 * Decode a JPEG 2000 buffer to raw pixel data or RGBA.
 *
 * For grayscale (numcomps == 1):
 *   - *out_pixels will contain (width * height) int32_t values.
 *   - *out_rgba will be NULL.
 * For color (numcomps >= 3):
 *   - *out_pixels will be NULL.
 *   - *out_rgba will contain (width * height * 4) uint8_t RGBA values.
 *
 * The non-null buffer must be freed with opj_free_buffer() after use.
 *
 * @return 1 on success, 0 on failure.
 */
OPJ_BRIDGE_EXPORT int opj_decode_raw(
    const uint8_t *data,
    int length,
    int *out_width,
    int *out_height,
    int *out_num_comps,
    int *out_prec,
    int *out_sgnd,
    int32_t **out_pixels,
    uint8_t **out_rgba
);

/**
 * Free a buffer allocated by opj_decode_to_rgba or opj_decode_raw.
 */
OPJ_BRIDGE_EXPORT void opj_free_buffer(uint8_t *buf);

#ifdef __cplusplus
}
#endif

#endif /* OPENJPEG_BRIDGE_H */
