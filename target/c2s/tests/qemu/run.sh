#!/bin/bash
set -euo pipefail
log=$(mktemp)
trap 'rm -f "$log"' EXIT
set +e
timeout 240 qemu-system-aarch64 -machine virt,gic-version=2 -cpu cortex-a57 \
    -m 1536 -smp 2 -nographic -no-reboot \
    -kernel .qemu/kernel/Image -initrd .qemu/initramfs.gz \
    -append 'console=ttyAMA0 earlycon=pl011,0x9000000 rdinit=/init panic=-1' \
    2>&1 | tee "$log"
status=${PIPESTATUS[0]}
set -e
test "$status" -eq 0
grep -Fx QEMU_SUSFS_TESTS_PASS "$log"
! grep -q QEMU_SUSFS_TESTS_FAIL "$log"
