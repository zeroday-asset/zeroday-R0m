#!/bin/bash
set -euo pipefail
revision=cdadb9eb5d0f86aacffff60776333e6f6b73a30a
mkdir -p runtime-results .runtime/droidspaces .runtime/rootfs
printf 'Droidspaces source %s\nROM kernel was built separately at 906cbe7a735d3f11d96e6caa2f5833f8b5be228e\nRuntime host is the GitHub runner kernel, WITHOUT SUSFS.\n' "$revision" > runtime-results/scope.txt
uname -a >> runtime-results/scope.txt
curl -fLsS --retry 3 "https://codeload.github.com/ravindu644/Droidspaces-OSS/tar.gz/$revision" \
    | tar -xz --strip-components=1 -C .runtime/droidspaces
# This fixture tests the Linux backend using the runner's static glibc toolchain;
# it is not the Android ARM64/musl binary.
make -C .runtime/droidspaces -j2 output/droidspaces-x86_64 CC=gcc
echo 'Backend fixture: x86_64, static glibc build of pinned source.' >> runtime-results/scope.txt
sudo install -m755 .runtime/droidspaces/output/droidspaces-x86_64 /usr/local/bin/droidspaces
docker build -t c2s-droidspaces-fixture target/c2s/tests
fixture_id=$(docker create c2s-droidspaces-fixture)
trap 'docker rm -f "$fixture_id" >/dev/null' EXIT
docker export "$fixture_id" | sudo tar -x -C .runtime/rootfs
# Cloud runners may permit only their assigned DNS server. Avoid substituting
# a public resolver, and record the resolver used in the evidence.
dns_server=$(awk '$1=="nameserver" && $2 !~ /^127\./ {print $2; exit}' /run/systemd/resolve/resolv.conf /etc/resolv.conf)
test -n "$dns_server"
printf '%s\n' "$dns_server" > .runtime/dns-server
echo "Runtime DNS: $dns_server" >> runtime-results/scope.txt
sudo jq --arg dns "$dns_server" '.dns=[$dns]' .runtime/rootfs/etc/docker/daemon.json > .runtime/daemon.json
sudo cp .runtime/daemon.json .runtime/rootfs/etc/docker/daemon.json
docker pull busybox:1.36
docker save busybox:1.36 -o .runtime/busybox-image.tar
sudo cp .runtime/busybox-image.tar .runtime/rootfs/fixture/
docker image inspect c2s-droidspaces-fixture busybox:1.36 > runtime-results/fixture-images.json
truncate -s 5G .runtime/rootfs.img
sudo mkfs.ext4 -F -d .runtime/rootfs .runtime/rootfs.img
sudo rm -rf .runtime/rootfs
