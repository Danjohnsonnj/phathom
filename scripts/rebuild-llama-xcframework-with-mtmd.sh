#!/usr/bin/env bash
# Rebuilds llama.xcframework with libmtmd (multimodal) linked into the combined static library.
# Requires: cmake, xcrun, llama.cpp at ~/Local Documents/repos/llama.cpp
# Output: Phathom/vendor/llama/llama.xcframework
# After install: bash scripts/build-phathom.sh all
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEST_XCFRAMEWORK="${REPO_ROOT}/Phathom/vendor/llama/llama.xcframework"

LLAMA_CPP_DIR="${HOME}/Local Documents/repos/llama.cpp"
BUILD_SIM_DIR="${LLAMA_CPP_DIR}/build-ios-sim-mtmd"
BUILD_DEVICE_DIR="${LLAMA_CPP_DIR}/build-ios-device-mtmd"
BUILD_ARTIFACT_DIR="${LLAMA_CPP_DIR}/build-apple-ios-mtmd"
HEADERS_DIR="${BUILD_ARTIFACT_DIR}/Headers"
SIM_COMBINED_LIB="${BUILD_SIM_DIR}/llama-ios-sim-mtmd.a"
DEVICE_COMBINED_LIB="${BUILD_DEVICE_DIR}/llama-ios-device-mtmd.a"

# Match intrai-llama / Phathom simulator baseline where possible.
IOS_MIN_OS_VERSION="${IOS_MIN_OS_VERSION:-18.0}"

if [ ! -d "${LLAMA_CPP_DIR}" ]; then
  echo "Missing llama.cpp at: ${LLAMA_CPP_DIR}"
  exit 1
fi

COMMON_CMAKE_ARGS=(
  -DBUILD_SHARED_LIBS=OFF
  -DLLAMA_BUILD_COMMON=ON
  -DLLAMA_BUILD_EXAMPLES=OFF
  -DLLAMA_BUILD_TESTS=OFF
  -DLLAMA_BUILD_SERVER=OFF
  -DLLAMA_BUILD_TOOLS=ON
  -DGGML_NATIVE=OFF
  -DGGML_METAL=ON
  -DGGML_METAL_EMBED_LIBRARY=ON
  -DGGML_BLAS_DEFAULT=ON
  -DGGML_OPENMP=OFF
)

configure_and_build() {
  local build_dir="$1"
  local sysroot="$2"
  echo "Configuring ${build_dir} (${sysroot})..."
  cmake -B "${build_dir}" -G Xcode \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="${sysroot}" \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="${IOS_MIN_OS_VERSION}" \
    "${COMMON_CMAKE_ARGS[@]}"
  echo "Building mtmd + deps in ${build_dir}..."
  cmake --build "${build_dir}" --config Release --target mtmd -- -quiet
}

combine_mtmd_libs() {
  local build_dir="$1"
  local output_lib="$2"
  local release_dir="$3"

  local -a libs=()
  local candidates=(
    "${build_dir}/src/${release_dir}/libllama.a"
    "${build_dir}/ggml/src/${release_dir}/libggml.a"
    "${build_dir}/ggml/src/${release_dir}/libggml-base.a"
    "${build_dir}/ggml/src/${release_dir}/libggml-cpu.a"
    "${build_dir}/ggml/src/ggml-metal/${release_dir}/libggml-metal.a"
    "${build_dir}/ggml/src/ggml-blas/${release_dir}/libggml-blas.a"
    "${build_dir}/tools/mtmd/${release_dir}/libmtmd.a"
  )
  for lib in "${candidates[@]}"; do
    if [ -f "${lib}" ]; then
      libs+=("${lib}")
    else
      echo "Warning: missing ${lib}"
    fi
  done
  if [ "${#libs[@]}" -eq 0 ]; then
    echo "No libraries to combine in ${build_dir}"
    exit 1
  fi
  xcrun libtool -static "${libs[@]}" -o "${output_lib}"
  echo "Combined ${#libs[@]} archives -> ${output_lib}"
}

cd "${LLAMA_CPP_DIR}"
rm -rf "${BUILD_SIM_DIR}" "${BUILD_DEVICE_DIR}" "${BUILD_ARTIFACT_DIR}"
mkdir -p "${BUILD_ARTIFACT_DIR}" "${HEADERS_DIR}"

configure_and_build "${BUILD_SIM_DIR}" iphonesimulator
configure_and_build "${BUILD_DEVICE_DIR}" iphoneos

combine_mtmd_libs "${BUILD_SIM_DIR}" "${SIM_COMBINED_LIB}" "Release-iphonesimulator"
combine_mtmd_libs "${BUILD_DEVICE_DIR}" "${DEVICE_COMBINED_LIB}" "Release-iphoneos"

REQUIRED_HEADERS=(
  "include/llama.h"
  "ggml/include/ggml.h"
  "ggml/include/ggml-alloc.h"
  "ggml/include/ggml-backend.h"
  "ggml/include/ggml-blas.h"
  "ggml/include/ggml-cpu.h"
  "ggml/include/ggml-metal.h"
  "ggml/include/ggml-opt.h"
  "ggml/include/gguf.h"
  "tools/mtmd/mtmd.h"
  "tools/mtmd/mtmd-helper.h"
)

for header in "${REQUIRED_HEADERS[@]}"; do
  if [ -f "${header}" ]; then
    cp "${header}" "${HEADERS_DIR}/"
  else
    echo "Error: expected header not found: ${header}"
    exit 1
  fi
done

cat > "${HEADERS_DIR}/module.modulemap" << 'MODULEMAP'
module llama {
    header "llama.h"
    header "ggml.h"
    header "ggml-alloc.h"
    header "ggml-backend.h"
    header "ggml-metal.h"
    header "ggml-cpu.h"
    header "ggml-blas.h"
    header "gguf.h"
    header "mtmd.h"
    header "mtmd-helper.h"

    link "c++"
    link framework "Accelerate"
    link framework "Metal"
    link framework "Foundation"

    export *
}
MODULEMAP

xcrun xcodebuild -create-xcframework \
  -library "${DEVICE_COMBINED_LIB}" -headers "${HEADERS_DIR}" \
  -library "${SIM_COMBINED_LIB}" -headers "${HEADERS_DIR}" \
  -output "${BUILD_ARTIFACT_DIR}/llama.xcframework"

mkdir -p "$(dirname "${DEST_XCFRAMEWORK}")"
rm -rf "${DEST_XCFRAMEWORK}"
cp -R "${BUILD_ARTIFACT_DIR}/llama.xcframework" "${DEST_XCFRAMEWORK}"
echo "Installed ${DEST_XCFRAMEWORK} (with mtmd)"
