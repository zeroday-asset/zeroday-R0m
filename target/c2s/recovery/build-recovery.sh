#!/usr/bin/env bash
set -eo pipefail
task_dir="$(cd "$(dirname "$0")" && pwd)"
tree="$1"
kernel_dir="$2"
dist="$3"
cd "$tree"
mkdir -p device/samsung/exynos990 "$dist"
device_rev=eb8805d3a76df92aa52b3b96bafcd1a07a06253f
curl -fLsS --retry 3 "https://codeload.github.com/ExtremeXT/android_device_samsung_exynos990/tar.gz/$device_rev" -o /tmp/c2s-device.tar.gz
tar -xzf /tmp/c2s-device.tar.gz -C device/samsung/exynos990 --strip-components=1
rm /tmp/c2s-device.tar.gz
python3 "$task_dir/customize.py" device/samsung/exynos990
cp "$kernel_dir"/{Image,dtb.img,dtbo.img} device/samsung/exynos990/c2s/prebuilt/
export ALLOW_MISSING_DEPENDENCIES=true
export BUILD_USERNAME=zeroday-asset
export BUILD_HOSTNAME=github-actions
source build/envsetup.sh
lunch twrp_c2s-eng
mka recoveryimage -j4
image=out/target/product/c2s/recovery.img
test -s "$image"
python3 external/avb/avbtool.py verify_image --image "$image"
python3 "$task_dir/verify-image.py" "$image" "$kernel_dir/Image" "$dist/recovery-inspection.json"
cp "$image" "$dist/recovery.img"
tar --format=ustar -C "$dist" -cf "$dist/N986B-source-TWRP-r1.tar" recovery.img
cp "$task_dir/README.txt" "$dist/START-HERE.txt"
cp "$kernel_dir"/{kernel-source.txt,recovery-kernel.config} "$dist/"
cp device/samsung/exynos990/recovery/root/system/etc/twrp.flags "$dist/"
repo manifest -r -o "$dist/twrp-sources.xml"
printf 'Device tree: ExtremeXT/android_device_samsung_exynos990 %s\nCustomization: %s\nActions: https://github.com/%s/actions/runs/%s\n' "$device_rev" "$GITHUB_SHA" "$GITHUB_REPOSITORY" "$GITHUB_RUN_ID" > "$dist/build-source.txt"
(cd "$dist"; find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
