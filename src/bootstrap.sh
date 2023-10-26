#!/usr/bin/env bash

CICD_BOOTSTRAP_REPO_ORG="${CICD_BOOTSTRAP_REPO_ORG:-RedHatInsights}"
CICD_BOOTSTRAP_REPO_BRANCH="${CICD_BOOTSTRAP_REPO_BRANCH:-main}"
CICD_BOOTSTRAP_ROOTDIR="${CICD_BOOTSTRAP_ROOTDIR:-.cicd_tools}"
CICD_BOOTSTRAP_SKIP_CLEANUP=${CICD_BOOTSTRAP_SKIP_CLEANUP:-}
CICD_BOOTSTRAP_SKIP_GIT_CLONE=${CICD_BOOTSTRAP_SKIP_GIT_CLONE:-}

cicd::bootstrap::clone_cicd_tools_repo() {

  if [ -d "${CICD_BOOTSTRAP_ROOTDIR}" ]; then
    cicd::bootstrap::_delete_rootdir
  fi

  git clone -q \
    --branch "$CICD_BOOTSTRAP_REPO_BRANCH" \
    "https://github.com/${CICD_BOOTSTRAP_REPO_ORG}/cicd-tools.git" "$CICD_BOOTSTRAP_ROOTDIR"
}

cicd::bootstrap::_delete_rootdir() {
  cicd::log::debug "Removing existing CICD tools directory: '${CICD_BOOTSTRAP_ROOTDIR}'"
  rm -rf "${CICD_BOOTSTRAP_ROOTDIR}"
}

cicd::bootstrap::cleanup() {
  cicd::bootstrap::_delete_rootdir
  unset cicd::bootstrap::clone_cicd_tools_repo cicd::bootstrap::_delete_rootdir cicd::bootstrap::cleanup
  unset CICD_BOOTSTRAP_REPO_ORG CICD_BOOTSTRAP_REPO_BRANCH CICD_BOOTSTRAP_ROOTDIR CICD_BOOTSTRAP_SKIP_CLEANUP CICD_BOOTSTRAP_SKIP_GIT_CLONE
}

if [ -z "$CICD_BOOTSTRAP_SKIP_GIT_CLONE" ]; then
  if ! cicd::bootstrap::clone_cicd_tools_repo; then
    echo "couldn't clone cicd-tools repository!"
    exit 1
  fi
fi

# shellcheck source=src/load_module.sh
source "$CICD_BOOTSTRAP_ROOTDIR/src/load_module.sh" "$@" || exit 1
if [[ -z "$CICD_BOOTSTRAP_SKIP_CLEANUP" ]] && ! cicd::bootstrap::cleanup; then
  echo "couldn't perform cicd tools cleanup!"
  exit 1
fi
