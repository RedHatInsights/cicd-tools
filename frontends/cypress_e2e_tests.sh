#!/bin/bash

set -x

CYPRESS_TEST_IMAGE="quay.io/cloudservices/cypress-e2e-image:06b70f3"

source ./helpers/general.sh

trap_proxy teardown EXIT ERR SIGINT SIGTERM

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
