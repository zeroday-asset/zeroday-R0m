#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output_dir="$(realpath -m "${1:?Specify an output directory}")"
kernel_rev=e09780863f024ad1d0953ac096facacd620c0111
ksu_rev=c81cdf51c3bb606836c6fc9a7cc858053eb0bc62
droidspaces_rev=cdadb9eb5d0f86aacffff60776333e6f6b73a30a

work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT
mkdir -p "$work_dir/kernel" "$output_dir"

download_tree() {
    local repository="$1" revision="$2" directory="$3"
    curl --fail --silent --show-error --location --retry 3 \
        "https://codeload.github.com/$repository/tar.gz/$revision" -o "$work_dir/source.tar.gz"
    tar -xzf "$work_dir/source.tar.gz" -C "$directory" --strip-components=1
    rm "$work_dir/source.tar.gz"
}

download_tree Android-Artisan/android_kernel_samsung_exynos990 "$kernel_rev" "$work_dir/kernel"
cd "$work_dir/kernel"
mkdir -p KernelSU-Next toolchain/clang_14
download_tree KernelSU-Next/KernelSU-Next "$ksu_rev" KernelSU-Next
git -C KernelSU-Next apply --check "$source_dir/kernelsu-susfs.patch"
git -C KernelSU-Next apply "$source_dir/kernelsu-susfs.patch"
git apply --check "$source_dir/droidspaces-cgroup.patch"
git apply "$source_dir/droidspaces-cgroup.patch"
git apply --check "$source_dir/susfs-container.patch"
git apply "$source_dir/susfs-container.patch"
cat "$source_dir/droidspaces.config" >> arch/arm64/configs/ksu.config
printf '\nCONFIG_KSU_SUSFS=y\n# CONFIG_KSU_SUSFS_TRY_UMOUNT is not set\n' >> arch/arm64/configs/ksu.config

curl --fail --silent --show-error --location --retry 3 \
    'https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/tags/android-13.0.0_r13/clang-r450784d.tar.gz' \
    -o "$work_dir/clang.tar.gz"
tar -xzf "$work_dir/clang.tar.gz" -C toolchain/clang_14
rm "$work_dir/clang.tar.gz"

# 30000 + 3024 commits at the pinned legacy ref + the upstream legacy offset 289.
export KSU_VERSION_OVERRIDE=33313
export KSU_VERSION_TAG_OVERRIDE=c81cdf51-c2s-susfs
bash build.sh -m c2s -k y -r n
for config in KSU KSU_SUSFS KALLSYMS KALLSYMS_ALL EROFS_FS SYSVIPC POSIX_MQUEUE NAMESPACES PID_NS IPC_NS UTS_NS USER_NS NET_NS DEVTMPFS CGROUPS CGROUP_DEVICE CGROUP_PIDS CGROUP_CPUACCT CGROUP_FREEZER CGROUP_SCHED CGROUP_BPF CPUSETS BLK_CGROUP BLK_DEV_THROTTLING CFS_BANDWIDTH MEMCG SECCOMP SECCOMP_FILTER KEYS VETH BRIDGE BRIDGE_NETFILTER OVERLAY_FS FUSE_FS TUN IP_NF_FILTER IP_NF_MANGLE IP_NF_RAW IP_NF_NAT IP_NF_TARGET_MASQUERADE IP6_NF_FILTER IP6_NF_MANGLE IP6_NF_RAW IP6_NF_NAT IP6_NF_TARGET_MASQUERADE NETFILTER_XT_MATCH_ADDRTYPE NETFILTER_XT_MATCH_CONNTRACK NETFILTER_XT_MATCH_IPVS NETFILTER_XT_MARK; do
    grep -Fx "CONFIG_${config}=y" out/.config
done
toolchain/clang_14/bin/llvm-nm out/vmlinux > "$work_dir/kernel-symbols"
grep -E '[[:space:]]susfs_init$' "$work_dir/kernel-symbols"
grep -E '[[:space:]]ksu_handle_sys_reboot$' "$work_dir/kernel-symbols"
grep -E '[[:space:]]susfs_is_current_in_container$' "$work_dir/kernel-symbols"
# March's GoRhanHee workaround exposed a stock config instead of the real one.
# Keep runtime capability reports truthful and archive the same config we built.
gzip -cd out/kernel/config_data.gz > "$work_dir/embedded.config"
cmp out/.config "$work_dir/embedded.config"
if grep -E '^CONFIG_CMDLINE=.*cgroup_disable=(memory|cpu|pids)' out/.config; then
    echo 'Required container controller disabled in kernel command line' >&2
    exit 1
fi
install -m 0644 build/out/c2s/{boot,dtbo}.img "$output_dir/"
install -m 0644 out/.config "$output_dir/kernel.config"
printf 'Artisan kernel %s\nKernelSU Next %s\nDroidspaces requirements %s\n' "$kernel_rev" "$ksu_rev" "$droidspaces_rev" > "$output_dir/kernel-sources.txt"

