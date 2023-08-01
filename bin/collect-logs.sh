#!/bin/bash -ex

main() {
    local ns="${1:?Namespace name was not provided}"
    local artifacts_dir=${2:?Artifacts dir was not provided}
    local logs_dir="${artifacts_dir}/k8s_artifacts/${ns}"

    collect_k8s_artifacts "$ns" "$logs_dir"
    get_pod_logs "$ns" "$logs_dir"
}

collect_k8s_artifacts() {
    local ns="${1:?Namespace name was not provided}"
    local logs_dir="${2:?Logs dir was not provided}"

    mkdir -p "$logs_dir"
    
    echo "Collecting events and k8s configs..."
    oc_wrapper get events -n "$ns" --sort-by='.lastTimestamp' > "${logs_dir}/oc_get_events.txt"
    oc_wrapper get all -n "$ns" -o yaml > "${logs_dir}/oc_get_all.yaml"
    oc_wrapper get clowdapp -n "$ns" -o yaml > "${logs_dir}/oc_get_clowdapp.yaml"
    oc_wrapper get clowdenvironment "env-$ns" -o yaml > "${logs_dir}/oc_get_clowdenvironment.yaml"
    oc_wrapper get clowdjobinvocation -n "$ns" -o yaml > "${logs_dir}/oc_get_clowdjobinvocation.yaml"
}

get_pod_logs() {
    local ns="${1:?Namespace name was not provided}"
    local logs_dir="${2:?Logs dir was not provided}/logs"

    mkdir -p "$logs_dir"

    # get array of pod_name:container1,container2,..,containerN for all containers in all pods
    echo "Collecting container logs..."
    local pod_containers
    pod_containers=($(oc_wrapper get pods --ignore-not-found=true -n $ns -o "jsonpath={range .items[*]}{' '}{.metadata.name}{':'}{range .spec['containers', 'initContainers'][*]}{.name}{','}"))

    for pc in "${pod_containers[@]}"; do
        # https://stackoverflow.com/a/4444841
        local pod=${pc%%:*}
        local containers=${pc#*:}
        local container
        for container in ${containers//,/ }; do
            oc_wrapper logs \
                "$pod" \
                -c "$container" \
                -n "$ns" \
                > "${logs_dir}/${pod}_${container}.log" \
                2> /dev/null \
                || continue
            oc_wrapper logs \
                "$pod" \
                -c $container \
                --previous \
                -n $ns \
                > "${logs_dir}/${POD}_${container}-previous.log" \
                2> /dev/null \
                || continue
        done
    done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi

