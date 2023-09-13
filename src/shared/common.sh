#!/usr/bin/env bash

# Common functions that are shared across the different libraries

CICD_TOOLS_COMMON_LOADED=${CICD_TOOLS_COMMON_LOADED:-1}
LOCAL_BUILD=${LOCAL_BUILD:-false}

if [ "$CICD_TOOLS_COMMON_LOADED" -eq 0 ]; then
    return 0
fi

_debug_mode() {
    [[ -n "$CICD_TOOLS_DEBUG" ]]
}

if _debug_mode; then
    echo "loading common"
fi

command_is_present() {
    command -v "$1" > /dev/null 2>&1
}

_get_n_chars_commit_hash() {
    git rev-parse --short="$1" HEAD
}

cicd_tools::common::get_7_chars_commit_hash() {
    _get_n_chars_commit_hash 7
}

local_build() {
    [[ "$LOCAL_BUILD" = true ||  "$CI" != "true" ]]
}

cicd_tools::common::err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

CICD_TOOLS_COMMON_LOADED=0
