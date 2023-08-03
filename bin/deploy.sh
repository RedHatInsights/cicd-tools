#!/bin/bash -ex

main() {
    # For simplicitly, since there are a lot of arguments,
    # consume them from the environment (easier than positional arguments)

    # Mandatory Arguments
    local ns="${1:?Namespace was not provided}"
    local app_name="${APP_NAME:?APP_NAME was not provided}"
    local component_name="${COMPONENT_NAME:?}"
    local git_commit="${GIT_COMMIT:?}"
    local image="${IMAGE:?IMAGE was not provided}"
    local image_tag="${IMAGE_TAG:?IMAGE_TAG was not provided}"
    
    # Optional Arguments
    local deploy_timeout=${DEPLOY_TIMEOUT:-900}
    local ref_env="${REF_ENV:-insights-production}"
    local deploy_frontends="${DEPLOY_FRONTENDS:-false}"
    local optional_deps_method="${OPTIONAL_DEPS_METHOD:-hybrid}"
    local extra_deploy_args="${EXTRA_DEPLOY_ARGS:-""}"
    local components_arg components_resources_arg



    if [[ -n "$COMPONENTS" ]]; then
        components_arg=($(printf -- '--component %s ' $COMPONENTS))
    fi

    if [[ -n "$COMPONENTS_W_RESOURCES" ]]; then
        components_resources_arg=($(printf -- '--no-remove-resources %s ' $COMPONENTS_W_RESOURCES))
    fi

    bonfire deploy \
        "$app_name" \
        --source=appsre \
        --ref-env "$ref_env" \
        --set-template-ref "$component_name"="$git_commit" \
        --set-image-tag "${image}=${image_tag}" \
        --namespace "$ns" \
        --timeout "$deploy_timeout" \
        --optional-deps-method "$optional_deps_method" \
        --frontends "$deploy_frontends" \
        "${components_arg[@]}" \
        "${components_resources_arg[@]}" \
        "${extra_deploy_args[@]}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi



