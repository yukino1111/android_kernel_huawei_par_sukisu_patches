#!/usr/bin/env bash
set -euo pipefail

repo_root="${REPO_ROOT:-/repo}"
kernel_dir="${KERNEL_DIR:-/workspace/kernel}"
toolchain_dir="${TOOLCHAIN_DIR:-/workspace/deps/toolchain}"
out_dir="${OUT_DIR:-/workspace/out}"
dist_dir="${DIST_DIR:-/workspace/dist}"
selinux_mode="${SELINUX_MODE:-enforcing}"
jobs="${JOBS:-$(nproc)}"

enable_ksu="${ENABLE_KSU:-1}"
enable_susfs="${ENABLE_SUSFS:-1}"
enable_rekernel="${ENABLE_REKERNEL:-1}"
enable_network="${ENABLE_NETWORK:-1}"
enable_droidspaces="${ENABLE_DROIDSPACES:-1}"
enable_ntsync="${ENABLE_NTSYNC:-1}"
enable_bbg="${ENABLE_BBG:-1}"

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

set_config() {
  "$kernel_dir/scripts/config" --file "$out_dir/.config" "$@"
}

require_y() {
  grep -qx "CONFIG_$1=y" "$out_dir/.config" ||
    die "CONFIG_$1=y missing from generated config"
}

require_enabled() {
  grep -Eq "^CONFIG_$1=(y|m)$" "$out_dir/.config" ||
    die "CONFIG_$1 is not enabled in generated config"
}

require_disabled() {
  ! grep -Eq "^CONFIG_$1=(y|m)$" "$out_dir/.config" ||
    die "CONFIG_$1 is unexpectedly enabled"
}

case "$selinux_mode" in
  enforcing) config_file="$repo_root/configs/par_susfs2_enforcing.config" ;;
  selinux-switchable) config_file="$repo_root/configs/par_susfs2_selinux_switchable.config" ;;
  *) die "unknown SELinux mode: $selinux_mode" ;;
esac

[[ "$jobs" =~ ^[0-9]+$ ]] && [ "$jobs" -gt 0 ] || die "invalid JOBS: $jobs"
[ -f "$kernel_dir/Makefile" ] || die "kernel tree not found: $kernel_dir"
[ -x "$toolchain_dir/bin/aarch64-linux-android-gcc" ] ||
  die "AArch64 GCC toolchain not found: $toolchain_dir"
[ -f "$config_file" ] || die "config not found: $config_file"

mkdir -p "$out_dir" "$dist_dir"
cp "$config_file" "$out_dir/.config"

if [ "$enable_ksu" = 1 ]; then
  set_config -e KSU
else
  set_config -d KSU
fi

if [ "$enable_susfs" = 1 ]; then
  set_config -e KSU_SUSFS
  for symbol in \
    KSU_SUSFS_SUS_PATH KSU_SUSFS_SUS_MOUNT KSU_SUSFS_SUS_KSTAT \
    KSU_SUSFS_SPOOF_UNAME KSU_SUSFS_ENABLE_LOG \
    KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS \
    KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG KSU_SUSFS_OPEN_REDIRECT \
    KSU_SUSFS_SUS_MAP; do
    set_config -e "$symbol"
  done
else
  set_config -d KSU_SUSFS
fi

if [ "$enable_rekernel" = 1 ]; then
  set_config -e REKERNEL -e REKERNEL_NETWORK
else
  set_config -d REKERNEL -d REKERNEL_NETWORK
fi

if [ "$enable_ntsync" = 1 ]; then
  set_config -e NTSYNC
else
  set_config -d NTSYNC
fi

set_config -d BBG_BLOCK_BOOT -d BBG_BLOCK_RECOVERY
if [ "$enable_bbg" = 1 ]; then
  set_config -e BBG
else
  set_config -d BBG
fi

if [ "$enable_droidspaces" = 1 ]; then
  for symbol in \
    SYSCTL SYSVIPC POSIX_MQUEUE NAMESPACES UTS_NS IPC_NS PID_NS USER_NS \
    NET_NS SECCOMP SECCOMP_FILTER CGROUPS CGROUP_DEVICE MEMCG \
    CGROUP_SCHED FAIR_GROUP_SCHED CGROUP_FREEZER CGROUP_NET_PRIO \
    HW_CGROUP_PIDS DEVTMPFS DEVTMPFS_MOUNT OVERLAY_FS TMPFS_POSIX_ACL \
    TMPFS_XATTR FW_LOADER FW_LOADER_USER_HELPER VETH BRIDGE NETFILTER \
    BRIDGE_NETFILTER NETFILTER_ADVANCED NF_CONNTRACK IP_NF_IPTABLES \
    IP_NF_FILTER NF_NAT NF_TABLES IP_NF_TARGET_MASQUERADE \
    NETFILTER_XT_TARGET_TCPMSS NETFILTER_XT_MATCH_ADDRTYPE \
    NF_CONNTRACK_NETLINK NF_NAT_REDIRECT IP_ADVANCED_ROUTER \
    IP_MULTIPLE_TABLES NF_CONNTRACK_IPV4 NF_NAT_IPV4 IP_NF_NAT; do
    set_config -e "$symbol"
  done
  set_config -d CGROUP_PIDS -d ANDROID_PARANOID_NETWORK
fi

if [ "$enable_network" = 1 ]; then
  for symbol in \
    NET_SCH_FQ NET_SCH_FQ_CODEL NET_SCH_PIE IP_NF_TARGET_TTL \
    IP6_NF_TARGET_HL IP6_NF_MATCH_HL IP_SET IP_SET_BITMAP_IP \
    IP_SET_BITMAP_IPMAC IP_SET_BITMAP_PORT IP_SET_HASH_IP \
    IP_SET_HASH_IPMARK IP_SET_HASH_IPPORT IP_SET_HASH_IPPORTIP \
    IP_SET_HASH_IPPORTNET IP_SET_HASH_MAC IP_SET_HASH_NETPORTNET \
    IP_SET_HASH_NET IP_SET_HASH_NETNET IP_SET_HASH_NETPORT \
    IP_SET_HASH_NETIFACE IP_SET_LIST_SET NETFILTER_XT_SET IP6_NF_NAT \
    IP6_NF_TARGET_MASQUERADE; do
    set_config -e "$symbol"
  done
  set_config --set-val IP_SET_MAX 65534
fi

export PATH="$toolchain_dir/bin:$PATH"
export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-android-
export KBUILD_BUILD_USER=android
export KBUILD_BUILD_HOST=android-build

make -C "$kernel_dir" O="$out_dir" olddefconfig

if [ "$enable_ksu" = 1 ]; then require_y KSU; else require_disabled KSU; fi
if [ "$enable_susfs" = 1 ]; then require_y KSU_SUSFS; else require_disabled KSU_SUSFS; fi
if [ "$enable_rekernel" = 1 ]; then
  require_y REKERNEL
  require_y REKERNEL_NETWORK
else
  require_disabled REKERNEL
fi
if [ "$enable_ntsync" = 1 ]; then require_y NTSYNC; else require_disabled NTSYNC; fi
if [ "$enable_bbg" = 1 ]; then require_y BBG; else require_disabled BBG; fi
require_disabled BBG_BLOCK_BOOT
require_disabled BBG_BLOCK_RECOVERY

if [ "$enable_droidspaces" = 1 ]; then
  for symbol in \
    SYSVIPC POSIX_MQUEUE NAMESPACES UTS_NS IPC_NS PID_NS USER_NS NET_NS \
    SECCOMP SECCOMP_FILTER CGROUPS CGROUP_DEVICE MEMCG CGROUP_SCHED \
    FAIR_GROUP_SCHED CGROUP_FREEZER CGROUP_NET_PRIO HW_CGROUP_PIDS \
    DEVTMPFS DEVTMPFS_MOUNT OVERLAY_FS TMPFS_POSIX_ACL TMPFS_XATTR \
    VETH BRIDGE NETFILTER NF_CONNTRACK IP_NF_IPTABLES IP_NF_FILTER \
    NF_NAT IP_NF_NAT; do
    require_enabled "$symbol"
  done
  require_disabled CGROUP_PIDS
  require_disabled ANDROID_PARANOID_NETWORK
fi

if [ "$enable_network" = 1 ]; then
  for symbol in \
    NET_SCH_FQ NET_SCH_FQ_CODEL NET_SCH_PIE IP_NF_TARGET_TTL \
    IP6_NF_TARGET_HL IP6_NF_MATCH_HL IP_SET IP_SET_HASH_IP \
    IP_SET_HASH_NET NETFILTER_XT_SET IP6_NF_NAT \
    IP6_NF_TARGET_MASQUERADE; do
    require_enabled "$symbol"
  done
fi

make -C "$kernel_dir" O="$out_dir" -j"$jobs"
[ -s "$out_dir/arch/arm64/boot/Image.gz" ] || die "build completed without Image.gz"

feature_tag="ksu${enable_ksu}-susfs${enable_susfs}-rk${enable_rekernel}"
feature_tag+="-net${enable_network}-ds${enable_droidspaces}"
feature_tag+="-ntsync${enable_ntsync}-bbg${enable_bbg}"
output="$dist_dir/KERNEL-PAR-${selinux_mode}-${feature_tag}.img"
"$repo_root/scripts/package-kernel.sh" \
  "$out_dir/arch/arm64/boot/Image.gz" "$output" "$kernel_dir/tools/mkbootimg"
printf '%s\n' "$output" > "$dist_dir/image-path.txt"
