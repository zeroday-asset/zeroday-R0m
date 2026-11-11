FROM docker:29-dind AS docker-current
FROM debian:bookworm-slim
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    docker.io iptables iproute2 util-linux procps curl ca-certificates uidmap python3 systemd-sysv \
    && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --set iptables /usr/sbin/iptables-legacy \
    && update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy \
    && mkdir -p /etc/docker /fixture /www \
    && printf '{"userns-remap":"default","exec-opts":["native.cgroupdriver=systemd"],"features":{"containerd-snapshotter":false}}\n' > /etc/docker/daemon.json
COPY --from=docker-current /usr/local/bin/ /usr/local/bin/
COPY guest-docker.sh /fixture/guest-docker.sh
RUN chmod 755 /fixture/guest-docker.sh \
    && systemctl disable docker.service docker.socket containerd.service \
    && mkdir -p /etc/systemd/network \
    && printf '[Match]\nName=eth0\n[Network]\nDHCP=yes\n[DHCPv4]\nUseDNS=no\n' > /etc/systemd/network/20-fixture.network \
    && systemctl enable systemd-networkd.service \
    && printf '[Unit]\nAfter=basic.target\n[Service]\nType=oneshot\nExecStart=/usr/bin/touch /fixture/init-ready\nRemainAfterExit=yes\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/fixture-ready.service \
    && systemctl enable fixture-ready.service \
    && printf '[Unit]\nAfter=network.target\n[Service]\nType=notify\nExecStart=/usr/local/bin/dockerd\nDelegate=yes\nKillMode=process\nTasksMax=infinity\nTimeoutStartSec=120\n' > /lib/systemd/system/docker.service
