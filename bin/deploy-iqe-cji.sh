#!/bin/bash -ex

set -o pipefail

cleanup() {

    local pid="${1:?}"
    kill -9 "$pid" || :

}

main() {
    # Mandatory arguments
    local ns="${1:?Namespace was not provided}"
    local ns_requester="${2:?Namespace requester name was not provided}"
    local component_name="${COMPONENT_NAME:?Component name not provided}"
    local cji_name=$component_name

    # Optional arguments
    local selenium="${IQE_SELENIUM:-false}"
    local iqe_marker_expression="${IQE_MARKER_EXPRESSION}"
    local iqe_filter_expression="${IQE_FILTER_EXPRESSION}"
    local iqe_image_tag="${IQE_IMAGE_TAG}"
    local iqe_requirements="${IQE_REQUIREMENTS}"
    local iqe_requirements_priority="${IQE_REQUIREMENTS_PRIORITY}"
    local iqe_test_importance="${IQE_TEST_IMPORTANCE}"
    local iqe_plugins="${IQE_PLUGINS}"
    local iqe_env="${IQE_ENV:-clowder_smoke}"
    local iqe_cji_timeout="${IQE_CJI_TIMEOUT:-10m}"

    local selenium_arg=""
    if [[ "$selenium" == "true" ]]; then
        selenium_arg="--selenium"
    fi

    export BONFIRE_NS_REQUESTER="$ns_requester"

    # Invoke the CJI using the options set via env vars
    pod=$(bonfire deploy-iqe-cji "$component_name" \
    --marker "$iqe_marker_expression" \
    --filter "$iqe_filter_expression" \
    --image-tag "${iqe_image_tag}" \
    --requirements "$iqe_requirements" \
    --requirements-priority "$iqe_requirements_priority" \
    --test-importance "$iqe_test_importance" \
    --plugins "$iqe_plugins" \
    --env "$iqe_env" \
    --cji-name "$cji_name" \
    $selenium_arg \
    --namespace "$ns")

    container=$(oc_wrapper get pod $pod -n $ns -o jsonpath="{.status.containerStatuses[0].name}")
    oc_wrapper logs -n $ns $pod -c $container -f &
    pid=$!
    trap "cleanup $pid" EXIT

    oc_wrapper wait "--timeout=$iqe_cji_timeout" --for=condition=JobInvocationComplete -n "$ns" "cji/$cji_name"
    oc_wrapper get -o json -n "$ns" "cji/$cji_name" | check_cji_jobs.py
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
