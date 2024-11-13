#!/usr/bin/env bash

set -eufo pipefail

input="$1"
native_bin="$2"
output="$3"

rootdir="/mnt/builder-rootfs"
chcon system_u:object_r:unlabeled_t:s0 "${rootdir}"

tar --extract --xattrs --xattrs-include 'security.*' --directory "${rootdir}" < "$input"
tar --extract --xattrs --xattrs-include 'security.*' --directory "${rootdir}" < "$native_bin"

mount --rbind --make-rprivate /proc "${rootdir}/proc"
mount --rbind --make-rprivate /sys "${rootdir}/sys"
mount --rbind --make-rprivate /dev "${rootdir}/dev"

mkdir "${rootdir}/mnt/builder"
mount --rbind --make-rprivate /opt/builder "${rootdir}/mnt/builder"
PATH="${rootdir}/opt/native_bin:$PATH" chroot "${rootdir}" /mnt/builder/build_chrooted.sh
umount -l "${rootdir}/mnt/builder"
rmdir "${rootdir}/mnt/builder"

for feature in "${features[@]}"; do
	if [ -e "/opt/builder/features/$feature/exec.post" ]; then
		printf 'exec: %s\n' "/opt/builder/features/$feature/exec.post"
		"/opt/builder/features/$feature/exec.post" "${rootdir}" 2>&1 | sed 's/^/  /'
	fi
done

rm -rf "${rootdir}/opt/native_bin"

umount -l "${rootdir}/proc"
umount -l "${rootdir}/sys"
umount -l "${rootdir}/dev"

find "${rootdir}/run" "${rootdir}/tmp" -mindepth 1 -delete
tar --create --mtime="@$BUILDER_TIMESTAMP" --sort name --xattrs --xattrs-include 'security.*' --numeric-owner --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime --transform 's|^\./||' --directory "${rootdir}" . > "$output"

sha256sum "$output"
