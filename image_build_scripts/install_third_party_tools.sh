#!/bin/bash

install_location="${1:-/tools/bin}"

#install_oc_tools() {
#
#    local version=4.14
#    local url="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-${version}/openshift-client-linux.tar.gz"
#    local filename="oc.tar.gz"
#
#    if ! curl -L "$url" -o "$filename"; then
#        echo "cannot download OC tools from URL:$url"
#        return 1
#    fi
#    
#    if ! tar -C "$install_location" -xvzf "$filename" oc kubectl; then
#        echo "cannot extract OC tools!"
#        return 1
#    fi
#
#    rm -f "$filename"
#}

install_mc_tools() {

    local url="https://dl.min.io/client/mc/release/linux-amd64/mc"

    __install_tool 'mc' "$url" 'false' 'mc'

#    if ! curl -L "$url" -o "$filename"; then
#        echo "cannot download MC from URL:$url"
#        return 1
#    fi
#    
#    if ! tar -C "$install_location" -xvzf "$filename" mc; then
#        echo "cannot extract MC tools!"
#        return 1
#    fi
}

install_jq_tools() {

    local url="https://github.com/jqlang/jq/releases/download/jq-1.6/jq-linux64"
    local filename="jq"

    __install_tool "jq" "$url" 'false' 'jq'
}

__download_tool() {

    local name="$1"
    local url="$2"
    local filename

    filename=$(mktemp)

    if ! curl -L "$url" -o "$filename"; then
        echo "cannot download tool: '$name' from URL:$url"
        return 1
    fi

    echo "$filename"
}

install_oc_tools() {

    local version=4.14
    local url="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest-${version}/openshift-client-linux.tar.gz"

    __install_tool 'oc' "$url" 'tar.gz' 'oc' 'kubectl'
}

__install_tool() {

    local name="$1"
    local dowload_url="$2"
    local compressed="${3:-false}"
    local commands=("${@:4}")

    local downloaded_tmpfile=""

    if ! downloaded_tmpfile=$(__download_tool "$1" "$2"); then
        echo "Error downloading tool: '$name' from '$dowload_url'"
        return 1
    fi

    # TODO: refactor extract to function
    if [[ "$compressed" != "false" ]]; then
        if [[ "$compressed" =~ tar.gz ]]; then
            if ! tar -C "$install_location" -xvzf "$downloaded_tmpfile" "${commands[@]}"; then
                echo "cannot extract '$name' tools!"
                return 1
            fi
        else
            echo "unsupported compression: '$compressed'"
            return 1
        fi
    else
        mv -v "$downloaded_tmpfile" "$install_location/${commands[0]}"
    fi

    for cmd in "${commands[@]}"; do

        local cmd_path="${install_location}/${cmd}"

        if ! [[ -x "$cmd_path" ]]; then
            if ! chmod +x "$cmd_path"; then
                echo "Error setting exectution permissions to '$cmd_path'" 
                return 1
            fi
        fi
    done
}

install_tools() {

    if ! install_oc_tools; then
        return 1
    fi

    if ! install_mc_tools; then
        return 1
    fi
}

if ! mkdir -p "$install_location"; then
    echo "can't create installation dir '$install_location'"
    exit 1
fi

if ! install_tools; then
    echo "Error installing third party tools"
    exit 1
fi
