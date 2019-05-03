#!/bin/bash

set -euo pipefail
set -x

if [[ $(uname -s) != "Darwin" ]]; then
    echo >&2 "OS X is required to build macosx wheels."
    exit 1
fi

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

# Download and unpack icu4c
if [[ ! -f "${CACHE}/icu4c-${ICU_VERSION}-src.tgz" ]]; then
    curl "http://download.icu-project.org/files/icu4c/${ICU_VERSION/_/.}/icu4c-${ICU_VERSION}-src.tgz" \
        > "${CACHE}/icu4c-${ICU_VERSION}-src.tgz"
fi

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
sed -i.bak 's/^setup(name="PyICU"/setup(name="PyICU-binary"/' \
    "${VENV}/src/PyICU-${PYICU_VERSION}/setup.py"

# Build the macosx wheels
PYVERSIONS="2.7 3.4 3.5 3.6 3.7"
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
    -x 10_9 -x 10_10 -x 10_11 -x 10_12 \
    ${VENV}/wheels/PyICU_binary-*.whl

# Copy the finished wheels into dist
mkdir -p dist
cp ${VENV}/wheels/PyICU_binary-*.whl dist/
