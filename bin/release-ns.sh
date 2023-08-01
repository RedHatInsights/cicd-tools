#!/bin/bash -ex

main() {
    local ns_file="${1:?Namespace file was not provided}"
    bonfire namespace release "$(cat "$ns_file")" -f
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
