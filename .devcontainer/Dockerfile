# Make hadolint available
FROM hadolint/hadolint:latest-debian AS hadolint
# Build on top of nf-core gitpod
FROM nfcore/gitpod:3.2.0
# Copy the latest hadolint
COPY --from=hadolint /bin/hadolint /bin/hadolint
# Set up ARGS (These are declared in the devcontainer.json)
ARG FULLNAME="Your full name"
ARG MAIL="some@mail.address"
ARG USERNAME=something
ARG USER_UID=1000
ARG USER_GID=${USER_UID}
# Install dependencies
USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        fish=3.3.1+ds-3 \
        fuse-overlayfs=1.7.1-1 \
        openssh-server=1:8.9p1-3ubuntu0.11 \
        silversearcher-ag=2.2.0+git20200805-1 \
    && echo "LC_ALL=en_US.UTF-8" > /etc/default/locale \
    && locale-gen en_US.UTF-8 \
    && apt-get clean \
    && rm -Rf /usr/share/doc && rm -Rf /usr/share/man \
    && rm -rf /var/lib/apt/lists/*
# convert gitpod to local user
RUN groupmod -n ${USERNAME} -g ${USER_GID} gitpod \
    && usermod -md /home/${USERNAME} -l ${USERNAME} -u ${USER_UID} -s /usr/bin/fish -aG docker gitpod \
    && echo ${USERNAME} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME} \
    && find / -uid 33333 -not -path "/proc/*" -exec chown ${USERNAME}:${USERNAME} {} +
ENV HOME=/home/${USERNAME} \
    LC_ALL=en_US.UTF-8
USER ${USERNAME}
RUN git config --global pull.rebase false \
    && git config --global user.email "${MAIL}" \
    && git config --global user.name "${FULLNAME}"
