#!/usr/bin/env bash

# container engine helper functions to handle both podman and docker commands

CICD_TOOLS_COMMON_LOADED=${CICD_TOOLS_COMMON_LOADED:-1}
CICD_TOOLS_CONTAINER_ENGINE_LOADED=${CICD_TOOLS_CONTAINER_ENGINE_LOADED:-1}

if [[ "$CICD_TOOLS_CONTAINER_ENGINE_LOADED" -eq 0 ]]; then
    return 0
fi

if [ -z "$CICD_TOOLS_SCRIPTS_DIR" ]; then
    echo "scripts directory not defined, please load through main.sh script"
    return 1
fi

if [[ "$CICD_TOOLS_COMMON_LOADED" -ne 0 ]]; then
    # shellcheck source=src/shared/common.sh
    source "${CICD_TOOLS_SCRIPTS_DIR}/shared/common.sh"
fi

if _debug_mode; then
    echo "loading container engine"
fi

CONTAINER_ENGINE_CMD=''
PREFER_CONTAINER_ENGINE=${PREFER_CONTAINER_ENGINE:-}

container_engine_cmd() {

    if [[ -z "$CONTAINER_ENGINE_CMD" ]]; then
        if ! _set_container_engine_cmd; then
            return 1
        fi
    fi

    "$CONTAINER_ENGINE_CMD" "$@"
}

_set_container_engine_cmd() {

    if _preferred_container_engine_available; then
        CONTAINER_ENGINE_CMD="$PREFER_CONTAINER_ENGINE"
    else
        if _container_engine_available 'podman'; then
            CONTAINER_ENGINE_CMD='podman'
        elif _container_engine_available 'docker'; then
            CONTAINER_ENGINE_CMD='docker'
        else
            echo "ERROR, no container engine found, please install either podman or docker first"
            return 1
        fi
    fi

    if _debug_mode; then
        echo "Container engine selected: $CONTAINER_ENGINE_CMD"
    fi
}

_preferred_container_engine_available() {

    local CONTAINER_ENGINE_AVAILABLE=1

    if [ -n "$PREFER_CONTAINER_ENGINE" ]; then
        if _container_engine_available "$PREFER_CONTAINER_ENGINE"; then
            CONTAINER_ENGINE_AVAILABLE=0
        else
            echo "WARNING: preferred container engine '${PREFER_CONTAINER_ENGINE}' not present, or isn't supported, finding alternative..."
        fi
    fi

    return "$CONTAINER_ENGINE_AVAILABLE"
}

_container_engine_available() {

    local CONTAINER_ENGINE_TO_CHECK="$1"
    local CONTAINER_ENGINE_AVAILABLE=1

    if _container_engine_command_exists_and_is_supported "$CONTAINER_ENGINE_TO_CHECK"; then
        CONTAINER_ENGINE_AVAILABLE=0
    fi

    return "$CONTAINER_ENGINE_AVAILABLE"
}

_container_engine_command_exists_and_is_supported() {

    local COMMAND="$1"
    local RESULT=0

    if _supported_container_engine "$COMMAND" && command_is_present "$COMMAND"; then
        if [[ "$COMMAND" == 'docker' ]] && _docker_seems_emulated; then
            echo "WARNING: docker seems emulated, skipping."
            RESULT=1
        fi
    else
        RESULT=1
    fi

    return "$RESULT"
}

_supported_container_engine() {

    local CONTAINER_ENGINE_TO_CHECK="$1"

    [ "$CONTAINER_ENGINE_TO_CHECK" = 'docker' ] || \
        [ "$CONTAINER_ENGINE_TO_CHECK" = 'podman' ]
}

_docker_seems_emulated() {
    [[ "$(docker 2>/dev/null --version)" =~ podman\ +version ]]
}

_podman_version_under_4_5_0() {
    [ "$(echo -en "4.5.0\n$(_podman_version)" | sort -V | head -1)" != "4.5.0" ]
}

CICD_TOOLS_CONTAINER_ENGINE_LOADED=0
