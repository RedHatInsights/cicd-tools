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

cicd_tools::image_builder::get_image_tag() {
    echo -n "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_IMAGE_TAG"
}

cicd_tools::image_builder::build_image() {
  echo "WIP"
}

_set_image_tag() {

  local image_tag
  local commit_hash
  local build_id

  commit_hash=$(cicd_tools::common::get_7_chars_commit_hash)

  if _is_change_request_context; then
    build_id=$(_get_build_id)
    if [ -z "$build_id" ]; then
      cicd_tools::common::err "cannot get build ID from environment"
      return 1
    fi
    image_tag="pr-${build_id}-${commit_hash}"
  else
    image_tag="$commit_hash"
  fi

  CICD_TOOLS_CONTAINER_IMAGE_BUILDER_IMAGE_TAG="$image_tag"
  readonly CICD_TOOLS_CONTAINER_IMAGE_BUILDER_IMAGE_TAG
}

_is_change_request_context() {
    [ -n "$ghprbPullId" ] || [ -n "$gitlabMergeRequestId" ]
}

_get_build_id() {

    local build_id

    if [ -n "$ghprbPullId" ]; then
        build_id="$ghprbPullId"
    elif [ -n "$gitlabMergeRequestId" ]; then
        build_id="$gitlabMergeRequestId"
    else
        build_id=''
    fi

    echo -n "$build_id"
}


_set_image_tag
CICD_TOOLS_CONTAINER_IMAGE_BUILDER_LOADED=0
