#!/bin/bash

set -x

source ./helpers/general.sh

trap_proxy teardown EXIT ERR SIGINT SIGTERM

docker run --name $TEST_CONT -d -i --rm $NODE_BASE_IMAGE /bin/sh

docker cp . "${TEST_CONT}:/opt/app-root/src/"

docker exec -i -w "/opt/app-root/src/" $TEST_CONT sh -c "npm i"
docker exec -i -w "/opt/app-root/src/" $TEST_CONT sh -c "npm run ci:lint"

RESULT=$?

exit $RESULT
