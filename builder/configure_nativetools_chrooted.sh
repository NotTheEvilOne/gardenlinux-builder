#!/usr/bin/env bash

set -eufo pipefail

mkdir /opt/native_bin

if [ "$#" -gt 0 ]; then
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends patchelf "$@"

	dpkg -L "$@" | grep -F -f <(tr ':' '\n' <<< "$PATH") \
	| while read -r file; do
		[ -f "$file" ] || continue
		new_file="/opt/native_bin/$(basename "$file")"
		[ ! -e "$new_file" ] || continue
		[ "$new_file" != /opt/native_bin/dpkg ] || continue
		if [ -L "$file" ]; then
			link_target="$(basename "$(realpath "$file")")"
			ln -s "$link_target" "$new_file"
		elif interpreter="$(patchelf --print-interpreter "$file" 2> /dev/null)"; then
			cp "$file" "$new_file"
			new_interpreter="/opt/native_bin/$(basename "$interpreter")"
			[ -e "$new_interpreter" ] || cp "$interpreter" "$new_interpreter"
			ldd "$new_file" | grep -oP '(?<=\=\> )/[^ ]+' | grep -vF "$interpreter" \
			| while read -r lib; do\
				new_lib="/opt/native_bin/$(basename "$lib")"
				cp "$lib" "$new_lib"
				patchelf --set-rpath /opt/native_bin "$new_lib"
				echo "$new_lib"
				ldd "$new_lib"
			done
			patchelf --set-interpreter "$new_interpreter" --set-rpath /opt/native_bin "$new_file"
			echo "$new_file"
			ldd "$new_file"
		fi
	done

	find /opt/native_bin -xtype l -delete
fi

tar cf /output /opt/native_bin
