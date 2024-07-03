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

function changes_excluding_docs() {

    local target_branch=${ghprbTargetBranch:-master}
    local docs_regex='^docs/.*\|^.*\.adoc'

    local detect_changes=$(git --no-pager diff --name-only "origin/${target_branch}" |\
        grep -v "$docs_regex" | grep -q '.')

    if [ -z detect_changes ]; then
        echo "No code changes detected, exiting"
        create_junit_dummy_result

        exit 0
    fi
}

function create_junit_dummy_result() {

    mkdir -p 'artifacts'

    cat <<- EOF > 'artifacts/junit-dummy.xml'
	<?xml version="1.0" encoding="UTF-8"?>
	<testsuite tests="1">
	    <testcase classname="dummy" name="dummy-empty-test"/>
	</testsuite>
	EOF
}
