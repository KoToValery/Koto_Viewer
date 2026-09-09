/**
 * openjpeg_bridge.c — Minimal C wrapper for openjpeg JPEG 2000 decoding.
 *
 * Exposes a single function:
 *   opj_decode_to_rgba(data, length, out_width, out_height, out_rgba)
 *
 * The caller provides the JPEG 2000 compressed bytes and receives back:
 *   - Image width and height (via out pointers)
 *   - Raw RGBA pixel data (malloc-allocated; caller must free with opj_free_buffer)
 *
 * This wrapper handles:
 *   - Both JPEG 2000 codestream (J2K) and JP2 file format containers
 *   - Grayscale (1 component) → RGBA conversion
 *   - RGB (3 components) → RGBA conversion
 *   - RGBA (4 components) — passed through
 *   - 8-bit and 16-bit precision (16-bit is scaled to 8-bit for display)
 */

#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "openjpeg.h"
#include "openjpeg_bridge.h"

/* -------------------------------------------------------------------------- */
/* Silent message handlers (suppress openjpeg console output)                 */
/* -------------------------------------------------------------------------- */
static void _opj_quiet_msg(const char *msg, void *client_data) {
    (void)msg; (void)client_data;
}

/* -------------------------------------------------------------------------- */
/* In-memory stream implementation for openjpeg                                */
/* -------------------------------------------------------------------------- */
typedef struct {
    const OPJ_BYTE *pData;
    OPJ_SIZE_T dataSize;
    OPJ_SIZE_T offset;
} opj_memory_stream_t;

static OPJ_SIZE_T _opj_mem_read(void *p_buffer, OPJ_SIZE_T p_nb_bytes, void *p_user_data) {
    opj_memory_stream_t *m = (opj_memory_stream_t *)p_user_data;
    if (m->offset >= m->dataSize) {
        return (OPJ_SIZE_T)-1;
    }
    OPJ_SIZE_T bytes_to_read = p_nb_bytes;
    if (m->offset + bytes_to_read > m->dataSize) {
        bytes_to_read = m->dataSize - m->offset;
    }
    memcpy(p_buffer, m->pData + m->offset, bytes_to_read);
    m->offset += bytes_to_read;
    return bytes_to_read;
}

static OPJ_OFF_T _opj_mem_skip(OPJ_OFF_T p_nb_bytes, void *p_user_data) {
    opj_memory_stream_t *m = (opj_memory_stream_t *)p_user_data;
    if (p_nb_bytes < 0) {
        return -1;
    }
    if ((OPJ_SIZE_T)p_nb_bytes > m->dataSize - m->offset) {
        p_nb_bytes = (OPJ_OFF_T)(m->dataSize - m->offset);
    }
    m->offset += (OPJ_SIZE_T)p_nb_bytes;
    return p_nb_bytes;
}

static OPJ_BOOL _opj_mem_seek(OPJ_OFF_T p_nb_bytes, void *p_user_data) {
    opj_memory_stream_t *m = (opj_memory_stream_t *)p_user_data;
    if (p_nb_bytes < 0 || (OPJ_SIZE_T)p_nb_bytes > m->dataSize) {
        return OPJ_FALSE;
    }
    m->offset = (OPJ_SIZE_T)p_nb_bytes;
    return OPJ_TRUE;
}

static void _opj_mem_free(void *p_user_data) {
    free(p_user_data);
}

static opj_stream_t *_opj_stream_create_memory(const uint8_t *data, OPJ_SIZE_T length) {
    opj_memory_stream_t *m = (opj_memory_stream_t *)malloc(sizeof(opj_memory_stream_t));
    if (!m) return NULL;
    m->pData = (const OPJ_BYTE *)data;
    m->dataSize = length;
    m->offset = 0;

    OPJ_SIZE_T buf_size = length < 4096 ? length : 4096;
    if (buf_size == 0) buf_size = 1;

    opj_stream_t *stream = opj_stream_create(buf_size, OPJ_TRUE);
    if (!stream) {
        free(m);
        return NULL;
    }

    opj_stream_set_read_function(stream, _opj_mem_read);
    opj_stream_set_skip_function(stream, _opj_mem_skip);
    opj_stream_set_seek_function(stream, _opj_mem_seek);
    opj_stream_set_user_data(stream, m, _opj_mem_free);
    opj_stream_set_user_data_length(stream, (OPJ_UINT64)length);
    return stream;
}

/* -------------------------------------------------------------------------- */
/* Public API                                                                  */
/* -------------------------------------------------------------------------- */

/**
 * Decode a JPEG 2000 buffer to RGBA pixels.
 *
 * @param data        Pointer to the compressed J2K/JP2 bytes.
 * @param length      Number of bytes in data.
 * @param out_width   Output: decoded image width in pixels.
 * @param out_height  Output: decoded image height in pixels.
 * @param out_rgba    Output: pointer to malloc'd RGBA buffer (width*height*4 bytes).
 *                    The caller must free this with opj_free_buffer().
 * @return 1 on success, 0 on failure.
 */
OPJ_BRIDGE_EXPORT int opj_decode_to_rgba(
    const uint8_t *data,
    int length,
    int *out_width,
    int *out_height,
    uint8_t **out_rgba
) {
    if (!data || length <= 0 || !out_width || !out_height || !out_rgba) {
        return 0;
    }

    *out_width = 0;
    *out_height = 0;
    *out_rgba = NULL;

    /* Auto-detect format: JP2 starts with 0x0000000C6A502020, J2K starts with FF4F */
    OPJ_CODEC_FORMAT format = OPJ_CODEC_J2K;
    if (length >= 12) {
        /* JP2 signature: 0x0000000C 6A502020 0D0A870A */
        if (data[0] == 0x00 && data[1] == 0x00 && data[2] == 0x00 &&
            data[3] == 0x0C && data[4] == 0x6A && data[5] == 0x50) {
            format = OPJ_CODEC_JP2;
        }
    }

    /* Create stream from memory buffer */
    opj_stream_t *stream = _opj_stream_create_memory(data, (OPJ_SIZE_T)length);
    if (!stream) return 0;

    /* Create and configure decoder */
    opj_codec_t *codec = opj_create_decompress(format);
    if (!codec) {
        opj_stream_destroy(stream);
        return 0;
    }

    /* Suppress all messages */
    opj_set_info_handler(codec, _opj_quiet_msg, NULL);
    opj_set_warning_handler(codec, _opj_quiet_msg, NULL);
    opj_set_error_handler(codec, _opj_quiet_msg, NULL);

    /* Default parameters */
    opj_dparameters_t params;
    opj_set_default_decoder_parameters(&params);
    if (!opj_setup_decoder(codec, &params)) {
        opj_destroy_codec(codec);
        opj_stream_destroy(stream);
        return 0;
    }

    /* Read header */
    opj_image_t *image = NULL;
    if (!opj_read_header(stream, codec, &image)) {
        opj_destroy_codec(codec);
        opj_stream_destroy(stream);
        return 0;
    }

    /* Decode full image */
    if (!opj_decode(codec, stream, image) || !opj_end_decompress(codec, stream)) {
        opj_image_destroy(image);
        opj_destroy_codec(codec);
        opj_stream_destroy(stream);
        return 0;
    }

    opj_stream_destroy(stream);
    opj_destroy_codec(codec);

    const int width  = (int)(image->x1 - image->x0);
    const int height = (int)(image->y1 - image->y0);
    const int comps  = (int)image->numcomps;

    if (width <= 0 || height <= 0 || comps < 1) {
        opj_image_destroy(image);
        return 0;
    }

    const int pixels = width * height;
    uint8_t *rgba = (uint8_t*)malloc((size_t)pixels * 4);
    if (!rgba) {
        opj_image_destroy(image);
        return 0;
    }

    /* Determine bit depth of first component */
    const int prec = (int)image->comps[0].prec;
    const int shift = (prec > 8) ? (prec - 8) : 0;
    const int sgnd  = image->comps[0].sgnd;
    const int offset = sgnd ? (1 << (prec - 1)) : 0;

    for (int i = 0; i < pixels; i++) {
        uint8_t r, g, b, a;

        if (comps == 1) {
            /* Grayscale */
            int v = image->comps[0].data[i] + offset;
            v >>= shift;
            if (v < 0) v = 0;
            if (v > 255) v = 255;
            r = g = b = (uint8_t)v;
            a = 255;
        } else if (comps >= 3) {
            /* RGB or RGBA */
            int rv = image->comps[0].data[i] + offset;
            int gv = image->comps[1].data[i] + offset;
            int bv = image->comps[2].data[i] + offset;
            rv >>= shift; gv >>= shift; bv >>= shift;
            if (rv < 0) rv = 0; if (rv > 255) rv = 255;
            if (gv < 0) gv = 0; if (gv > 255) gv = 255;
            if (bv < 0) bv = 0; if (bv > 255) bv = 255;
            r = (uint8_t)rv;
            g = (uint8_t)gv;
            b = (uint8_t)bv;
            a = (comps >= 4)
                ? (uint8_t)(image->comps[3].data[i] >> shift)
                : 255;
        } else {
            /* 2-component — treat as grayscale+alpha */
            int v = image->comps[0].data[i] + offset;
            v >>= shift;
            if (v < 0) v = 0; if (v > 255) v = 255;
            r = g = b = (uint8_t)v;
            a = 255;
        }

        rgba[i * 4]     = r;
        rgba[i * 4 + 1] = g;
        rgba[i * 4 + 2] = b;
        rgba[i * 4 + 3] = a;
    }

    opj_image_destroy(image);

    *out_width  = width;
    *out_height = height;
    *out_rgba   = rgba;
    return 1;
}

/**
 * Free a buffer previously allocated by opj_decode_to_rgba.
 */
OPJ_BRIDGE_EXPORT void opj_free_buffer(uint8_t *buf) {
    free(buf);
}
