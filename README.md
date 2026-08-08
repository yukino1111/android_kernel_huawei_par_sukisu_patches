# Huawei nova 3 (PAR) kernel patches

## What this repository implements

The reproducible source-patch and release home for a personal Huawei nova 3
(`PAR`) kernel based on the pinned LineageOS Kirin 970 Linux 4.9.97 tree. It
integrates the upstream work listed below with PAR-specific adaptation and a
hardware-decoder fix. KPM was investigated, but no stable working integration
could be produced, so release builds do not include KPM. The retained
`research/kpm-failed/` files are non-release experiment records and are not
applied by `scripts/apply.sh`.

## Upstream source base

- LineageOS and Huawei contributors provide the Kirin 970 Linux 4.9.97 base.
- ShirkNeko and the SukiSU Ultra contributors provide SukiSU Ultra 4.1.3.
- simonpunk and the SuSFS contributors provide SuSFS 2.2.0.
- Coconut's (`Coconutat`) Huawei Linux 4.9 SuSFS/KPM backport is the legacy
  Huawei integration starting point; KPM remains disabled in the release.
- Todd Kjos and Android kernel contributors provide the Binder sender
  security-context change used by the Keystore2/Vold backport.

These items are upstream work rather than original changes by yukino1111. The
PAR-specific ownership boundary is recorded in `ATTRIBUTION.md`.

## Disclaimer

This is a personal project shared as-is. Flashing a custom kernel can cause data
loss, boot failure, or a bricked device. You accept all risk and responsibility
for flashing and recovery. No warranty, updates, porting, or device-recovery
support is provided. If you need different behavior, use the published source
and build instructions to compile it yourself.

## Compatibility

- Device: Huawei nova 3 (`PAR`).
- Verified stock firmware base: EMUI `9.0.0.187`.
- An EMUI 9 base is required; other major base versions are likely not to boot.
- Android target: Android 13.

## Build

Clone the kernel and SukiSU revisions listed in [`SOURCE_STATE`](SOURCE_STATE),
then use an AArch64 Android GCC 4.9 toolchain:

```bash
scripts/apply.sh /path/to/kernel /path/to/SukiSU-Ultra
mkdir -p /path/to/out
cp configs/par_susfs2_enforcing.config /path/to/out/.config
make -C /path/to/kernel O=/path/to/out ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- olddefconfig
make -C /path/to/kernel O=/path/to/out ARCH=arm64 CROSS_COMPILE=aarch64-linux-android- -j"$(nproc)"
```

## Installation

Back up the original kernel image and make sure the bootloader is unlocked.
Enter Fastboot mode, then flash the release image to the `kernel` partition:

```bash
fastboot flash kernel KERNEL.img
fastboot reboot
```

## License

Original repository material uses GPL-2.0-only. Upstream-derived patches keep
their original terms, including the separate SuSFS GPL-3.0-or-later scope; see
[`ATTRIBUTION.md`](ATTRIBUTION.md) and [`LICENSES.md`](LICENSES.md).

## Acknowledgements

- The kernel source comes primarily from
  [LineageOS/android_kernel_huawei_kirin970](https://github.com/LineageOS/android_kernel_huawei_kirin970).
- Root support comes from
  [SukiSU Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra) and
  [SuSFS](https://gitlab.com/simonpunk/susfs4ksu).
- SukiSU Ultra is maintained by ShirkNeko; the pinned SuSFS revision is by
  simonpunk. The Huawei Linux 4.9 starting point is Coconut's (`Coconutat`)
  backport, and the Binder security-context change is by Todd Kjos.
- Huawei KernelSU adaptation also referenced
  [xixiaobei-bei/KernelSU_on_Huawei](https://github.com/xixiaobei-bei/KernelSU_on_Huawei)
  and [Coconutat's Huawei GSI and KernelSU tutorial](https://github.com/Coconutat/Huawei-GSI-And-Modify-Or-Support-KernelSU-Tutorial).
