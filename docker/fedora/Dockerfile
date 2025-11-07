FROM fedora:latest

LABEL maintainer="Hugo Saporetti Junior <taius.hhs@gmail.com>"

USER root

ENV SHELL=/bin/bash
ENV HOME=/root

# Update and install base system
RUN dnf -y upgrade && \
    dnf -y install \
        sudo redhat-rpm-config curl vim git findutils procps-ng hostname uptimed glibc-langpack-en \
        gcc postgresql-devel rsync file cmake ruby ruby-devel xclip net-tools \
        bat fd-find fzf gawk \
        python3.11 python3.11-devel portaudio-devel ffmpeg && \
    dnf clean all

# Ruby gem install
RUN gem install colorls

# Pip installer
RUN curl -sS https://bootstrap.pypa.io/get-pip.py -o get-pip.py && \
    python3.11 get-pip.py && \
    rm -f get-pip.py

WORKDIR /root

# HomeSetup installation
RUN curl -fsSL https://raw.githubusercontent.com/yorevs/homesetup/master/install.bash | bash

CMD ["bash", "--login"]
