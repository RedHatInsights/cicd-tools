#!/bin/bash

set -e

# check that unit_test.sh complies w/ best practices
URL="https://github.com/RedHatInsights/cicd-tools/tree/main/examples"
if test -f unit_test.sh; then
  if grep 'exit $result' unit_test.sh; then
    echo "----------------------------"
    echo "ERROR: unit_test.sh is calling 'exit' improperly, refer to examples at $URL"
    echo "----------------------------"
    exit 1
  fi
fi

export APP_ROOT=$(pwd)
export WORKSPACE=${WORKSPACE:-$APP_ROOT}  # if running in jenkins, use the build's workspace
export BONFIRE_ROOT=${WORKSPACE}/.bonfire
export CICD_ROOT=${BONFIRE_ROOT}
export IMAGE_TAG=$(git rev-parse --short=7 HEAD)
export BONFIRE_BOT="true"
export BONFIRE_NS_REQUESTER="${JOB_NAME}-${BUILD_NUMBER}"
# which branch to fetch cicd scripts from in bonfire repo
export BONFIRE_REPO_BRANCH="${BONFIRE_REPO_BRANCH:-main}"
export BONFIRE_REPO_ORG="${BONFIRE_REPO_ORG:-RedHatInsights}"
SUPPORTED_CLUSTERS=('ephemeral' 'crcd')
if [[ -z "${AVAILABLE_CLUSTERS[*]}" ]]; then
    AVAILABLE_CLUSTERS=("${SUPPORTED_CLUSTERS[@]}")
fi

set -x
# Set up docker cfg
export DOCKER_CONFIG="${WORKSPACE}/.docker"
rm -rf "$DOCKER_CONFIG"
mkdir "$DOCKER_CONFIG"

# Set up kube cfg
export KUBECONFIG_DIR="${WORKSPACE}/.kube"
export KUBECONFIG="${KUBECONFIG_DIR}/config"
rm -rf "$KUBECONFIG_DIR"
mkdir "$KUBECONFIG_DIR"

set +x

# if this is a PR, use a different tag, since PR tags expire
if [ -n "$ghprbPullId" ]; then
  export IMAGE_TAG="pr-${ghprbPullId}-${IMAGE_TAG}"
fi

if [ -n "$gitlabMergeRequestIid" ]; then
  export IMAGE_TAG="pr-${gitlabMergeRequestIid}-${IMAGE_TAG}"
fi


export GIT_COMMIT=$(git rev-parse HEAD)
export ARTIFACTS_DIR="$WORKSPACE/artifacts"

rm -rf "$ARTIFACTS_DIR" && mkdir -p "$ARTIFACTS_DIR"

# TODO: create custom jenkins agent image that has a lot of this stuff pre-installed
export LANG=en_US.utf-8
export LC_ALL=en_US.utf-8

python3 -m venv .bonfire_venv
source .bonfire_venv/bin/activate

python3 -m pip install --upgrade pip 'setuptools<58' wheel
python3 -m pip install --upgrade 'crc-bonfire>=4.10.4'

# clone repo to download cicd scripts
rm -rf "$BONFIRE_ROOT"
echo "Fetching branch '$BONFIRE_REPO_BRANCH' of https://github.com/${BONFIRE_REPO_ORG}/cicd-tools.git"
git clone --branch "$BONFIRE_REPO_BRANCH" "https://github.com/${BONFIRE_REPO_ORG}/cicd-tools.git" "$BONFIRE_ROOT"

# Do a docker login to ensure our later 'docker pull' calls have an auth file created
source "${CICD_ROOT}/_common_container_logic.sh"
login

# Gives access to helper commands such as "oc_wrapper"
add_cicd_bin_to_path() {
  if ! command -v oc_wrapper; then export PATH=$PATH:${CICD_ROOT}/bin; fi
}

try_login_openshift_cluster() {

    local success cluster_url cluster_token cluster_id

    success=1

    for cluster_id in "${AVAILABLE_CLUSTERS[@]}"; do

        cluster_url=''
        cluster_token=''

        _try_set_cluster_environment_variables "$cluster_id"

        if [[ -z "$cluster_url" ]] || [[ -z "$cluster_token" ]]; then
            echo "Environment variables for cluster '$cluster_id' not found"
        else 
            if _try_login_cluster "$cluster_url" "$cluster_token"; then
                echo "Logged in to cluster '$cluster_id'"
                success=0
                break
            else
                echo "Failed logging into cluster: '$cluster_id'"
            fi
        fi
    done

    return "$success"
}

_try_set_cluster_environment_variables() {

    local cluster_id="$1"

    case "$cluster_id" in

        crcd)
            cluster_url="$OC_LOGIN_SERVER_DEV"
            cluster_token="$OC_LOGIN_TOKEN_DEV"
            ;;

        ephemeral)
            cluster_url="$OC_LOGIN_SERVER"
            cluster_token="$OC_LOGIN_TOKEN"
            ;;

        *)
            echo "Unknown cluster $cluster_id"
            return 1
            ;;
    esac
}

_try_login_cluster() {
    local url="$1"
    local token="$2"
    oc_wrapper login --token="$token" --server="$url"
}

add_cicd_bin_to_path
if ! try_login_openshift_cluster; then
    echo "Failed logging into any cluster!"
    exit 1
fi
