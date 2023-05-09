# syntax=docker/dockerfile:1

ARG ZIG_VERSION="0.10.1"
ARG XX_VERSION="1.2.1"
ARG ALPINE_VERSION="3.17"

ARG MCPU="baseline"

FROM --platform=${BUILDPLATFORM} alpine:${ALPINE_VERSION} AS src
RUN apk add --update git
WORKDIR /src
RUN git init . && git remote add origin "https://github.com/ziglang/zig-bootstrap.git"
ARG ZIG_VERSION
RUN git fetch origin "${ZIG_VERSION}" && git checkout -q FETCH_HEAD

FROM --platform=${BUILDPLATFORM:-linux/amd64} tonistiigi/xx:${XX_VERSION} AS xx
FROM --platform=${BUILDPLATFORM:-linux/amd64} alpine:${ALPINE_VERSION} AS base
COPY --from=xx / /
RUN apk add --update --no-cache \
    binutils \
    clang \
    cmake \
    file \
    gcc \
    git \
    linux-headers \
    make \
    musl-dev \
    patch \
    pkgconf \
    python3 \
    tree

FROM base AS build-base
COPY --from=src /src /src
WORKDIR /src
COPY rootfs/src/.vars /src/

FROM build-base AS build-host
COPY rootfs/src/build-host-* /src/
ARG ZIG_VERSION
ARG MCPU
ARG NPROC
RUN CMAKE_BUILD_PARALLEL_LEVEL=${NPROC:-$(nproc)} ./build-host-zlib
RUN CMAKE_BUILD_PARALLEL_LEVEL=${NPROC:-$(nproc)} ./build-host-llvm
RUN CMAKE_BUILD_PARALLEL_LEVEL=${NPROC:-$(nproc)} ./build-host-zig
# FIXME: mounts cache are not exported
#RUN --mount=type=cache,target=/out/base/zlib-host \
#    CMAKE_BUILD_PARALLEL_LEVEL=${NPROC:-$(nproc)} ./build-host-zlib
#RUN --mount=type=cache,target=/out/base/zlib-host \
#    --mount=type=cache,target=/out/base/llvm-host \
#    CMAKE_BUILD_PARALLEL_LEVEL=${NPROC:-$(nproc)} ./build-host-llvm
#RUN --mount=type=cache,target=/out/base/zlib-host \
#    --mount=type=cache,target=/out/base/llvm-host \
#    --mount=type=cache,target=/out/base/zig-host \
#    CMAKE_BUILD_PARALLEL_LEVEL=${NPROC:-$(nproc)} ./build-host-zig

FROM build-base AS build
COPY --from=build-host /out /out
COPY rootfs/src/build-cross-* /src/
ARG ZIG_VERSION
ARG MCPU
ARG NPROC
ARG TARGETPLATFORM
RUN CMAKE_BUILD_PARALLEL_LEVEL=${NPROC:-$(nproc)} ./build-cross-zlib
RUN CMAKE_BUILD_PARALLEL_LEVEL=${NPROC:-$(nproc)} ./build-cross-zstd
RUN CMAKE_BUILD_PARALLEL_LEVEL=${NPROC:-$(nproc)} ./build-cross-llvm
RUN CMAKE_BUILD_PARALLEL_LEVEL=${NPROC:-$(nproc)} ./build-cross-zig && \
    xx-verify --static /out/zig/bin/zig$([ "$(xx-info os)" = "windows" ] && echo ".exe")
# FIXME: mounts cache are not exported
#RUN --mount=type=cache,target=/out/base/zlib-host \
#    --mount=type=cache,target=/out/base/llvm-host \
#    --mount=type=cache,target=/out/base/zig-host \
#    --mount=type=cache,target=/out/base/zlib,id=zlib-$TARGETPLATFORM \
#    CMAKE_BUILD_PARALLEL_LEVEL=${NPROC:-$(nproc)} ./build-cross-zlib
#RUN --mount=type=cache,target=/out/base/zlib-host \
#    --mount=type=cache,target=/out/base/llvm-host \
#    --mount=type=cache,target=/out/base/zig-host \
#    --mount=type=cache,target=/out/base/zlib,id=zlib-$TARGETPLATFORM \
#    --mount=type=cache,target=/out/base/zstd,id=zstd-$TARGETPLATFORM \
#    CMAKE_BUILD_PARALLEL_LEVEL=${NPROC:-$(nproc)} ./build-cross-zstd
#RUN --mount=type=cache,target=/out/base/zlib-host \
#    --mount=type=cache,target=/out/base/llvm-host \
#    --mount=type=cache,target=/out/base/zig-host \
#    --mount=type=cache,target=/out/base/zlib,id=zlib-$TARGETPLATFORM \
#    --mount=type=cache,target=/out/base/zstd,id=zstd-$TARGETPLATFORM \
#    --mount=type=cache,target=/out/base/llvm,id=llvm-$TARGETPLATFORM \
#    CMAKE_BUILD_PARALLEL_LEVEL=${NPROC:-$(nproc)} ./build-cross-llvm
#RUN --mount=type=cache,target=/out/base/zlib-host \
#    --mount=type=cache,target=/out/base/llvm-host \
#    --mount=type=cache,target=/out/base/zig-host \
#    --mount=type=cache,target=/out/base/zlib,id=zlib-$TARGETPLATFORM \
#    --mount=type=cache,target=/out/base/zstd,id=zstd-$TARGETPLATFORM \
#    --mount=type=cache,target=/out/base/llvm,id=llvm-$TARGETPLATFORM \
#    --mount=type=cache,target=/out/base/zig,id=zig-$TARGETPLATFORM \
#    CMAKE_BUILD_PARALLEL_LEVEL=${NPROC:-$(nproc)} ./build-cross-zig && \
#    xx-verify --static /out/zig/bin/zig

FROM base AS tgz
ARG ZIG_VERSION
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
WORKDIR /dist
RUN --mount=from=build,source=/out/zig,target=/zig <<EOT
  set -e
  mkdir /out
  cd /zig
  tar cvzf "/out/zig-$TARGETOS-$TARGETARCH$TARGETVARIANT.tar.gz" *
EOT

FROM scratch AS dist
COPY --from=build /out/zig /

FROM scratch AS dist-tgz
COPY --from=tgz /out /
