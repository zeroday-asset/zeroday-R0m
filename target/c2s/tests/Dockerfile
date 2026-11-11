FROM debian:bookworm-slim
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    docker.io iptables iproute2 util-linux procps curl ca-certificates uidmap python3 \
    && rm -rf /var/lib/apt/lists/* \
    && update-alternatives --set iptables /usr/sbin/iptables-legacy \
    && update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy \
    && mkdir -p /etc/docker /fixture /www \
    && printf '{"userns-remap":"default","exec-opts":["native.cgroupdriver=cgroupfs"]}\n' > /etc/docker/daemon.json
COPY guest-init.sh /sbin/fixture-init
COPY guest-docker.sh /fixture/guest-docker.sh
RUN chmod 755 /sbin/fixture-init /fixture/guest-docker.sh
