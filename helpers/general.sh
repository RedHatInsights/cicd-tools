#!/bin/bash

TEARDOWN_RAN=0

function install_bootstrap {
    curl -s "${CICD_URL}/bootstrap.sh" > .cicd_bootstrap.sh
    source ./.cicd_bootstrap.sh
}

function trap_proxy {
    # https://stackoverflow.com/questions/9256644/identifying-received-signal-name-in-bash
    func="$1"; shift
    for sig; do
        trap "$func $sig" "$sig"
    done
}

function teardown() {
    local CAPTURED_SIGNAL="$1"

    [ "$TEARDOWN_RAN" -ne "0" ] && return
    echo "------------------------"
    echo "----- TEARING DOWN -----"
    echo "------------------------"

    echo "Tear down operation triggered by signal: $CAPTURED_SIGNAL"

    docker rm -f "$TEST_CONT"
    TEARDOWN_RAN=1
}
