# Source attribution

This repository is a port and patch archive. Importing or rebasing upstream
code does not transfer authorship to the repository maintainer.

## Required upstream work

| Area | Upstream author or project | Use in this repository |
| --- | --- | --- |
| Linux 4.9.97 Kirin 970 base | LineageOS and Huawei kernel contributors | Exact base revision recorded in `SOURCE_STATE` |
| SukiSU Ultra 4.1.3 | ShirkNeko and SukiSU Ultra contributors | Root implementation at pinned commit `b1d534bc41941b2c818d7a1a1dac341e4aabfc2d` |
| SuSFS 2.2.0 | simonpunk and SuSFS contributors | Filesystem-hiding implementation at pinned commit `ee7dc7a03b7c836952cce55c5f3834de62a465d1` |
| Huawei Linux 4.9 SuSFS/KPM backport | Coconut (`Coconutat`) | Starting point for the legacy-kernel and Huawei compatibility portions of `patches/kernel/0001-par-android13-sukisu-susfs2.patch`; the released config still disables KPM |
| Binder sender security-context support | Todd Kjos / Android kernel contributors | Android Binder security-context change backported into the aggregate kernel patch for Keystore2 and Vold |
| Huawei KernelSU references | xixiaobei-bei and Coconut (`Coconutat`) | Reference implementations used during the Huawei port |

The Binder work is based on Android common kernel commit
`3d5885175b90e5059a0ff3dcbe3ba93de9c8ff6f` (original upstream commit
`ec74136ded792deed80780d5fb8b557af1327d36`).

These upstream portions are required by the released Android 13/SukiSU/SuSFS
combination and are therefore retained with their original attribution and
licenses. Files under `research/kpm-failed/` are retained only as failed
experiment records: they are excluded from `scripts/apply.sh`, the formal
patch series, release images, and the list of implemented features.

The formal aggregate patch retains compatibility code inherited from
Coconut's combined SuSFS/KPM backport. Retaining that source is not a claim
that KPM is enabled or working: `CONFIG_KPM` is disabled in the published
release configuration.

## PAR-specific work

The following integration and validated device fixes are maintained by
yukino1111:

- adaptation of the pinned SukiSU and SuSFS revisions to this exact Huawei
  Kirin 970 Linux 4.9.97 tree and reproducible configuration;
- Huawei policydb, legacy-kernel API, build, GPT/AVB, and Android 13 integration
  needed by the published PAR image;
- the UID authorization guard added to SukiSU `sucompat`;
- the Kirin 970 VDEC protected-SMR fix in
  `0002-kirin970-vdec-keep-protected-smr-in-secure-world.patch`.

This local maintenance does not claim authorship of SukiSU, SuSFS, Linux,
Huawei, LineageOS, or the referenced Android Binder implementation.
