#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
output_dir="$(realpath -m "${1:?Specify an output directory}")"
kernel_rev=e09780863f024ad1d0953ac096facacd620c0111
ksu_rev=c81cdf51c3bb606836c6fc9a7cc858053eb0bc62

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
for config in KSU KSU_SUSFS KSU_SUSFS_SUS_MOUNT KALLSYMS KALLSYMS_ALL EROFS_FS; do
    grep -Fx "CONFIG_${config}=y" out/.config
done
toolchain/clang_14/bin/llvm-nm out/vmlinux > "$work_dir/kernel-symbols"
grep -E '[[:space:]]susfs_init$' "$work_dir/kernel-symbols"
grep -E '[[:space:]]ksu_handle_sys_reboot$' "$work_dir/kernel-symbols"
if grep -q 'susfs_is_current_in_container' "$work_dir/kernel-symbols"; then
    echo 'Unexpected experimental container hook in baseline kernel' >&2
    exit 1
fi
# March's GoRhanHee workaround exposed a stock config instead of the real one.
# Keep runtime capability reports truthful and archive the same config we built.
gzip -cd out/kernel/config_data.gz > "$work_dir/embedded.config"
cmp out/.config "$work_dir/embedded.config"
install -m 0644 build/out/c2s/{boot,dtbo}.img "$output_dir/"
install -m 0644 out/.config "$output_dir/kernel.config"
printf 'Artisan kernel %s\nKernelSU Next %s\nBaseline: native Artisan configuration plus SUSFS; no container exception\n' "$kernel_rev" "$ksu_rev" > "$output_dir/kernel-sources.txt"

