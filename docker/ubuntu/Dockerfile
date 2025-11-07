FROM ubuntu:latest

LABEL maintainer="Hugo Saporetti Junior <taius.hhs@gmail.com>"

USER root

ENV SHELL=/bin/bash
ENV HOME=/root
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# System update and core setup
RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
        software-properties-common locales curl sudo build-essential procps file vim git rsync cmake ruby ruby-dev \
        bsdmainutils bat fd-find fzf gawk libpq-dev libnl-3-dev portaudio19-dev ffmpeg && \
    add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update -y && \
    apt-get install -y python3.11 python3.11-dev && \
    locale-gen "en_US.UTF-8" && \
    gem install colorls && \
    curl -sS https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3.11 get-pip.py && \
    python3.11 -m pip install --upgrade pip setuptools wheel && \
    rm -f get-pip.py && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /root

# HomeSetup installation
RUN curl -fsSL https://raw.githubusercontent.com/yorevs/homesetup/master/install.bash | bash

CMD ["bash", "--login"]
