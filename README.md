# Huawei nova 3 (PAR) kernel patches

Source patches and GitHub Actions builds for the Huawei nova 3 (`PAR`) on the
LineageOS Kirin 970 Linux 4.9.97 kernel base. The target system is Android 13
on an EMUI 9 firmware base.

This branch provides a selectable feature builder using device-tested, pinned
upstream revisions. It uses KernelSU 32629 and SuSFS 2.3.0. KPM is not
included.

## Disclaimer

This is a personal project shared as-is. Flashing a custom kernel can cause
data loss, boot failure, or a bricked device. You accept all risk and
responsibility for flashing and recovery. No warranty, porting, or
device-recovery support is provided.

## Compatibility

- Device: Huawei nova 3 (`PAR`).
- Firmware base: EMUI 9.
- Android target: Android 13.
- Kernel: Linux 4.9.97.

Other devices and other major firmware bases are unsupported.

## Downloads

Device-tested kernel images are published in the
[PAR Android kernel directory on SourceForge](https://sourceforge.net/projects/par-android/files/kernel/).
GitHub Actions artifacts are build candidates and are not releases until they
have been tested on the device.

## GitHub Actions

The `Build pinned feature PAR kernel` workflow lets you select:

- SELinux Enforcing or runtime-switchable SELinux;
- KernelSU, SuSFS, Re-Kernel, DroidSpaces support, NTSync, and Baseband Guard;
- Re-Kernel's separate network wake monitor;
- the network extensions available in this Linux 4.9 tree.

All upstream inputs are fetched at the exact revisions recorded in
[`SOURCE_STATE`](SOURCE_STATE). The resolved revisions used by each build are
also recorded in the artifact's `build-info.txt`.

## Important notes

- The Kirin 970 hardware-decoder fix keeps protected SMMU configuration in the
  secure world.
- Re-Kernel Binder and signal support works independently of its network wake
  monitor. The network wake monitor is known to cause problems on PAR; keep it
  disabled.
- Keep DroidSpaces's optional `/system/bin/droidspaces` convenience symlink
  disabled.
- Baseband Guard is configured not to block the kernel or recovery partitions.
- KPM is excluded from release builds.

## Installation

Back up the current kernel and keep a known-good rollback image. Flash the
downloaded image to the `kernel` partition:

```bash
fastboot flash kernel KERNEL-PAR-*.img
fastboot reboot
```

## License

Original repository material uses GPL-2.0-only. Upstream-derived patches keep
their original terms, including the separate SuSFS GPL-3.0-or-later scope; see
[`ATTRIBUTION.md`](ATTRIBUTION.md) and [`LICENSES.md`](LICENSES.md).

## Acknowledgements

- [LineageOS/android_kernel_huawei_kirin970](https://github.com/LineageOS/android_kernel_huawei_kirin970)
- [SukiSU Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra)
- [KernelSU](https://github.com/tiann/KernelSU)
- [SuSFS](https://gitlab.com/simonpunk/susfs4ksu)
- [Re-Kernel](https://github.com/Sakion-Team/Re-Kernel)
- [DroidSpaces](https://github.com/ravindu644/Droidspaces-OSS)
- [WildKernels kernel patches](https://github.com/WildKernels/kernel_patches)
- [Baseband Guard](https://github.com/vc-teahouse/Baseband-guard)
- [KernelSU_on_Huawei](https://github.com/xixiaobei-bei/KernelSU_on_Huawei)
- [Huawei GSI and KernelSU tutorial](https://github.com/Coconutat/Huawei-GSI-And-Modify-Or-Support-KernelSU-Tutorial)
