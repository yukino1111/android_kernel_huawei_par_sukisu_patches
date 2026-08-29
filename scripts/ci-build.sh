#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
config_name="${1:?usage: $0 enforcing|selinux-switchable WORK_ROOT}"
work_root="${2:?usage: $0 enforcing|selinux-switchable WORK_ROOT}"
state_file="$repo_root/SOURCE_STATE"

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

state_value() {
  sed -n "s/^$1=//p" "$state_file"
}

case "$config_name" in
  enforcing) config_file="$repo_root/configs/par_susfs2_enforcing.config" ;;
  selinux-switchable) config_file="$repo_root/configs/par_susfs2_selinux_switchable.config" ;;
  *) die "unknown config: $config_name" ;;
esac

kernel_commit="$(state_value kernel_commit)"
sukisu_commit="$(state_value sukisu_commit)"
susfs_commit="$(state_value susfs_commit)"
toolchain_commit="$(state_value toolchain_commit)"

mkdir -p "$work_root"
[ -z "$(find "$work_root" -mindepth 1 -maxdepth 1 -print -quit)" ] ||
  die "work root must be empty: $work_root"

fetch_commit() {
  local url=$1 commit=$2 destination=$3
  git init -q "$destination"
  git -C "$destination" remote add origin "$url"
  git -C "$destination" fetch -q --depth=1 origin "$commit"
  git -C "$destination" checkout -q --detach FETCH_HEAD
}

kernel_tree="$work_root/kernel"
sukisu_tree="$work_root/sukisu"
toolchain_tree="$work_root/toolchain"
out_dir="$work_root/out"
dist_dir="$work_root/dist"

fetch_commit "$(state_value kernel_url)" "$kernel_commit" "$kernel_tree"
fetch_commit "$(state_value sukisu_url)" "$sukisu_commit" "$sukisu_tree"
fetch_commit "$(state_value toolchain_url)" "$toolchain_commit" "$toolchain_tree"

"$repo_root/scripts/apply.sh" "$kernel_tree" "$sukisu_tree"

image_tag="par-kernel-ci:${GITHUB_RUN_ID:-local}-${config_name}"
docker build \
  --build-arg "BASE_IMAGE=${BASE_IMAGE:-ubuntu:20.04}" \
  --build-arg "USER_ID=$(id -u)" \
  --build-arg "GROUP_ID=$(id -g)" \
  -t "$image_tag" \
  -f "$repo_root/docker/Dockerfile.par-kernel-ubuntu20" \
  "$repo_root/docker"

mkdir -p "$out_dir" "$dist_dir"
docker run --rm \
  --user "$(id -u):$(id -g)" \
  --volume "$kernel_tree:/workspace/kernel" \
  --volume "$toolchain_tree:/workspace/toolchain:ro" \
  --volume "$out_dir:/workspace/out" \
  --volume "$config_file:/workspace/config:ro" \
  --volume "$repo_root/scripts/build-kernel.sh:/usr/local/bin/build-par-kernel:ro" \
  --env CONFIG_FILE=/workspace/config \
  --env "JOBS=${JOBS:-$(nproc)}" \
  "$image_tag" \
  /usr/local/bin/build-par-kernel

short_sukisu="${sukisu_commit:0:8}"
output="$dist_dir/KERNEL-PAR-${config_name}-sukisu-${short_sukisu}-susfs-${susfs_commit:0:8}.img"
"$repo_root/scripts/package-kernel.sh" \
  "$out_dir/arch/arm64/boot/Image.gz" \
  "$output" \
  "$kernel_tree/tools/mkbootimg"

{
  printf 'kernel_commit=%s\n' "$kernel_commit"
  printf 'sukisu_commit=%s\n' "$sukisu_commit"
  printf 'susfs_commit=%s\n' "$susfs_commit"
  printf 'toolchain_commit=%s\n' "$toolchain_commit"
  printf 'config=%s\n' "$config_name"
  sha256sum "$output"
} > "$dist_dir/build-info.txt"

printf 'pinned output: %s\n' "$output"
