#!/bin/bash

set -euo pipefail
set -x

PYTHON_BIN=/opt/python/cp39-cp39/bin
BUILD_DIR="${PWD}/build"

# Download icu4c
curl -L "https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION/_/-}/icu4c-${ICU_VERSION}-src.tgz" \
    > "${BUILD_DIR}/icu4c-${ICU_VERSION}-src.tgz"

curl -L "https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION/_/-}/icu4c-${ICU_VERSION}-src.tgz.asc" \
    > "${BUILD_DIR}/icu4c-${ICU_VERSION}-src.tgz.asc"

# Verify
gpg --import /build/KEYS
gpg --verify "${BUILD_DIR}/icu4c-${ICU_VERSION}-src.tgz.asc" "${BUILD_DIR}/icu4c-${ICU_VERSION}-src.tgz"

# Unpack
tar -C "${BUILD_DIR}/" -xzf "${BUILD_DIR}/icu4c-$ICU_VERSION-src.tgz"

# Build icu4c
(cd "${BUILD_DIR}/icu/source" && \
    ./runConfigureICU MacOSX --prefix="${BUILD_DIR}" --enable-static --disable-shared)
(cd "${BUILD_DIR}/icu/source" && make)
(cd "${BUILD_DIR}/icu/source" && make install)

# Download PyICU source
$PYTHON_BIN/pip download \
    --no-binary=:all: \
    --no-deps \
    --dest "${BUILD_DIR}" \
    "PyICU==${PYICU_VERSION}"

tar -C "${BUILD_DIR}/" -xmzf "${BUILD_DIR}/PyICU-$PYICU_VERSION.tar.gz"

# Replace the package name
patch --verbose -p1 -d "${BUILD_DIR}/PyICU-$PYICU_VERSION" < pyicu.patch
