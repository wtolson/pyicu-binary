#!/bin/bash

set -euo pipefail
set -x

PYTHON_BIN=/opt/python/cp39-cp39/bin
BUILD_DIR="${PWD}/build"

# Setup build dir
mkdir -p "${BUILD_DIR}"

# Download icu4c
curl -L "https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION/_/-}/icu4c-${ICU_VERSION}-src.tgz" \
    > "${BUILD_DIR}/icu4c-${ICU_VERSION}-src.tgz"

curl -L "https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION/_/-}/icu4c-${ICU_VERSION}-src.tgz.asc" \
    > "${BUILD_DIR}/icu4c-${ICU_VERSION}-src.tgz.asc"

# Verify
gpg --import KEYS
gpg --verify "${BUILD_DIR}/icu4c-${ICU_VERSION}-src.tgz.asc" "${BUILD_DIR}/icu4c-${ICU_VERSION}-src.tgz"

# Unpack
tar -C "${BUILD_DIR}/" -xzf "${BUILD_DIR}/icu4c-$ICU_VERSION-src.tgz"

# Build and install icu4c
(cd "${BUILD_DIR}/icu/source" && PATH=$PYTHON_BIN:$PATH ./runConfigureICU Linux)
(cd "${BUILD_DIR}/icu/source" && make)
(cd "${BUILD_DIR}/icu/source" && make install)
