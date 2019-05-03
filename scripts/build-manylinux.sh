#!/bin/bash

# Create manylinux1 wheels for PyICU
#
# Run this script with something like:
#
# docker run --rm -v `pwd`:/build \
#     --env PYICU_VERSION=2.0.3 --env ICU_VERSION=61_1 \
#     quay.io/pypa/manylinux1_x86_64 linux32 /build/scripts/build-manylinux.sh

set -euo pipefail
set -x

# Ensure cache directory exists
CACHE="/build/.cache"
mkdir -p "${CACHE}"

# Download and unpack icu4c
if [[ ! -f "${CACHE}/icu4c-${ICU_VERSION}-src.tgz" ]]; then
    curl "http://download.icu-project.org/files/icu4c/${ICU_VERSION/_/.}/icu4c-${ICU_VERSION}-src.tgz" \
        > "${CACHE}/icu4c-${ICU_VERSION}-src.tgz"
fi

if [[ ! -f "${CACHE}/icu4c-src-${ICU_VERSION}.md5" ]]; then
    curl "https://ssl.icu-project.org/files/icu4c/${ICU_VERSION/_/.}/icu4c-src-$ICU_VERSION.md5" \
        > "${CACHE}/icu4c-src-${ICU_VERSION}.md5"
fi

(cd "${CACHE}" && grep "icu4c-$ICU_VERSION-src.tgz" "icu4c-src-$ICU_VERSION.md5" | md5sum -c -)
tar -C /root/ -xzf "${CACHE}/icu4c-$ICU_VERSION-src.tgz"

# Build and install icu4c
cd /root/icu/source
./configure

make
make install

# Download PyICU source
if [[ ! -f "${CACHE}/PyICU-${PYICU_VERSION}.tar.gz" ]]; then
    /opt/python/cp36-cp36m/bin/pip download \
        --no-binary=:all: \
        --no-deps \
        --dest "${CACHE}" \
        "PyICU==${PYICU_VERSION}"
fi

tar -C /root/ -xzf "${CACHE}/PyICU-$PYICU_VERSION.tar.gz"

# Replace the package name
sed -i.bak 's/^setup(name="PyICU"/setup(name="PyICU-binary"/' \
    "/root/PyICU-$PYICU_VERSION/setup.py"

# Create the wheel packages
for PYBIN in /opt/python/*/bin; do
    if $("${PYBIN}/python" --version 2>&1  | grep -qE '2\.6|3\.2|3\.3'); then
        "${PYBIN}/pip" install "wheel<0.30"
    fi
    "${PYBIN}/pip" wheel "/root/PyICU-$PYICU_VERSION/" -w /root/wheels/
done

# Bundle external shared libraries into the wheels
mkdir -p /build/dist

for WHL in /root/wheels/*.whl; do
    auditwheel repair "$WHL" -w /build/dist
done
