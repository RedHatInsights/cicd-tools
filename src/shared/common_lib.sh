#!/usr/bin/env bash

# Common functions that are shared across the different libraries

CICD_TOOLS_COMMON_LOADED=${CICD_TOOLS_COMMON_LOADED:-1}
LOCAL_BUILD=${LOCAL_BUILD:-false}

if [ "$CICD_TOOLS_COMMON_LOADED" -eq 0 ]; then
    cicd_tools::debug "common library already loaded, skipping"
    return 0
fi

if [ -z "$CICD_TOOLS_SCRIPTS_DIR" ]; then
    echo "scripts directory not defined, please load through main.sh script" >&2
    return 1
fi

cicd_tools::debug "loading common lib"

cicd_tools::common::command_is_present() {
    command -v "$1" > /dev/null 2>&1
}

cicd_tools::common::_get_n_chars_commit_hash() {
    git rev-parse --short="$1" HEAD
}

cicd_tools::common::get_7_chars_commit_hash() {
    cicd_tools::common::_get_n_chars_commit_hash 7
}

cicd_tools::common::local_build() {
    [[ "$LOCAL_BUILD" = true ||  "$CI" != "true" ]]
}

cicd_tools::debug "common lib loaded"

CICD_TOOLS_COMMON_LOADED=0
