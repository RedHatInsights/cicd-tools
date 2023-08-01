#!/bin/bash -ex

main() {
    local ns_file=${1:?A Path to a namespace file was not provided}
    local namespace_pool="${2:-default}"
    bonfire namespace reserve --pool "$namespace_pool" > "$ns_file"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi



