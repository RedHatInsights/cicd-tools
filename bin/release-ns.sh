#!/bin/bash -ex

main() {
    local ns_file="${1:?Namespace file was not provided}"
    local ns_requester="${2:?Namespace requester name was not provided}"

    export BONFIRE_NS_REQUESTER="$ns_requester"
    export BONFIRE_BOT="true"
    
    bonfire namespace release "$(cat "$ns_file")" -f
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
