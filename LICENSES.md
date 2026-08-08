# License scope

The root `LICENSE` applies GPL-2.0-only to original repository material and
to Linux, Huawei/LineageOS, and pinned SukiSU-derived changes unless a more
specific upstream notice applies.

- `patches/kernel/0002-kirin970-vdec-keep-protected-smr-in-secure-world.patch`
  is derived from the GPL-2.0-only kernel source.
- `patches/sukisu/` is derived from the pinned GPLv2 SukiSU source.
- SuSFS-derived portions of
  `patches/kernel/0001-par-android13-sukisu-susfs2.patch` retain
  GPL-3.0-or-later; that license text is under `LICENSES/`.
- Existing file-level copyright and license notices take precedence.

Original authors and the PAR-specific maintenance boundary are recorded in
`ATTRIBUTION.md`.

Linux identifies the kernel as GPL-2.0-only while the pinned SuSFS upstream
declares GPL-3.0-or-later. This archive preserves both notices and makes no
claim that combining or distributing those portions resolves that license
compatibility question.
