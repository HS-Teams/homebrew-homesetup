FROM quay.io/centos/centos:stream8

LABEL maintainer="Hugo Saporetti Junior <taius.hhs@gmail.com>"

USER root

ENV SHELL=/bin/bash
ENV HOME=/root

RUN dnf -y update && \
    dnf -y install sudo curl vim wget procps-ng glibc-common libpq-devel file cmake git \
                   openssl-devel bzip2-devel libffi-devel rsync sqlite-devel \
                   alsa-lib-devel ffmpeg && \
    dnf -y groupinstall "Development Tools" && \
    dnf clean all

WORKDIR /root

# Python build
RUN wget https://www.python.org/ftp/python/3.11.11/Python-3.11.11.tgz && \
    tar -xzf Python-3.11.11.tgz && \
    cd Python-3.11.11 && \
    ./configure --enable-optimizations --enable-loadable-sqlite-extensions && \
    make install && \
    cd .. && rm -rf Python-3.11.11 Python-3.11.11.tgz

# PortAudio build
RUN wget https://files.portaudio.com/archives/pa_stable_v190700_20210406.tgz && \
    tar -xzf pa_stable_v190700_20210406.tgz && \
    cd portaudio && \
    ./configure && make install && \
    cd .. && rm -rf portaudio pa_stable_v190700_20210406.tgz
