
ARG BASE_TAG=latest

FROM ghcr.io/tristiisch/docker_through_ssh:${BASE_TAG}
ARG SSH_PUBLIC_KEY
ARG SSH_PRIVATE_ACCOUNT=deploy

RUN test -n "$SSH_PUBLIC_KEY" || (echo "Error: SSH_PUBLIC_KEY is not set" && exit 1)

# Authentification only with key
RUN echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config.d/aa-custom

# SSH Account
RUN useradd -m $SSH_PRIVATE_ACCOUNT \
	&& usermod -aG docker $SSH_PRIVATE_ACCOUNT \
	&& chmod 700 -R /home/$SSH_PRIVATE_ACCOUNT \
    && mkdir -p /home/$SSH_PRIVATE_ACCOUNT/.ssh \
    && chmod 700 /home/$SSH_PRIVATE_ACCOUNT/.ssh \
    && chown $SSH_PRIVATE_ACCOUNT:$SSH_PRIVATE_ACCOUNT /home/$SSH_PRIVATE_ACCOUNT/.ssh \
    && echo "$SSH_PUBLIC_KEY" > /home/$SSH_PRIVATE_ACCOUNT/.ssh/authorized_keys \
    && chmod 600 /home/$SSH_PRIVATE_ACCOUNT/.ssh/authorized_keys \
    && chown $SSH_PRIVATE_ACCOUNT:$SSH_PRIVATE_ACCOUNT /home/$SSH_PRIVATE_ACCOUNT/.ssh/authorized_keys

# Create one shot usage service to init swarm on first container boot
COPY ./docker-swarm-init.service /etc/systemd/system/docker-swarm-init.service
RUN ln -s /etc/systemd/system/docker-swarm-init.service /etc/systemd/system/multi-user.target.wants/docker-swarm-init.service
