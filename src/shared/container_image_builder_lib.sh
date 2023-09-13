#!/usr/bin/env bash

CICD_TOOLS_CONTAINER_IMAGE_BUILDER_LOADED=${CICD_TOOLS_CONTAINER_IMAGE_BUILDER_LOADED:-1}

if [[ "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_LOADED" -eq 0 ]]; then
    return 0
fi

# TODO: consider remove
if [ -z "$CICD_TOOLS_SCRIPTS_DIR" ]; then
    echo "scripts directory not defined, please load through main.sh script"
    return 1
fi

# shellcheck source=src/shared/container-engine-lib.sh
source "${CICD_TOOLS_SCRIPTS_DIR}/shared/container_engine_lib.sh"

if _debug_mode; then
    echo "loading build container images"
fi

CICD_TOOLS_CONTAINER_IMAGE_BUILDER_IMAGE_TAG=''

cicd_tools::build_container_images::get_image_tag() {
    echo -n "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_IMAGE_TAG"
}

cicd_tools::build_container_images::build_image() {
  echo "WIP"
}

CICD_TOOLS_CONTAINER_IMAGE_BUILDER_LOADED=0
