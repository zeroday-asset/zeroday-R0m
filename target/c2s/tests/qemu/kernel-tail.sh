#!/bin/bash
# Sourced inside the patched kernel tree by the phone build's preparation code.
test_dir="$source_dir/../tests/qemu"
export PATH="$PWD/toolchain/clang_14/bin:$PATH"
# Samsung's disabled-debug branch has both a macro and a function with the
# same name. Keep its function stub when compiling without Samsung hardware.
git apply "$test_dir/virtual-board.patch"
make LLVM=1 LLVM_IAS=1 ARCH=arm64 O=out defconfig
# Remove the hardware platform selections from the generic defconfig. QEMU virt
# uses the generic GIC/PSCI/PL011 paths; Samsung-only drivers cannot run there.
while read -r platform; do
    scripts/config --file out/.config --disable "$platform"
done < <(sed -n 's/^config \(ARCH_[A-Z0-9_]*\)$/\1/p' arch/arm64/Kconfig.platforms)
scripts/kconfig/merge_config.sh -m -O out out/.config arch/arm64/configs/ksu.config "$test_dir/virt.config"
make LLVM=1 LLVM_IAS=1 ARCH=arm64 O=out olddefconfig
cp "$test_dir/susfs_qemu_probe.c" kernel/susfs_qemu_probe.c
echo 'obj-y += susfs_qemu_probe.o' >> kernel/Makefile
make -j"$(nproc)" LLVM=1 LLVM_IAS=1 ARCH=arm64 O=out Image
for option in KSU KSU_SUSFS KSU_SUSFS_SUS_MOUNT PID_NS; do
    grep -Fx "CONFIG_$option=y" out/.config
done
install -m644 out/arch/arm64/boot/Image "$output_dir/Image"
install -m644 out/.config "$output_dir/kernel.config"
