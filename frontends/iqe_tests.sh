#!/bin/bash

set -x

source ./helpers/general.sh

trap_proxy teardown EXIT ERR SIGINT SIGTERM

install_bootstrap

GIT_COMMIT="$GIT_COMMIT_HASH"
IMAGE_TAG="pr-${ghprbPullId}-${ghprbActualCommit:0:7}"

source $CICD_ROOT/deploy_ephemeral_env.sh

COMPONENT_NAME="$CJI_COMPONENT_NAME"
source $CICD_ROOT/cji_smoke_test.sh

RESULT=$?

mkdir -p $WORKSPACE/artifacts
cat << EOF > $WORKSPACE/artifacts/junit-dummy.xml
<testsuite tests="1">
    <testcase classname="dummy" name="dummytest"/>
</testsuite>
EOF

exit $RESULT
