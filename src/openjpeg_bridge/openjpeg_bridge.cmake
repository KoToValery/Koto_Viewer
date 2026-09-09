# openjpeg_bridge.cmake — included directly by windows/CMakeLists.txt
#
# Defines: openjpeg_bridge (SHARED library target)
# Requires: CMAKE_CURRENT_LIST_DIR available (set by CMake for included files)

# ---------------------------------------------------------------------------
# openjpeg source location
# ---------------------------------------------------------------------------
set(OPJ_BRIDGE_ROOT "${CMAKE_CURRENT_LIST_DIR}")
set(OPJ_BRIDGE_SRC  "${CMAKE_CURRENT_LIST_DIR}/openjpeg_bridge.c")
set(OPJ_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../third_party/openjpeg")
set(OPJ_SRC  "${OPJ_ROOT}/src/lib/openjp2")

# Explicit list of openjp2 core sources (omits JPIP indexing managers like cidx, phix, etc.)
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

# ---------------------------------------------------------------------------
# openjpeg_bridge shared library
# ---------------------------------------------------------------------------
add_library(openjpeg_bridge SHARED
    "${OPJ_BRIDGE_SRC}"
    ${OPJ_SOURCES}
)

target_include_directories(openjpeg_bridge PRIVATE
    "${OPJ_BRIDGE_ROOT}"   # contains opj_config.h and opj_config_private.h
    "${OPJ_SRC}"
    "${OPJ_ROOT}/src/lib"
)

target_compile_definitions(openjpeg_bridge PRIVATE
    OPJ_STATIC
    OPJ_HAVE_STDINT_H
    _CRT_SECURE_NO_WARNINGS
    MUTEX_win32
)

# Suppress warnings from openjpeg (W0) + release optimisations
target_compile_options(openjpeg_bridge PRIVATE
    /W0
    $<$<CONFIG:Release>:/O2>
    $<$<CONFIG:Profile>:/O2>
)

set_target_properties(openjpeg_bridge PROPERTIES
    OUTPUT_NAME "openjpeg_bridge"
)
