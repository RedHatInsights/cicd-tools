#!/bin/bash -ex

set -o pipefail

main() {
    # Mandatory arguments
    local ns="${1:?Namespace was not provided}"
    local artifacts_dir="${3:? Artifacts dir was not provided}"
    local pod

    pod="$(get_iqe_pod_or_die "$ns")"

    # Set up port-forward for minio
    local local_svc_port
    local_svc_port=$(python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()')
    oc_wrapper port-forward "svc/env-$ns-minio" "$local_svc_port:9000" -n "$ns" &
    sleep 5

    # Get the secret from the env
    oc_wrapper get secret "env-$ns-minio" -o json -n "$ns" | jq -r '.data' > minio-creds.json 

    # Grab the needed creds from the secret
    local minio_access
    minio_access=$(jq -r .accessKey < minio-creds.json | base64 -d)
    local minio_secret
    minio_secret=$(jq -r .secretKey < minio-creds.json | base64 -d)
    local minio_host=localhost
    
    if [[ -z "$minio_access" ]] || [[ -z "$minio_secret" ]] || [[ -z "$local_svc_port" ]]; then
        echo "Failed to fetch minio connection info when running 'oc' commands"
        exit 1
    fi

    # Setup the minio client to auth to the local eph minio in the ns
    echo "Fetching artifacts from minio..."

    local bucket_name="${pod}-artifacts"

    mc --no-color --quiet alias set minio "http://${minio_host}:${local_svc_port}" "${minio_access}" "${minio_secret}"
    mc --no-color --quiet mirror --overwrite "minio/${bucket_name}" "$artifacts_dir"
}

get_iqe_pod_or_die() {
    local ns=${1:?}
    local pod
    local ret=0

    pods=($(oc_wrapper get pods -o name -n "$ns" | grep iqe)) || ret="$?"
    if [[ "$ret" -ne 0 ]]; then
        echo "Failed to detect IQE pod in $ns" >&2 
        echo "Available pods:"  >&2
        oc_wrapper get pods -n "$ns" >&2
        exit 1
    fi

    if [[ ${#pods[@]} -ne 1 ]]; then
        echo "Found zero or more than one IQE pods:" >&2
        echo "${pods[@]}" >&2
        exit 1
    fi

    echo "${pods[0]#pod/}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
