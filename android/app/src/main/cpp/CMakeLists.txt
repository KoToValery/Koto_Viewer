cmake_minimum_required(VERSION 3.10.2)

project(koto_dwg C)

include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

# Prebuilt LibreDWG shared library from jniLibs
add_library(redwg SHARED IMPORTED)
set_target_properties(redwg PROPERTIES
    IMPORTED_LOCATION "${CMAKE_CURRENT_SOURCE_DIR}/../jniLibs/${ANDROID_ABI}/libredwg.so"
)

add_library(koto_dwg SHARED
    dwg_converter_bridge.c
)

target_compile_definitions(koto_dwg PRIVATE HAVE_LIBREDWG=1)

find_library(log-lib log)
find_library(m-lib m)

target_link_libraries(koto_dwg PRIVATE
    redwg
    ${log-lib}
    ${m-lib}
)
