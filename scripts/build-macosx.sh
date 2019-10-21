#!/bin/bash

set -euo pipefail
set -x

if [[ $(uname -s) != "Darwin" ]]; then
    echo >&2 "OS X is required to build macosx wheels."
    exit 1
fi

DIST="$(pwd)/dist"

# Ensure cache directory exists
CACHE="$(pwd)/.cache"
mkdir -p "${CACHE}"

# Cleanup previous virutalenvs
VENV="$(pwd)/.venv"
rm -rf "${VENV}"

# Make our working virtualenv
virtualenv "${VENV}"

mkdir "${VENV}/src"
mkdir "${VENV}/wheels"

PS1=${PS1:-} source "${VENV}/bin/activate"
pip install -U pip wheel delocate twine

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
gpg --import KEYS
gpg --verify "${CACHE}/icu4c-${ICU_VERSION}-src.tgz.asc" "${CACHE}/icu4c-${ICU_VERSION}-src.tgz"

# Unpack
tar -C "${VENV}/src/" -xzf "${CACHE}/icu4c-${ICU_VERSION}-src.tgz"

# Build icu4c
(cd "${VENV}/src/icu/source" && \
    ./configure --prefix="${VENV}" --enable-static --disable-shared)
(cd "${VENV}/src/icu/source" && make)
(cd "${VENV}/src/icu/source" && make install)

# Download PyICU source
if [[ ! -f "${CACHE}/PyICU-${PYICU_VERSION}.tar.gz" ]]; then
    pip download \
        --no-binary=:all: \
        --no-deps \
        --dest "${CACHE}" \
        "PyICU==${PYICU_VERSION}"
fi

tar -C ${VENV}/src/ -xzf "${CACHE}/PyICU-${PYICU_VERSION}.tar.gz"

# Replace the package name
patch --verbose -p1 -d "${VENV}/src/PyICU-${PYICU_VERSION}" < pyicu.patch

# Build the macosx wheels
PYVERSIONS="2.7 3.5 3.6 3.7 3.8"
LFLAGS="${VENV}/lib/libicui18n.a:${VENV}/lib/libicuuc.a:${VENV}/lib/libicudata.a"

for PYVER in $PYVERSIONS; do
    virtualenv -p "python${PYVER}" "${VENV}/cp-${PYVER}"

    "${VENV}/cp-${PYVER}/bin/pip" install -U pip wheel

    PYICU_LFLAGS="${LFLAGS}" "${VENV}/cp-${PYVER}/bin/pip" wheel \
        -w "${VENV}/wheels" \
        "${VENV}/src/PyICU-${PYICU_VERSION}"
done

# Patch any remaning shared libraries
delocate-wheel -v ${VENV}/wheels/PyICU_binary-*.whl

delocate-addplat \
    --rm-orig \
    -x 10_9 -x 10_10 \
    ${VENV}/wheels/PyICU_binary-*.whl

# Copy the finished wheels into dist
mkdir -p "${DIST}"
cp ${VENV}/wheels/PyICU_binary-*.whl "${DIST}/"

# Make a source dist
(cd "${VENV}/src/PyICU-${PYICU_VERSION}" && \
    python setup.py sdist --dist-dir "${DIST}")
