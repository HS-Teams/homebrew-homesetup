FROM quay.io/centos/centos:stream8

LABEL maintainer="Hugo Saporetti Junior <taius.hhs@gmail.com>"

USER root

ENV SHELL=/bin/bash
ENV HOME=/root

# Fix broken mirrors and prepare base repos
RUN sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/*.repo && \
    sed -i 's|^#baseurl=http://mirror.centos.org|baseurl=https://vault.centos.org|g' /etc/yum.repos.d/*.repo && \
    dnf -y install dnf-plugins-core epel-release && \
    dnf config-manager --set-enabled powertools || dnf config-manager --set-enabled crb && \
    dnf -y install \
        https://download1.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm && \
    dnf -y update && \
    dnf -y install \
        sudo curl vim wget git procps-ng glibc-common libpq-devel file cmake \
        openssl-devel bzip2-devel libffi-devel rsync sqlite-devel \
        alsa-lib-devel ffmpeg --nobest && \
    dnf -y groupinstall "Development Tools" && \
    dnf clean all && rm -rf /var/cache/dnf /var/cache/yum

WORKDIR /root

# Python 3.11 build
RUN dnf -y install \
      gcc make openssl-devel bzip2-devel libffi-devel zlib-devel \
      xz-devel readline-devel sqlite-devel tk-devel gdbm-devel libuuid-devel \
      ncurses-devel && \
    wget https://www.python.org/ftp/python/3.11.11/Python-3.11.11.tgz && \
    tar -xzf Python-3.11.11.tgz && \
    cd Python-3.11.11 && \
    ./configure --enable-optimizations --enable-loadable-sqlite-extensions && \
    make -j"$(nproc)" && make install && \
    cd .. && rm -rf Python-3.11.11 Python-3.11.11.tgz && dnf clean all

# PortAudio build
RUN dnf -y install \
      alsa-lib-devel jack-audio-connection-kit-devel libsndfile-devel && \
    wget https://files.portaudio.com/archives/pa_stable_v190700_20210406.tgz && \
    tar -xzf pa_stable_v190700_20210406.tgz && \
    cd portaudio && \
    ./configure --with-alsa && \
    make -j"$(nproc)" && make install && \
    cd .. && rm -rf portaudio pa_stable_v190700_20210406.tgz && \
    ldconfig

# HomeSetup installation
RUN curl -fsSL https://raw.githubusercontent.com/yorevs/homesetup/master/install.bash | bash

CMD ["bash", "--login"]
