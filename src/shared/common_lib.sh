#!/usr/bin/env bash

# Common functions that are shared across the different libraries

CICD_TOOLS_COMMON_LOADED=${CICD_TOOLS_COMMON_LOADED:-1}
LOCAL_BUILD=${LOCAL_BUILD:-false}

if [ "$CICD_TOOLS_COMMON_LOADED" -eq 0 ]; then
  cicd::debug "common library already loaded, skipping"
  return 0
fi

if [ -z "$CICD_TOOLS_SCRIPTS_DIR" ]; then
  echo "scripts directory not defined, please load through main.sh script" >&2
  return 1
fi

cicd::debug "loading common lib"

cicd::common::command_is_present() {
  command -v "$1" > /dev/null 2>&1
}

cicd::common::_get_n_chars_commit_hash() {
  git rev-parse --short="$1" HEAD
}

cicd::common::get_7_chars_commit_hash() {
  cicd::common::_get_n_chars_commit_hash 7
}

cicd::common::is_ci_context() {
  [[ "$CI" = "true" ]]
}

cicd::common::local_build() {
  [[ "$LOCAL_BUILD" = true ]] || ! cicd::common::is_ci_context
}

cicd::debug "common lib loaded"

CICD_TOOLS_COMMON_LOADED=0
