#!/usr/bin/env bash

# Mock functions
podman() {
    echo "Podman version 99"
}

docker() {
    echo "Docker version 99"
}

load_cicd_helper_functions() {

    local CICD_CONTAINER_PREFER_ENGINE='docker'
    local LIBRARY_TO_LOAD=${1:-all}
    local CICD_TOOLS_URL="https://raw.githubusercontent.com/RedHatInsights/cicd-tools/main/src/bootstrap.sh"
    source <(curl -sSL "$CICD_TOOLS_URL") "$LIBRARY_TO_LOAD"

    # required to persist container preferrence
    cicd::container::cmd --version
}

load_cicd_helper_functions container

EXPECTED_OUTPUT=$(cicd::container::cmd --version)

# Assert there's an actual output
if ! [ "Docker version 99" == "$EXPECTED_OUTPUT" ]; then
    echo "container preference not working!"
    exit 1
fi

load_cicd_helper_functions

# Assert output doesn't change 
if ! [ "$(cicd::container::cmd --version)" == "$EXPECTED_OUTPUT" ]; then
    echo "Container command not preserved between runs!"
    exit 1
fi

if ! [ "$(cicd::container::cmd --version)" == "$EXPECTED_OUTPUT" ]; then
    echo "Container command not preserved between runs!"
    exit 1
fi
