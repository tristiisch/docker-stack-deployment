FROM debian:12
ARG SHELL=/bin/bash

LABEL org.opencontainers.image.source=https://github.com/tristiisch/docker-stack-deployment

ENV container=docker
ENV DEBIAN_FRONTEND=noninteractive

# Install systemd
RUN apt update && \
	apt install -y \
		systemd \
		systemd-sysv\
		dbus && \
	# Clean up
	rm -rf /var/lib/apt/lists/*

RUN rm -rf /lib/systemd/system/multi-user.target.wants/* && \
	rm -rf /etc/systemd/system/*.wants/* && \
	rm -rf /lib/systemd/system/local-fs.target.wants/* && \
	rm -rf /lib/systemd/system/sockets.target.wants/*udev* && \
	rm -rf /lib/systemd/system/sockets.target.wants/*initctl* && \
	rm -rf /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup* && \
	rm -rf /lib/systemd/system/systemd-update-utmp*

RUN \
	# SSH server and tools to install Docker's APT repository
    apt update && \
	apt install -y --no-install-recommends \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common \
        openssh-server && \
	# Clean up
	rm -rf /var/lib/apt/lists/*

# Setup Docker's APT repository and install Docker
RUN install -m 0755 -d /etc/apt/keyrings && \
	curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
	chmod a+r /etc/apt/keyrings/docker.asc && \
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
		tee /etc/apt/sources.list.d/docker.list && \
	apt update && \
	apt install -y --no-install-recommends \
		docker-ce \
		docker-ce-cli \
		containerd.io \
		docker-buildx-plugin \
		docker-compose-plugin && \
	# Clean up
	rm -rf /var/lib/apt/lists/*

# SSH Server Configuration
RUN mkdir -p /run/sshd && \
    echo 'PermitRootLogin no' >> /etc/ssh/sshd_config.d/custom && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config.d/custom && \
    useradd -m -s $SHELL president && \
    usermod -aG docker president && \
    chmod 700 -R /home/president && \
    echo 'president:P@ssword!' | chpasswd
	# && rm /etc/ssh/ssh_host_*
	# ssh-keygen -A

VOLUME ["/sys/fs/cgroup"]
EXPOSE 22
STOPSIGNAL SIGRTMIN+3
CMD ["/lib/systemd/systemd"]
