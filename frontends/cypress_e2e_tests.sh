#!/bin/bash

set -x

CYPRESS_TEST_IMAGE="quay.io/cloudservices/cypress-e2e-image:06b70f3"

source ./helpers/general.sh

trap_proxy teardown EXIT ERR SIGINT SIGTERM

# Create tmp dir to store data in during job run (do NOT store in $WORKSPACE)
export TMP_JOB_DIR=$(mktemp -d -p "$HOME" -t "jenkins-${JOB_NAME}-${BUILD_NUMBER}-XXXXXX")
echo "job tmp dir location: $TMP_JOB_DIR"

# Set up docker cfg
export DOCKER_CONFIG="${TMP_JOB_DIR}/.docker"
export REGISTRY_AUTH_FILE="${DOCKER_CONFIG}/config.json"

mkdir "$DOCKER_CONFIG"

docker login -u="$QUAY_USER" -p="$QUAY_TOKEN" quay.io

docker run \
    --name $TEST_CONT \
    -v $PWD:/e2e:ro,Z \
    -e CHROME_ACCOUNT=$CHROME_ACCOUNT \
    -e CHROME_PASSWORD=$CHROME_PASSWORD \
    --add-host stage.foo.redhat.com:127.0.0.1 \
    --add-host prod.foo.redhat.com:127.0.0.1 \
    --rm \
    --entrypoint bash \
    "${CYPRESS_TEST_IMAGE}" /e2e/run-e2e.sh

RESULT=$?

exit $RESULT
