#!/usr/bin/env bash

set -eufo pipefail

IFS=',' read -r -a features <<< "$BUILDER_FEATURES"
builder_dir="/mnt/builder"

for feature in "${features[@]}"; do
	if [ -e "${builder_dir}/features/$feature/exec.early" ]; then
		printf 'exec: %s\n' "${builder_dir}/features/$feature/exec.early"
		"${builder_dir}/features/$feature/exec.early" 2>&1 | sed 's/^/  /'
	fi
done

pkg_include="$(mktemp)"
pkg_exclude="$(mktemp)"

for feature in "${features[@]}"; do
	[ ! -e "${builder_dir}/features/$feature/pkg.include" ] || cat "${builder_dir}/features/$feature/pkg.include" >> "$pkg_include" && echo >> "$pkg_include"
	[ ! -e "${builder_dir}/features/$feature/pkg.exclude" ] || cat "${builder_dir}/features/$feature/pkg.exclude" >> "$pkg_exclude" && echo >> "$pkg_include"
done

dir="$(mktemp -d)"

pkg_include_processed="$(mktemp)"
#shellcheck disable=SC2123,SC2030,SC2034
(
	cd "$dir"
	arch="$(dpkg --print-architecture)"
	PATH=""
	set -r
	while read -r line; do
		eval "echo $line"
	done
) < "$pkg_include" | sort > "$pkg_include_processed"
rm "$pkg_include"

pkg_exclude_processed="$(mktemp)"
#shellcheck disable=SC2123,SC2030,SC2034
(
	cd "$dir"
	arch="$(dpkg --print-architecture)"
	PATH=""
	set -r
	while read -r line; do
		eval "echo $line"
	done
) < "$pkg_exclude" | sort > "$pkg_exclude_processed"
rm "$pkg_exclude"

rmdir "$dir"

pkg_list="$(mktemp)"
comm -2 -3 "$pkg_include_processed" "$pkg_exclude_processed" > "$pkg_list"
rm "$pkg_include_processed" "$pkg_exclude_processed"

mapfile -t pkg_array < "$pkg_list"
#shellcheck disable=SC2031
INITRD=No DEBIAN_FRONTEND=noninteractive apt-get install -o DPkg::Path="$PATH" -y --no-install-recommends "${pkg_array[@]}"
rm "$pkg_list"

for feature in "${features[@]}"; do
	if [ -d "${builder_dir}/features/$feature/file.include" ]; then
		cp --recursive --no-target-directory --remove-destination --preserve=mode,link "${builder_dir}/features/$feature/file.include" /
		find "${builder_dir}/features/$feature/file.include" -mindepth 1 -printf '/%P\n' | while read -r file; do
			[ -L "$file" ] || chmod u+rw,go=u-w "$file"
			printf 'included %s\n' "$file"
		done
	fi
done

for feature in "${features[@]}"; do
	if [ -e "${builder_dir}/features/$feature/file.include.stat" ]; then
		sed 's/#.*$//;/^[[:space:]]*$/d' "${builder_dir}/features/$feature/file.include.stat" | while read -r user group perm files; do
			set +f
			shopt -s globstar
			shopt -s nullglob
			for file in $files; do
				old_stat="$(stat -c '%A %U:%G' "$file")"
				chown "$user:$group" "$file"
				chmod "$perm" "$file"
				new_stat="$(stat -c '%A %U:%G' "$file")"
				printf '%s: %s -> %s\n' "$file" "$old_stat" "$new_stat"
			done
		done
	fi
done

for feature in "${features[@]}"; do
	if [ -e "${builder_dir}/features/$feature/exec.config" ]; then
		printf 'exec: %s\n' "${builder_dir}/features/$feature/exec.config"
		"${builder_dir}/features/$feature/exec.config" 2>&1 | sed 's/^/  /'
	fi
done

for feature in "${features[@]}"; do
	if [ -e "${builder_dir}/features/$feature/exec.late" ]; then
		printf 'exec: %s\n' "${builder_dir}/features/$feature/exec.late"
		"${builder_dir}/features/$feature/exec.late" 2>&1 | sed 's/^/  /'
	fi
done

rm_files_list="$(mktemp)"

for feature in "${features[@]}"; do
	if [ -e "${builder_dir}/features/$feature/file.exclude" ]; then
		sed 's/#.*$//;/^[[:space:]]*$/d' "${builder_dir}/features/$feature/file.exclude" | while read -r exclude; do
			set +f
			shopt -s globstar
			shopt -s nullglob
			for file in $exclude; do echo "$file"; done
		done
	fi
done > "$rm_files_list"

xargs rm -rf < "$rm_files_list"
sed 's/^/removed /' "$rm_files_list"
rm "$rm_files_list"
