#!/usr/bin/env bash

CICD_TOOLS_REPO_ORG="${CICD_TOOLS_REPO_ORG:-RedHatInsights}"
CICD_TOOLS_REPO_BRANCH="${CICD_TOOLS_REPO_BRANCH:-main}"
CICD_TOOLS_ROOTDIR="${CICD_TOOLS_ROOTDIR:-.cicd_tools}"
CICD_TOOLS_SCRIPTS_DIR="${CICD_TOOLS_ROOTDIR}/src"
CICD_TOOLS_SKIP_CLEANUP=${CICD_TOOLS_SKIP_CLEANUP:-}

recreate_cicd_tools_repo() {

    if [ -d "${CICD_TOOLS_ROOTDIR}" ]; then
        _delete_cicd_tools_rootdir
    fi

    git clone -q \
        --branch "$CICD_TOOLS_REPO_BRANCH" \
        "https://github.com/${CICD_TOOLS_REPO_ORG}/cicd-tools.git" "$CICD_TOOLS_ROOTDIR"
}

_delete_cicd_tools_rootdir() {
    echo "Removing existing CICD tools directory: '${CICD_TOOLS_ROOTDIR}'"
    rm -rf "${CICD_TOOLS_ROOTDIR}"
}

cleanup() {
    _delete_cicd_tools_rootdir
}

if [ -z "$CICD_TOOLS_SKIP_RECREATE" ]; then
    if ! recreate_cicd_tools_repo; then
        echo "couldn't recreate cicd_tools repository!"
        exit 1
    fi
fi

# shellcheck source=src/main.sh
source "$CICD_TOOLS_SCRIPTS_DIR/main.sh" "$@" || exit 1
if [ -z "$CICD_TOOLS_SKIP_CLEANUP" ]; then
    if ! cleanup; then
        echo "couldn't perform cicd tools cleanup!"
        exit 1
    fi
fi
