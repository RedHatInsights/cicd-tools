#!/bin/bash -ex

main() {
    local ns_file="${1:?A Path to a namespace file was not provided}"
    local ns_requester="${2:?Namespace requester name was not provided}"
    local namespace_pool="${3:-default}"
    local ns

    export BONFIRE_NS_REQUESTER="$ns_requester"

    ns="$(bonfire namespace reserve --pool "$namespace_pool")" 
    echo -n "${ns//'\n'}" > "$ns_file"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi



