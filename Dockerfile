# syntax=docker/dockerfile:1-labs

ARG ZIG_VERSION="0.8.1"
ARG XX_VERSION="1.1.0"

FROM --platform=${BUILDPLATFORM:-linux/amd64} tonistiigi/xx:${XX_VERSION} AS xx
FROM --platform=${BUILDPLATFORM:-linux/amd64} alpine:3.15 AS base
COPY --from=xx / /
RUN apk add --update  --no-cache \
    clang-dev \
    clang-libs \
    clang-static \
    cmake \
    file \
    libstdc++ \
    libxml2-dev \
    lld-dev \
    lld-static \
    llvm12-libs \
    llvm12-static \
    llvm-dev \
    make \
    zlib-static

FROM --platform=$BUILDPLATFORM alpine:3.15 AS zig
RUN apk --update --no-cache add git patch
WORKDIR /out
ARG ZIG_VERSION
RUN git clone --branch $ZIG_VERSION https://github.com/ziglang/zig.git zig
COPY patches patches
RUN <<EOT
set -ex
for l in $(cat patches/aports.config); do
  if [ "$(printf "$ver\n$l" | sort -V | head -n 1)" != "$ZIG_VERSION" ]; then
    commit=$(echo $l | cut -d, -f2)
    break
  fi
done
mkdir -p aports && cd aports && git init
git fetch --depth 1 https://github.com/alpinelinux/aports.git "$commit"
git checkout FETCH_HEAD
mkdir -p ../patches
cp -a testing/zig/*.patch ../patches/
cd - && rm -rf aports
cd zig
for f in ../patches/*.patch; do
  patch -p1 < "$f"
done
EOT

FROM base as zig-build
COPY --from=zig /out/zig /src
WORKDIR /src/build
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG ZIG_TARGET=${TARGETOS}-${TARGETARCH}${TARGETVARIANT}
RUN TARGETPLATFORM= TARGETPAIR=$ZIG_TARGET xx-apk add clang-dev gcc g++ libxml2-dev lld-dev llvm-dev
RUN <<EOT
set -e
#if $(TARGETPLATFORM= TARGETPAIR=$ZIG_TARGET xx-info) is-cross; then
#  CMAKE_CROSSOPTS="-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_HOST_SYSTEM_NAME=Linux"
#fi
set -x
#cmake $(TARGETPLATFORM= TARGETPAIR=$ZIG_TARGET xx-clang --print-cmake-defines) -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DZIG_STATIC=ON ${CMAKE_CROSSOPTS} ..
cmake $(TARGETPLATFORM= TARGETPAIR=$ZIG_TARGET xx-clang --print-cmake-defines) -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DZIG_STATIC_LLVM=ON ${CMAKE_CROSSOPTS} ..
make DESTDIR="/out" install
EOT
RUN file /out/usr/bin/zig
#RUN xx-verify --static /out/usr/bin/zig

FROM zig-build AS zig-build-tgz
ARG TARGETOS
ARG TARGETARCH
ARG TARGETVARIANT
ARG ZIG_TARGET
WORKDIR /out
RUN mkdir /out-tgz && tar cvzf /out-tgz/$ZIG_TARGET-zig-$TARGETOS-$TARGETARCH$TARGETVARIANT.tar.gz *

FROM scratch AS zig-static
COPY --from=zig-build /out /

FROM scratch AS zig-static-tgz
COPY --from=zig-build-tgz /out-tgz/ /
