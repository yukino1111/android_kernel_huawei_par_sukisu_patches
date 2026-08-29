#!/usr/bin/env bash
set -euo pipefail

kernel_dir="${KERNEL_DIR:-/workspace/kernel}"
toolchain_dir="${TOOLCHAIN_DIR:-/workspace/toolchain}"
out_dir="${OUT_DIR:-/workspace/out}"
config_file="${CONFIG_FILE:?CONFIG_FILE is required}"
jobs="${JOBS:-$(nproc)}"

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

[ -f "$kernel_dir/Makefile" ] || die "kernel tree not found: $kernel_dir"
[ -x "$toolchain_dir/bin/aarch64-linux-android-gcc" ] ||
  die "AArch64 GCC toolchain not found: $toolchain_dir"
[ -f "$config_file" ] || die "kernel config not found: $config_file"
if ! [[ "$jobs" =~ ^[0-9]+$ ]] || [ "$jobs" -lt 1 ]; then
  die "invalid JOBS: $jobs"
fi

export PATH="$toolchain_dir/bin:$PATH"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-android-
export KBUILD_BUILD_USER=android
export KBUILD_BUILD_HOST=android-build

make_args=()
if [ -n "${PAR_KSU_VERSION:-}" ]; then
  make_args+=("KSU_VERSION=$PAR_KSU_VERSION")
fi
if [ -n "${PAR_KSU_VERSION_TAG:-}" ]; then
  make_args+=("VERSION_TAG=$PAR_KSU_VERSION_TAG")
fi
if [ -n "${PAR_KSU_VERSION_FULL:-}" ]; then
  make_args+=("KSU_VERSION_FULL=$PAR_KSU_VERSION_FULL")
fi

mkdir -p "$out_dir"
cp "$config_file" "$out_dir/.config"
make -C "$kernel_dir" O="$out_dir" "${make_args[@]}" olddefconfig

grep -qx 'CONFIG_KSU=y' "$out_dir/.config" || die 'CONFIG_KSU is not enabled'
grep -qx 'CONFIG_KSU_SUSFS=y' "$out_dir/.config" || die 'CONFIG_KSU_SUSFS is not enabled'
grep -qx '# CONFIG_KPM is not set' "$out_dir/.config" || die 'KPM must stay disabled'

make -C "$kernel_dir" O="$out_dir" "${make_args[@]}" -j"$jobs"
[ -s "$out_dir/arch/arm64/boot/Image.gz" ] || die 'build completed without Image.gz'
sha256sum "$out_dir/arch/arm64/boot/Image.gz"
