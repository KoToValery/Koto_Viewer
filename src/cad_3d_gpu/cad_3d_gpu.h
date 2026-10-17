#ifndef KOTO_CAD_3D_GPU_H
#define KOTO_CAD_3D_GPU_H

#include <stdint.h>

#if defined(_WIN32)
  #if defined(KOTO_GPU_BUILD_DLL)
    #define KOTO_GPU_API __declspec(dllexport)
  #else
    #define KOTO_GPU_API __declspec(dllimport)
  #endif
#elif defined(__GNUC__) || defined(__clang__)
  #define KOTO_GPU_API __attribute__((visibility("default")))
#else
  #define KOTO_GPU_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Checks whether this native software depth renderer is available.
 * The legacy GPU symbol names are retained for ABI compatibility.
 */
KOTO_GPU_API int32_t cad_3d_gpu_is_available(void);

/**
 * Allocates the native offscreen depth buffer. No hardware context is created.
 * Returns 1 on success, 0 on failure.
 */
KOTO_GPU_API int32_t cad_3d_gpu_init(int32_t width, int32_t height);

/**
 * Releases native vertex and depth buffers.
 */
KOTO_GPU_API void cad_3d_gpu_destroy(void);

/**
 * Copies triangle mesh data into native memory.
 *
 * @param positions Contiguous array of 3D coordinates (x, y, z) per vertex (3 vertices per triangle).
 * @param normals   Contiguous array of 3D normals (nx, ny, nz) per vertex.
 * @param colors    Contiguous array of RGBA color channels (r, g, b, a in range [0, 1]) per vertex.
 * @param flags     Contiguous array of 4 floats per vertex: [depthBias, isTransparent, isDoubleSided, reserved].
 * @param vertexCount Total number of vertices (triangleCount * 3).
 *
 * Returns 1 on success, 0 on failure.
 */
KOTO_GPU_API int32_t cad_3d_gpu_upload_mesh(
    const float* positions,
    const float* normals,
    const float* colors,
    const float* flags,
    int32_t vertexCount
);

/**
 * Renders the mesh into the destination RGBA buffer using software Z-buffering.
 *
 * @param mvpMatrix 16-element column-major 4x4 Model-View-Projection matrix.
 * @param lightParams 16-element array of lighting parameters (key, fill, headlight, ambient, etc.).
 * @param outRgbaPixels Output buffer of size (width * height * 4) bytes.
 * @param width Viewport width in pixels.
 * @param height Viewport height in pixels.
 *
 * Returns 1 on success, 0 on failure.
 */
KOTO_GPU_API int32_t cad_3d_gpu_render(
    const float* mvpMatrix,
    const float* lightParams,
    uint8_t* outRgbaPixels,
    int32_t width,
    int32_t height
);

#ifdef __cplusplus
}
#endif

#endif /* KOTO_CAD_3D_GPU_H */
