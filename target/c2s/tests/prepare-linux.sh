#!/bin/bash
set -euo pipefail
revision=cdadb9eb5d0f86aacffff60776333e6f6b73a30a
mkdir -p runtime-results .runtime/droidspaces .runtime/rootfs
printf 'Droidspaces source %s\nROM kernel was built separately at 906cbe7a735d3f11d96e6caa2f5833f8b5be228e\nRuntime host is the GitHub runner kernel, WITHOUT SUSFS.\n' "$revision" > runtime-results/scope.txt
uname -a >> runtime-results/scope.txt
curl -fLsS --retry 3 "https://codeload.github.com/ravindu644/Droidspaces-OSS/tar.gz/$revision" \
    | tar -xz --strip-components=1 -C .runtime/droidspaces
make -C .runtime/droidspaces -j2 output/droidspaces-x86_64 CC=musl-gcc
sudo install -m755 .runtime/droidspaces/output/droidspaces-x86_64 /usr/local/bin/droidspaces
docker build -t c2s-droidspaces-fixture target/c2s/tests
fixture_id=$(docker create c2s-droidspaces-fixture)
trap 'docker rm -f "$fixture_id" >/dev/null' EXIT
docker export "$fixture_id" | sudo tar -x -C .runtime/rootfs
docker pull busybox:1.36
docker save busybox:1.36 -o .runtime/busybox-image.tar
sudo cp .runtime/busybox-image.tar .runtime/rootfs/fixture/
docker image inspect c2s-droidspaces-fixture busybox:1.36 > runtime-results/fixture-images.json
truncate -s 5G .runtime/rootfs.img
sudo mkfs.ext4 -F -d .runtime/rootfs .runtime/rootfs.img
sudo rm -rf .runtime/rootfs
