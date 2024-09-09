FROM debian:bookworm

ENV PBS_VERSION=3.2-1 \
    DEBIAN_FRONTEND=noninteractive \
    SERVICE=pbs-docker

LABEL maintainer="docker-dario@neomediatech.it" \ 
      org.label-schema.version=$PBS_VERSION \
      org.label-schema.vcs-type=Git \
      org.label-schema.vcs-url=https://github.com/Neomediatech/${SERVICE} \
      org.label-schema.maintainer=Neomediatech

# workaround to make PBS install
RUN ln -s /bin/true /usr/bin/systemctl && \
    echo exit 0 > /usr/sbin/policy-rc.d

# check and execute updates
RUN apt-get update && \
    apt-get -y --no-install-recommends --no-install-suggests dist-upgrade

# install some needed package
RUN apt-get -y --no-install-recommends --no-install-suggests install ca-certificates openssl wget gosu rsyslog tini

# add PBS repository
RUN wget https://enterprise.proxmox.com/debian/proxmox-release-bookworm.gpg -O /etc/apt/trusted.gpg.d/proxmox-release-bookworm.gpg
RUN echo "deb http://download.proxmox.com/debian/pbs bookworm pbs-no-subscription" > /etc/apt/sources.list.d/pbs-free.list

# install PBS
RUN apt-get update && \
    apt-get install -y -V --no-install-recommends proxmox-backup-server 

# disable kernel logging module and log everything to stdout
RUN sed -i '/.*imklog.*/d' /etc/rsyslog.conf && \
    echo '*.* /dev/stdout' >> /etc/rsyslog.conf

COPY entrypoint.sh /

# create some dir and change permissions/owner
RUN mkdir -p /etc/proxmox-backup /var/log/proxmox-backup /var/lib/proxmox-backup /var/log/proxmox-backup/tasks/ /run/proxmox-backup && \
    chsh -s /bin/bash backup && \
    usermod -a -G backup root && \
    usermod -g backup root && \
    usermod -aG sudo backup && \
    chown -R backup:backup /etc/proxmox-backup && \
    chown -R backup:backup /var/log/proxmox-backup && \
    chown -R backup:backup /var/lib/proxmox-backup && \
    chmod -R 700 /etc/proxmox-backup && \
    chmod +x /entrypoint.sh

# add tini support to avoid zombies (as Postfix does)
ENTRYPOINT [ "tini", "--", "/entrypoint.sh" ]

CMD ["/bin/bash"]

