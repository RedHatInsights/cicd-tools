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
CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAGS=()
readonly CICD_TOOLS_IMAGE_BUILDER_CONTAINER_FILE="${CICD_TOOLS_IMAGE_BUILDER_CONTAINER_FILE:-Dockerfile}"
readonly CICD_TOOLS_IMAGE_BUILDER_BUILD_CONTEXT="${CICD_TOOLS_IMAGE_BUILDER_BUILD_CONTEXT:-.}"
readonly CICD_TOOLS_IMAGE_BUILDER_REPOSITORY="${CICD_TOOLS_IMAGE_BUILDER_REPOSITORY:-$IMAGE_REPOSITORY}"
readonly CICD_TOOLS_IMAGE_BUILDER_REDHAT_REGISTRY='registry.redhat.io'
readonly CICD_TOOLS_IMAGE_BUILDER_QUAY_REGISTRY='quay.io'
readonly CICD_TOOLS_IMAGE_BUILDER_QUAY_EXPIRE_TIME=${CICD_TOOLS_IMAGE_BUILDER_QUAY_EXPIRE_TIME:-3d}
readonly CICD_TOOLS_IMAGE_BUILDER_QUAY_USER="${CICD_TOOLS_IMAGE_BUILDER_QUAY_USER:-$QUAY_USER}"
readonly CICD_TOOLS_IMAGE_BUILDER_QUAY_PASSWORD="${CICD_TOOLS_IMAGE_BUILDER_QUAY_PASSWORD:-$QUAY_TOKEN}"
readonly CICD_TOOLS_IMAGE_BUILDER_REDHAT_USER="${CICD_TOOLS_IMAGE_BUILDER_REDHAT_USER:-$RH_REGISTRY_USER}"
readonly CICD_TOOLS_IMAGE_BUILDER_REDHAT_PASSWORD="${CICD_TOOLS_IMAGE_BUILDER_REDHAT_PASSWORD:-$RH_REGISTRY_TOKEN}"
CICD_TOOLS_IMAGE_BUILDER_ADDITIONAL_TAGS=("${CICD_TOOLS_IMAGE_BUILDER_ADDITIONAL_TAGS[@]:-${ADDITIONAL_TAGS[@]}}")
#readonly CICD_TOOLS_IMAGE_BUILDER_ADDITIONAL_TAGS=("${CICD_TOOLS_IMAGE_BUILDER_ADDITIONAL_TAGS[@]:-}")
CICD_TOOLS_IMAGE_BUILDER_BUILD_ARGS=("${CICD_TOOLS_IMAGE_BUILDER_BUILD_ARGS[@]:-${BUILD_ARGS[@]}}")
#readonly CICD_TOOLS_IMAGE_BUILDER_BUILD_ARGS=("${CICD_TOOLS_IMAGE_BUILDER_BUILD_ARGS[@]:-}")
CICD_TOOLS_IMAGE_BUILDER_LABELS=("${CICD_TOOLS_IMAGE_BUILDER_LABELS[@]:-${LABELS[@]}}")
#CICD_TOOLS_IMAGE_BUILDER_LABELS=("${CICD_TOOLS_IMAGE_BUILDER_LABELS[@]:-}")

cicd_tools::image_builder::get_default_image_tag() {
  echo -n "${CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAGS[0]}"
}

cicd_tools::image_builder::get_image_tags() {
  echo -n "${CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAGS[@]}"
}

cicd_tools::image_builder::build_deploy() {

  cicd_tools::image_builder::build || return 1
  if cicd_tools::image_builder::is_change_request_context; then
    cicd_tools::image_builder::push || return 1
  fi
}

cicd_tools::image_builder::tag() {

  local source_image
  source_image=$(cicd_tools::image_builder::get_default_image_tag)

  for target_image in "${CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAGS[@]}"; do
      cicd_tools::container::cmd tag "$source_image" "$target_image"
  done
}

cicd_tools::image_builder::build() {

  declare -a label_params
  declare -a image_tag_params
  declare -a build_arg_params

  local containerfile build_context

  containerfile="${CICD_TOOLS_IMAGE_BUILDER_CONTAINER_FILE}"
  build_context="${CICD_TOOLS_IMAGE_BUILDER_BUILD_CONTEXT}"

  for label in "${CICD_TOOLS_IMAGE_BUILDER_LABELS[@]}"; do
    label_params+=("--label ${label}")
  done

  for image_tag in "${CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAGS[@]}"; do
    image_tag_params+=("-t ${image_tag}")
  done

  for build_arg in "${CICD_TOOLS_IMAGE_BUILDER_BUILD_ARGS[@]}"; do
      build_arg_params+=("--build-arg ${build_arg}")
  done

  if ! cicd_tools::container::cmd build -f "$containerfile" "${image_tag_params[@]}" \
    "${build_arg_params[@]}" "${label_params[@]}" "$build_context"; then
    cicd_tools::err "Error building image"
    return 1
  fi
}

cicd_tools::image_builder::push() {

  for image_tag in "${CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAGS[@]}"; do
    if ! cicd_tools::container::cmd push "${image_tag}"; then
        cicd_tools::err "Error pushing image: '$image_tag'"
        return 1
    fi
  done
}

cicd_tools::image_builder::_get_expiry_label() {
  echo "quay.expires-after=${CICD_TOOLS_IMAGE_BUILDER_QUAY_EXPIRE_TIME}"
}

cicd_tools::image_builder::get_main_tag() {
  echo -n "${CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAGS[0]}"
}

cicd_tools::image_builder::_array_empty() {
    local arr=("$1")

    [[ "${#arr[@]}" -eq 1 && -z "${arr[0]}" ]]
}

cicd_tools::image_builder::_sanitize_arrays() {

    if cicd_tools::image_builder::_array_empty "${CICD_TOOLS_IMAGE_BUILDER_ADDITIONAL_TAGS[@]}";then
        CICD_TOOLS_IMAGE_BUILDER_ADDITIONAL_TAGS=()
    fi
    if cicd_tools::image_builder::_array_empty "${CICD_TOOLS_IMAGE_BUILDER_BUILD_ARGS[@]}";then
        CICD_TOOLS_IMAGE_BUILDER_BUILD_ARGS=()
    fi
    if cicd_tools::image_builder::_array_empty "${CICD_TOOLS_IMAGE_BUILDER_LABELS[@]}";then
        CICD_TOOLS_IMAGE_BUILDER_LABELS=()
    fi
}

cicd_tools::image_builder::_set_image_tags() {

  local main_tag commit_hash build_id
  local repository="$CICD_TOOLS_IMAGE_BUILDER_REPOSITORY"

  # TODO: handle if not in a `git` repository, git not available, etc
  commit_hash=$(cicd_tools::common::get_7_chars_commit_hash)

  if cicd_tools::image_builder::is_change_request_context; then
    build_id=$(cicd_tools::image_builder::get_build_id)
    main_tag="pr-${build_id}-${commit_hash}"
  else
    main_tag="$commit_hash"
  fi

  CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAGS=("${repository}:${main_tag}")

  for additional_tag in "${CICD_TOOLS_IMAGE_BUILDER_ADDITIONAL_TAGS[@]}"; do
    CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAGS+=("${repository}:${additional_tag}")
  done

  cicd_tools::debug "Image tags: ${CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAGS[*]}"
  readonly CICD_TOOLS_IMAGE_BUILDER_IMAGE_TAGS
}

cicd_tools::image_builder::_add_expiry_label() {

    local expiry_label
    expiry_label=$(cicd_tools::image_builder::_get_expiry_label)

    CICD_TOOLS_IMAGE_BUILDER_LABELS+=("${expiry_label}")
}

cicd_tools::image_builder::is_change_request_context() {
  [ -n "$ghprbPullId" ] || [ -n "$gitlabMergeRequestId" ]
}

# TODO: decide on should this be private?
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

  if [ -z "$CICD_TOOLS_IMAGE_BUILDER_REPOSITORY" ]; then
      cicd_tools::err "Image repository not defined, please set IMAGE_REPOSITORY"
      return 1
  fi

  cicd_tools::image_builder::_sanitize_arrays
  cicd_tools::image_builder::_set_image_tags

  if cicd_tools::image_builder::is_change_request_context; then
    cicd_tools::image_builder::_add_expiry_label
  fi

  readonly CICD_TOOLS_IMAGE_BUILDER_LABELS
  readonly CICD_TOOLS_IMAGE_BUILDER_ADDITIONAL_TAGS
  readonly CICD_TOOLS_IMAGE_BUILDER_BUILD_ARGS
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
  cicd_tools::image_builder::_log_in_to_container_registry \
    "$CICD_TOOLS_IMAGE_BUILDER_QUAY_USER" \
    "$CICD_TOOLS_IMAGE_BUILDER_QUAY_PASSWORD" \
    "$CICD_TOOLS_IMAGE_BUILDER_QUAY_REGISTRY"
}

cicd_tools::image_builder::_log_in_to_redhat_registry() {
  cicd_tools::image_builder::_log_in_to_container_registry \
    "$CICD_TOOLS_IMAGE_BUILDER_REDHAT_USER" \
    "$CICD_TOOLS_IMAGE_BUILDER_REDHAT_PASSWORD" \
    "$CICD_TOOLS_IMAGE_BUILDER_REDHAT_REGISTRY"
}

if ! cicd_tools::image_builder::_image_builder_setup; then
  cicd_tools::err "Image builder setup failed!"
  return 1
fi

cicd_tools::debug "Image builder lib loaded"

CICD_TOOLS_IMAGE_BUILDER_LOADED=0
