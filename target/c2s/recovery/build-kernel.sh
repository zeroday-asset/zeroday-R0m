#!/usr/bin/env bash
set -euo pipefail
output_dir="$(realpath -m "${1:?Output directory required}")"
kernel_rev=e09780863f024ad1d0953ac096facacd620c0111
work_dir="$(mktemp -d)"
trap 'rm -rf -- "$work_dir"' EXIT
mkdir -p "$work_dir/kernel" "$output_dir"
curl -fLsS --retry 3 "https://codeload.github.com/Android-Artisan/android_kernel_samsung_exynos990/tar.gz/$kernel_rev" -o "$work_dir/kernel.tar.gz"
tar -xzf "$work_dir/kernel.tar.gz" -C "$work_dir/kernel" --strip-components=1
rm "$work_dir/kernel.tar.gz"
cd "$work_dir/kernel"
mkdir -p toolchain/clang_14
curl -fLsS --retry 3 'https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/tags/android-13.0.0_r13/clang-r450784d.tar.gz' -o "$work_dir/clang.tar.gz"
tar -xzf "$work_dir/clang.tar.gz" -C toolchain/clang_14
rm "$work_dir/clang.tar.gz"
# Recovery has its own kernel. Do not put the Android root/SUSFS kernel here.
bash build.sh -m c2s -k n -r y
for config in SECURITY_SELINUX_ALWAYS_PERMISSIVE F2FS_FS EXT4_FS EROFS_FS; do
    grep -Fx "CONFIG_${config}=y" out/.config
done
if grep -Eq '^CONFIG_(KSU|SECURITY_SELINUX_ALWAYS_ENFORCE)=y$' out/.config; then
    echo 'Unexpected Android root or always-enforcing kernel in recovery' >&2
    exit 1
fi
gzip -cd out/kernel/config_data.gz > "$work_dir/embedded.config"
cmp out/.config "$work_dir/embedded.config"
install -m 0644 build/out/c2s/{Image,dtb.img,dtbo.img} "$output_dir/"
install -m 0644 out/.config "$output_dir/recovery-kernel.config"
printf 'Kernel: Android-Artisan/android_kernel_samsung_exynos990 %s\nBuild: c2s -k n -r y\n' "$kernel_rev" > "$output_dir/kernel-source.txt"
