#!/bin/bash

# Env vars caller defines:
#IMAGE="quay.io/myorg/myapp" -- docker image URI to push to
#DOCKERFILE=Dockerfile.custom  -- dockerfile to use (optional)
#CACHE_FROM_LATEST_IMAGE=true  -- build image from cache from latest image (optional)
: ${QUAY_EXPIRE_TIME:="3d"}  # sets a time to expire from when the image is built

# Env vars set by bootstrap.sh:
#IMAGE_TAG="abcd123" -- image tag to push to
#APP_ROOT="/path/to/app/root" -- path to the cloned app repo

# Env vars for local use
CMD_OPTS="-t ${IMAGE}:${IMAGE_TAG}"
set -e

source ${CICD_ROOT}/_common_container_logic.sh

is_pr_or_mr_build() {
    [ -n "$ghprbPullId" ] || [ -n "$gitlabMergeRequestIid" ]
}

is_rhel7_host() {

    local RELEASE_FILE='/etc/redhat-release'

    [ -f "$RELEASE_FILE" ] && grep -q -i "release 7" "$RELEASE_FILE"
}

build() {

    local IMAGE_TAG_LATEST=''
    local DOCKERFILE_PATH="${APP_ROOT}/${DOCKERFILE}"

    if [ ! -f "$DOCKERFILE_PATH" ]; then
        echo "ERROR: Dockerfile '$DOCKERFILE_PATH' not found"
        exit 1
    fi

    if is_pr_or_mr_build; then
        add_expiry_label_to_file "$DOCKERFILE_PATH" "$QUAY_EXPIRE_TIME"
        IMAGE_TAG_LATEST="$(cut -d "-" -f 1,2 <<< $IMAGE_TAG)-latest"
        CMD_OPTS+=" -t ${IMAGE}:${IMAGE_TAG_LATEST} --build-arg TEST_IMAGE=true"
    fi

    if is_rhel7_host; then
        # on RHEL7, use docker
        docker_build
    else
        # on RHEL8 or anything else, use podman
        podman_build
    fi
}

# https://github.com/RedHatInsights/bonfire/issues/291
add_expiry_label_to_file() {

    local FILE="$1"
    local EXPIRE_TIME="$2"
    local LABEL="quay.expires-after=${EXPIRE_TIME}"

    local LINE="LABEL ${LABEL}"

    if ! _file_ends_with_newline "$FILE"; then
        LINE="\n${LINE}"
    fi

    echo -e "${LINE}" >> "$FILE"
}

_file_ends_with_newline() {
    [ $(tail -1 "$1" | wc -l) -ne 0 ]
}

docker_build() {
    if [ "$CACHE_FROM_LATEST_IMAGE" == "true" ]; then
        echo "Attempting to build image using cache"
        {
            set -x
            docker pull "${IMAGE}" &&
            docker build $CMD_OPTS $APP_ROOT -f $APP_ROOT/$DOCKERFILE --cache-from "${IMAGE}"
            set +x
        } || {
            echo "Build from cache failed, attempting build without cache"
            set -x
            docker build $CMD_OPTS $APP_ROOT -f $APP_ROOT/$DOCKERFILE
            set +x
        }
    else
        set -x
        docker build $CMD_OPTS $APP_ROOT -f $APP_ROOT/$DOCKERFILE
        set +x
    fi
    set -x

    docker push "${IMAGE}:${IMAGE_TAG}"
    if  [ ! -z "$IMAGE_TAG_LATEST" ]; then
        docker push "${IMAGE}:${IMAGE_TAG_LATEST}"
    fi
    set +x
}

podman_build() {
    set -x
    podman build -f $APP_ROOT/$DOCKERFILE ${CMD_OPTS} $APP_ROOT
    podman push "${IMAGE}:${IMAGE_TAG}"
    if  [ ! -z "$IMAGE_TAG_LATEST" ]; then
        podman push "${IMAGE}:${IMAGE_TAG_LATEST}"
    fi
    set +x
}

get_tag_data() {

    local token="$1"
    local repository="$2"
    local tag="$3"
    local auth_header="Authorization: Bearer $token"
    local query_url="https://quay.io/api/v1/repository/$repository/tag/?specificTag=$tag&onlyActiveTags=true"

    local response
    local tag_info

    if ! response=$(curl -Ls -H "$auth_header" "$query_url"); then
        echo "Error retrieving tag data from Quay"
        echo "Response: $response"
        return 1
    fi

    tag_info=$(jq '.tags' <<< "$response")

    if [[ 'null' == "$tag_info" ]]; then
        echo "Error retrieving tags info, response: $response"
        return 1
    fi

    echo "$tag_info"
}

tag_already_exists() {

    local tag_data="$1"
    local tags_found

    tags_found=$(jq 'length' <<< "$tag_data")
    [[ "$tags_found" -ne 0 ]]
}

: ${DOCKERFILE:="Dockerfile"}
: ${CACHE_FROM_LATEST_IMAGE:="false"}

# Login to registry with podman/docker
login

if [[ $IMAGE == quay.io/* ]]; then

    # if using quay, check to see if this tag already exists
    echo "checking if image '$IMAGE:$IMAGE_TAG' already exists in quay.io..."
    QUAY_REPO=${IMAGE#"quay.io/"}

    if ! tag_data=$(get_tag_data "$QUAY_API_TOKEN" "$QUAY_REPO" "$IMAGE_TAG"); then
        echo "Error retrieving tag data!"
        echo "$tag_data"
        exit 1
    fi

    # find all non-expired tags
    if tag_already_exists "$tag_data"; then
        echo "$IMAGE:$IMAGE_TAG already present in quay, not rebuilding"
    else
        # image does not yet exist, build and push it
        build
    fi
else
    # if not pushing to quay, always build
    build
fi
