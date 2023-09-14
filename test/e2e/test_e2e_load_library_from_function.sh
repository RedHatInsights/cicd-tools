#!/usr/bin/env bash

# Mock functions
podman() {
    echo "Podman version 99"
}

docker() {
    echo "Docker version 99"
}


load_common_helper_cicd_tools() {

    local PREFER_CONTAINER_ENGINE='docker'
    local LIBRARY_TO_LOAD=${1:-all}
    local MAIN_SCRIPT='./src/main.sh'
    source "$MAIN_SCRIPT" "$LIBRARY_TO_LOAD"
    cicd_tools::container::cmd --version
}
load_common_helper_cicd_tools container

EXPECTED_OUTPUT=$(cicd_tools::container::cmd --version)

# Assert there's an actual output
if ! [ "Docker version 99" == "$EXPECTED_OUTPUT" ]; then
    echo "container preference not working!"
    exit 1
fi

load_cicd_helper_functions

# Assert output doesn't change 
if ! [ "$(cicd_tools::container::cmd --version)" == "$EXPECTED_OUTPUT" ]; then
    echo "Container command not preserved between runs!"
    exit 1
fi

if ! [ "$(cicd_tools::container::cmd --version)" == "$EXPECTED_OUTPUT" ]; then
    echo "Container command not preserved between runs!"
    exit 1
fi
