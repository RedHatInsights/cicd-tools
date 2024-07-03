#!/bin/bash

set -x

source ./helpers/general.sh

trap_proxy teardown EXIT ERR SIGINT SIGTERM

docker login -u="$QUAY_USER" -p="$QUAY_TOKEN" quay.io

docker run --name $TEST_CONT -d -i --rm  "${CYPRESS_TEST_IMAGE}" /bin/bash

docker cp -a . "${TEST_CONT}:/e2e/"

docker exec -i $TEST_CONT sh -c "npm i"
docker exec -i $TEST_CONT sh -c "npm run ci:cypress-component-tests"

RESULT=$?

if [[ $RESULT -ne 0 ]]; then
    exit $RESULT
fi
