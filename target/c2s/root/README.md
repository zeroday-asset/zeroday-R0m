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
as a container boot failure. `susfs-container.patch` is an experimental local
compatibility change: processes in a non-initial PID namespace bypass SUSFS
mount-list filtering and the unmounted-process metadata predicates. Ordinary
Android processes in the initial PID namespace retain their existing behavior.
This applies to every non-initial PID namespace, not a Droidspaces allowlist.
It does not prevent container-visible mounts being inspected from within a
container, and does not change mount ID allocation or namespace creation.

The included SUSFS R28 module is unchanged upstream, including its global
mount-hiding default. The exception is intended to let Linux container processes
see their own mounts while Android apps retain hiding. This combination is
unsupported upstream and needs device validation; a successful compile is not
proof of container boot, nested containers or root hiding. Global hiding off is
an available diagnostic fallback if the experimental exception is insufficient.

Install the official Droidspaces APK after flashing and grant it root. Its
app installs the backend and requests a reboot. Container boot and networking
still require validation on the actual phone. For Linux 4.19, the project
recommends distributions with systemd older than 258, or an OpenRC distro.

Docker/Podman support includes user namespaces, seccomp, keys, cgroup device,
CPU/memory/pids controllers, cgroup BPF, bridge/veth and IPv4/IPv6 iptables/NAT.
The build fails if the required resolved options are missing. Use NAT mode,
a sparse ext4 rootfs image and a current Droidspaces backend. For rootless
containers enable Droidspaces' Allow Sandboxing and install the distribution's
uid/gid mapping helpers and fuse-overlayfs (kernel 4.19 cannot use native
rootless OverlayFS). iptables-legacy is the initial networking choice; older
cgroup implementations may need the cgroupfs driver. Actual Docker and Podman
workloads, networking, storage and resource limits remain untested on N986B.

The build also compares the embedded `/proc/config.gz` data with the resolved
kernel config. It does not spoof a stock configuration. See
[the March 2026 audit](march-droidspaces-audit.md) for the failed Exynos9820
attempt and the limits of what its public history establishes.

## Updates

Aether's unofficial build path signs with test keys and omits the official
OTA client. Upstream updates require rebasing and rebuilding this branch.
The kernel cache is keyed by all of its source patches and configuration.

