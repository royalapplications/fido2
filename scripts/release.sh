#!/usr/bin/env bash

set -e

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
echo "Script Path: ${SCRIPT_PATH}"

if [[ -z $FIDO2_VERSION ]]; then
  echo "FIDO2_VERSION not set; aborting"
  exit 1
fi

BUILD_DIR="${SCRIPT_PATH}/../build/fido2-build-${FIDO2_VERSION}"
echo "Build Path: ${BUILD_DIR}"

if [[ ! -d "${BUILD_DIR}" ]]; then
  echo "Build dir not found: ${BUILD_DIR}"
  exit 1
fi

pushd "${BUILD_DIR}"

echo "Creating ${BUILD_DIR}/fido2.tar.gz"
rm -f "fido2.tar.gz"
tar czf "fido2.tar.gz" macosx

echo "Creating ${BUILD_DIR}/FIDO2.xcframework.tar.gz"
rm -f "FIDO2.xcframework.tar.gz"
tar czf "FIDO2.xcframework.tar.gz" FIDO2.xcframework

popd
