# Windows uses a child process; Android uses the shared Rust core through JNI.
option(KOTO_BUILD_ACADRUST "Build and bundle the acadrust DWG converter" ON)
if(NOT KOTO_BUILD_ACADRUST)
  return()
endif()

set(KOTO_ACADRUST_SOURCE "${CMAKE_CURRENT_LIST_DIR}")
get_filename_component(KOTO_REPO_ROOT "${KOTO_ACADRUST_SOURCE}/../.." ABSOLUTE)
set(KOTO_LOCAL_RUST "${KOTO_REPO_ROOT}/build/acadrust-toolchain")
find_program(KOTO_CARGO_EXECUTABLE cargo HINTS
  "$ENV{USERPROFILE}/.cargo/bin"
  "${KOTO_LOCAL_RUST}/cargo/bin")
if(NOT KOTO_CARGO_EXECUTABLE)
  message(WARNING "Rust/Cargo not found: direct DWG opening unavailable. Install Rust to bundle acadrust.")
  return()
endif()

if(CMAKE_GENERATOR_PLATFORM STREQUAL "ARM64")
  set(KOTO_RUST_TARGET "aarch64-pc-windows-msvc")
else()
  set(KOTO_RUST_TARGET "x86_64-pc-windows-msvc")
endif()
set(KOTO_ACADRUST_TARGET_DIR "${KOTO_REPO_ROOT}/build/acadrust")
set(KOTO_ACADRUST_EXE
  "${KOTO_ACADRUST_TARGET_DIR}/${KOTO_RUST_TARGET}/release/koto-acadrust.exe")
set(KOTO_RUST_ENV)
if(KOTO_CARGO_EXECUTABLE STREQUAL "${KOTO_LOCAL_RUST}/cargo/bin/cargo.exe")
  list(APPEND KOTO_RUST_ENV
    "CARGO_HOME=${KOTO_LOCAL_RUST}/cargo"
    "RUSTUP_HOME=${KOTO_LOCAL_RUST}/rustup"
    "RUSTC=${KOTO_LOCAL_RUST}/cargo/bin/rustc.exe")
endif()

add_custom_command(OUTPUT "${KOTO_ACADRUST_EXE}"
  COMMAND "${CMAKE_COMMAND}" -E env ${KOTO_RUST_ENV}
    "${KOTO_CARGO_EXECUTABLE}" build --release --locked
    --manifest-path "${KOTO_ACADRUST_SOURCE}/Cargo.toml"
    --target-dir "${KOTO_ACADRUST_TARGET_DIR}" --target "${KOTO_RUST_TARGET}"
  DEPENDS
    "${KOTO_ACADRUST_SOURCE}/Cargo.toml"
    "${KOTO_ACADRUST_SOURCE}/Cargo.lock"
    "${KOTO_ACADRUST_SOURCE}/src/main.rs"
    "${KOTO_ACADRUST_SOURCE}/src/lib.rs"
    "${KOTO_ACADRUST_SOURCE}/src/ffi.rs"
    "${KOTO_ACADRUST_SOURCE}/src/reader.rs"
    "${KOTO_ACADRUST_SOURCE}/src/writer.rs"
  WORKING_DIRECTORY "${KOTO_ACADRUST_SOURCE}"
  COMMENT "Building acadrust DWG converter"
  VERBATIM)
add_custom_target(koto_acadrust DEPENDS "${KOTO_ACADRUST_EXE}")
add_dependencies(${BINARY_NAME} koto_acadrust)

install(PROGRAMS "${KOTO_ACADRUST_EXE}"
  DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
install(DIRECTORY "${KOTO_ACADRUST_SOURCE}/licenses/"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}/licenses/acadrust" COMPONENT Runtime)
