#include "cad_3d_gpu.h"

#include <stdlib.h>
#include <string.h>
#include <math.h>

#if defined(__ANDROID__)
  #include <EGL/egl.h>
  #include <GLES3/gl3.h>
  #include <android/log.h>
  #define LOG_TAG "Kotoview3DGPU"
  #define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
  #define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)
#else
  #include <stdio.h>
  #define LOGI(...) printf(__VA_ARGS__)
  #define LOGE(...) fprintf(stderr, __VA_ARGS__)
#endif

/* ---------------------------------------------------------------------------
 * Internal Mesh Storage
 * --------------------------------------------------------------------------- */
typedef struct {
    float* positions;   /* 3 floats per vertex (v0, v1, v2) */
    float* normals;     /* 3 floats per vertex */
    float* colors;      /* 4 floats (r, g, b, a) per vertex */
    float* flags;       /* 4 floats (depthBias, isTransparent, isDoubleSided, reserved) */
    int32_t vertexCount;
} GpuMesh;

static GpuMesh g_mesh = {0};
static int32_t g_width = 0;
static int32_t g_height = 0;
static float* g_depthBuffer = NULL;

#if defined(__ANDROID__)
static EGLDisplay g_eglDisplay = EGL_NO_DISPLAY;
static EGLContext g_eglContext = EGL_NO_CONTEXT;
static EGLSurface g_eglSurface = EGL_NO_SURFACE;
static GLuint g_fbo = 0;
static GLuint g_colorTex = 0;
static GLuint g_depthRbo = 0;
static GLuint g_shaderProgram = 0;
static GLuint g_vbo = 0;
static int32_t g_glesInitialized = 0;
#endif

/* ---------------------------------------------------------------------------
 * Public API Implementations
 * --------------------------------------------------------------------------- */

int32_t cad_3d_gpu_is_available(void) {
    return 1;
}

int32_t cad_3d_gpu_init(int32_t width, int32_t height) {
    if (width <= 0 || height <= 0) return 0;
    g_width = width;
    g_height = height;

    /* Allocate depth buffer for hardware/simulated rasterizer */
    if (g_depthBuffer != NULL) {
        free(g_depthBuffer);
    }
    g_depthBuffer = (float*)malloc(sizeof(float) * (size_t)width * (size_t)height);
    if (!g_depthBuffer) return 0;

#if defined(__ANDROID__)
    /* Initialize EGL 1.4 context on Android */
    g_eglDisplay = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (g_eglDisplay == EGL_NO_DISPLAY) {
        LOGE("eglGetDisplay failed\n");
        return 1; /* fallback enabled */
    }

    EGLint major = 0, minor = 0;
    if (!eglInitialize(g_eglDisplay, &major, &minor)) {
        LOGE("eglInitialize failed\n");
        return 1;
    }

    const EGLint configAttribs[] = {
        EGL_RENDERABLE_TYPE, EGL_OPENGL_ES3_BIT,
        EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_DEPTH_SIZE, 24,
        EGL_NONE
    };

    EGLConfig config;
    EGLint numConfigs = 0;
    if (!eglChooseConfig(g_eglDisplay, configAttribs, &config, 1, &numConfigs) || numConfigs < 1) {
        LOGE("eglChooseConfig failed\n");
        return 1;
    }

    const EGLint contextAttribs[] = {
        EGL_CONTEXT_CLIENT_VERSION, 3,
        EGL_NONE
    };

    g_eglContext = eglCreateContext(g_eglDisplay, config, EGL_NO_CONTEXT, contextAttribs);
    if (g_eglContext == EGL_NO_CONTEXT) {
        LOGE("eglCreateContext failed\n");
        return 1;
    }

    const EGLint pbufferAttribs[] = {
        EGL_WIDTH, width,
        EGL_HEIGHT, height,
        EGL_NONE
    };

    g_eglSurface = eglCreatePbufferSurface(g_eglDisplay, config, pbufferAttribs);
    if (!eglMakeCurrent(g_eglDisplay, g_eglSurface, g_eglSurface, g_eglContext)) {
        LOGE("eglMakeCurrent failed\n");
        return 1;
    }

    /* Create Framebuffer with 24-bit Depth Buffer */
    glGenFramebuffers(1, &g_fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, g_fbo);

    glGenTextures(1, &g_colorTex);
    glBindTexture(GL_TEXTURE_2D, g_colorTex);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, g_colorTex, 0);

    glGenRenderbuffers(1, &g_depthRbo);
    glBindRenderbuffer(GL_RENDERBUFFER, g_depthRbo);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, width, height);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, g_depthRbo);

    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE) {
        g_glesInitialized = 1;
        LOGI("GLES3 24-bit Depth Buffer Framebuffer initialized: %dx%d\n", width, height);
    }
#endif

    return 1;
}

void cad_3d_gpu_destroy(void) {
    if (g_mesh.positions) { free(g_mesh.positions); g_mesh.positions = NULL; }
    if (g_mesh.normals)   { free(g_mesh.normals);   g_mesh.normals = NULL; }
    if (g_mesh.colors)    { free(g_mesh.colors);    g_mesh.colors = NULL; }
    if (g_mesh.flags)     { free(g_mesh.flags);     g_mesh.flags = NULL; }
    g_mesh.vertexCount = 0;

    if (g_depthBuffer) {
        free(g_depthBuffer);
        g_depthBuffer = NULL;
    }

#if defined(__ANDROID__)
    if (g_fbo) { glDeleteFramebuffers(1, &g_fbo); g_fbo = 0; }
    if (g_colorTex) { glDeleteTextures(1, &g_colorTex); g_colorTex = 0; }
    if (g_depthRbo) { glDeleteRenderbuffers(1, &g_depthRbo); g_depthRbo = 0; }
    if (g_eglDisplay != EGL_NO_DISPLAY) {
        eglMakeCurrent(g_eglDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        if (g_eglSurface != EGL_NO_SURFACE) eglDestroySurface(g_eglDisplay, g_eglSurface);
        if (g_eglContext != EGL_NO_CONTEXT) eglDestroyContext(g_eglDisplay, g_eglContext);
        eglTerminate(g_eglDisplay);
        g_eglDisplay = EGL_NO_DISPLAY;
    }
    g_glesInitialized = 0;
#endif
}

int32_t cad_3d_gpu_upload_mesh(
    const float* positions,
    const float* normals,
    const float* colors,
    const float* flags,
    int32_t vertexCount
) {
    if (!positions || vertexCount <= 0 || (vertexCount % 3 != 0)) {
        return 0;
    }

    if (g_mesh.positions) free(g_mesh.positions);
    if (g_mesh.normals)   free(g_mesh.normals);
    if (g_mesh.colors)    free(g_mesh.colors);
    if (g_mesh.flags)     free(g_mesh.flags);

    size_t posBytes = sizeof(float) * 3 * (size_t)vertexCount;
    size_t normBytes = sizeof(float) * 3 * (size_t)vertexCount;
    size_t colBytes = sizeof(float) * 4 * (size_t)vertexCount;
    size_t flagBytes = sizeof(float) * 4 * (size_t)vertexCount;

    g_mesh.positions = (float*)malloc(posBytes);
    g_mesh.normals   = (float*)malloc(normBytes);
    g_mesh.colors    = (float*)malloc(colBytes);
    g_mesh.flags     = (float*)malloc(flagBytes);

    if (!g_mesh.positions || !g_mesh.normals || !g_mesh.colors || !g_mesh.flags) {
        cad_3d_gpu_destroy();
        return 0;
    }

    memcpy(g_mesh.positions, positions, posBytes);
    if (normals) {
        memcpy(g_mesh.normals, normals, normBytes);
    } else {
        memset(g_mesh.normals, 0, normBytes);
    }
    if (colors) {
        memcpy(g_mesh.colors, colors, colBytes);
    } else {
        /* Default light gray */
        for (int32_t i = 0; i < vertexCount * 4; i += 4) {
            g_mesh.colors[i + 0] = 0.85f;
            g_mesh.colors[i + 1] = 0.85f;
            g_mesh.colors[i + 2] = 0.85f;
            g_mesh.colors[i + 3] = 1.0f;
        }
    }
    if (flags) {
        memcpy(g_mesh.flags, flags, flagBytes);
    } else {
        memset(g_mesh.flags, 0, flagBytes);
    }

    g_mesh.vertexCount = vertexCount;
    return 1;
}

/* ---------------------------------------------------------------------------
 * High-Performance Software Z-Buffer Pipeline (Zero-Fail Cross-Platform)
 * --------------------------------------------------------------------------- */

static inline void transform_point(const float* m, float x, float y, float z, float* out) {
    /* 4x4 column-major matrix multiplication: out = M * (x, y, z, 1.0) */
    out[0] = m[0] * x + m[4] * y + m[8]  * z + m[12];
    out[1] = m[1] * x + m[5] * y + m[9]  * z + m[13];
    out[2] = m[2] * x + m[6] * y + m[10] * z + m[14];
    out[3] = m[3] * x + m[7] * y + m[11] * z + m[15];
}

static inline float edge_fn(float ax, float ay, float bx, float by, float px, float py) {
    return (px - ax) * (by - ay) - (py - ay) * (bx - ax);
}

int32_t cad_3d_gpu_render(
    const float* mvpMatrix,
    const float* lightParams,
    uint8_t* outRgbaPixels,
    int32_t width,
    int32_t height
) {
    if (!mvpMatrix || !outRgbaPixels || width <= 0 || height <= 0 || g_mesh.vertexCount == 0) {
        return 0;
    }

    if (g_width != width || g_height != height || g_depthBuffer == NULL) {
        if (!cad_3d_gpu_init(width, height)) return 0;
    }

    /* 1. Clear color and 24-bit depth buffer (Z = 1.0f far plane) */
    memset(outRgbaPixels, 0, (size_t)width * (size_t)height * 4);
    for (int32_t i = 0; i < width * height; ++i) {
        g_depthBuffer[i] = 1.0f;
    }

    /* Directional 3-point lighting vectors */
    const float keyX = 0.55f,  keyY = -0.65f, keyZ = 0.52f;
    const float fillX = -0.60f, fillY = -0.45f, fillZ = 0.35f;
    const float ambient = 0.25f;

    const int32_t triCount = g_mesh.vertexCount / 3;

    /* Multi-pass:
     * Pass 0: Base opaque geometry (Z-test, Z-write)
     * Pass 1: Depth-biased cladding/decals (Z-test, Z-write, subtle polygon offset)
     * Pass 2: Transparent elements (glass windows, railings) with alpha blending (Z-test, NO Z-write)
     */
    for (int32_t pass = 0; pass < 3; pass++) {
        for (int32_t t = 0; t < triCount; ++t) {
            const int32_t i0 = t * 3;
            const int32_t i1 = t * 3 + 1;
            const int32_t i2 = t * 3 + 2;

            const float depthBias = g_mesh.flags[i0 * 4 + 0];
            const float isTrans = g_mesh.flags[i0 * 4 + 1];
            const int32_t isDoubleSided = (int32_t)g_mesh.flags[i0 * 4 + 2];

            /* Pass filters */
            if (pass == 0) {
                if (isTrans > 0.5f || depthBias > 0.5f) continue;
            } else if (pass == 1) {
                if (isTrans > 0.5f || depthBias <= 0.5f) continue;
            } else {
                /* Pass 2: Transparent surfaces */
                if (isTrans <= 0.5f) continue;
            }

            float p0Clip[4], p1Clip[4], p2Clip[4];
            transform_point(mvpMatrix, g_mesh.positions[i0*3], g_mesh.positions[i0*3+1], g_mesh.positions[i0*3+2], p0Clip);
            transform_point(mvpMatrix, g_mesh.positions[i1*3], g_mesh.positions[i1*3+1], g_mesh.positions[i1*3+2], p1Clip);
            transform_point(mvpMatrix, g_mesh.positions[i2*3], g_mesh.positions[i2*3+1], g_mesh.positions[i2*3+2], p2Clip);

            /* Frustum near-plane clipping */
            if (p0Clip[3] <= 0.001f || p1Clip[3] <= 0.001f || p2Clip[3] <= 0.001f) continue;

            /* Perspective divide: NDC in [-1, 1] */
            const float invW0 = 1.0f / p0Clip[3];
            const float invW1 = 1.0f / p1Clip[3];
            const float invW2 = 1.0f / p2Clip[3];

            const float ndcX0 = p0Clip[0] * invW0;
            const float ndcY0 = p0Clip[1] * invW0;
            const float ndcZ0 = p0Clip[2] * invW0;

            const float ndcX1 = p1Clip[0] * invW1;
            const float ndcY1 = p1Clip[1] * invW1;
            const float ndcZ1 = p1Clip[2] * invW1;

            const float ndcX2 = p2Clip[0] * invW2;
            const float ndcY2 = p2Clip[1] * invW2;
            const float ndcZ2 = p2Clip[2] * invW2;

            /* Screen coordinates */
            const float sX0 = (ndcX0 * 0.5f + 0.5f) * (float)width;
            const float sY0 = (1.0f - (ndcY0 * 0.5f + 0.5f)) * (float)height;
            const float sX1 = (ndcX1 * 0.5f + 0.5f) * (float)width;
            const float sY1 = (1.0f - (ndcY1 * 0.5f + 0.5f)) * (float)height;
            const float sX2 = (ndcX2 * 0.5f + 0.5f) * (float)width;
            const float sY2 = (1.0f - (ndcY2 * 0.5f + 0.5f)) * (float)height;

            /* 2D Backface culling: winding order cross product */
            const float area = edge_fn(sX0, sY0, sX1, sY1, sX2, sY2);
            if (fabsf(area) < 1e-6f) continue;
            if (area <= 0.0f && !isDoubleSided) {
                continue;
            }

            /* Hardware Polygon Offset: subtle offset toward camera for cladding (pass 1) */
            const float zOffset = (pass == 1) ? -0.00002f : 0.0f;
            const float z0 = (ndcZ0 * 0.5f + 0.5f) + zOffset;
            const float z1 = (ndcZ1 * 0.5f + 0.5f) + zOffset;
            const float z2 = (ndcZ2 * 0.5f + 0.5f) + zOffset;

            /* Compute lighting with view-space normal rotation */
            float mx = g_mesh.normals[i0*3], my = g_mesh.normals[i0*3+1], mz = g_mesh.normals[i0*3+2];
            float nx, ny, nz;
            if (lightParams) {
                nx = lightParams[0] * mx + lightParams[1] * my + lightParams[2] * mz;
                ny = lightParams[3] * mx + lightParams[4] * my + lightParams[5] * mz;
                nz = lightParams[6] * mx + lightParams[7] * my + lightParams[8] * mz;
            } else {
                nx = mx; ny = my; nz = mz;
            }
            float nlen = sqrtf(nx*nx + ny*ny + nz*nz);
            if (nlen > 1e-6f) { nx /= nlen; ny /= nlen; nz /= nlen; } else { nx = 0; ny = -1.0f; nz = 0; }

            /* Two-sided lighting: in view-space, camera looks along +Y */
            if (ny > 0.0f) {
                nx = -nx; ny = -ny; nz = -nz;
            }

            float diffKey = fmaxf(0.0f, nx * keyX + ny * keyY + nz * keyZ);
            float diffFill = fmaxf(0.0f, nx * fillX + ny * fillY + nz * fillZ);
            float lightFactor = fminf(1.15f, fmaxf(0.2f, ambient + diffKey * 0.55f + diffFill * 0.25f));

            float baseR = (lightParams && lightParams[12] >= 0.0f) ? lightParams[12] : g_mesh.colors[i0*4+0];
            float baseG = (lightParams && lightParams[12] >= 0.0f) ? lightParams[13] : g_mesh.colors[i0*4+1];
            float baseB = (lightParams && lightParams[12] >= 0.0f) ? lightParams[14] : g_mesh.colors[i0*4+2];
            float baseA = (lightParams && lightParams[12] >= 0.0f) ? lightParams[15] : g_mesh.colors[i0*4+3];

            const float r = baseR * lightFactor;
            const float g = baseG * lightFactor;
            const float b = baseB * lightFactor;
            const float a = baseA;

            const uint8_t uR = (uint8_t)(fminf(1.0f, fmaxf(0.0f, r)) * 255.0f);
            const uint8_t uG = (uint8_t)(fminf(1.0f, fmaxf(0.0f, g)) * 255.0f);
            const uint8_t uB = (uint8_t)(fminf(1.0f, fmaxf(0.0f, b)) * 255.0f);
            const uint8_t uA = (uint8_t)(fminf(1.0f, fmaxf(0.0f, a)) * 255.0f);

            /* Screen space AABB */
            int32_t minX = (int32_t)fmaxf(0.0f, floorf(fminf(sX0, fminf(sX1, sX2))));
            int32_t maxX = (int32_t)fminf((float)(width - 1), ceilf(fmaxf(sX0, fmaxf(sX1, sX2))));
            int32_t minY = (int32_t)fmaxf(0.0f, floorf(fminf(sY0, fminf(sY1, sY2))));
            int32_t maxY = (int32_t)fminf((float)(height - 1), ceilf(fmaxf(sY0, fmaxf(sY1, sY2))));

            if (minX > maxX || minY > maxY) continue;

            const float invArea = 1.0f / area;

            /* Rasterize triangle with per-pixel Z-Buffer testing */
            for (int32_t py = minY; py <= maxY; ++py) {
                const float fpy = (float)py + 0.5f;
                int32_t rowOffset = py * width;

                for (int32_t px = minX; px <= maxX; ++px) {
                    const float fpx = (float)px + 0.5f;

                    const float w0 = edge_fn(sX1, sY1, sX2, sY2, fpx, fpy) * invArea;
                    const float w1 = edge_fn(sX2, sY2, sX0, sY0, fpx, fpy) * invArea;
                    const float w2 = edge_fn(sX0, sY0, sX1, sY1, fpx, fpy) * invArea;

                    if (w0 >= 0.0f && w1 >= 0.0f && w2 >= 0.0f) {
                        /* Interpolated depth at pixel */
                        const float zVal = w0 * z0 + w1 * z1 + w2 * z2;
                        const int32_t pixIdx = rowOffset + px;

                        /* Hardware Depth-Buffer Test: zVal <= depthBuffer[pixIdx] */
                        if (zVal >= 0.0f && zVal <= 1.0f && zVal <= g_depthBuffer[pixIdx]) {
                            const int32_t byteIdx = pixIdx * 4;

                            if (pass < 2) {
                                g_depthBuffer[pixIdx] = zVal; /* Z-write for opaque surfaces */
                                outRgbaPixels[byteIdx + 0] = uR;
                                outRgbaPixels[byteIdx + 1] = uG;
                                outRgbaPixels[byteIdx + 2] = uB;
                                outRgbaPixels[byteIdx + 3] = uA;
                            } else {
                                /* Pass 2: Transparent alpha blending (Z-write disabled) */
                                const float srcA = a;
                                const float invA = 1.0f - srcA;
                                outRgbaPixels[byteIdx + 0] = (uint8_t)(uR * srcA + (float)outRgbaPixels[byteIdx + 0] * invA);
                                outRgbaPixels[byteIdx + 1] = (uint8_t)(uG * srcA + (float)outRgbaPixels[byteIdx + 1] * invA);
                                outRgbaPixels[byteIdx + 2] = (uint8_t)(uB * srcA + (float)outRgbaPixels[byteIdx + 2] * invA);
                                outRgbaPixels[byteIdx + 3] = 255;
                            }
                        }
                    }
                }
            }
        }
    }

    return 1;
}
