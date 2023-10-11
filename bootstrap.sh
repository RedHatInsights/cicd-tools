#!/bin/bash

set -e

# Gives access to helper commands such as "oc_wrapper"
add_cicd_bin_to_path() {
  if ! command -v oc_wrapper; then
      export PATH=$PATH:${CICD_ROOT}/bin
  fi
}

check_available_server() {
    echo "Checking connectivity to ephemeral cluster ..."
    if ! curl -s $OC_LOGIN_SERVER > /dev/null; then
        echo "Connectivity check failed"
        return 1
    fi
}

# Hotswap based on availability
login_to_available_server() {
    if check_available_server; then
      # log in to ephemeral cluster
      oc_wrapper login --token=$OC_LOGIN_TOKEN --server=$OC_LOGIN_SERVER
      echo "logging in to Ephemeral cluster"
    else
      # switch to crcd cluster
      oc_wrapper login --token=$OC_LOGIN_TOKEN_DEV --server=$OC_LOGIN_SERVER_DEV
      echo "logging in to CRCD cluster"
    fi
}

check_unit_test_script() {

    # check that unit_test.sh complies w/ best practices
    local URL="https://github.com/RedHatInsights/cicd-tools/tree/main/examples"

    if test -f unit_test.sh; then
      if grep 'exit $result' unit_test.sh; then
        echo "----------------------------"
        echo "ERROR: unit_test.sh is calling 'exit' improperly, refer to examples at $URL"
        echo "----------------------------"
        exit 1
      fi
    fi
}

# TODO: create custom jenkins agent image that has a lot of this stuff pre-installed
export LANG=en_US.utf-8
export LC_ALL=en_US.utf-8
export APP_ROOT=$(pwd)
export WORKSPACE=${WORKSPACE:-$APP_ROOT}  # if running in jenkins, use the build's workspace
export CICD_ROOT=${WORKSPACE}/.cicd-tools
export IMAGE_TAG=$(git rev-parse --short=7 HEAD)
export BONFIRE_BOT="true"
export BONFIRE_NS_REQUESTER="${JOB_NAME}-${BUILD_NUMBER}"
# which branch to fetch cicd scripts from in cicd-tools repo
export CICD_REPO_BRANCH="${CICD_REPO_BRANCH:-main}"
export CICD_REPO_ORG="${CICD_REPO_ORG:-RedHatInsights}"
export DOCKER_CONFIG="$WORKSPACE/.docker"
export KUBECONFIG_DIR="$WORKSPACE/.kube"
export KUBECONFIG="$KUBECONFIG_DIR/config"
export GIT_COMMIT=$(git rev-parse HEAD)
export ARTIFACTS_DIR="$WORKSPACE/artifacts"

# if this is a PR, use a different tag, since PR tags expire
if [ ! -z "$ghprbPullId" ]; then
  export IMAGE_TAG="pr-${ghprbPullId}-${IMAGE_TAG}"
fi

if [ ! -z "$gitlabMergeRequestIid" ]; then
  export IMAGE_TAG="pr-${gitlabMergeRequestIid}-${IMAGE_TAG}"
fi

# TODO: decide removal
check_unit_test_script

# Set up docker cfg
rm -fr $DOCKER_CONFIG
mkdir $DOCKER_CONFIG

# Set up kube cfg
rm -fr $KUBECONFIG_DIR
mkdir $KUBECONFIG_DIR

rm -fr $ARTIFACTS_DIR && mkdir -p $ARTIFACTS_DIR

# clone repo to download cicd scripts
rm -fr "$CICD_ROOT"
echo "Fetching branch '$CICD_REPO_BRANCH' of https://github.com/${CICD_REPO_ORG}/cicd-tools.git"
git clone --branch "$CICD_REPO_BRANCH" "https://github.com/${CICD_REPO_ORG}/cicd-tools.git" "$CICD_ROOT"

python3 -m venv "${CICD_ROOT}/.bonfire_venv"
source "${CICD_ROOT}/.bonfire_venv/bin/activate"

python3 -m pip install --upgrade pip 'setuptools<58' wheel
python3 -m pip install --upgrade 'crc-bonfire>=4.10.4'

# Do a docker login to ensure our later 'docker pull' calls have an auth file created
source ${CICD_ROOT}/_common_container_logic.sh
login

add_cicd_bin_to_path
login_to_available_server
