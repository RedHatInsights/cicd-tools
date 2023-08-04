#!/usr/bin/env bash

# Mock functions
podman() {
    echo "Podman version 99"
}

docker() {
    echo "Docker version 99"
}

load_cicd_helper_functions() {

    local PREFER_CONTAINER_ENGINE='docker'
    local LIBRARY_TO_LOAD=${1:-all}
    
    if [ "CI" != "true" ]; then
        CICD_TOOLS_ROOTDIR=.
        CICD_TOOLS_SKIP_RECREATE=1
        CICD_TOOLS_SKIP_CLEANUP=1
        source src/bootstrap.sh "$LIBRARY_TO_LOAD"
    else
        if [ "$GITHUB_HEAD_REF" != "main" ]; then
            CICD_TOOLS_ROOTDIR=.
            source src/bootstrap.sh "$LIBRARY_TO_LOAD"
        else
            source <(curl -sSL "$CICD_TOOLS_URL") "$LIBRARY_TO_LOAD"
        fi
    fi

    # required to persist container preferrence
    container_engine_cmd --version
}

load_cicd_helper_functions container_engine

EXPECTED_OUTPUT=$(container_engine_cmd --version)

# Assert there's an actual output
if ! [ "Docker version 99" == "$EXPECTED_OUTPUT" ]; then
    echo "container preference not working!"
    exit 1
fi

load_cicd_helper_functions

# Assert output doesn't change 
if ! [ "$(container_engine_cmd --version)" == "$EXPECTED_OUTPUT" ]; then
    echo "Container command not preserved between runs!"
    exit 1
fi

if ! [ "$(container_engine_cmd --version)" == "$EXPECTED_OUTPUT" ]; then
    echo "Container command not preserved between runs!"
    exit 1
fi
