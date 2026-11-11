# Aether c2s root and Droidspaces build

This branch targets SM-N986B and is based on ArtisanROM Aether v4.0.2.
GitHub Actions compiles the pinned Artisan kernel and KernelSU Next sources.
Artifacts include the ROM, final kernel config, source revisions and checksums.
The ROM boot image must pass AVB verification at 61,865,984 bytes.

The KernelSU Next patch adapts Artisan's SUSFS integration from `a4eaa915`
to the pinned legacy driver, uses the devpts hook already in the kernel, and
preserves Aether v4.0.2's SELinux fixes. SUSFS is built into the kernel.
KPM is provided by the upstream KPatch-Next Module v0.0.1. Its boot patch and
KPM loading need a device test.

## Droidspaces

Spaces means [ravindu644/Droidspaces-OSS](https://github.com/ravindu644/Droidspaces-OSS).
The kernel fragment follows the non-GKI requirements at `cdadb9eb5d0f86aacffff60776333e6f6b73a30a`.
It enables IPC and PID namespaces, cgroups, devtmpfs, overlayfs, container
networking, resource limits, FUSE and TUN. The required cgroup prefix patch is
included. The xt_qtaguid patch is inapplicable because this kernel has no
`net/netfilter/xt_qtaguid.c`.

Droidspaces documents SUSFS as unsupported and identifies global mount hiding
as a container boot failure. This kernel defaults that mode off. The included
SUSFS module is the upstream v1.5.2+ R28 package with the single default
`hide_sus_mnts_for_all_or_non_su_procs=0` change. Keep that option off when
running Droidspaces. Other SUSFS settings retain upstream defaults.

Install the official Droidspaces APK after flashing and grant it root. Its
app installs the backend and requests a reboot. Container boot and networking
still require validation on the actual phone. For Linux 4.19, the project
recommends distributions with systemd older than 258, or an OpenRC distro.

## Updates

Aether's unofficial build path signs with test keys and omits the official
OTA client. Upstream updates require rebasing and rebuilding this branch.
The kernel cache is keyed by all of its source patches and configuration.
