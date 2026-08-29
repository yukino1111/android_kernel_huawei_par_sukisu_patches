#!/usr/bin/env bash
set -euo pipefail

image_gz="${1:?usage: $0 Image.gz OUTPUT.img [MKBOOTIMG]}"
output="${2:?usage: $0 Image.gz OUTPUT.img [MKBOOTIMG]}"
mkbootimg="${3:-${MKBOOTIMG:-}}"
partition_size=25165824
stock_cmdline='loglevel=4 initcall_debug=n page_tracker=on unmovable_isolate1=2:192M,3:224M,4:256M printktimer=0xfff0a000,0x534,0x538 androidboot.selinux=enforcing buildvariant=user'

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

[ -s "$image_gz" ] || die "Image.gz not found: $image_gz"
[ -n "$mkbootimg" ] && [ -x "$mkbootimg" ] || die "mkbootimg not executable: $mkbootimg"
[ "$(head -c 2 "$image_gz" | xxd -p)" = 1f8b ] || die 'kernel input is not gzip'

kernel_size="$(stat -c %s "$image_gz")"
[ $((2048 + kernel_size)) -le "$partition_size" ] ||
  die 'kernel payload exceeds the PAR kernel partition'

mkdir -p "$(dirname "$output")"
"$mkbootimg" \
  --kernel "$image_gz" \
  --cmdline "$stock_cmdline" \
  --base 0 \
  --kernel_offset 0x00080000 \
  --ramdisk_offset 0x07c00000 \
  --second_offset 0x00f00000 \
  --tags_offset 0x07a00000 \
  --pagesize 2048 \
  --header_version 1 \
  --os_version 9.0.0 \
  --os_patch_level 2019-04-01 \
  --output "$output"

[ "$(head -c 8 "$output")" = 'ANDROID!' ] || die 'packaged image has no Android boot header'
packed_size="$(od -An -tu4 -j8 -N4 "$output" | tr -d ' ')"
[ "$packed_size" = "$kernel_size" ] || die 'packaged kernel_size does not match Image.gz'
sha256sum "$output"
