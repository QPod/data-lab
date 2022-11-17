#!/bin/bash
set -xu

export REGISTRY_URL="docker.io"   # docker.io or other registry URL, DOCKER_REGISTRY_USER/DOCKER_REGISTRY_PASSWORD to be set in CI env.
export BUILDKIT_PROGRESS="plain"  # Full logs for CI build.
# DOCKER_REGISTRY_USER and DOCKER_REGISTRY_PASSWORD is required for docker image push, they should be set in CI secrets.

CI_PROJECT_NAME=${GITHUB_REPOSITORY:-"QPod/data-lab"}
CI_PROJECT_BRANCH=${GITHUB_HEAD_REF:-"main"}
CI_PROJECT_SPACE=$(echo "${CI_PROJECT_BRANCH}" | cut -f1 -d'/')

if [ "${CI_PROJECT_BRANCH}" = "main" ] ; then
    # If on the main branch, docker images namespace will be same as CI_PROJECT_NAME's name space
    export CI_PROJECT_NAMESPACE="$(dirname ${CI_PROJECT_NAME})" ;
else
    # not main branch, docker namespace = {CI_PROJECT_NAME's name space} + "0" + {1st substr before / in CI_PROJECT_SPACE}
    export CI_PROJECT_NAMESPACE="$(dirname ${CI_PROJECT_NAME})0${CI_PROJECT_SPACE}" ;
fi

export NAMESPACE=$(echo "${REGISTRY_URL:-"docker.io"}/${CI_PROJECT_NAMESPACE}" | awk '{print tolower($0)}')
echo "--------> CI_PROJECT_NAMESPACE=${CI_PROJECT_NAMESPACE}"
echo "--------> Docker Repo=${NAMESPACE}"

jq '.experimental=true'  /etc/docker/daemon.json > /tmp/daemon.json && sudo mv /tmp/daemon.json /etc/docker/
sudo service docker restart

build_image() {
    echo "$@" ;
    IMG=$1; TAG=$2; FILE=$3; shift 3; VER=$(date +%Y.%m%d.%H%M); WORKDIR="$(dirname $FILE)";
    docker build --squash --compress --force-rm=true -t "${NAMESPACE}/${IMG}:${TAG}" -f "$FILE" --build-arg "BASE_NAMESPACE=${NAMESPACE}" "$@" "${WORKDIR}" ;
    docker tag "${NAMESPACE}/${IMG}:${TAG}" "${NAMESPACE}/${IMG}:${VER}" ;
}

build_image_no_tag() {
    echo "$@" ;
    IMG=$1; TAG=$2; FILE=$3; shift 3; WORKDIR="$(dirname $FILE)";
    docker build --squash --compress --force-rm=true -t "${NAMESPACE}/${IMG}:${TAG}" -f "$FILE" --build-arg "BASE_NAMESPACE=${NAMESPACE}" "$@" "${WORKDIR}" ;
}

build_image_common() {
    echo "$@" ;
    IMG=$1; TAG=$2; FILE=$3; shift 3; VER=$(date +%Y.%m%d.%H%M); WORKDIR="$(dirname $FILE)";
    docker build --compress --force-rm=true -t "${NAMESPACE}/${IMG}:${TAG}" -f "$FILE" --build-arg "BASE_NAMESPACE=${NAMESPACE}" "$@" "${WORKDIR}" ;
    docker tag "${NAMESPACE}/${IMG}:${TAG}" "${NAMESPACE}/${IMG}:${VER}" ;
}

alias_image() {
    IMG_1=$1; TAG_1=$2; IMG_2=$3; TAG_2=$4; shift 4; VER=$(date +%Y.%m%d.%H%M);
    docker tag "${NAMESPACE}/${IMG_1}:${TAG_1}" "${NAMESPACE}/${IMG_2}:${TAG_2}" ;
    docker tag "${NAMESPACE}/${IMG_2}:${TAG_2}" "${NAMESPACE}/${IMG_2}:${VER}" ;
}

push_image() {
    KEYWORD="${1:-second}";
    docker image prune --force && docker images | sort;
    IMAGES=$(docker images | grep "${KEYWORD}" | awk '{print $1 ":" $2}') ;
    echo "$DOCKER_REGISTRY_PASSWORD" | docker login "${REGISTRY_URL}" -u "$DOCKER_REGISTRY_USER" --password-stdin ;
    for IMG in $(echo "${IMAGES}" | tr " " "\n") ;
    do
      docker push "${IMG}";
      status=$?;
      echo "[${status}] Image pushed > ${IMG}";
    done
}

remove_folder() {
    sudo du -h -d1 "$1" || true ;
    sudo rm -rf "$1" || true ;
}

free_diskspace() {
    remove_folder /usr/share/dotnet
    remove_folder /usr/local/lib/android
    # remove_folder /var/lib/docker
    df -h
}
