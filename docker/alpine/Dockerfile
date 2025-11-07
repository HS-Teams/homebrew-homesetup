FROM alpine:latest

LABEL maintainer="Hugo Saporetti Junior <taius.hhs@gmail.com>"

USER root

ENV SHELL=/bin/bash
ENV HOME=/root
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Base system update
RUN apk update && apk upgrade

# Core tools and build dependencies
RUN apk add --no-cache \
      bash bash-completion sudo curl vim wget git cmake build-base \
      libffi-dev openssl-dev bzip2-dev sqlite-dev \
      alsa-lib-dev ffmpeg-dev portaudio-dev linux-headers \
      py3-pip py3-setuptools py3-wheel python3

# Python setup
RUN ln -sf "$(command -v python3)" /usr/local/bin/python
RUN ln -sf "$(command -v python3)" /usr/local/bin/python3 && \
    python -m pip install --break-system-packages --no-cache-dir --upgrade pip setuptools wheel

# Optional utilities (quality of life)
RUN apk add --no-cache less grep coreutils util-linux jq rsync

# Bash login environment
RUN echo "export LANG=en_US.UTF-8" >> /etc/profile && \
    echo "export LC_ALL=en_US.UTF-8" >> /etc/profile && \
    echo "[[ -f /etc/profile ]] && source /etc/profile" >> /root/.bashrc && \
    echo 'PS1="[\u@\h \W]\\$ "' >> /root/.bashrc && \
    echo "cd ~" >> /root/.bash_profile

WORKDIR /root

# Cleanup to keep image lean
RUN rm -rf /var/cache/apk/*

# HomeSetup installation
RUN curl -fsSL https://raw.githubusercontent.com/yorevs/homesetup/master/install.bash | bash

# Default shell
CMD ["bash", "--login"]
