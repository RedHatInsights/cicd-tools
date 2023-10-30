#!/bin/bash

# helper functions to build container images

if [[ -n "$CICD_IMAGE_BUILDER_MODULE_LOADED" ]]; then
  cicd::log::debug "image builder module already loaded, skipping"
  return 0
fi

if [[ -z "$CICD_LOADER_MODULE_LOADED" ]]; then
  echo "loader module not found, please use 'load_module.sh' to load modules."
  return 1
fi

cicd::log::debug "loading image_builder module"

readonly CICD_IMAGE_BUILDER_LOCAL_BUILD=${CICD_IMAGE_BUILDER_LOCAL_BUILD:-$LOCAL_BUILD}
readonly CICD_IMAGE_BUILDER_REDHAT_REGISTRY='registry.redhat.io'
readonly CICD_IMAGE_BUILDER_QUAY_REGISTRY='quay.io'
readonly CICD_IMAGE_BUILDER_QUAY_EXPIRE_TIME=${CICD_IMAGE_BUILDER_QUAY_EXPIRE_TIME:-3d}
readonly CICD_IMAGE_BUILDER_QUAY_USER="${CICD_IMAGE_BUILDER_QUAY_USER:-$QUAY_USER}"
readonly CICD_IMAGE_BUILDER_QUAY_PASSWORD="${CICD_IMAGE_BUILDER_QUAY_PASSWORD:-$QUAY_TOKEN}"
readonly CICD_IMAGE_BUILDER_REDHAT_USER="${CICD_IMAGE_BUILDER_REDHAT_USER:-$RH_REGISTRY_USER}"
readonly CICD_IMAGE_BUILDER_REDHAT_PASSWORD="${CICD_IMAGE_BUILDER_REDHAT_PASSWORD:-$RH_REGISTRY_TOKEN}"
readonly CICD_IMAGE_BUILDER_DEFAULT_BUILD_CONTEXT='.'
readonly CICD_IMAGE_BUILDER_DEFAULT_CONTAINERFILE_PATH='Dockerfile'

cicd::image_builder::local_build() {
  [[ "$CICD_IMAGE_BUILDER_LOCAL_BUILD" = true ]] || ! cicd::common::is_ci_context
}

cicd::image_builder::build_and_push() {
  cicd::image_builder::build "$@" || return 1
  if ! cicd::image_builder::local_build; then
    cicd::image_builder::push || return 1
  fi
}

cicd::image_builder::build() {

  local containerfile build_context image_name image_tags default_image_name
  declare -a build_params

  containerfile="$(cicd::image_builder::get_containerfile)"
  build_context="$(cicd::image_builder::get_build_context)"
  image_name="$(cicd::image_builder::_get_image_name)" || return 1
  default_image_name=$(cicd::image_builder::get_full_image_name) || return 1

  if ! [[ -r "$containerfile" ]]; then
    cicd::log::err "Containerfile '$containerfile' does not exist or is not readable!"
    return 1
  fi

  build_params=("-f" "$containerfile")
  build_params+=('-t' "$default_image_name")

  for additional_tag in $(cicd::image_builder::get_additional_tags); do
    build_params+=('-t' "${image_name}:${additional_tag}")
  done

  for label in $(cicd::image_builder::get_labels); do
    build_params+=('--label' "${label}")
  done

  for build_arg in $(cicd::image_builder::get_build_args); do
    build_params+=('--build-arg' "${build_arg}")
  done

  build_params+=("$@")

  build_params+=("$build_context")

  if ! cicd::container::cmd build "${build_params[@]}"; then
    cicd::log::err "Error building image"
    return 1
  fi
}

cicd::image_builder::get_containerfile() {

  local containerfile="${CICD_IMAGE_BUILDER_CONTAINERFILE_PATH:-"$CONTAINERFILE_PATH"}"

  if [ -z "$containerfile" ]; then
    containerfile=$CICD_IMAGE_BUILDER_DEFAULT_CONTAINERFILE_PATH
  fi

  echo -n "$containerfile"
}

cicd::image_builder::get_build_context() {

  local build_context="${CICD_IMAGE_BUILDER_BUILD_CONTEXT:-"$BUILD_CONTEXT"}"

  if [ -z "$build_context" ]; then
    build_context="$CICD_IMAGE_BUILDER_DEFAULT_BUILD_CONTEXT"
  fi

  echo -n "$build_context"
}

cicd::image_builder::_get_image_name() {

  local image_name="${CICD_IMAGE_BUILDER_IMAGE_NAME:-$IMAGE_NAME}"

  if [ -z "$image_name" ]; then
    cicd::log::err "Image name not defined, please set IMAGE_NAME environment variable"
    return 1
  fi

  echo -n "$image_name"
}

cicd::image_builder::get_image_tag() {

  local base_tag="${CICD_IMAGE_BUILDER_IMAGE_TAG:-$IMAGE_TAG}"

  if [[ -z "$base_tag" ]]; then
    base_tag=$(cicd::image_builder::get_commit_based_image_tag)
  fi

  cicd::image_builder::_get_context_based_image_tag "$base_tag"
}

cicd::image_builder::get_commit_based_image_tag() {

  local commit_hash

  if ! commit_hash=$(cicd::common::get_7_chars_commit_hash); then
    cicd::log::err "Cannot retrieve commit hash!"
    return 1
  fi

  echo -n "$commit_hash"
}

cicd::image_builder::_get_context_based_image_tag() {

  local base_tag="$1"
  local tag

  if cicd::image_builder::is_change_request_context; then
    build_id=$(cicd::image_builder::get_build_id)
    tag="pr-${build_id}-${base_tag}"
  else
    tag="${base_tag}"
  fi

  echo -n "${tag}"
}

cicd::image_builder::is_change_request_context() {
  [ -n "$ghprbPullId" ] || [ -n "$gitlabMergeRequestId" ]
}

cicd::image_builder::get_build_id() {

  local build_id

  if [ -n "$ghprbPullId" ]; then
    build_id="$ghprbPullId"
  elif [ -n "$gitlabMergeRequestId" ]; then
    build_id="$gitlabMergeRequestId"
  fi

  echo -n "$build_id"
}

cicd::image_builder::get_additional_tags() {

  declare -a configured_tags=("${CICD_IMAGE_BUILDER_ADDITIONAL_TAGS[@]:-${ADDITIONAL_TAGS[@]}}")
  declare -a additional_tags

  if cicd::image_builder::_array_empty "${configured_tags[@]}"; then
    configured_tags=()
  fi

  for tag in "${configured_tags[@]}"; do
    additional_tags+=("$(cicd::image_builder::_get_context_based_image_tag "$tag")")
  done

  echo -n "${additional_tags[@]}"
}

cicd::image_builder::_array_empty() {
  local arr=("$1")

  [[ "${#arr[@]}" -eq 1 && -z "${arr[0]}" ]]
}

cicd::image_builder::get_labels() {

  declare -a labels=("${CICD_IMAGE_BUILDER_LABELS[@]:-${LABELS[@]}}")

  if cicd::image_builder::_array_empty "${labels[@]}"; then
    labels=()
  fi

  if cicd::image_builder::is_change_request_context; then
    labels+=("$(cicd::image_builder::_get_expiry_label)")
  fi

  echo -n "${labels[@]}"
}

cicd::image_builder::_get_expiry_label() {
  echo "quay.expires-after=${CICD_IMAGE_BUILDER_QUAY_EXPIRE_TIME}"
}

cicd::image_builder::get_build_args() {

  declare -a build_args=("${CICD_IMAGE_BUILDER_BUILD_ARGS[@]:-${BUILD_ARGS[@]}}")

  if cicd::image_builder::_array_empty "${build_args[@]}"; then
    build_args=()
  fi

  echo -n "${build_args[@]}"
}

cicd::image_builder::tag() {

  local source_image target_tag image_name
  image_name="$(cicd::image_builder::_get_image_name)" || return 1
  source_image="$(cicd::image_builder::get_full_image_name)" || return 1

  for target_tag in $(cicd::image_builder::get_additional_tags); do
    if ! cicd::container::cmd tag "$source_image" "${image_name}:${target_tag}"; then
      cicd::log::err "Error tagging '$source_image' as '${image_name}:${target_tag}'"
      return 1
    fi
  done
}

cicd::image_builder::push() {

  local image_name image_tag
  image_name="$(cicd::image_builder::_get_image_name)" || return 1
  image_tag=$(cicd::image_builder::get_image_tag) || return 1

  image_tags=("$image_tag")

  for additional_tag in $(cicd::image_builder::get_additional_tags); do
    image_tags+=("$additional_tag")
  done

  for tag in "${image_tags[@]}"; do
    if ! cicd::container::cmd push "${image_name}:${tag}"; then
      cicd::log::err "Error pushing image: '${image_name}:${tag}'"
      return 1
    fi
  done
}

cicd::image_builder::get_full_image_name() {

  local image_name image_tag
  image_name="$(cicd::image_builder::_get_image_name)" || return 1
  image_tag=$(cicd::image_builder::get_image_tag) || return 1

  echo -n "${image_name}:${image_tag}"
}

cicd::image_builder::_module_setup() {

  if ! cicd::image_builder::_try_log_in_to_image_registries; then
    cicd::log::err "Error trying to log into the image registries!"
    return 1
  fi
}

cicd::image_builder::_try_log_in_to_image_registries() {

  if ! cicd::image_builder::local_build; then
    DOCKER_CONFIG="$(mktemp -d)"
    export DOCKER_CONFIG
    echo -n '{}' >"${DOCKER_CONFIG}/config.json"
  fi

  if cicd::image_builder::_quay_credentials_found; then
    if ! cicd::image_builder::_log_in_to_quay_registry; then
      cicd::log::err "Error logging in to Quay.io!"
      return 1
    fi
  fi

  if cicd::image_builder::_redhat_registry_credentials_found; then
    if ! cicd::image_builder::_log_in_to_redhat_registry; then
      cicd::log::err "Error logging in to Red Hat Registry!"
      return 1
    fi
  fi
}

cicd::image_builder::_quay_credentials_found() {
  [ -n "$CICD_IMAGE_BUILDER_QUAY_USER" ] &&
    [ -n "$CICD_IMAGE_BUILDER_QUAY_PASSWORD" ]
}

cicd::image_builder::_log_in_to_quay_registry() {
  cicd::image_builder::_log_in_to_container_registry "$CICD_IMAGE_BUILDER_QUAY_USER" \
    "$CICD_IMAGE_BUILDER_QUAY_PASSWORD" \
    "$CICD_IMAGE_BUILDER_QUAY_REGISTRY"
}

cicd::image_builder::_log_in_to_container_registry() {

  local username="$1"
  local password="$2"
  local registry="$3"

  cicd::container::cmd login "-u=${username}" "--password-stdin" "$registry" <<<"$password"
}

cicd::image_builder::_redhat_registry_credentials_found() {
  [ -n "$CICD_IMAGE_BUILDER_REDHAT_USER" ] &&
    [ -n "$CICD_IMAGE_BUILDER_REDHAT_PASSWORD" ]
}

cicd::image_builder::_log_in_to_redhat_registry() {
  cicd::image_builder::_log_in_to_container_registry "$CICD_IMAGE_BUILDER_REDHAT_USER" \
    "$CICD_IMAGE_BUILDER_REDHAT_PASSWORD" \
    "$CICD_IMAGE_BUILDER_REDHAT_REGISTRY"
}

if ! cicd::image_builder::_module_setup; then
  cicd::log::err "image_builder module setup failed!"
  return 1
fi

cicd::log::debug "image_builder module loaded"
CICD_IMAGE_BUILDER_MODULE_LOADED='true'
