# Aether c2s root build

This branch targets SM-N986B and is based on ArtisanROM Aether v4.0.2. The
branch-specific GitHub Actions workflow compiles the pinned Artisan kernel and
KernelSU Next sources. Its artifact includes the ROM, kernel config, source
revisions and checksums. The boot image is AVB-verified at 61,865,984 bytes.

The KernelSU Next patch backports Artisan's SUSFS integration from
`a4eaa915`, adapting the UID hook to the pinned legacy driver and using
the devpts hook already present in the Artisan kernel. It also carries the SELinux changes from Aether v4.0.2.
SUSFS is built into the kernel. KPM is provided separately by the upstream
KPatch-Next Module v0.0.1. Its boot patch and KPM loading need a device test.

Android Spaces is interpreted here as Android Private Space. This build
retains Artisan's One UI Secure Folder implementation. Profile creation and
unlock still need to be verified on the phone.

Aether's unofficial build path signs the ROM with test keys and omits its
official OTA client. Upstream updates can be brought forward by rebasing the
source branch and validating the new kernel and ROM together.
