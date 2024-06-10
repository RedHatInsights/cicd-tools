#!/bin/bash -ex

main() {
    local ns="${1:?Namespace was not provided}"
    local ns_requester="${2:?Namespace requester name was not provided}"

    export BONFIRE_NS_REQUESTER="$ns_requester"

    bonfire namespace release "$ns" -f
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
