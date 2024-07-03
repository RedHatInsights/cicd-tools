#!/bin/bash

set -x

QUAY_EXPIRE_TIME="${IMAGE_AUTO_DELETION_DAYS}d"

# source "./helpers/general.sh"

# trap_proxy teardown EXIT ERR SIGINT SIGTERM

NODE_BUILD_VERSION=`node -e 'console.log(require("./package.json").engines.node.match(/(\d+)\.\d+\.\d+/)[1])'`

IMAGE="$APP_IMAGE"
IMAGE_TAG="${ghprbActualCommit:0:7}"

curl -sSL "${COMMON_BUILDER}/src/frontend-build.sh" > ".frontend-build.sh"
source "./.frontend-build.sh"

BUILD_RESULTS=$?

exit $BUILD_RESULTS
