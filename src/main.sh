#!/usr/bin/env bash

CICD_TOOLS_COMMON_LIB_LOADED=${CICD_TOOLS_COMMON_LIB_LOADED:-1}
CICD_TOOLS_CONTAINER_LIB_LOADED=${CICD_TOOLS_CONTAINER_LIB_LOADED:-1}
CICD_TOOLS_DEBUG="${CICD_TOOLS_DEBUG:-}"
# https://stackoverflow.com/a/246128
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CICD_TOOLS_SCRIPTS_DIR="${CICD_TOOLS_SCRIPTS_DIR:-$SCRIPT_DIR}"
LIB_TO_LOAD=${1:-container}

cicd::debug() {
  if cicd::_debug_mode; then
    cicd::log "$*"
  fi
}

cicd::_debug_mode() {
  [[ -n "$CICD_TOOLS_DEBUG" ]]
}

cicd::log() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

cicd::err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

cicd::load_library() {

  case $LIB_TO_LOAD in
    all) cicd::_load_all ;;
    common) cicd::_load_common_lib ;;
    container) cicd::_load_container_lib ;;
    image_builder) cicd::_load_image_builder_lib ;;
    *) cicd::err "Unsupported library: '$LIB_TO_LOAD'" && return 1 ;;
  esac
}

cicd::_load_all() {
  cicd::_load_common_lib
  cicd::_load_container_lib
  cicd::_load_image_builder_lib
}

cicd::_load_common_lib() {
  # shellcheck source=src/shared/common_lib.sh
  source "${CICD_TOOLS_SCRIPTS_DIR}/shared/common_lib.sh"
}

cicd::_load_container_lib() {
  cicd::_load_common_lib
  # shellcheck source=src/shared/container_lib.sh
  source "${CICD_TOOLS_SCRIPTS_DIR}/shared/container_lib.sh"
}

cicd::_load_image_builder_lib() {
  cicd::_load_common_lib
  cicd::_load_container_lib
  # shellcheck source=src/shared/image_builder_lib.sh
  source "${CICD_TOOLS_SCRIPTS_DIR}/shared/image_builder_lib.sh"
}

cicd::load_library "$LIB_TO_LOAD"
