#!/usr/bin/env bash

CICD_TOOLS_IMAGE_BUILDER_LOADED=${CICD_TOOLS_IMAGE_BUILDER_LOADED:-1}

if [[ "$CICD_TOOLS_IMAGE_BUILDER_LOADED" -eq 0 ]]; then
    return 0
fi

if [ -z "$CICD_TOOLS_SCRIPTS_DIR" ]; then
    echo "scripts directory not defined, please load through main.sh script" >&2
    return 1
fi

cicd_tools::debug "loading image builder library"

# TODO: reconsider namespaced variables
CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG=''
readonly CICD_TOOLS_IMAGE_BUILDER_REDHAT_REGISTRY='registry.redhat.io'
readonly CICD_TOOLS_IMAGE_BUILDER_QUAY_REGISTRY='quay.io'
readonly CICD_TOOLS_IMAGE_BUILDER_QUAY_EXPIRE_TIME=${CICD_TOOLS_IMAGE_BUILDER_QUAY_EXPIRE_TIME:-3d}
readonly CICD_TOOLS_IMAGE_BUILDER_QUAY_USER="${CICD_TOOLS_IMAGE_BUILDER_QUAY_USER:-$QUAY_USER}"
readonly CICD_TOOLS_IMAGE_BUILDER_QUAY_PASSWORD="${CICD_TOOLS_IMAGE_BUILDER_QUAY_PASSWORD:-$QUAY_TOKEN}"
readonly CICD_TOOLS_IMAGE_BUILDER_REDHAT_USER="${CICD_TOOLS_IMAGE_BUILDER_REDHAT_USER:-$RH_REGISTRY_USER}"
readonly CICD_TOOLS_IMAGE_BUILDER_REDHAT_PASSWORD="${CICD_TOOLS_IMAGE_BUILDER_REDHAT_PASSWORD:-$RH_REGISTRY_TOKEN}"

cicd_tools::image_builder::get_image_tag() {
  echo -n "$CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG"
}

cicd_tools::image_builder::build() {

# TODO: review params
  local OPTIND OPTARG option image context containerfile additional_tags \
      labels labels_param build_args build_args_param tags tags_param

  while getopts 'b:c:f:i:l:t:' option; do
    case "${option}" in
      b) build_args="${OPTARG}" ;;
      c) context="${OPTARG}" ;;
      f) containerfile="${OPTARG}" ;;
      i) image="${OPTARG}" ;;
      l) labels="${OPTARG}" ;;
      t) additional_tags="${OPTARG}" ;;
      *) cicd_tools::err "cannot handle parameter" && return 1;;
    esac
  done
  # shift $((OPTIND-1))

  containerfile="${containerfile:-Dockerfile}"
  context="${context:-.}"

  if [ -z "$image" ]; then
      cicd_tools::err "you must specify an image name to build with -i"
      return 1
  fi

  if [ ! -r "$containerfile" ]; then
      cicd_tools::err "${containerfile} not found or not readable"
      return 1
  fi

  if cicd_tools::image_builder::is_change_request_context; then
    labels="${labels} $(cicd_tools::image_builder::_get_expiry_label)"
  fi

  for tag in ${CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG} ${additional_tags}; do
    tags="$tags ${image}:${tag}"
  done

  IFS=" " read -r -a labels_param <<< "$(cicd_tools::image_builder::_get_build_param '--label' "$labels")"
  IFS=" " read -r -a build_args_param <<< "$(cicd_tools::image_builder::_get_build_param '--build_arg' "$build_args")"
  IFS=" " read -r -a tags_param <<< "$(cicd_tools::image_builder::_get_build_param '-t' "$tags")"

  if ! cicd_tools::container::cmd build -f "$containerfile" "${tags_param[@]}" \
    "${build_args_param[@]}" "${labels_param[@]}" "$context"; then
    cicd_tools::err "Error building image"
    return 1
  fi
}

cicd_tools::image_builder::_get_build_param() {

  local option_key="$1"
  local raw_params="$2"
  local build_param

  for raw_param in $raw_params; do
      build_param=$(echo -n "${build_param} ${option_key} ${raw_param}")
  done

  echo -n "$build_param"
}

cicd_tools::image_builder::_get_expiry_label() {
  echo "quay.expires-after=${CICD_TOOLS_IMAGE_BUILDER_QUAY_EXPIRE_TIME}"
}

cicd_tools::image_builder::_set_image_tag() {

  local image_tag commit_hash build_id

  commit_hash=$(cicd_tools::common::get_7_chars_commit_hash)

  if cicd_tools::image_builder::is_change_request_context; then
    build_id=$(cicd_tools::image_builder::get_build_id)
    image_tag="pr-${build_id}-${commit_hash}"
  else
    image_tag="$commit_hash"
  fi

  CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG="$image_tag"
  readonly CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAG
}

cicd_tools::image_builder::is_change_request_context() {
  [ -n "$ghprbPullId" ] || [ -n "$gitlabMergeRequestId" ]
}

cicd_tools::image_builder::get_build_id() {

  local build_id

  if [ -n "$ghprbPullId" ]; then
    build_id="$ghprbPullId"
  elif [ -n "$gitlabMergeRequestId" ]; then
    build_id="$gitlabMergeRequestId"
  fi

  echo -n "$build_id"
}

cicd_tools::image_builder::_image_builder_setup() {
  if ! cicd_tools::image_builder::_try_log_in_to_image_registries; then
      cicd_tools::err "Error trying to log into the image registries!"
      return 1
  fi
  cicd_tools::image_builder::_set_image_tag
}

cicd_tools::image_builder::_try_log_in_to_image_registries() {

  if cicd_tools::image_builder::_quay_credentials_found; then
    if ! cicd_tools::image_builder::_log_in_to_quay_registry; then
        cicd_tools::err "Error logging in to Quay.io!"
        return 1
    fi
  fi

  if cicd_tools::image_builder::_redhat_registry_credentials_found; then
    if ! cicd_tools::image_builder::_log_in_to_redhat_registry; then
        cicd_tools::err "Error logging in to Red Hat Registry!"
        return 1
    fi 
  fi
}

cicd_tools::image_builder::_quay_credentials_found() {
  [ -n "$CICD_TOOLS_IMAGE_BUILDER_QUAY_USER" ] && \
    [ -n "$CICD_TOOLS_IMAGE_BUILDER_QUAY_PASSWORD" ]
}

cicd_tools::image_builder::_redhat_registry_credentials_found() {
  [ -n "$CICD_TOOLS_IMAGE_BUILDER_REDHAT_USER" ] && \
    [ -n "$CICD_TOOLS_IMAGE_BUILDER_REDHAT_PASSWORD" ]
}

cicd_tools::image_builder::_log_in_to_container_registry() {

  local username="$1"
  local password="$2"
  local registry="$3"

  cicd_tools::container::cmd login "-u=${username}" "--password-stdin" "$registry" <<< "$password"
}

cicd_tools::image_builder::_log_in_to_quay_registry() {
  cicd_tools::image_builder::_log_in_to_container_registry "$CICD_TOOLS_IMAGE_BUILDER_QUAY_USER" \
    "$CICD_TOOLS_IMAGE_BUILDER_QUAY_PASSWORD" \
    "$CICD_TOOLS_IMAGE_BUILDER_QUAY_REGISTRY"
}

cicd_tools::image_builder::_log_in_to_redhat_registry() {
  cicd_tools::image_builder::_log_in_to_container_registry "$CICD_TOOLS_IMAGE_BUILDER_REDHAT_USER" \
    "$CICD_TOOLS_IMAGE_BUILDER_REDHAT_PASSWORD" \
    "$CICD_TOOLS_IMAGE_BUILDER_REDHAT_REGISTRY"
}

if ! cicd_tools::image_builder::_image_builder_setup; then
  cicd_tools::err "Image builder setup failed!"
  return 1
fi

cicd_tools::debug "Image builder lib loaded"

CICD_TOOLS_IMAGE_BUILDER_LOADED=0
