#!/bin/bash -e

main() {
    local server="${OC_LOGIN_SERVER:?OC_LOGIN_SERVER env var was not defined}"
    local token="${OC_LOGIN_TOKEN:?OC_LOGIN_SERVER env var was not defined}"

    oc_wrapper login --token="$token" --server="$server"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
