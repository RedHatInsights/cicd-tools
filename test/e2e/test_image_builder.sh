#!/usr/bin/env bash

# Mock functions
podman() {
    echo -n "$@"
}

git() {
    echo -n "abcdef1"
}

CICD_TOOLS_IMAGE_BUILDER_CONTAINER_FILE='test/data/Containerfile.test'
IMAGE_REPOSITORY='quay.io/awesome_repo/awesome/app'
MAIN_SCRIPT='./src/main.sh'

source "$MAIN_SCRIPT" "image_builder"

EXPECTED_OUTPUT=$(cicd::image_builder::build_and_push)

if ! [ "build -f ${CICD_TOOLS_IMAGE_BUILDER_CONTAINER_FILE} -t ${IMAGE_REPOSITORY}:abcdef1 ." = "$EXPECTED_OUTPUT" ]; then
    echo "Build and Push script not working!"
    exit 1
fi

unset podman


cicd::image_builder::build_and_push
