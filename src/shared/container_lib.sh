#!/usr/bin/env bash

# container engine helper functions to handle both podman and docker commands

CICD_TOOLS_CONTAINER_ENGINE_LOADED=${CICD_TOOLS_CONTAINER_ENGINE_LOADED:-1}

if [[ "$CICD_TOOLS_CONTAINER_ENGINE_LOADED" -eq 0 ]]; then
  cicd_tools::debug "container engine library already loaded, skipping"
  return 0
fi

if [ -z "$CICD_TOOLS_SCRIPTS_DIR" ]; then
  echo "scripts directory not defined, please load through main.sh script" >&2
  return 1
fi

cicd_tools::debug "loading container lib"

CONTAINER_ENGINE_CMD=''
PREFER_CONTAINER_ENGINE=${PREFER_CONTAINER_ENGINE:-}

cicd_tools::container::cmd() {

  if [[ -z "$CONTAINER_ENGINE_CMD" ]]; then
    if ! cicd_tools::container::_set_container_engine_cmd; then
      return 1
    fi
  fi

  "$CONTAINER_ENGINE_CMD" "$@"
}

cicd_tools::container::_set_container_engine_cmd() {

  if cicd_tools::container::_preferred_container_engine_available; then
    CONTAINER_ENGINE_CMD="$PREFER_CONTAINER_ENGINE"
  else
    if cicd_tools::container::_container_engine_available 'podman'; then
      CONTAINER_ENGINE_CMD='podman'
    elif cicd_tools::container::_container_engine_available 'docker'; then
      CONTAINER_ENGINE_CMD='docker'
    else
      cicd_tools::err "ERROR, no container engine found, please install either podman or docker first"
      return 1
    fi
  fi

  cicd_tools::debug "Container engine selected: $CONTAINER_ENGINE_CMD"
}

cicd_tools::container::_preferred_container_engine_available() {

  local CONTAINER_ENGINE_AVAILABLE=1

  if [ -n "$PREFER_CONTAINER_ENGINE" ]; then
    if cicd_tools::container::_container_engine_available "$PREFER_CONTAINER_ENGINE"; then
      CONTAINER_ENGINE_AVAILABLE=0
    else
      cicd_tools::log "WARNING: preferred container engine '${PREFER_CONTAINER_ENGINE}' not present, or isn't supported, finding alternative..."
    fi
  fi

  return "$CONTAINER_ENGINE_AVAILABLE"
}

cicd_tools::container::_container_engine_available() {

  local cmd="$1"
  local available=1

  if cicd_tools::container::_cmd_exists_and_is_supported "$cmd"; then
    available=0
  fi

  return "$available"
}

cicd_tools::container::_cmd_exists_and_is_supported() {

  local cmd="$1"
  local result=0

  if cicd_tools::container::_supported_container_engine "$cmd" && cicd_tools::common::command_is_present "$cmd"; then
    if [[ "$cmd" == 'docker' ]] && cicd_tools::container::_docker_seems_emulated; then
      cicd_tools::log "WARNING: docker seems emulated, skipping."
      result=1
    fi
  else
    result=1
  fi

  return "$result"
}

cicd_tools::container::_supported_container_engine() {

  local CONTAINER_ENGINE_TO_CHECK="$1"

  [ "$CONTAINER_ENGINE_TO_CHECK" = 'docker' ] ||
    [ "$CONTAINER_ENGINE_TO_CHECK" = 'podman' ]
}

cicd_tools::container::_docker_seems_emulated() {
  [[ "$(docker 2> /dev/null --version)" =~ podman\ +version ]]
}

cicd_tools::container::_podman_version_under_4_5_0() {
  [ "$(echo -en "4.5.0\n$(_podman_version)" | sort -V | head -1)" != "4.5.0" ]
}

CICD_TOOLS_CONTAINER_ENGINE_LOADED=0
