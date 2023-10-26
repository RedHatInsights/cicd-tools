#!/bin/bash

# Common functions that are shared across the different modules

if [[ -n "$CICD_COMMON_MODULE_LOADED" ]]; then
  cicd::log::debug "common module already loaded, skipping"
  return 0
fi

if [[ -z "$CICD_LOADER_MODULE_LOADED" ]]; then
  echo "loader module not found, please use 'load_module.sh' to load modules."
  return 1
fi

cicd::log::debug "loading common module"

cicd::common::command_is_present() {
  command -v "$1" >/dev/null 2>&1
}

cicd::common::get_7_chars_commit_hash() {
  cicd::common::_get_n_chars_commit_hash 7
}

cicd::common::_get_n_chars_commit_hash() {
  git rev-parse --short="$1" HEAD
}

cicd::common::is_ci_context() {
  [[ "$CI" = "true" ]]
}

cicd::log::debug "common module loaded"

CICD_COMMON_MODULE_LOADED='true'
