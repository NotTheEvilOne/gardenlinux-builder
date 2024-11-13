#!/usr/bin/env bash
# File to be included

export BUILDAH="${BUILDAH:-}"
export BUILD_CONTAINER_CLEANUP="${BUILD_CONTAINER_CLEANUP:-true}"
export BUILD_CONTAINER_ID="${BUILD_CONTAINER_ID:-}"
export BUILD_CONTAINER_ID_COMMITTED="${BUILD_CONTAINER_ID_COMMITTED:-}"
export BUILD_CONTAINER_NAME="gardenlinux-build"
export BUILD_CONTAINER_WORKDIR="${BUILD_CONTAINER_WORKDIR:-}"

commit_build_container_workdir() {
    reset_build_container_workdir
    BUILD_CONTAINER_ID_COMMITTED=$(${BUILDAH} commit ${BUILD_CONTAINER_NAME})
}

reset_build_container() {
    if [ ! -z ${BUILD_CONTAINER_ID} ]; then
        reset_build_container_workdir

        if [ "${BUILD_CONTAINER_CLEANUP}" == "true" ]; then
            _=$(${BUILDAH} rm ${BUILD_CONTAINER_NAME})
        fi

        BUILD_CONTAINER_ID=""
    fi
}

reset_build_container_workdir() {
    if [ ! -z ${BUILD_CONTAINER_WORKDIR} ]; then
        _=$(${BUILDAH} umount ${BUILD_CONTAINER_ID})
        BUILD_CONTAINER_WORKDIR=""
    fi
}

setup_build_container() {
    if [ -z ${BUILD_CONTAINER_ID} ]; then
        BUILD_CONTAINER_ID=$(${BUILDAH} from --name ${BUILD_CONTAINER_NAME} scratch)
        BUILD_CONTAINER_WORKDIR=""
    fi

    trap 'reset_build_container' EXIT
}

setup_build_container_workdir() {
    setup_build_container

    if [ ! -z ${BUILD_CONTAINER_WORKDIR} ]; then
        echo "Build container workdir already defined"
        exit 1
    fi

    BUILD_CONTAINER_WORKDIR=$(${BUILDAH} mount ${BUILD_CONTAINER_ID})
}

setup_buildah() {
    if [ -z ${BUILDAH} ]; then
        BUILDAH=$(which buildah || echo "Failed determining buildah location"; exit)
    fi
}
