#!/bin/sh
# Build libldclint.so (release + debug) for a single LDC version.
# Invoked from per-version stages in the Dockerfile.
#
# Usage: docker-build-one.sh <ldc-version> <github-repo> <output-dir>
#
# Example:
#   docker-build-one.sh 1.42.0 ldc-developers/ldc /output

set -eu

VERSION=${1:?ldc version required}
REPO=${2:?github repo (owner/name) required}
OUT=${3:?output directory required}

LDCLINT=${LDCLINT:-/work/ldclint}
ARCH=$(uname -m)

mkdir -p "$OUT"

# Download the upstream "linux-${ARCH}" tarball — the glibc-targeted build
# that runs natively on the debian base. We don't try the alpine (musl)
# variants here because they wouldn't run on glibc.
download_ldc() {
    _dest=$1
    _url="https://github.com/${REPO}/releases/download/v${VERSION}/ldc2-${VERSION}-linux-${ARCH}.tar.xz"
    if ! curl -fsLI "$_url" >/dev/null 2>&1; then
        echo "ERROR: no linux-${ARCH} tarball for ${VERSION} at ${_url}" >&2
        return 1
    fi
    echo "  -> downloading $_url"
    mkdir -p "$_dest"
    curl -fsL "$_url" | tar -xJ -C "$_dest" --strip-components=1
}

bin_dir=/tmp/ldc
src_dir=/tmp/ldc-src

echo "============================================================"
echo " Building ldclint for LDC ${VERSION} (${REPO})"
echo "============================================================"

download_ldc "$bin_dir"

# The Makefile imports DMD frontend modules and druntime/phobos sources from
# LDC2_SRC, so the source tree must match the binary version exactly.
git clone --depth=1 --branch "v${VERSION}" --recurse-submodules \
    "https://github.com/${REPO}.git" "$src_dir"

cd "$LDCLINT"

# Release + tests
make clean
PATH="${bin_dir}/bin:$PATH" \
    make build test LDC2_SRC="$src_dir" DEBUG=0
cp builddir/out/libldclint.so "${OUT}/libldclint.${VERSION}.so"

# Debug (same logic, -g -O0 -debug; tests would be redundant)
make clean
PATH="${bin_dir}/bin:$PATH" \
    make build test LDC2_SRC="$src_dir" DEBUG=1
cp builddir/out/libldclint.so "${OUT}/libldclint-debug.${VERSION}.so"

echo "  -> wrote ${OUT}/libldclint.${VERSION}.so"
echo "  -> wrote ${OUT}/libldclint-debug.${VERSION}.so"
