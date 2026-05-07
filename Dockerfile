# Multi-stage build: each supported LDC version gets its own builder stage
# `FROM base`, so BuildKit can run them in parallel and cache each one
# independently. Touching the ldclint source busts every per-version stage;
# bumping a single LDC version only busts that one.
#
#   docker build -t ldclint .
#   docker create --name x ldclint && docker cp x:/. ./out && docker rm x
#
# Tests run inside every release stage; build fails if any version's tests do.

# ---------- base ----------
# Common build environment shared by every per-version stage. Built once.
#
# Why glibc (debian) instead of musl (alpine):
# - LDC's "linux" prebuilt tarballs are dynamically linked against glibc,
#   libxml2 and FORTIFY symbols. On Alpine they need a stack of compat
#   shims (gcompat + libc6-compat) and still miss libxml2 + __*_chk symbols
#   for several LDC versions.
# - LDC ships musl-native "alpine" tarballs only for 1.40.1+ on x86_64 and
#   only 1.42 on aarch64; weka builds publish neither.
# Glibc base lets every published "linux-${ARCH}" tarball run unmodified.
#
# The `--platform=$TARGETPLATFORM` declaration here lets BuildKit re-resolve
# this stage for amd64 when a downstream `--platform=linux/amd64 base-amd64`
# stage forces emulation (used for weka builds — see below).
FROM debian:bookworm-slim AS base

ENV DEBIAN_FRONTEND=noninteractive

# - llvm-14-tools: provides FileCheck for the lit suite (symlinked to PATH).
# - python3-venv: required for `python3 -m venv` (the Makefile's venv target).
# - binutils / gcc / libc6-dev: linker, headers, strip.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        bash \
        binutils \
        ca-certificates \
        curl \
        gcc \
        git \
        libc6-dev \
        llvm-14-tools \
        make \
        python3 \
        python3-pip \
        python3-venv \
        xz-utils \
 && ln -sf /usr/lib/llvm-14/bin/FileCheck /usr/local/bin/FileCheck \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /work
COPY . /work/ldclint

RUN test -f /work/ldclint/libdparse/src/dparse/parser.d \
 || (echo "ERROR: libdparse submodule is not populated; run 'git submodule update --init --recursive' on the host before docker build" >&2 && exit 1)

# ---------- amd64-pinned base ----------
# weka/ldc only publishes linux-x86_64 tarballs (no aarch64 release artifacts),
# so on non-x86 hosts those builds have to run under emulation. BuildKit only
# applies `--platform` when the FROM target is a top-level image (not another
# stage), so we duplicate the base here from the same image but pinned. On
# x86_64 hosts this is essentially the same image; on aarch64 hosts BuildKit
# pulls debian:bookworm-slim for amd64 and runs the steps via qemu emulation.
FROM --platform=linux/amd64 debian:bookworm-slim AS base-amd64

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        bash \
        binutils \
        ca-certificates \
        curl \
        gcc \
        git \
        libc6-dev \
        llvm-14-tools \
        make \
        python3 \
        python3-pip \
        python3-venv \
        xz-utils \
 && ln -sf /usr/lib/llvm-14/bin/FileCheck /usr/local/bin/FileCheck \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /work
COPY . /work/ldclint

RUN test -f /work/ldclint/libdparse/src/dparse/parser.d \
 || (echo "ERROR: libdparse submodule is not populated; run 'git submodule update --init --recursive' on the host before docker build" >&2 && exit 1)

# ---------- per-version builder stages ----------
# Each stage downloads a single LDC tarball, clones the matching source tree,
# runs `make test` (release) and `make build` (debug), and writes the two
# resulting .so files to /output. BuildKit parallelises these.

FROM base AS build-1.42.0
RUN /work/ldclint/scripts/docker-build-one.sh 1.42.0 ldc-developers/ldc /output

FROM base AS build-1.41.0
RUN /work/ldclint/scripts/docker-build-one.sh 1.41.0 ldc-developers/ldc /output

FROM base AS build-1.40.1
RUN /work/ldclint/scripts/docker-build-one.sh 1.40.1 ldc-developers/ldc /output

FROM base AS build-1.39.0
RUN /work/ldclint/scripts/docker-build-one.sh 1.39.0 ldc-developers/ldc /output

FROM base AS build-1.38.0
RUN /work/ldclint/scripts/docker-build-one.sh 1.38.0 ldc-developers/ldc /output

# weka/ldc only publishes linux-x86_64 tarballs (no aarch64 release artifacts).
# The amd64-pinned base ensures `uname -m` reports x86_64 inside these stages,
# so the script picks the right tarball and the binary runs natively (or via
# qemu emulation on aarch64 hosts).
FROM base-amd64 AS build-1.38.0-weka11
RUN /work/ldclint/scripts/docker-build-one.sh 1.38.0-weka11 weka/ldc /output

FROM base-amd64 AS build-1.38.0-weka10
RUN /work/ldclint/scripts/docker-build-one.sh 1.38.0-weka10 weka/ldc /output

# ---------- collector ----------
# Merges every per-version /output into a single tree and creates the
# `libldclint.so -> latest-upstream` symlink. Needs a shell.
FROM debian:bookworm-slim AS collector
WORKDIR /out
COPY --from=build-1.42.0        /output/ /out/
COPY --from=build-1.41.0        /output/ /out/
COPY --from=build-1.40.1        /output/ /out/
COPY --from=build-1.39.0        /output/ /out/
COPY --from=build-1.38.0        /output/ /out/
COPY --from=build-1.38.0-weka11 /output/ /out/
COPY --from=build-1.38.0-weka10 /output/ /out/

# Pick the highest semver-sorted upstream release (weka tags excluded by name).
RUN cd /out \
 && latest=$(ls libldclint.[0-9]*.so | grep -v -- '-weka' | sort -V | tail -1) \
 && ln -sf "$latest" libldclint.so

# ---------- final ----------
FROM scratch
COPY --from=collector /out/ /
