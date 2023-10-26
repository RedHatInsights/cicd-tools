#!/bin/bash

# container engine helper functions to handle both podman and docker commands

if [[ -n "$CICD_CONTAINER_MODULE_LOADED" ]]; then
  cicd::log::debug "container engine module already loaded, skipping"
  return 0
fi

if [[ -z "$CICD_LOADER_MODULE_LOADED" ]]; then
  echo "loader module not found, please use 'load_module.sh' to load modules."
  return 1
fi

cicd::log::debug "loading container module"

CICD_CONTAINER_ENGINE=''
CICD_CONTAINER_PREFER_ENGINE=${CICD_CONTAINER_PREFER_ENGINE:-}

cicd::container::cmd() {
  "$CICD_CONTAINER_ENGINE" "$@"
}

cicd::container::_set_container_engine_cmd() {

  if cicd::container::_preferred_container_engine_available; then
    CICD_CONTAINER_ENGINE="$CICD_CONTAINER_PREFER_ENGINE"
  else
    if cicd::container::_container_engine_available 'podman'; then
      CICD_CONTAINER_ENGINE='podman'
    elif cicd::container::_container_engine_available 'docker'; then
      CICD_CONTAINER_ENGINE='docker'
    else
      cicd::log::err "ERROR, no container engine found, please install either podman or docker first"
      return 1
    fi
  fi

  readonly CICD_CONTAINER_ENGINE

  cicd::log::debug "Container engine selected: $CICD_CONTAINER_ENGINE"
}

cicd::container::_preferred_container_engine_available() {

  local engine_available=1

  if [ -n "$CICD_CONTAINER_PREFER_ENGINE" ]; then
    if cicd::container::_container_engine_available "$CICD_CONTAINER_PREFER_ENGINE"; then
      engine_available=0
    else
      cicd::log::info "WARNING: preferred container engine '${CICD_CONTAINER_PREFER_ENGINE}' not present, or isn't supported, finding alternative..."
    fi
  fi

  return "$engine_available"
}

cicd::container::_container_engine_available() {

  local cmd="$1"
  local available=1

  if cicd::container::_cmd_exists_and_is_supported "$cmd"; then
    available=0
  fi

  return "$available"
}

cicd::container::_cmd_exists_and_is_supported() {

  local cmd="$1"
  local result=0

  if cicd::container::_supported_container_engine "$cmd" && cicd::common::command_is_present "$cmd"; then
    if [[ "$cmd" == 'docker' ]] && cicd::container::_docker_seems_emulated; then
      cicd::log::info "WARNING: docker seems emulated, skipping."
      result=1
    fi
  else
    result=1
  fi

  return "$result"
}

cicd::container::_supported_container_engine() {

  local engine_to_check="$1"

  [ "$engine_to_check" = 'docker' ] ||
    [ "$engine_to_check" = 'podman' ]
}

cicd::container::_docker_seems_emulated() {
  [[ "$(docker 2>/dev/null --version)" =~ podman\ +version ]]
}

cicd::container::_podman_version_under_4_5_0() {
  [ "$(echo -en "4.5.0\n$(_podman_version)" | sort -V | head -1)" != "4.5.0" ]
}

cicd::container::_module_setup() {

  if ! cicd::container::_set_container_engine_cmd; then
    cicd::log::err "Error configuring a container engine!"
    return 1
  fi
}

if ! cicd::container::_module_setup; then
  cicd::log::err "container module setup failed!"
  return 1
fi

cicd::log::debug "container module loaded"
CICD_CONTAINER_MODULE_LOADED='true'
