# BKG Professional NtripCaster v2.0.48
# https://igs.bkg.bund.de/ntrip/bkgcaster

# ---------- Stage 1: build ----------
FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        libssl-dev \
        ca-certificates \
        curl \
        bzip2 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

ARG CASTER_VERSION=2.0.48
ARG CASTER_SHA256=0415eef671300f175504a7638c8d1ec420202b035e89d72fa878d8a8cc41e388

RUN curl -fSL -o ntripcaster.tar.bz2 \
        "https://igs.bkg.bund.de/root_ftp/NTRIP/software/caster/ntripcaster-${CASTER_VERSION}.tar.bz2" \
    && echo "${CASTER_SHA256}  ntripcaster.tar.bz2" | sha256sum -c - \
    && tar xjf ntripcaster.tar.bz2

WORKDIR /build/ntripcaster-${CASTER_VERSION}

RUN ./configure --prefix=/usr/local/ntripcaster \
    && make -j"$(nproc)" \
    && make install

# ---------- Stage 2: runtime ----------
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        libssl3 \
        libcrypt1 \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/ntripcaster/ /usr/local/ntripcaster/

# Copy .dist templates as default configs
RUN cd /usr/local/ntripcaster/conf \
    && for f in *.dist; do cp "$f" "${f%.dist}"; done

# Ensure log and var directories exist
RUN mkdir -p /usr/local/ntripcaster/logs /usr/local/ntripcaster/var

# Set console_mode to 2 (log window / foreground-friendly) so the daemon
# does not detach when run without -b, which keeps the container alive.
RUN sed -i 's/^console_mode.*/console_mode 2/' /usr/local/ntripcaster/conf/ntripcaster.conf

EXPOSE 2101

WORKDIR /usr/local/ntripcaster

CMD ["/usr/local/ntripcaster/sbin/ntripdaemon", "-d", "/usr/local/ntripcaster/conf"]
