#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
kernel_tree="${1:?usage: $0 KERNEL_TREE SUKISU_TREE}"
sukisu_tree="${2:?usage: $0 KERNEL_TREE SUKISU_TREE}"
kernel_commit="$(sed -n 's/^kernel_commit=//p' "$repo_root/SOURCE_STATE")"
sukisu_commit="$(sed -n 's/^sukisu_commit=//p' "$repo_root/SOURCE_STATE")"

for tree in "$kernel_tree" "$sukisu_tree"; do
  git -C "$tree" rev-parse --is-inside-work-tree >/dev/null
  test -z "$(git -C "$tree" status --porcelain --untracked-files=all)" || {
    echo "worktree is not clean: $tree" >&2
    exit 2
  }
done

test "$(git -C "$kernel_tree" rev-parse HEAD)" = "$kernel_commit"
test "$(git -C "$sukisu_tree" rev-parse HEAD)" = "$sukisu_commit"
test ! -e "$kernel_tree/drivers/kernelsu"

while IFS= read -r patch; do
  git -C "$sukisu_tree" apply --whitespace=nowarn "$repo_root/patches/sukisu/$patch"
done < "$repo_root/patches/sukisu/series"

mkdir -p "$kernel_tree/drivers/kernelsu"
cp -a "$sukisu_tree/kernel/." "$kernel_tree/drivers/kernelsu/"

while IFS= read -r patch; do
  git -C "$kernel_tree" apply --whitespace=nowarn "$repo_root/patches/kernel/$patch"
done < "$repo_root/patches/kernel/series"

echo "Patches applied. No commit was created."
