#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

bin_dir="$(dirname ${BASH_SOURCE})"
base_dir="$(dirname ${bin_dir})"
source_dir="$(pwd)"
target_dir="${source_dir}/.build"

. ${bin_dir}/build_container_workdir.inc

setup_buildah
setup_build_container_workdir

container_cmd=()
container_image=localhost/builder
container_engine=podman

container_run_opts=(
	--memory 4G
	--security-opt seccomp=unconfined
	--security-opt apparmor=unconfined
	--security-opt label=disable
	--read-only
)

use_kms=0
resolve_cname=0

while [ $# -gt 0 ]; do
	case "$1" in
		--container-image)
			container_image="$2"
			shift 2
			;;
		--container-engine)
			container_engine="$2"
			shift 2
			;;
		--container-run-opts)
			declare -a "container_run_opts=($2)"
			shift 2
			;;
		--keep-container)
			BUILD_CONTAINER_CLEANUP="false"
			shift
			;;
		--privileged)
			container_run_opts+=(--privileged)
			container_cmd=(--second-stage)
			shift
			;;
		--kms)
			use_kms=1
			shift
			;;
		--print-container-image)
			printf '%s\n' "$container_image" >&3
			exit 0
			;;
		--resolve-cname)
			resolve_cname=1
			shift
			;;
        --generate-sbom)
            if [ ! $(which syft) ]; then
			    echo "'syft' is not installed to generate SBOM"
			    exit -1
            fi

            generate_sbom=1
			shift
            ;;
		*)
			break
			;;
	esac
done

[ -d "$target_dir" ] || mkdir "$target_dir"

container_mount_opts=(
	-v "${source_dir}/keyring.gpg:/opt/builder/keyring.gpg:ro"
	-v "${target_dir}:/mnt/builder-target"
	-v "${BUILD_CONTAINER_WORKDIR}:/mnt/builder-rootfs"
)

for feature_dir in ${source_dir}/features/*; do
	if [ -d "$feature_dir" ]; then
		container_mount_opts+=(-v "${feature_dir}:/opt/builder/features/$(basename "$feature_dir"):ro")
	fi
done

if [ "$container_image" = localhost/builder ]; then
	"$container_engine" build -t "$container_image" "$base_dir"
fi

repo="$(${source_dir}/get_repo)"
commit="$(${source_dir}/get_commit)"
timestamp="$(${source_dir}/get_timestamp)"
default_version="$(${source_dir}/get_version)"

if [ "$resolve_cname" = 1 ]; then
	arch="$("$container_engine" run --rm "${container_run_opts[@]}" "${container_mount_opts[@]}" "$container_image" dpkg --print-architecture)"
	cname="$("$container_engine" run --rm "${container_run_opts[@]}" "${container_mount_opts[@]}" "$container_image" /opt/builder/parse_features --feature-dir /opt/builder/features --default-arch "$arch" --default-version "$default_version" --cname "$1")"
	short_commit="$(head -c 8 <<< "$commit")"
	echo "$cname-$short_commit" >&3
	exit 0
fi

make_opts=(
	REPO="$repo"
	COMMIT="$commit"
	TIMESTAMP="$timestamp"
	DEFAULT_VERSION="$default_version"
)

if [ "$use_kms" = 1 ]; then
	for e in AWS_DEFAULT_REGION AWS_REGION AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN; do
		if [ -n "${!e-}" ]; then
			make_opts+=("$e=${!e}")
		fi
	done
fi

# Default values which can be overriden via 'build.config' file
tempfs_size=2G

if [[ -f ${source_dir}/build.config ]]; then
	${source_dir}/build.config
fi

make_opts+=("TEMPFS_SIZE=$tempfs_size")

if [ -d ${source_dir}/cert ]; then
	container_mount_opts+=(-v "${source_dir}/cert:/opt/builder/cert:ro")
fi

"$container_engine" run --rm "${container_run_opts[@]}" "${container_mount_opts[@]}" "$container_image" ${container_cmd[@]+"${container_cmd[@]}"} fake_xattr make --no-print-directory -C /opt/builder "${make_opts[@]}" "$@"
commit_build_container_workdir

if [ "$generate_sbom" = 1 ]; then
    oci_archive_generated=$(find ${target_dir} -name "*.oci" -print -quit)
    oci_temp_archive_generated=

    if [ -z ${oci_archive_generated} ]; then
        oci_temp_archive_generated=$(mktemp)
        podman save -o ${oci_temp_archive_generated} --format oci-archive ${BUILD_CONTAINER_ID_COMMITTED}
        oci_archive_generated=${oci_temp_archive_generated}
    fi

    syft oci-archive:${oci_archive_generated} --select-catalogers debian -o spdx-json=${target_dir}/sbom.json

    if [ ${oci_temp_archive_generated} ]; then
        unlink ${oci_temp_archive_generated}
    fi
fi
