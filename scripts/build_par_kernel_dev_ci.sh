#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
selinux_mode="${1:?usage: $0 enforcing|selinux-switchable WORK_ROOT}"
work_root="${2:?usage: $0 enforcing|selinux-switchable WORK_ROOT}"
state_file="$repo_root/SOURCE_STATE"

enable_ksu="${ENABLE_KSU:-1}"
enable_susfs="${ENABLE_SUSFS:-1}"
enable_rekernel="${ENABLE_REKERNEL:-1}"
enable_rekernel_network="${ENABLE_REKERNEL_NETWORK:-0}"
enable_network="${ENABLE_NETWORK:-1}"
enable_droidspaces="${ENABLE_DROIDSPACES:-1}"
enable_ntsync="${ENABLE_NTSYNC:-1}"
enable_bbg="${ENABLE_BBG:-1}"

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

state_value() {
  sed -n "s/^$1=//p" "$state_file"
}

normalize_bool() {
  case "$1" in
    1|true) printf '1\n' ;;
    0|false) printf '0\n' ;;
    *) die "invalid boolean: $1" ;;
  esac
}

fetch_revision() {
  local url=$1 revision=$2 destination=$3
  git init -q "$destination"
  git -C "$destination" remote add origin "$url"
  git -C "$destination" fetch -q --depth=1 origin "$revision"
  git -C "$destination" checkout -q --detach FETCH_HEAD
}

apply_series() {
  local tree=$1 series=$2
  while IFS= read -r patch; do
    [ -n "$patch" ] || continue
    git -C "$tree" apply "$(dirname "$series")/$patch"
  done < "$series"
}

for variable in \
  enable_ksu enable_susfs enable_rekernel enable_rekernel_network enable_network enable_droidspaces \
  enable_ntsync enable_bbg; do
  printf -v "$variable" '%s' "$(normalize_bool "${!variable}")"
done
[ "$enable_susfs" = 0 ] || [ "$enable_ksu" = 1 ] ||
  die "SuSFS requires KernelSU"
case "$selinux_mode" in enforcing|selinux-switchable) ;; *) die "invalid SELinux mode" ;; esac

mkdir -p "$work_root"
[ -z "$(find "$work_root" -mindepth 1 -maxdepth 1 -print -quit)" ] ||
  die "work root must be empty: $work_root"

kernel_tree="$work_root/kernel"
deps_dir="$work_root/deps"
toolchain_tree="$deps_dir/toolchain"
susfs_tree="$deps_dir/susfs"
ksu_tree="$deps_dir/kernelsu"
rekernel_tree="$deps_dir/rekernel"
droidspaces_tree="$deps_dir/droidspaces"
kernel_patches_tree="$deps_dir/kernel-patches"
bbg_tree="$deps_dir/baseband-guard"
dist_dir="$work_root/dist"
mkdir -p "$deps_dir" "$dist_dir"

fetch_revision "$(state_value kernel_url)" "$(state_value kernel_commit)" "$kernel_tree"
fetch_revision "$(state_value toolchain_url)" "$(state_value toolchain_commit)" "$toolchain_tree"
fetch_revision "$(state_value susfs_dev_url)" "$(state_value susfs_dev_ref)" "$susfs_tree"

apply_series "$kernel_tree" "$repo_root/patches/kernel/series"
git -C "$kernel_tree" apply \
  "$repo_root/patches/dev/kernel/0006-par-hisi-pagecache-memcg-compat.patch"
cp "$susfs_tree/kernel_patches/fs/susfs.c" "$kernel_tree/fs/susfs.c"
cp "$susfs_tree/kernel_patches/include/linux/susfs.h" "$kernel_tree/include/linux/susfs.h"
cp "$susfs_tree/kernel_patches/include/linux/susfs_def.h" "$kernel_tree/include/linux/susfs_def.h"
git -C "$kernel_tree" apply \
  "$repo_root/patches/dev/kernel/0005-par-susfs-fsnotify-4.9-compat.patch"

if [ "$enable_ksu" = 1 ]; then
  fetch_revision "$(state_value kernelsu_dev_url)" "$(state_value kernelsu_dev_ref)" "$ksu_tree"
  git -C "$ksu_tree" apply \
    "$susfs_tree/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch"
  apply_series "$ksu_tree" "$repo_root/patches/dev/kernelsu/series"
  ln -s ../../deps/kernelsu/kernel "$kernel_tree/drivers/kernelsu"
fi

if [ "$enable_rekernel" = 1 ]; then
  fetch_revision "$(state_value rekernel_url)" "$(state_value rekernel_ref)" "$rekernel_tree"
  placeholder="$kernel_tree/arch/arm64/configs/defconfig"
  [ -e "$placeholder" ] || : > "$placeholder"
  (cd "$kernel_tree" && bash "$rekernel_tree/Integrate/patches.sh")
  rm -f "$placeholder"
  [ -f "$kernel_tree/drivers/rekernel/rekernel.c" ] || die "Re-Kernel integration failed"
  grep -q 'CONFIG_REKERNEL' "$kernel_tree/drivers/android/binder.c" ||
    die "Re-Kernel Binder integration failed"
  grep -q 'CONFIG_REKERNEL' "$kernel_tree/kernel/signal.c" ||
    die "Re-Kernel signal integration failed"
  git -C "$kernel_tree" apply \
    "$repo_root/patches/dev/kernel/0002-par-rekernel-4.9-compat.patch"
fi

if [ "$enable_droidspaces" = 1 ]; then
  fetch_revision "$(state_value droidspaces_url)" "$(state_value droidspaces_ref)" "$droidspaces_tree"
  git -C "$kernel_tree" apply \
    "$droidspaces_tree/Documentation/resources/kernel-patches/non-GKI/01.fix_kernel_panic_in_xt_qtaguid.patch"
  git -C "$kernel_tree" apply \
    "$repo_root/patches/dev/kernel/0004-par-droidspaces-cgroup-v1-compat.patch"
fi

if [ "$enable_ntsync" = 1 ]; then
  fetch_revision "$(state_value kernel_patches_url)" "$(state_value kernel_patches_ref)" "$kernel_patches_tree"
  git -C "$kernel_tree" apply "$kernel_patches_tree/common/ntsync/ntsync_base.patch"
  git -C "$kernel_tree" apply \
    "$repo_root/patches/dev/kernel/0003-par-ntsync-4.9-compat.patch"
fi

if [ "$enable_bbg" = 1 ]; then
  fetch_revision "$(state_value baseband_guard_url)" "$(state_value baseband_guard_ref)" "$bbg_tree"
  apply_series "$bbg_tree" "$repo_root/patches/dev/baseband-guard/series"
  ln -s ../deps/baseband-guard "$kernel_tree/Baseband-guard"
  (cd "$kernel_tree" && sh Baseband-guard/setup.sh "$(git -C "$bbg_tree" rev-parse HEAD)")
fi

git -C "$kernel_tree" apply \
  "$repo_root/patches/dev/kernel/0001-par-ksu-susfs-4.9-compat.patch"

image_tag="par-kernel-dev:${GITHUB_RUN_ID:-local}-${selinux_mode}"
docker build \
  --build-arg "BASE_IMAGE=${BASE_IMAGE:-ubuntu:20.04}" \
  --build-arg "USER_ID=$(id -u)" \
  --build-arg "GROUP_ID=$(id -g)" \
  -t "$image_tag" \
  -f "$repo_root/docker/Dockerfile.par-kernel-ubuntu20" \
  "$repo_root/docker"

docker run --rm \
  --user "$(id -u):$(id -g)" \
  --volume "$work_root:/workspace" \
  --volume "$repo_root:/repo:ro" \
  --env REPO_ROOT=/repo \
  --env SELINUX_MODE="$selinux_mode" \
  --env ENABLE_KSU="$enable_ksu" \
  --env ENABLE_SUSFS="$enable_susfs" \
  --env ENABLE_REKERNEL="$enable_rekernel" \
  --env ENABLE_REKERNEL_NETWORK="$enable_rekernel_network" \
  --env ENABLE_NETWORK="$enable_network" \
  --env ENABLE_DROIDSPACES="$enable_droidspaces" \
  --env ENABLE_NTSYNC="$enable_ntsync" \
  --env ENABLE_BBG="$enable_bbg" \
  --env "JOBS=${JOBS:-$(nproc)}" \
  "$image_tag" \
  /repo/scripts/build_par_kernel_dev.sh

image_path="$(cat "$dist_dir/image-path.txt")"
case "$image_path" in
  /workspace/dist/*) image_path="$dist_dir/${image_path##*/}" ;;
esac
rm -f "$dist_dir/image-path.txt"
{
  printf 'development_build=1\n'
  printf 'kernel_commit=%s\n' "$(git -C "$kernel_tree" rev-parse HEAD)"
  printf 'toolchain_commit=%s\n' "$(git -C "$toolchain_tree" rev-parse HEAD)"
  printf 'susfs_dev_commit=%s\n' "$(git -C "$susfs_tree" rev-parse HEAD)"
  [ "$enable_ksu" = 0 ] || printf 'kernelsu_dev_commit=%s\n' "$(git -C "$ksu_tree" rev-parse HEAD)"
  [ "$enable_rekernel" = 0 ] || printf 'rekernel_commit=%s\n' "$(git -C "$rekernel_tree" rev-parse HEAD)"
  [ "$enable_droidspaces" = 0 ] || printf 'droidspaces_dev_commit=%s\n' "$(git -C "$droidspaces_tree" rev-parse HEAD)"
  [ "$enable_ntsync" = 0 ] || printf 'kernel_patches_commit=%s\n' "$(git -C "$kernel_patches_tree" rev-parse HEAD)"
  [ "$enable_bbg" = 0 ] || printf 'baseband_guard_commit=%s\n' "$(git -C "$bbg_tree" rev-parse HEAD)"
  printf 'selinux_mode=%s\n' "$selinux_mode"
  printf 'enable_ksu=%s\n' "$enable_ksu"
  printf 'enable_susfs=%s\n' "$enable_susfs"
  printf 'enable_rekernel=%s\n' "$enable_rekernel"
  printf 'enable_rekernel_network=%s\n' "$enable_rekernel_network"
  printf 'enable_network=%s\n' "$enable_network"
  printf 'enable_droidspaces=%s\n' "$enable_droidspaces"
  if [ "$enable_droidspaces" = 1 ]; then
    printf 'hisi_pagecache_helper=disabled-for-memcg\n'
  else
    printf 'hisi_pagecache_helper=stock-config\n'
  fi
  printf 'enable_ntsync=%s\n' "$enable_ntsync"
  printf 'enable_bbg=%s\n' "$enable_bbg"
  printf 'unicode_hardening=unsupported-linux-4.9-no-fs-unicode\n'
  printf 'network_unsupported=CAKE,FQ_PIE,IP_SET_HASH_IPMAC\n'
  sha256sum "$image_path"
} > "$dist_dir/build-info.txt"

printf 'development output: %s\n' "$image_path"
