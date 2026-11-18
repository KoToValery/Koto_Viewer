option(KOTO_BUILD_ACADRUST "Build the Android acadrust JNI backend" ON)
if(NOT KOTO_BUILD_ACADRUST)
  return()
endif()
option(KOTO_REBUILD_ACADRUST "Rebuild Rust instead of packaging the bundled Android reader" OFF)
set(KOTO_ACADRUST_SOURCE "${CMAKE_CURRENT_LIST_DIR}")
get_filename_component(KOTO_REPO_ROOT "${KOTO_ACADRUST_SOURCE}/../.." ABSOLUTE)
if(NOT KOTO_REBUILD_ACADRUST)
  # Gradle's jniLibs source set packages these. Validate every ABI here, so a
  # Git checkout with missing/changed binaries cannot silently omit DWG support.
  set(KOTO_BUNDLE "${KOTO_ACADRUST_SOURCE}/prebuilt/android")
  if(NOT EXISTS "${KOTO_BUNDLE}/manifest.cmake")
    message(FATAL_ERROR "Bundled acadrust binaries are missing. Sync src/acadrust_converter/prebuilt, or rebuild with -PkotoRebuildAcadrust=true.")
  endif()
  include("${KOTO_BUNDLE}/manifest.cmake")
  foreach(KOTO_ABI IN ITEMS arm64-v8a armeabi-v7a x86_64)
    set(KOTO_LIBRARY "${KOTO_BUNDLE}/${KOTO_ABI}/libkoto_acadrust.so")
    if(NOT EXISTS "${KOTO_LIBRARY}")
      message(FATAL_ERROR "Missing bundled acadrust JNI library: ${KOTO_ABI}")
    endif()
    file(SHA256 "${KOTO_LIBRARY}" KOTO_LIBRARY_HASH)
    if(NOT KOTO_LIBRARY_HASH STREQUAL "${KOTO_ACADRUST_SHA256_${KOTO_ABI}}")
      message(FATAL_ERROR "Bundled acadrust JNI checksum mismatch: ${KOTO_ABI}")
    endif()
  endforeach()
  set(KOTO_SOURCE_INDEX 0)
  foreach(KOTO_INPUT IN LISTS KOTO_ACADRUST_NATIVE_INPUTS)
    file(READ "${KOTO_ACADRUST_SOURCE}/${KOTO_INPUT}" KOTO_SOURCE_TEXT)
    string(REPLACE "\r\n" "\n" KOTO_SOURCE_TEXT "${KOTO_SOURCE_TEXT}")
    string(SHA256 KOTO_SOURCE_HASH "${KOTO_SOURCE_TEXT}")
    if(NOT KOTO_SOURCE_HASH STREQUAL "${KOTO_ACADRUST_SOURCE_${KOTO_SOURCE_INDEX}}")
      message(FATAL_ERROR "Bundled acadrust is stale: ${KOTO_INPUT}. Rebuild and run tools/bundle_acadrust_android.ps1.")
    endif()
    math(EXPR KOTO_SOURCE_INDEX "${KOTO_SOURCE_INDEX} + 1")
  endforeach()
  return()
endif()
set(KOTO_LOCAL_RUST "${KOTO_REPO_ROOT}/build/acadrust-toolchain")
find_program(KOTO_CARGO_EXECUTABLE cargo HINTS
  "$ENV{HOME}/.cargo/bin" "$ENV{USERPROFILE}/.cargo/bin"
  "${KOTO_LOCAL_RUST}/cargo/bin")
if(NOT KOTO_CARGO_EXECUTABLE)
  message(FATAL_ERROR "Rust/Cargo not found. Direct Android DWG opening requires acadrust. Install Rust or explicitly set KOTO_BUILD_ACADRUST=OFF to build without DWG support.")
endif()
if(ANDROID_ABI STREQUAL "arm64-v8a")
  set(KOTO_RUST_TARGET "aarch64-linux-android")
elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
  set(KOTO_RUST_TARGET "armv7-linux-androideabi")
elseif(ANDROID_ABI STREQUAL "x86_64")
  set(KOTO_RUST_TARGET "x86_64-linux-android")
else()
  message(WARNING "acadrust is not configured for Android ABI ${ANDROID_ABI}")
  return()
endif()
set(KOTO_RUST_ENV)
if(KOTO_CARGO_EXECUTABLE STREQUAL "${KOTO_LOCAL_RUST}/cargo/bin/cargo.exe")
  list(APPEND KOTO_RUST_ENV
    "CARGO_HOME=${KOTO_LOCAL_RUST}/cargo"
    "RUSTUP_HOME=${KOTO_LOCAL_RUST}/rustup"
    "RUSTC=${KOTO_LOCAL_RUST}/cargo/bin/rustc.exe")
endif()

# Cargo produces a static archive. NDK links the final JNI library for the
# selected ABI/API, including the alignment required by 16 KB page devices.
string(TOUPPER "${KOTO_RUST_TARGET}" KOTO_TARGET_ENV)
string(REPLACE "-" "_" KOTO_TARGET_ENV "${KOTO_TARGET_ENV}")
list(APPEND KOTO_RUST_ENV
  "CARGO_TARGET_${KOTO_TARGET_ENV}_LINKER=${CMAKE_C_COMPILER}")
set(KOTO_TARGET_DIR "${KOTO_REPO_ROOT}/build/acadrust/android/${ANDROID_ABI}")
set(KOTO_RUST_ARCHIVE "${KOTO_TARGET_DIR}/${KOTO_RUST_TARGET}/release/libkoto_acadrust.a")
add_custom_command(OUTPUT "${KOTO_RUST_ARCHIVE}"
  COMMAND "${CMAKE_COMMAND}" -E env ${KOTO_RUST_ENV}
    "${KOTO_CARGO_EXECUTABLE}" build --lib --release --locked
    --manifest-path "${KOTO_ACADRUST_SOURCE}/Cargo.toml"
    --target-dir "${KOTO_TARGET_DIR}" --target "${KOTO_RUST_TARGET}"
  DEPENDS
    "${KOTO_ACADRUST_SOURCE}/Cargo.toml" "${KOTO_ACADRUST_SOURCE}/Cargo.lock"
    "${KOTO_ACADRUST_SOURCE}/src/lib.rs" "${KOTO_ACADRUST_SOURCE}/src/ffi.rs"
    "${KOTO_ACADRUST_SOURCE}/src/reader.rs"
  WORKING_DIRECTORY "${KOTO_ACADRUST_SOURCE}"
  COMMENT "Building acadrust for ${ANDROID_ABI}"
  VERBATIM)
add_custom_target(acadrust_android_build DEPENDS "${KOTO_RUST_ARCHIVE}")
add_library(acadrust_android_static STATIC IMPORTED)
set_target_properties(acadrust_android_static PROPERTIES IMPORTED_LOCATION "${KOTO_RUST_ARCHIVE}")
add_library(koto_acadrust SHARED "${KOTO_REPO_ROOT}/android/app/src/main/cpp/acadrust_jni.c")
add_dependencies(koto_acadrust acadrust_android_build)
target_link_libraries(koto_acadrust PRIVATE acadrust_android_static log m dl)
target_link_options(koto_acadrust PRIVATE "-Wl,-z,max-page-size=16384" "-Wl,--exclude-libs,ALL")
