#!/bin/bash -ex

main() {
    # For simplicitly, since there are a lot of arguments,
    # consume them from the environment (easier than positional arguments)

    # Mandatory Arguments
    local ns="${1:?Namespace was not provided}"
    local ns_requester="${2:?Namespace requester name was not provided}"
    local app_name="${APP_NAME:?APP_NAME was not provided}"
    
    # Optional Arguments
    local deploy_timeout=${DEPLOY_TIMEOUT:-900}
    local ref_env="${REF_ENV:-insights-production}"
    local deploy_frontends="${DEPLOY_FRONTENDS:-false}"
    local optional_deps_method="${OPTIONAL_DEPS_METHOD:-hybrid}"
    local extra_deploy_args=()
    local components_arg components_resources_arg

    export BONFIRE_NS_REQUESTER="$ns_requester"

    # shellcheck disable=SC2153
    if [[ -n "$EXTRA_DEPLOY_ARGS" ]]; then
        # shellcheck disable=SC2206
        extra_deploy_args+=($EXTRA_DEPLOY_ARGS)
    fi

    if [[ -n "$COMPONENTS" ]]; then
        # shellcheck disable=SC2207,SC2086
        components_arg=($(printf -- '--component %s ' $COMPONENTS))
    fi

    if [[ -n "$COMPONENTS_W_RESOURCES" ]]; then
        # shellcheck disable=SC2207,SC2086
        components_resources_arg=($(printf -- '--no-remove-resources %s ' $COMPONENTS_W_RESOURCES))
    fi

    bonfire deploy \
        --source=appsre \
        --ref-env "$ref_env" \
        --namespace "$ns" \
        --timeout "$deploy_timeout" \
        --optional-deps-method "$optional_deps_method" \
        --frontends "$deploy_frontends" \
        "${components_arg[@]}" \
        "${components_resources_arg[@]}" \
        "${extra_deploy_args[@]}" \
        "$app_name"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
