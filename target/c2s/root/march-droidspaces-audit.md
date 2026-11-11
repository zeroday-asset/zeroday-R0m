# Ravindu / GoRhanHee Droidspaces integration audit

Reviewed 2026-11-11 for the N986B Aether build. The historical kernel is
Exynos9820/9825 (4.14); our target is Exynos990 (4.19). These are different
kernel trees, so a failure or fix in one is not proof about the other.

## What the public history establishes

- March 12: [PR 12](https://github.com/GoRhanHee/android_kernel_samsung_exynos9820/pull/12)
  merged Ravindu's three changes: remove unsafe live interface-stat reads in
  xt_qtaguid, add cgroup controller-prefix symlinks and enable a Droidspaces
  kernel configuration fragment.
- March 13: [PR 13](https://github.com/GoRhanHee/android_kernel_samsung_exynos9820/pull/13)
  changed `kernel/Makefile` to embed `arch/arm64/configs/stock_defconfig` instead
  of `$(KCONFIG_CONFIG)`. Ravindu describes a userspace error after boot and
  chose an S10 stock config as a workaround. It conceals the changed config;
  it does not implement missing kernel features or fix namespace behavior.
- March 18: GoRhanHee reverted all four changes, in commits
  [fe38c9f](https://github.com/GoRhanHee/android_kernel_samsung_exynos9820/commit/fe38c9fc722880b820583226789558989eb92923),
  [892b147](https://github.com/GoRhanHee/android_kernel_samsung_exynos9820/commit/892b147e912ffdd706adb1e0232fc44a99b15023),
  [384471a](https://github.com/GoRhanHee/android_kernel_samsung_exynos9820/commit/384471a15f2a351b1aada8a3253dfcfffca50b7d)
  and [0e0b570](https://github.com/GoRhanHee/android_kernel_samsung_exynos9820/commit/0e0b5706e0b6fe26648272b32d14a8464366323d).
  The revert messages give no reason. Both PRs have no public discussion/reviews.
- [Issue 14](https://github.com/GoRhanHee/android_kernel_samsung_exynos9820/issues/14)
  reports an internal-problem warning following an update. The maintainer
  acknowledged a kernel issue March 21 and linked a fixed release April 15.
  It contains no kernel log establishing a Droidspaces failure cause.

## An important contemporaneous runtime limitation

Droidspaces added a namespace-blocking seccomp compatibility shield during
March, targeting a `grab_super()` VFS hang on legacy Samsung-era kernels.
Its [March 12 change](https://github.com/ravindu644/Droidspaces-OSS/commit/eed18bc66c938a6e74b093f1545dacb079060ef9)
explicitly warns that this blocks Docker, Podman, LXC and systemd sandboxing.
The [September removal](https://github.com/ravindu644/Droidspaces-OSS/commit/af01153d8032bf2e5f6fcc13d3b0f39d9a42da42)
states that it never reliably fixed the hang. The current documentation requires
a kernel fix rather than blocking namespace creation.

This is a concrete lead about failures in that period, not a proven explanation
for GoRhanHee's rollback. There is no stack trace in the reviewed PRs/issues
tying his specific attempt to `grab_super()`, SUSFS or any individual option.
The daemon mode added later in March also addresses Android-inherited seccomp
restrictions; config flags alone did not resolve every runtime constraint.

## Consequences for the N986B build

1. Keep the useful cgroup prefix change. The xt_qtaguid patch does not apply:
   this pinned Artisan kernel has no `net/netfilter/xt_qtaguid.c`.
2. Do not transplant the fake-stock-config workaround. The pinned Artisan
   Makefile embeds the real config; CI verifies the embedded gzip matches it.
   A Samsung compatibility warning needs its actual userspace diagnostic,
   not fabricated capability reporting.
3. Preserve nested namespace syscalls. The former Deadlock Shield defeats the
   explicit requirement to run Docker and Podman inside Droidspaces.
4. Check Docker's additional resolved options, not only the outer container's
   configuration fragment. Preserve the real generated config as an artifact.
5. Treat global SUSFS mount hiding as a separate, documented incompatibility.
   The experimental PID-namespace exception is our compatibility patch, not a
   historical fix from Ravindu, and is not yet device-validated.

## Evidence still required on the phone

- Start/stop a Linux container repeatedly with global hiding enabled.
- Confirm real container mounts and consistent fd/mountinfo/statfs metadata.
- Exercise nested `unshare`/proc mounts and Docker/Podman workloads, rather than
  merely checking that their version commands execute.
- Test container networking, port publishing, overlay/FUSE storage and resource
  limits; verify ordinary Android app hiding behavior independently.
- If a hang occurs, obtain the blocked-task stack / kernel log before selecting
  a VFS backport. The public March history alone does not identify that patch.
