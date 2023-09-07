#!/usr/bin/env bash

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

get_7_chars_commit_hash() {
    git rev-parse --short=7 HEAD
}

local_build() {
    [[ "$LOCAL_BUILD" = true ]]
}

CICD_TOOLS_COMMON_LOADED=0
