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
    local component_name="${IQE_CJI_CLOWDAPP_NAME:-${BONFIRE_COMPONENT_NAME:-${COMPONENT_NAME:?Component name not provided}}}"
    local cji_name=$component_name

    # Optional arguments
    local selenium="${IQE_SELENIUM:-false}"
    local playwright="${IQE_PLAYWRIGHT:-false}"
    local iqe_marker_expression="${IQE_MARKER_EXPRESSION}"
    local iqe_filter_expression="${IQE_FILTER_EXPRESSION}"
    local iqe_image_tag="${IQE_IMAGE_TAG}"
    local iqe_requirements="${IQE_REQUIREMENTS}"
    local iqe_requirements_priority="${IQE_REQUIREMENTS_PRIORITY}"
    local iqe_test_importance="${IQE_TEST_IMPORTANCE}"
    local iqe_plugins="${IQE_PLUGINS}"
    local iqe_env="${IQE_ENV:-clowder_smoke}"
    # IQE_ENV_VARS="ENV_VAR1=value1,ENV_VAR2=value2" -- extra env vars for the IQE pod (bonfire --env-var)
    local iqe_env_vars="${IQE_ENV_VARS:-}"
    local iqe_cji_timeout="${IQE_CJI_TIMEOUT:-10m}"
    local iqe_parallel_enabled="${IQE_PARALLEL_ENABLED}"
    local iqe_rp_args="${IQE_RP_ARGS:-}"
    local iqe_cji_template="${IQE_CJI_TEMPLATE:-}"
    local ibutsu_mode="${IBUTSU_MODE:-}"
    local ibutsu_source="${IQE_IBUTSU_SOURCE:-${IBUTSU_SOURCE:-}}"

    local selenium_arg=""
    if [[ "$selenium" == "true" ]]; then
        selenium_arg="--selenium"
    fi

    local playwright_arg=""
    if [[ "$playwright" == "true" ]]; then
        playwright_arg="--playwright"
    fi

    iqe_env_var_args=$(awk -v IQE_ENV_VARS="$iqe_env_vars" 'BEGIN {
      split(IQE_ENV_VARS, iqe_env_vars, ",");
      for (i in iqe_env_vars) {
        printf "--env-var " iqe_env_vars[i] " "
      }
    }')

    template_file_arg=""
    if [[ -n "$iqe_cji_template" ]]; then
        if [[ ! -f "$iqe_cji_template" ]]; then
            echo "ERROR: IQE_CJI_TEMPLATE is set but file does not exist: ${iqe_cji_template}"
            exit 1
        fi
        template_file_arg="--template-file ${iqe_cji_template}"
    fi

    if [[ -n "$ibutsu_mode" ]]; then
        iqe_env_var_args+=" --env-var IBUTSU_MODE=${ibutsu_mode}"
    fi

    ibutsu_source_arg=""
    if [[ -n "$ibutsu_source" ]]; then
        ibutsu_source_arg="--ibutsu-source ${ibutsu_source}"
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
    --parallel-enabled "$iqe_parallel_enabled" \
    --rp-args "${iqe_rp_args}" \
    $selenium_arg \
    $playwright_arg \
    $template_file_arg \
    $ibutsu_source_arg \
    $iqe_env_var_args \
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
