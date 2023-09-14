#!/usr/bin/env bash

CICD_TOOLS_CONTAINER_IMAGE_BUILDER_LOADED=${CICD_TOOLS_CONTAINER_IMAGE_BUILDER_LOADED:-1}

if [[ "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_LOADED" -eq 0 ]]; then
    return 0
fi

if [ -z "$CICD_TOOLS_SCRIPTS_DIR" ]; then
    echo "scripts directory not defined, please load through main.sh script" >&2
    return 1
fi

cicd_tools::debug "loading image builder library"

# TODO: reconsider namespaced variables
CICD_TOOLS_CONTAINER_IMAGE_BUILDER_IMAGE_TAG=''
readonly CICD_TOOLS_CONTAINER_IMAGE_BUILDER_REDHAT_REGISTRY='registry.redhat.io'
readonly CICD_TOOLS_CONTAINER_IMAGE_BUILDER_QUAY_REGISTRY='quay.io'
readonly CICD_TOOLS_CONTAINER_IMAGE_BUILDER_QUAY_EXPIRE_TIME=${CICD_TOOLS_CONTAINER_IMAGE_BUILDER_QUAY_EXPIRE_TIME:-3d}
readonly CICD_TOOLS_CONTAINER_IMAGE_BUILDER_QUAY_USER="${CICD_TOOLS_CONTAINER_IMAGE_BUILDER_QUAY_USER:-$QUAY_USER}"
readonly CICD_TOOLS_CONTAINER_IMAGE_BUILDER_QUAY_PASSWORD="${CICD_TOOLS_CONTAINER_IMAGE_BUILDER_QUAY_PASSWORD:-$QUAY_TOKEN}"
readonly CICD_TOOLS_CONTAINER_IMAGE_BUILDER_REDHAT_USER="${CICD_TOOLS_CONTAINER_IMAGE_BUILDER_REDHAT_USER:-$RH_REGISTRY_USER}"
readonly CICD_TOOLS_CONTAINER_IMAGE_BUILDER_REDHAT_PASSWORD="${CICD_TOOLS_CONTAINER_IMAGE_BUILDER_REDHAT_PASSWORD:-$RH_REGISTRY_TOKEN}"

cicd_tools::image_builder::get_image_tag() {
  echo -n "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_IMAGE_TAG"
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
      cicd_tools::err "you must specify an image name"
      return 1
  fi

  if [ ! -r "$containerfile" ]; then
      cicd_tools::err "${containerfile} not found or not readable"
      return 1
  fi

  if _is_change_request_context; then
    labels="${labels} $(_get_expiry_label)"
  fi


  for tag in ${CICD_TOOLS_CONTAINER_IMAGE_BUILDER_IMAGE_TAG} ${additional_tags}; do
    tags="$tags ${image}:${tag}"
  done

  labels_param="$(_get_build_param '--label' "$labels")"
  build_args_param="$(_get_build_param '--build_arg' "$build_args")"
  tags_param="$(_get_build_param '-t' "$tags")"

# TODO: delete
#  for label in $labels; do
#    labels_param="${labels_param} --label $label"
#  done
#
#  for build_arg in $build_args; do
#    build_args_param="${build_args_param} --build_arg $build_arg"
#  done
#
#  tags="${CICD_TOOLS_CONTAINER_IMAGE_BUILDER_IMAGE_TAG} ${additional_tags}"
#
#  for tag in $tags; do
#    tags_param="$tags_param -t ${image}:${tag}"
#  done

  if ! cicd_tools::container::cmd build -f "$containerfile" $tags_param $build_args_param $labels_param \
      "$context"; then
    cicd_tools::err "Error building image: ${image_name}"
    return 1
  fi
}

_get_build_param() {

  local option_key="$1"
  local raw_params="$2"
  local build_param

  for raw_param in $raw_params; do
    build_param="$build_param "$option_key" $raw_param"
  done

  echo -n "$build_param"
}

_get_expiry_label() {
  echo "--label quay.expires-after=${CICD_TOOLS_CONTAINER_IMAGE_BUILDER_QUAY_EXPIRE_TIME}"
}

_set_image_tag() {

  local image_tag commit_hash build_id

  commit_hash=$(cicd_tools::common::get_7_chars_commit_hash)

  if _is_change_request_context; then
    build_id=$(_get_build_id)
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
  fi

  echo -n "$build_id"
}

_image_builder_setup() {
  _try_log_in_to_image_registries 
  _set_image_tag
}

_try_log_in_to_image_registries() {

  if _quay_credentials_found; then
    _log_in_to_quay
  fi

  if _redhat_registry_credentials_found; then
    _log_in_to_redhat_registry
  fi
}

_quay_credentials_found() {
  [ -n "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_QUAY_USER" ] && \
    [ -n "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_QUAY_PASSWORD" ]
}

_redhat_registry_credentials_found() {
  [ -n "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_REDHAT_USER" ] && \
    [ -n "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_REDHAT_PASSWORD" ]
}

_log_in_to_container_registry() {

  local username="$1"
  local password="$2"
  local registry="$3"

  cicd_tools::container::cmd login "-u=${username}" "--password-stdin" "$registry" <<< "$password"
}

_log_in_to_quay_registry() {
  _log_in_to_container_registry "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_QUAY_USER" \
    "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_QUAY_PASSWORD" \
    "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_QUAY_REGISTRY"
}

_log_in_to_redhat_registry() {
  _log_in_to_container_registry "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_REDHAT_USER" \
    "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_REDHAT_PASSWORD" \
    "$CICD_TOOLS_CONTAINER_IMAGE_BUILDER_REDHAT_REGISTRY"
}

if ! _image_builder_setup; then
  cicd_tools::err "Image builder setup failed!"
  return 1
fi

CICD_TOOLS_CONTAINER_IMAGE_BUILDER_LOADED=0
