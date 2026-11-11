#!/bin/bash
set -euo pipefail
repo=$(pwd)
root="$repo/target/c2s/root"
test_dir="$repo/target/c2s/tests/qemu"
mkdir -p "$repo/qemu-results" "$repo/.qemu"
# Reuse exactly the phone build's pinned downloads and patch application.
# Only replace its compile/package tail for the virtual hardware configuration.
python3 - "$root/build-kernel.sh" "$root/.qemu-prepare.sh" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text().split('bash build.sh -m c2s -k y -r n')[0]
s+='\nsource "$source_dir/../tests/qemu/kernel-tail.sh"\n'
Path(sys.argv[2]).write_text(s)
PY
bash "$root/.qemu-prepare.sh" "$repo/.qemu/kernel"
cp "$repo/.qemu/kernel/kernel.config" "$repo/qemu-results/kernel.config"
printf '%s\n' \
  'Virtual ARM64 build of pinned Artisan/KSU/SUSFS sources and the phone compatibility patches.' \
  'Different board config, plus synthetic test-only SID/global-hiding controls.' \
  'Not a boot of the N986B ROM, Android policy, or phone binary.' > "$repo/qemu-results/scope.txt"
rootfs="$repo/.qemu/initramfs"
mkdir -p "$rootfs"
base=https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/aarch64
curl -fLsS --retry 3 "$base/alpine-minirootfs-3.21.7-aarch64.tar.gz" -o "$repo/.qemu/alpine.tar.gz"
curl -fLsS --retry 3 "$base/alpine-minirootfs-3.21.7-aarch64.tar.gz.sha512" -o "$repo/.qemu/alpine.tar.gz.sha512"
(cd "$repo/.qemu"; sed 's/alpine-minirootfs-3.21.7-aarch64.tar.gz/alpine.tar.gz/' alpine.tar.gz.sha512 | sha512sum -c -)
sudo tar -xzf "$repo/.qemu/alpine.tar.gz" -C "$rootfs"
sudo cp "$test_dir/init.sh" "$rootfs/init"
sudo chmod 755 "$rootfs/init"
aarch64-linux-gnu-gcc -static -O2 -Wall -Wextra -Werror "$test_dir/fd-mount-check.c" -o "$repo/.qemu/fd-mount-check"
sudo cp "$repo/.qemu/fd-mount-check" "$rootfs/bin/"
(cd "$rootfs"; sudo find . -print0 | sudo cpio --null -o -H newc --owner=0:0 | gzip -1) > "$repo/.qemu/initramfs.gz"
