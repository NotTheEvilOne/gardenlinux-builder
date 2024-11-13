#!/usr/bin/env bash

set -eufo pipefail

arch="$1"
version="$2"
repo="$3"
keyring="$(realpath "$4")"
output="$5"
rootdir="/mnt/builder-rootfs"

mmdebstrap --mode unshare --keyring "$keyring" --arch "$arch" --variant required --include ca-certificates --skip check/qemu --skip cleanup/apt/lists "$version" "${rootdir}" "$repo"

gpg --keyring "$keyring" --no-default-keyring --export -a > "${rootdir}/etc/apt/trusted.gpg.d/keyring.asc"
echo "deb $repo $version main" > "${rootdir}/etc/apt/sources.list"

find "${rootdir}/proc" "${rootdir}/sys" "${rootdir}/dev" "${rootdir}/run" "${rootdir}/tmp" -mindepth 1 -delete
tar --create --sort name --xattrs --xattrs-include 'security.*' --numeric-owner --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime --transform 's|^\./||' --directory "${rootdir}" . > "$output"
