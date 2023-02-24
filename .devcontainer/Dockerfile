FROM ubuntu:focal
ARG USERNAME=something
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
ARG FULLNAME="Your full name"
ARG MAIL="some@mail.address"
ENV DEBIAN_FRONTEND noninteractive
ENV HTTPS_PROXY http://proxy.ihelse.net:3128
ENV HTTP_PROXY http://proxy.ihelse.net:3128
ENV http_proxy http://proxy.ihelse.net:3128
ENV https_proxy http://proxy.ihelse.net:3128
ENV DOCKER_TLS_CERTDIR=/certs
ENV docker_version=20.10.19
ENV nextflow_version=22.10.6
ENV nf_core_version=2.7.2
 
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        btrfs-progs \
        ca-certificates \
        curl \
        e2fsprogs \
        fakeroot \
        fish \
        fuse2fs \
        fuse-overlayfs \
        git \
        gnupg \
        iproute2 \
        iptables \
        libfuse2 \
        libseccomp-dev \
        openssl \
        pigz \
        python3-dev \
        python3-pip \
        openjdk-11-jdk-headless \
        openssh-client \
        silversearcher-ag \
        squashfs-tools \
        squashfuse \
        sshpass \
        sudo \
        uidmap \
        vim \
        xfsprogs \
        xz-utils \
        zfsutils-linux \
    && rm -rf /var/lib/apt/lists/* \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man \
    && apt-get clean \
    && curl -JL -o apptainer.deb https://github.com/apptainer/apptainer/releases/download/v1.1.2/apptainer_1.1.2_amd64.deb \
    && apt-get install -y ./apptainer.deb \
    && rm apptainer.deb \
    && rm -rf rm -rf /var/lib/apt/lists/* \
    && groupadd --gid ${USER_GID} ${USERNAME} \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /usr/bin/fish \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME
RUN echo 'hosts: files dns' > /etc/nsswitch.conf
RUN curl -JL -o docker.tgz https://download.docker.com/linux/static/stable/x86_64/docker-$docker_version.tgz && \
    tar --extract --file docker.tgz --strip-components 1 --directory /usr/local/bin/ --no-same-owner && \
    rm docker.tgz
RUN mkdir /certs /certs/client && chmod 1777 /certs /certs/client
RUN addgroup -q dockremap && \
    adduser -q --disabled-password --ingroup dockremap dockremap && \
    echo 'dockremap:165536:65536' >> /etc/subuid && \
    echo 'dockremap:165536:65536' >> /etc/subgid
RUN curl -o /usr/local/bin/dind https://raw.githubusercontent.com/docker/docker/42b1175eda071c0e9121e1d64345928384a93df1/hack/dind && \
    chmod +x /usr/local/bin/dind && \
    curl -o /usr/local/bin/dockerd-entrypoint.sh https://raw.githubusercontent.com/docker-library/docker/master/dockerd-entrypoint.sh && \
    chmod +x /usr/local/bin/dockerd-entrypoint.sh
RUN ln -sf python3 /usr/bin/python && \
    pip3 install --no-cache-dir \
    nf-core==${nf_core_version}
RUN curl -JLs -o /usr/bin/nextflow https://github.com/nextflow-io/nextflow/releases/download/v${nextflow_version}/nextflow-${nextflow_version}-all && \
    chmod 755 /usr/bin/nextflow
COPY modprobe.sh /usr/local/bin/modprobe
VOLUME /var/lib/docker
EXPOSE 2375 2376
USER ${USERNAME}
RUN git config --global pull.rebase false && \
    git config --global user.email "${MAIL}" && \
    git config --global user.name "${FULLNAME}"
ENTRYPOINT ["dockerd-entrypoint.sh"]
