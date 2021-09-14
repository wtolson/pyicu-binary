#!/bin/bash

# Create manylinux wheels for PyICU
#
# Run this script with something like:
#
# docker run --rm -v `pwd`:/build \
#     --env PYICU_VERSION=2.0.3 --env ICU_VERSION=61_1 \
#     quay.io/pypa/manylinux_2_24_x86_64 /build/scripts/build-manylinux.sh

set -euo pipefail
set -x

# Ensure cache directory exists
CACHE="/build/.cache"
mkdir -p "${CACHE}"

# Download icu4c
if [[ ! -f "${CACHE}/icu4c-${ICU_VERSION}-src.tgz" ]]; then
    curl -L "https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION/_/-}/icu4c-${ICU_VERSION}-src.tgz" \
        > "${CACHE}/icu4c-${ICU_VERSION}-src.tgz"
fi

if [[ ! -f "${CACHE}/icu4c-${ICU_VERSION}-src.tgz.asc" ]]; then
    curl -L "https://github.com/unicode-org/icu/releases/download/release-${ICU_VERSION/_/-}/icu4c-${ICU_VERSION}-src.tgz.asc" \
        > "${CACHE}/icu4c-${ICU_VERSION}-src.tgz.asc"
fi

# Verify
gpg --import /build/KEYS
gpg --verify "${CACHE}/icu4c-${ICU_VERSION}-src.tgz.asc" "${CACHE}/icu4c-${ICU_VERSION}-src.tgz"

# Unpack
tar -C /root/ -xzf "${CACHE}/icu4c-$ICU_VERSION-src.tgz"

# Build and install icu4c
cd /root/icu/source
PATH=/opt/python/cp39-cp39/bin:$PATH ./runConfigureICU Linux

make
make install

# Download PyICU source
if [[ ! -f "${CACHE}/PyICU-${PYICU_VERSION}.tar.gz" ]]; then
    /opt/python/cp39-cp39/bin/pip download \
        --no-binary=:all: \
        --no-deps \
        --dest "${CACHE}" \
        "PyICU==${PYICU_VERSION}"
fi

tar -C /root/ -xmzf "${CACHE}/PyICU-$PYICU_VERSION.tar.gz"

# Replace the package name
patch --verbose -p1 -d "/root/PyICU-$PYICU_VERSION" < /build/pyicu.patch

# Create the wheel packages
for PYBIN in /opt/python/*/bin; do
    "${PYBIN}/pip" wheel "/root/PyICU-$PYICU_VERSION/" -w /root/wheels/
done

# Bundle external shared libraries into the wheels
mkdir -p /build/dist

for WHL in /root/wheels/*.whl; do
    auditwheel repair "$WHL" -w /build/dist
done
