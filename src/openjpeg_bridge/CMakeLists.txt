cmake_minimum_required(VERSION 3.18)
project(openjpeg_bridge C)

# ---------------------------------------------------------------------------
# openjpeg source path (relative to this CMakeLists.txt location)
# Flutter plugin CMake is invoked from the build/ directory, but CMAKE_CURRENT_SOURCE_DIR
# points to this file's directory. We locate third_party relative to the Flutter root.
# ---------------------------------------------------------------------------
set(OPJ_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/openjpeg")
set(OPJ_SRC  "${OPJ_ROOT}/src/lib/openjp2")

# Collect openjpeg source files (exclude tools and test utilities)
file(GLOB OPJ_SOURCES
    "${OPJ_SRC}/*.c"
)

# Remove files that have main() or are platform-specific non-essential utilities
list(FILTER OPJ_SOURCES EXCLUDE REGEX ".*bench_.*\\.c$")
list(FILTER OPJ_SOURCES EXCLUDE REGEX ".*t1_generate.*\\.c$")

# ---------------------------------------------------------------------------
# openjpeg_bridge shared library
# ---------------------------------------------------------------------------
add_library(openjpeg_bridge SHARED
    "${CMAKE_CURRENT_SOURCE_DIR}/openjpeg_bridge.c"
    ${OPJ_SOURCES}
)

target_include_directories(openjpeg_bridge PRIVATE
    "${CMAKE_CURRENT_SOURCE_DIR}"
    "${OPJ_SRC}"
    "${OPJ_ROOT}/src/lib"  # for opj_common.h etc.
)

# openjpeg needs these definitions
target_compile_definitions(openjpeg_bridge PRIVATE
    OPJ_STATIC          # Link statically (we compile into one shared lib)
    OPJ_HAVE_STDINT_H
    _CRT_SECURE_NO_WARNINGS  # Windows: suppress fopen warnings
)

# Compiler options & optimisations
if(MSVC)
    target_compile_options(openjpeg_bridge PRIVATE
        /W0
        $<$<CONFIG:Release>:/O2>
        $<$<CONFIG:Profile>:/O2>
    )
else()
    target_compile_options(openjpeg_bridge PRIVATE -w -O2)
endif()

# Export only our bridge symbols (not openjpeg internals)
set_target_properties(openjpeg_bridge PROPERTIES
    C_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN ON
    OUTPUT_NAME "openjpeg_bridge"
)
