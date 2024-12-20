#!/usr/bin/env bash

set -eufo pipefail

input="$1"
output="$2"
shift 2

touch "$output"

chroot_dir="$(mktemp -d)"
mount -t tmpfs -o size="$TEMPFS_SIZE" tmpfs "$chroot_dir"
chmod 755 "$chroot_dir"
chcon system_u:object_r:unlabeled_t:s0 "$chroot_dir"

tar --extract --xattrs --xattrs-include 'security.*' --directory "$chroot_dir" < "$input"

mount --rbind --make-rprivate /proc "$chroot_dir/proc"
mount --rbind --make-rprivate /proc "$chroot_dir/sys"
mount --rbind --make-rprivate /dev "$chroot_dir/dev"

mkdir "$chroot_dir/mnt/builder"
mount --rbind --make-rprivate /opt/builder "$chroot_dir/mnt/builder"
touch "$chroot_dir/output"
mount --bind "$output" "$chroot_dir/output"
chroot "$chroot_dir" /mnt/builder/configure_nativetools_chrooted.sh "$@"
umount "$chroot_dir/output"
umount -l "$chroot_dir/mnt/builder"

umount -l "$chroot_dir/proc"
umount -l "$chroot_dir/sys"
umount -l "$chroot_dir/dev"

umount "$chroot_dir"
rmdir "$chroot_dir"
