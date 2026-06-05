#!/bin/bash -ex

set -o pipefail

cleanup() {

    local pid="${1:?}"
    kill -9 "$pid" || :

}

timeout_to_seconds() {
    local t="${1:?}"
    if [[ "$t" =~ ^([0-9]+)h$ ]]; then
        echo $(( "${BASH_REMATCH[1]}" * 3600 ))
    elif [[ "$t" =~ ^([0-9]+)m$ ]]; then
        echo $(( "${BASH_REMATCH[1]}" * 60 ))
    elif [[ "$t" =~ ^([0-9]+)s$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo 600
    fi
}

# UI sidecars (Playwright/Selenium) keep running after pytest; the K8s Job never reaches
# Complete, so JobInvocationComplete never fires. Wait on the IQE container exit code instead.
wait_for_iqe_main_container() {
    local pod="${1:?}"
    local ns="${2:?}"
    local timeout="${3:?}"

    local iqe_container
    iqe_container="$(oc_wrapper get pod "$pod" -n "$ns" -o jsonpath='{.spec.containers[0].name}')"

    local deadline=$(( SECONDS + $(timeout_to_seconds "$timeout") ))
    while (( SECONDS < deadline )); do
        local exit_code reason waiting_reason
        exit_code="$(oc_wrapper get pod "$pod" -n "$ns" -o jsonpath="{.status.containerStatuses[?(@.name=='${iqe_container}')].state.terminated.exitCode}")"
        reason="$(oc_wrapper get pod "$pod" -n "$ns" -o jsonpath="{.status.containerStatuses[?(@.name=='${iqe_container}')].state.terminated.reason}")"

        if [[ -n "$exit_code" ]]; then
            if [[ "$exit_code" == "0" ]]; then
                echo "IQE container '${iqe_container}' completed successfully"
                return 0
            fi
            echo "IQE container '${iqe_container}' failed (exit=${exit_code}, reason=${reason})"
            return 1
        fi

        waiting_reason="$(oc_wrapper get pod "$pod" -n "$ns" -o jsonpath="{.status.containerStatuses[?(@.name=='${iqe_container}')].state.waiting.reason}")"
        if [[ "$waiting_reason" == "CrashLoopBackOff" || "$waiting_reason" == "ErrImagePull" || "$waiting_reason" == "ImagePullBackOff" ]]; then
            echo "IQE container '${iqe_container}' failed while waiting (${waiting_reason})"
            return 1
        fi

        sleep 10
    done

    echo "Timed out after ${timeout} waiting for IQE container '${iqe_container}' in pod ${pod}"
    return 1
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
    #iqe_env_vars="ENV_VAR1=value1,ENV_VAR2=value2" -- custom set of extra environment variables to set on IQE pod
    local iqe_env_vars="${IQE_ENV_VARS}"
    local iqe_cji_timeout="${IQE_CJI_TIMEOUT:-10m}"
    local iqe_env_vars="${IQE_ENV_VARS:=}"
    local iqe_parallel_enabled="${IQE_PARALLEL_ENABLED}"

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
    $selenium_arg \
    $playwright_arg \
    $iqe_env_var_args \
    --namespace "$ns")

    container=$(oc_wrapper get pod $pod -n $ns -o jsonpath="{.status.containerStatuses[0].name}")
    oc_wrapper logs -n $ns $pod -c $container -f &
    pid=$!
    trap "cleanup $pid" EXIT

    if [[ "$playwright" == "true" || "$selenium" == "true" ]]; then
        echo "Sidecar mode: skipping check_cji_jobs.py"
        wait_for_iqe_main_container "$pod" "$ns" "$iqe_cji_timeout"
    else
        oc_wrapper wait "--timeout=$iqe_cji_timeout" --for=condition=JobInvocationComplete -n "$ns" "cji/$cji_name"
        oc_wrapper get -o json -n "$ns" "cji/$cji_name" | check_cji_jobs.py
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
