#!/usr/bin/env bash
# File to be included

export BUILDAH="${BUILDAH:-}"
export BUILD_CONTAINER_CLEANUP="${BUILD_CONTAINER_CLEANUP:-true}"
export BUILD_CONTAINER_ID="${BUILD_CONTAINER_ID:-}"
export BUILD_CONTAINER_NAME="gardenlinux-build"
export BUILD_CONTAINER_WORKDIR="${BUILD_CONTAINER_WORKDIR:-}"

commit_build_container_workdir() {
    reset_build_container_workdir
    ${BUILDAH} commit ${BUILD_CONTAINER_NAME}
}

reset_build_container() {
    if [ ! -z ${BUILD_CONTAINER_ID} ]; then
        reset_build_container_workdir

        if [ "x${BUILD_CONTAINER_CLEANUP}" == "xtrue" ]; then
            ${BUILDAH} rm ${BUILD_CONTAINER_NAME}
        fi

        BUILD_CONTAINER_ID=""
    fi
}

reset_build_container_workdir() {
    if [ ! -z ${BUILD_CONTAINER_WORKDIR} ]; then
        ${BUILDAH} umount ${BUILD_CONTAINER_ID}
        BUILD_CONTAINER_WORKDIR=""
    fi
}

setup_build_container_workdir() {
    if [ -z ${BUILD_CONTAINER_ID} ]; then
        BUILD_CONTAINER_ID=`${BUILDAH} from --name ${BUILD_CONTAINER_NAME} scratch`
        BUILD_CONTAINER_WORKDIR=""
    fi

    if [ ! -z ${BUILD_CONTAINER_WORKDIR} ]; then
        echo "Build container workdir already defined"
        exit 1
    fi

    BUILD_CONTAINER_WORKDIR=`${BUILDAH} mount ${BUILD_CONTAINER_ID}`

    trap 'reset_build_container' EXIT
}

setup_buildah() {
    if [ -z ${BUILDAH} ]; then
        BUILDAH=`which buildah || echo "Failed determining buildah location"; exit`
    fi
}
