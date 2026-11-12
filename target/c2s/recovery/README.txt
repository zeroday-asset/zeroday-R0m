N986B SOURCE-BUILT TWRP — candidate r1

SM-N986B/DS (c2s, Exynos 990) only.
Replaces the rejected Artisan prebuilt recovery; it does not replace the ROM.
TWRP userspace and its recovery-only kernel are compiled in the public build.

Changes: explicit Data/Metadata controls; newly compiled permissive recovery
kernel with F2FS/EXT4/EROFS support; no automatic rewriting of Android's boot.
The ROM kernel and its SELinux settings are separate and are not modified.

This is a first-device-test candidate. Compilation and image checks do not
establish phone functionality. Existing Samsung-encrypted user files are not
promised decryptable. Do not treat a successful format banner as proof of
working data access if permission or mount errors remain.

Installation: use the recovery-only Odin .tar in USERDATA, Auto Reboot OFF,
Re-Partition unchecked, then boot directly back into recovery. The disabled
vbmeta already installed with the previous pack is retained, not rewritten.
Do not flash the .img to Boot. No PIT, bootloader or modem is included.

Before installing the ROM: Data must appear in Mount, mount successfully and
allow creating/browsing a temporary folder in the recovery file manager.
If formatting is needed, Format Data erases internal storage. Reboot Recovery
after formatting and verify access again. Stop if permission errors persist.

The bundle includes hashes, the compiled kernel config, exact source manifest
and an offline image inspection report. No hardware boot test was performed.
