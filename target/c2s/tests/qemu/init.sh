#!/bin/sh
export PATH=/bin:/sbin:/usr/bin:/usr/sbin
finish() { sync; poweroff -f; }
fail() { echo "QEMU_SUSFS_TESTS_FAIL: $*"; finish; }
mount -t proc proc /proc || fail proc
mount -t sysfs sysfs /sys || fail sysfs
mount -t devtmpfs devtmpfs /dev || fail devtmpfs
mkdir -p /susfs-marker
probe=/sys/module/susfs_qemu_probe/parameters
test -d "$probe" || fail 'test-only controls absent'
uname -a
test "$(cat "$probe/in_container")" = 0 || fail 'initial PID namespace misclassified'
echo 1 > "$probe/creator_domain" || fail 'synthetic creator identity'
mount -t tmpfs susfs-marker /susfs-marker || fail 'tagged mount'
echo marker > /susfs-marker/value
echo 0 > "$probe/creator_domain"
grep ' /susfs-marker ' /proc/self/mountinfo || fail 'baseline mount absent'
echo 1 > "$probe/global_hiding"
if grep -q ' /susfs-marker ' /proc/self/mountinfo; then fail 'global hiding did not filter marked mount'; fi
echo 'PASS: real SUSFS global filtering hides marked mount in initial PID namespace'
unshare -m sh -ec '
    test "$(cat /sys/module/susfs_qemu_probe/parameters/in_container)" = 0
    ! grep -q " /susfs-marker " /proc/self/mountinfo
' || fail 'mount namespace alone bypassed hiding'
echo 'PASS: unsharing only mounts retains hiding'
echo 1 > "$probe/unmounted_flag"
unshare -pmf sh -ec '
    mount -t proc proc /proc
    test "$(cat /sys/module/susfs_qemu_probe/parameters/in_container)" = 1
    grep " /susfs-marker " /proc/self/mountinfo
    /bin/fd-mount-check /susfs-marker/value
    unshare -pmf sh -ec "mount -t proc proc /proc; /bin/fd-mount-check /susfs-marker/value"
' || fail 'container mount visibility/metadata'
echo 0 > "$probe/unmounted_flag"
echo 'PASS: container and nested container retain real mount visibility and metadata'
if grep -q ' /susfs-marker ' /proc/self/mountinfo; then fail 'host hiding changed after namespace test'; fi
echo 0 > "$probe/global_hiding"
grep ' /susfs-marker ' /proc/self/mountinfo || fail 'disabling global filtering did not restore mount'
echo QEMU_SUSFS_TESTS_PASS
finish
