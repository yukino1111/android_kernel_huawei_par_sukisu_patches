# Huawei nova 3 (PAR) kernel patches

Source patches and GitHub Actions builds for the Huawei nova 3 (`PAR`) on the
LineageOS Kirin 970 Linux 4.9.97 kernel base. The target system is Android 13
on an EMUI 9 firmware base.

This branch provides pinned SukiSU Ultra 4.1.3 and SuSFS 2.2.0 builds. KPM is
not included.

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

The `Build pinned PAR kernel` workflow builds:

- a strict SELinux Enforcing image;
- a runtime-switchable SELinux image;
- SukiSU Ultra 4.1.3 with SuSFS 2.2.0.

Both images use the revisions recorded in [`SOURCE_STATE`](SOURCE_STATE). The
workflow is manual-only and does not run on source pushes or a schedule.

## Important notes

- The runtime-switchable build enables `CONFIG_SECURITY_SELINUX_DEVELOP`; the
  strict Enforcing build does not.
- The Kirin 970 hardware-decoder fix keeps protected SMMU configuration in the
  secure world.
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
- [SuSFS](https://gitlab.com/simonpunk/susfs4ksu)
- [KernelSU_on_Huawei](https://github.com/xixiaobei-bei/KernelSU_on_Huawei)
- [Huawei GSI and KernelSU tutorial](https://github.com/Coconutat/Huawei-GSI-And-Modify-Or-Support-KernelSU-Tutorial)
