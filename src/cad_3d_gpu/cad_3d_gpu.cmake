# Native software depth renderer; target name retained for ABI compatibility.
# Used by both Android (NDK) and Windows CMake builds

set(CAD_3D_GPU_DIR "${CMAKE_CURRENT_LIST_DIR}")

add_library(kotoview_3d_gpu SHARED
    "${CAD_3D_GPU_DIR}/cad_3d_gpu.c"
)

target_include_directories(kotoview_3d_gpu PUBLIC
    "${CAD_3D_GPU_DIR}"
)

target_compile_definitions(kotoview_3d_gpu PRIVATE
    KOTO_GPU_BUILD_DLL
)

if(ANDROID)
    target_link_libraries(kotoview_3d_gpu PRIVATE
        m
    )
elseif(UNIX)
    target_link_libraries(kotoview_3d_gpu PRIVATE
        m
    )
endif()
