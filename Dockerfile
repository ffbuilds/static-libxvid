
# http://websvn.xvid.org/cvs/viewvc.cgi/trunk/xvidcore/build/generic/configure.in?revision=2146&view=markup
# bump: xvid /XVID_VERSION=([\d.]+)/ svn:http://anonymous:@svn.xvid.org|/^release-(.*)$/|/_/./|^1
# bump: xvid after ./hashupdate Dockerfile XVID $LATEST
# add extra CFLAGS that are not enabled by -O3
ARG XVID_VERSION=1.3.7
ARG XVID_URL="https://downloads.xvid.com/downloads/xvidcore-$XVID_VERSION.tar.gz"
ARG XVID_SHA256=abbdcbd39555691dd1c9b4d08f0a031376a3b211652c0d8b3b8aa9be1303ce2d

# Must be specified
ARG ALPINE_VERSION

FROM alpine:${ALPINE_VERSION} AS base

FROM base AS download
ARG XVID_URL
ARG XVID_SHA256
ARG WGET_OPTS="--retry-on-host-error --retry-on-http-error=429,500,502,503 -nv"
WORKDIR /tmp
RUN \
  apk add --no-cache --virtual download \
    coreutils wget tar && \
  wget $WGET_OPTS -O libxvid.tar.gz "$XVID_URL" && \
  echo "$XVID_SHA256  libxvid.tar.gz" | sha256sum --status -c - && \
  mkdir xvid && \
  tar xf libxvid.tar.gz -C xvid --strip-components=1 && \
  rm libxvid.tar.gz && \
  apk del download

FROM base AS build 
COPY --from=download /tmp/xvid/ /tmp/xvid/
WORKDIR /tmp/xvid/build/generic
ARG CFLAGS="-O3 -s -static-libgcc -fno-strict-overflow -fstack-protector-all -fPIC"
RUN \
  apk add --no-cache --virtual build \
    build-base && \
  CFLAGS="$CFLAGS -fstrength-reduce -ffast-math" ./configure && \
  make -j$(nproc) && make install && \
  # Sanity tests
  ar -t /usr/local/lib/libxvidcore.a && \
  readelf -h /usr/local/lib/libxvidcore.a && \
  # Cleanup
  apk del build

FROM scratch
ARG XVID_VERSION
COPY --from=build /usr/local/lib/libxvidcore.* /usr/local/lib/
COPY --from=build /usr/local/include/xvid.h /usr/local/include/xvid.h
