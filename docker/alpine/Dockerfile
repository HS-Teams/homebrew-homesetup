FROM alpine:latest

LABEL maintainer="Hugo Saporetti Junior <taius.hhs@gmail.com>"

USER root

ENV SHELL=/bin/sh
ENV HOME=/root

# Use stable repos only (edge repos commented out)
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.alpinelinux.org/g' /etc/apk/repositories && \
    apk update && apk upgrade

# Core system and build deps
RUN apk add --no-cache \
      bash sudo curl vim wget git cmake build-base \
      libffi-dev openssl-dev bzip2-dev sqlite-dev \
      alsa-lib-dev ffmpeg-dev portaudio-dev \
      linux-headers

# Python 3.11 and tools
RUN apk add --no-cache python3=3.11.9-r0 py3-pip

# Make python3 alias consistent
RUN ln -sf "$(command -v python3)" /usr/local/bin/python && \
    python -m ensurepip && \
    pip install --upgrade pip setuptools wheel

WORKDIR /root
