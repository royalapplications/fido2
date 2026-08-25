#!/usr/bin/env bash

set -e

FIDO2_VERSION_STABLE="1.17.0_cbor-0.14.0_openssl-3.6.4" # https://developers.yubico.com/libfido2/Releases/
MACOS_VERSION_MIN="11.0"
CODESIGN_ID="-"

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
echo "Script Path: ${SCRIPT_PATH}"

BUILD_ROOT_DIR="${SCRIPT_PATH}/../build"
echo "Build Path: ${BUILD_ROOT_DIR}"
mkdir -p "${BUILD_ROOT_DIR}"

if [[ -z $FIDO2_VERSION ]]; then
  echo "FIDO2_VERSION not set; falling back to ${FIDO2_VERSION_STABLE} (Stable)"
  FIDO2_VERSION="${FIDO2_VERSION_STABLE}"
fi

FIDO2_VERSION_FULL="${FIDO2_VERSION}"

if [[ "${FIDO2_VERSION_FULL}" =~ ^([^_]+)_cbor-([^_]+)_openssl-(.*)$ ]]; then
  FIDO2_VERSION_DOWNLOAD="${BASH_REMATCH[1]}"
  CBOR_VERSION="${BASH_REMATCH[2]}"
  OPENSSL_VERSION="${BASH_REMATCH[3]}"
  echo "FIDO2_VERSION extracted: ${FIDO2_VERSION_DOWNLOAD}"
  echo "CBOR_VERSION extracted: ${CBOR_VERSION}"
  echo "OPENSSL_VERSION extracted: ${OPENSSL_VERSION}"
else
  echo "Cannot parse FIDO2_VERSION: ${FIDO2_VERSION_FULL}"
  exit 1
fi

if [[ ! -f "${BUILD_ROOT_DIR}/libfido2-${FIDO2_VERSION_DOWNLOAD}.tar.gz" ]]; then
  echo "Downloading libfido2-${FIDO2_VERSION_DOWNLOAD}.tar.gz"
  curl -fL "https://developers.yubico.com/libfido2/Releases/libfido2-${FIDO2_VERSION_DOWNLOAD}.tar.gz" -o "${BUILD_ROOT_DIR}/libfido2-${FIDO2_VERSION_DOWNLOAD}.tar.gz"
fi

SRC_DIR="${BUILD_ROOT_DIR}/libfido2-src-${FIDO2_VERSION_DOWNLOAD}"
BUILD_DIR="${BUILD_ROOT_DIR}/fido2-build-${FIDO2_VERSION_FULL}"

if [[ ! -d "${SRC_DIR}" ]]; then
  mkdir -p "${SRC_DIR}"
  tar xzf "${BUILD_ROOT_DIR}/libfido2-${FIDO2_VERSION_DOWNLOAD}.tar.gz" -C "${SRC_DIR}" --strip-components=1
fi

if [[ -d "${BUILD_DIR}" ]]; then
  rm -r "${BUILD_DIR}"
fi

mkdir -p "${BUILD_DIR}"

OPENSSL_BASE_DIR="${BUILD_ROOT_DIR}/openssl-${OPENSSL_VERSION}"
CBOR_BASE_DIR="${BUILD_ROOT_DIR}/cbor-${CBOR_VERSION}"

download_dependency() {
  local url="$1"
  local filename="$2"
  local target_dir="$3"
  local fallback_file="$4"

  if [[ -d "${target_dir}" ]]; then
    rm -rf "${target_dir}"
  fi

  mkdir -p "${target_dir}"

  if [[ ! -f "${BUILD_ROOT_DIR}/${filename}" ]]; then
    echo "Downloading ${url}"
    if ! curl -fL "${url}" -o "${BUILD_ROOT_DIR}/${filename}"; then
      if [[ -n "${fallback_file}" && -f "${fallback_file}" ]]; then
        echo "Download failed; using local fallback ${fallback_file}"
        cp "${fallback_file}" "${BUILD_ROOT_DIR}/${filename}"
      else
        echo "Download failed and no local fallback is available"
        exit 1
      fi
    fi
  else
    echo "Using cached ${filename}"
  fi

  echo "Extracting ${filename}"
  tar -xzf "${BUILD_ROOT_DIR}/${filename}" --directory "${target_dir}"
}

download_dependency \
  "https://github.com/royalapplications/openssl/releases/download/${OPENSSL_VERSION}/openssl.tar.gz" \
  "openssl-${OPENSSL_VERSION}.tar.gz" \
  "${OPENSSL_BASE_DIR}" \
  "${SCRIPT_PATH}/../../openssl/build/openssl-${OPENSSL_VERSION}/build/openssl.tar.gz"

download_dependency \
  "https://github.com/royalapplications/cbor/releases/download/${CBOR_VERSION}/cbor.tar.gz" \
  "cbor-${CBOR_VERSION}.tar.gz" \
  "${CBOR_BASE_DIR}" \
  "${SCRIPT_PATH}/../../cbor/build/cbor-build-${CBOR_VERSION}/cbor.tar.gz"

normalize_openssl_include_dir() {
  local include_dir="$1"

  if [[ -d "${include_dir}/OpenSSL" ]]; then
    local temp_dir="${include_dir}/OpenSSL.casefix"

    rm -rf "${temp_dir}"
    mv "${include_dir}/OpenSSL" "${temp_dir}"
    mv "${temp_dir}" "${include_dir}/openssl"
  fi
}

BUILD_DIR_MACOS="${BUILD_DIR}/macosx"

BUILD_DIR_MACOS_TEMP="${BUILD_DIR_MACOS}_temp"

THREAD_COUNT=$(sysctl hw.ncpu | awk '{print $2}')

copy_config() {
  local target_dir="$1"

  cp "${SCRIPT_PATH}/libfido2Config.cmake" "${target_dir}"

  cat > "${target_dir}/libfido2ConfigVersion.cmake" <<EOF
set(PACKAGE_VERSION "${FIDO2_VERSION_DOWNLOAD}")

if(PACKAGE_VERSION VERSION_LESS PACKAGE_FIND_VERSION)
  set(PACKAGE_VERSION_COMPATIBLE FALSE)
else()
  set(PACKAGE_VERSION_COMPATIBLE TRUE)

  if(PACKAGE_VERSION VERSION_EQUAL PACKAGE_FIND_VERSION)
    set(PACKAGE_VERSION_EXACT TRUE)
  endif()
endif()
EOF

  cat >> "${target_dir}/libfido2Config.cmake" <<EOF

set(LIBFIDO2_VERSION "${FIDO2_VERSION_DOWNLOAD}")
EOF
}

create_pkg_config_files() {
  local os="$1"
  local target_dir="$2"
  local sdk_root="$3"

  local pkg_config_dir="${target_dir}/pkgconfig"
  local cbor_dir="${CBOR_BASE_DIR}/${os}"
  local openssl_dir="${OPENSSL_BASE_DIR}/${os}"

  mkdir -p "${pkg_config_dir}"
  normalize_openssl_include_dir "${openssl_dir}/include"

  cat > "${pkg_config_dir}/libcbor.pc" <<EOF
prefix=${cbor_dir}
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: libcbor
Description: CBOR protocol implementation for C
Version: ${CBOR_VERSION}
Libs: -L\${libdir} -lcbor
Cflags: -I\${includedir}
EOF

  cat > "${pkg_config_dir}/libcrypto.pc" <<EOF
prefix=${openssl_dir}
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: libcrypto
Description: OpenSSL cryptography library
Version: ${OPENSSL_VERSION}
Libs: -L\${libdir} -lcrypto
Cflags: -I\${includedir}
EOF

  cat > "${pkg_config_dir}/zlib.pc" <<EOF
prefix=${sdk_root}/usr
exec_prefix=\${prefix}
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: zlib
Description: zlib compression library
Version: 1.2.12
Libs: -lz
Cflags: -I\${includedir}
EOF

  echo "${pkg_config_dir}"
}

build() {
  local os="$1"
  local target_dir="$2"
  local temp_dir="$3"
  local sdk="$4"
  local system_name="$5"
  local archs="$6"
  local deployment_flags="$7"

  echo "Building for ${os}"

  mkdir -p "${temp_dir}"

  pushd "${temp_dir}"

  local sdk_root=$(xcrun --sdk "${sdk}" --show-sdk-path)
  local cbor_dir="${CBOR_BASE_DIR}/${os}"
  local openssl_dir="${OPENSSL_BASE_DIR}/${os}"
  local pkg_config_dir=$(create_pkg_config_files "${os}" "${temp_dir}" "${sdk_root}")

  # Keep libfido2 on its Apple byte-order compatibility path.
  PKG_CONFIG_LIBDIR="${pkg_config_dir}" cmake "${SRC_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=Off \
    -DBUILD_STATIC_LIBS=On \
    -DBUILD_TESTS=Off \
    -DBUILD_EXAMPLES=Off \
    -DBUILD_MANPAGES=Off \
    -DBUILD_TOOLS=Off \
    -DUSE_HIDAPI=Off \
    -DUSE_PCSC=Off \
    -DNFC_LINUX=Off \
    -DCMAKE_INSTALL_PREFIX="${target_dir}" \
    -DCMAKE_OSX_ARCHITECTURES="${archs}" \
    -DCMAKE_SYSROOT="${sdk_root}" \
    -DCMAKE_SYSTEM_NAME="${system_name}" \
    -DCMAKE_C_FLAGS="${deployment_flags}" \
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DHAVE_ENDIAN_H=Off \
    -DCBOR_INCLUDE_DIRS="${cbor_dir}/include" \
    -DCBOR_LIBRARY_DIRS="${cbor_dir}/lib" \
    -DCBOR_LIBRARIES="cbor" \
    -DCRYPTO_INCLUDE_DIRS="${openssl_dir}/include" \
    -DCRYPTO_LIBRARY_DIRS="${openssl_dir}/lib" \
    -DCRYPTO_LIBRARIES="crypto" \
    -DZLIB_LIBRARIES="z"

  cmake --build . --config Release --parallel "${THREAD_COUNT}"
  cmake --install . --config Release

  copy_config "${target_dir}"

  popd
}

build \
  "macosx" \
  "${BUILD_DIR_MACOS}" \
  "${BUILD_DIR_MACOS_TEMP}" \
  "macosx" \
  "Darwin" \
  "arm64;x86_64" \
  "-mmacosx-version-min=${MACOS_VERSION_MIN}"

if [[ ! -d "${BUILD_DIR}/FIDO2.xcframework" ]]; then
  xcodebuild -create-xcframework \
    -library "${BUILD_DIR_MACOS}/lib/libfido2.a" \
    -output "${BUILD_DIR}/FIDO2.xcframework"

  codesign \
    --force --deep --strict \
    --sign "${CODESIGN_ID}" \
    "${BUILD_DIR}/FIDO2.xcframework"
fi
