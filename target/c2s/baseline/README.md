# N986B baseline build

This branch packages ArtisanROM Aether v4.0.2 for SM-N986B/DS with the pinned
Artisan kernel, KernelSU Next, and compiled SUSFS. GitHub Actions builds the ROM
and kernel from public source. The boot image is verified at 61,865,984 bytes.

The kernel uses the native Artisan c2s configuration plus the KernelSU/SUSFS
integration. No Droidspaces configuration fragment, cgroup patch or namespace
hiding exception is applied. The build rejects an experimental container-hook
symbol and compares embedded kernel configuration data with the actual build.

The download bundle contains the ROM, the unchanged official Artisan c2s
TWRP/vbmeta Odin package, the KernelSU Next manager, the upstream SUSFS module,
the optional KPatch-Next KPM add-on, pre-KPM boot/dtbo restore images, source
records and checksums. Every companion binary is checksum-pinned.

KPM is an optional post-boot add-on, not an already activated kernel feature.
Phone boot, SUSFS behavior and KPM loading still require a device test.
This unofficial ROM uses test signing keys and omits official OTA updates.

Read [START-HERE.txt](../baseline/START-HERE.txt) before flashing.
The outer GitHub artifact ZIP is a download bundle, not a recovery-flashable ZIP.
The ROM ZIP inside its 01-ROM directory already includes our kernel.
