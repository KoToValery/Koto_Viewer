cmake_minimum_required(VERSION 3.10.2)

project(koto_native C)

include("${CMAKE_CURRENT_SOURCE_DIR}/../../../../../src/acadrust_converter/acadrust_android.cmake")

find_library(log-lib log)
find_library(m-lib m)

# ---------------------------------------------------------------------------
# openjpeg_bridge — JPEG 2000 decoding via openjpeg 2.x
# ---------------------------------------------------------------------------
set(OPJ_SRC "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../third_party/openjpeg/src/lib/openjp2")

set(OPJ_SOURCES
    ${OPJ_SRC}/thread.c
    ${OPJ_SRC}/bio.c
    ${OPJ_SRC}/cio.c
    ${OPJ_SRC}/dwt.c
    ${OPJ_SRC}/event.c
    ${OPJ_SRC}/ht_dec.c
    ${OPJ_SRC}/image.c
    ${OPJ_SRC}/invert.c
    ${OPJ_SRC}/j2k.c
    ${OPJ_SRC}/jp2.c
    ${OPJ_SRC}/mct.c
    ${OPJ_SRC}/mqc.c
    ${OPJ_SRC}/openjpeg.c
    ${OPJ_SRC}/opj_clock.c
    ${OPJ_SRC}/pi.c
    ${OPJ_SRC}/t1.c
    ${OPJ_SRC}/t2.c
    ${OPJ_SRC}/tcd.c
    ${OPJ_SRC}/tgt.c
    ${OPJ_SRC}/function_list.c
    ${OPJ_SRC}/opj_malloc.c
    ${OPJ_SRC}/sparse_array.c
)

add_library(openjpeg_bridge SHARED
    "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../src/openjpeg_bridge/openjpeg_bridge.c"
    ${OPJ_SOURCES}
)

target_include_directories(openjpeg_bridge PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../src/openjpeg_bridge"
    "${OPJ_SRC}"
)

target_compile_definitions(openjpeg_bridge PRIVATE
    OPJ_STATIC
    OPJ_HAVE_STDINT_H
    MUTEX_pthread
)

target_compile_options(openjpeg_bridge PRIVATE
    -w        # suppress all warnings from openjpeg
    -O2
    -fvisibility=hidden
)

target_link_libraries(openjpeg_bridge PRIVATE
    ${log-lib}
    ${m-lib}
)

# ---------------------------------------------------------------------------
# kotoview_3d_gpu — Hardware GPU Depth-Buffer 3D Renderer (Android GLES3 / EGL)
# ---------------------------------------------------------------------------
include("${CMAKE_CURRENT_SOURCE_DIR}/../../../../../src/cad_3d_gpu/cad_3d_gpu.cmake")

