#!/bin/bash

location="${1:-/tools/bin}"

install_oc_tools() {

    local location="$1"
    local version=4.14
    local url="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-${version}/openshift-client-linux.tar.gz"
    local filename="oc.tar.gz"

    if ! curl -L "$url" -o "$filename"; then
        echo "cannot download OC tools from URL:$url"
        return 1
    fi
    
    if ! tar -C "$location" -xvzf "$filename" oc kubectl; then
        echo "cannot extract OC tools!"
        return 1
    fi

    rm -f "$filename"
}

if ! mkdir -p "$location"; then
    echo "can't create installation dir '$location'"
    exit 1
fi

if ! install_oc_tools "$location"; then
    echo "Error installing OC tools"
    exit 1
fi
