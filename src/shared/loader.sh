#!/bin/bash

# Internal module to provide module loading helper functions

CICD_LOADER_MODULE_LOADED=${CICD_LOADER_MODULE_LOADED:-1}

if [[ "$CICD_LOADER_MODULE_LOADED" -eq 0 ]]; then
  cicd::log::debug "loader module already loaded, skipping"
  return 0
fi

if [[ -z "$CICD_LOADER_SCRIPTS_DIR" ]]; then
  echo "Error, CICD_LOADER_SCRIPTS_DIR not defined, use 'load_module.sh' to load this module"
  echo "Then, use 'cicd::loader::load_module' to load modules"
  return 1
fi

# shellcheck source=src/shared/log.sh
if ! source "${CICD_LOADER_SCRIPTS_DIR}/shared/log.sh"; then
  echo "Error loading 'log' module!"
  return 1
fi

cicd::log::debug "loading loader module"

cicd::loader::load_module() {

  # TODO: refactor to source here and leave modules to define their dependencies

  local module_id="${1:-container}"

  case "$module_id" in
  all) cicd::loader::_load_all ;;
  log) cicd::loader::_load_log_module ;;
  common) cicd::loader::_load_common_module ;;
  container) cicd::loader::_load_container_module ;;
  image_builder) cicd::loader::_load_image_builder_module ;;
  loader) cicd::loader::_load_loader_module ;;
  *) cicd::log::err "Unsupported module: '$module_id'" && return 1 ;;
  esac
}

cicd::loader::_load_all() {
  cicd::loader::_load_log_module
  cicd::loader::_load_loader_module
  cicd::loader::_load_common_module
  cicd::loader::_load_container_module
  cicd::loader::_load_image_builder_module
}

cicd::loader::_load_log_module() {
  # shellcheck source=src/shared/log.sh
  source "${CICD_LOADER_SCRIPTS_DIR}/shared/log.sh"
}

cicd::loader::_load_loader_module() {
  # shellcheck source=src/shared/loader.sh
  source "${CICD_LOADER_SCRIPTS_DIR}/shared/loader.sh"
}

cicd::loader::_load_common_module() {
  # shellcheck source=src/shared/common.sh
  source "${CICD_LOADER_SCRIPTS_DIR}/shared/common.sh"
}

cicd::loader::_load_container_module() {
  # TODO: move dependencies within modules
  cicd::loader::_load_common_module
  # shellcheck source=src/shared/container.sh
  source "${CICD_LOADER_SCRIPTS_DIR}/shared/container.sh"
}

cicd::loader::_load_image_builder_module() {
  # TODO: move dependencies within modules
  cicd::loader::_load_common_module
  cicd::loader::_load_container_module
  # shellcheck source=src/shared/image_builder.sh
  source "${CICD_LOADER_SCRIPTS_DIR}/shared/image_builder.sh"
}

cicd::log::debug "loader module loaded"
CICD_LOADER_MODULE_LOADED=0
