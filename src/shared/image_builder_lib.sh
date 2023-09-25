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

readonly CICD_TOOLS_IMAGE_BUILDER_REDHAT_REGISTRY='registry.redhat.io'
readonly CICD_TOOLS_IMAGE_BUILDER_QUAY_REGISTRY='quay.io'
readonly CICD_TOOLS_IMAGE_BUILDER_QUAY_EXPIRE_TIME=${CICD_TOOLS_IMAGE_BUILDER_QUAY_EXPIRE_TIME:-3d}
readonly CICD_TOOLS_IMAGE_BUILDER_QUAY_USER="${CICD_TOOLS_IMAGE_BUILDER_QUAY_USER:-$QUAY_USER}"
readonly CICD_TOOLS_IMAGE_BUILDER_QUAY_PASSWORD="${CICD_TOOLS_IMAGE_BUILDER_QUAY_PASSWORD:-$QUAY_TOKEN}"
readonly CICD_TOOLS_IMAGE_BUILDER_REDHAT_USER="${CICD_TOOLS_IMAGE_BUILDER_REDHAT_USER:-$RH_REGISTRY_USER}"
readonly CICD_TOOLS_IMAGE_BUILDER_REDHAT_PASSWORD="${CICD_TOOLS_IMAGE_BUILDER_REDHAT_PASSWORD:-$RH_REGISTRY_TOKEN}"
readonly CICD_TOOLS_IMAGE_BUILDER_DEFAULT_BUILD_CONTEXT='.'
readonly CICD_TOOLS_IMAGE_BUILDER_DEFAULT_CONTAINERFILE_PATH='Dockerfile'

cicd_tools::image_builder::build_and_push() {
  cicd_tools::image_builder::build || return 1
  if cicd_tools::image_builder::is_change_request_context; then
    cicd_tools::image_builder::push || return 1
  fi
}

cicd_tools::image_builder::build() {

  local containerfile build_context image_name image_tags default_image_name
  declare -a label_params image_tag_params build_arg_params

  containerfile="$(cicd_tools::image_builder::get_containerfile)"
  build_context="$(cicd_tools::image_builder::get_build_context)"
  image_name="$(cicd_tools::image_builder::_get_image_name)" || return 1
  default_image_name=$(cicd_tools::image_builder::get_full_image_name) || return 1

  if ! [ -r "$containerfile" ]; then
    cicd_tools::err "Containerfile '$containerfile' does not exist or is not readable!"
    return 1
  fi

  image_tag_params=('-t' "$default_image_name")

  if ! cicd_tools::image_builder::is_change_request_context; then
    for additional_tag in $(cicd_tools::image_builder::get_additional_tags); do
      image_tag_params+=('-t' "${image_name}:${additional_tag}")
    done
  fi

  for label in $(cicd_tools::image_builder::get_labels); do
    label_params+=('--label' "${label}")
  done

  for build_arg in $(cicd_tools::image_builder::get_build_args); do
    build_arg_params+=('--build-arg' "${build_arg}")
  done

  if ! cicd_tools::container::cmd build -f "$containerfile" "${image_tag_params[@]}" \
    "${build_arg_params[@]}" "${label_params[@]}" "$build_context"; then
    cicd_tools::err "Error building image"
    return 1
  fi
}

cicd_tools::image_builder::get_containerfile() {

  local containerfile="${CICD_TOOLS_IMAGE_BUILDER_CONTAINERFILE_PATH:-"$CONTAINERFILE_PATH"}"

  if [ -z "$containerfile" ]; then
    containerfile=$CICD_TOOLS_IMAGE_BUILDER_DEFAULT_CONTAINERFILE_PATH
  fi

  echo -n "$containerfile"
}

cicd_tools::image_builder::get_build_context() {

  local build_context="${CICD_TOOLS_IMAGE_BUILDER_BUILD_CONTEXT:-"$BUILD_CONTEXT"}"

  if [ -z "$build_context" ]; then
    build_context="$CICD_TOOLS_IMAGE_BUILDER_DEFAULT_BUILD_CONTEXT"
  fi

  echo -n "$build_context"
}

cicd_tools::image_builder::_get_image_name() {

  local image_name="${CICD_TOOLS_IMAGE_BUILDER_IMAGE_NAME:-$IMAGE_NAME}"

  if [ -z "$image_name" ]; then
    cicd_tools::err "Image name not defined, please set IMAGE_NAME environment variable"
    return 1
  fi

  echo -n "$image_name"
}

cicd_tools::image_builder::get_image_tag() {

  local commit_hash build_id tag

  if ! commit_hash=$(cicd_tools::common::get_7_chars_commit_hash); then
    cicd_tools::err "Cannot retrieve commit hash!"
    return 1
  fi

  if cicd_tools::image_builder::is_change_request_context; then
    build_id=$(cicd_tools::image_builder::get_build_id)
    tag="pr-${build_id}-${commit_hash}"
  else
    tag="${commit_hash}"
  fi

  echo -n "${tag}"
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

cicd_tools::image_builder::get_additional_tags() {

  declare -a additional_tags=("${CICD_TOOLS_IMAGE_BUILDER_ADDITIONAL_TAGS[@]:-${ADDITIONAL_TAGS[@]}}")

  if cicd_tools::image_builder::_array_empty "${additional_tags[@]}"; then
    additional_tags=()
  fi

  echo -n "${additional_tags[@]}"
}

cicd_tools::image_builder::_array_empty() {
  local arr=("$1")

  [[ "${#arr[@]}" -eq 1 && -z "${arr[0]}" ]]
}

cicd_tools::image_builder::get_labels() {

  declare -a labels=("${CICD_TOOLS_IMAGE_BUILDER_LABELS[@]:-${LABELS[@]}}")

  if cicd_tools::image_builder::_array_empty "${labels[@]}"; then
    labels=()
  fi

  if cicd_tools::image_builder::is_change_request_context; then
    labels+=("$(cicd_tools::image_builder::_get_expiry_label)")
  fi

  echo -n "${labels[@]}"
}

cicd_tools::image_builder::_get_expiry_label() {
  echo "quay.expires-after=${CICD_TOOLS_IMAGE_BUILDER_QUAY_EXPIRE_TIME}"
}

cicd_tools::image_builder::get_build_args() {

  declare -a build_args=("${CICD_TOOLS_IMAGE_BUILDER_BUILD_ARGS[@]:-${BUILD_ARGS[@]}}")

  if cicd_tools::image_builder::_array_empty "${build_args[@]}"; then
    build_args=()
  fi

  echo -n "${build_args[@]}"
}

cicd_tools::image_builder::tag() {

  local source_image target_tag image_name
  image_name="$(cicd_tools::image_builder::_get_image_name)" || return 1
  source_image="$(cicd_tools::image_builder::get_full_image_name)" || return 1

  for target_tag in $(cicd_tools::image_builder::get_additional_tags); do
    if ! cicd_tools::container::cmd tag "$source_image" "${image_name}:${target_tag}"; then
      cicd_tools::err "Error tagging '$source_image' as '${image_name}:${target_tag}'"
      return 1
    fi
  done
}

cicd_tools::image_builder::push() {

  local image_name image_tag
  image_name="$(cicd_tools::image_builder::_get_image_name)" || return 1
  image_tag=$(cicd_tools::image_builder::get_image_tag) || return 1

  image_tags=("$image_tag")

  if ! cicd_tools::image_builder::is_change_request_context; then
    for additional_tag in $(cicd_tools::image_builder::get_additional_tags); do
      image_tags+=("${additional_tag}")
    done
  fi

  for tag in "${image_tags[@]}"; do
    if ! cicd_tools::container::cmd push "${image_name}:${tag}"; then
      cicd_tools::err "Error pushing image: '${image_name}:${tag}'"
      return 1
    fi
  done
}

cicd_tools::image_builder::get_full_image_name() {

  local image_name image_tag
  image_name="$(cicd_tools::image_builder::_get_image_name)" || return 1
  image_tag=$(cicd_tools::image_builder::get_image_tag) || return 1

  echo -n "${image_name}:${image_tag}"
}

cicd_tools::image_builder::_image_builder_setup() {

  if ! cicd_tools::image_builder::_try_log_in_to_image_registries; then
    cicd_tools::err "Error trying to log into the image registries!"
    return 1
  fi
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
  [ -n "$CICD_TOOLS_IMAGE_BUILDER_QUAY_USER" ] &&
    [ -n "$CICD_TOOLS_IMAGE_BUILDER_QUAY_PASSWORD" ]
}

cicd_tools::image_builder::_log_in_to_quay_registry() {
  cicd_tools::image_builder::_log_in_to_container_registry "$CICD_TOOLS_IMAGE_BUILDER_QUAY_USER" \
    "$CICD_TOOLS_IMAGE_BUILDER_QUAY_PASSWORD" \
    "$CICD_TOOLS_IMAGE_BUILDER_QUAY_REGISTRY"
}

cicd_tools::image_builder::_log_in_to_container_registry() {

  local username="$1"
  local password="$2"
  local registry="$3"

  cicd_tools::container::cmd login "-u=${username}" "--password-stdin" "$registry" <<< "$password"
}

cicd_tools::image_builder::_redhat_registry_credentials_found() {
  [ -n "$CICD_TOOLS_IMAGE_BUILDER_REDHAT_USER" ] &&
    [ -n "$CICD_TOOLS_IMAGE_BUILDER_REDHAT_PASSWORD" ]
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
