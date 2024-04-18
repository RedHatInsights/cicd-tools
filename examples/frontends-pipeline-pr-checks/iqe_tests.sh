#!/bin/bash

set -x

curl -s $CICD_URL/bootstrap.sh > .cicd_bootstrap.sh 
source ./.cicd_bootstrap.sh

GIT_COMMIT="master"
IMAGE_TAG="latest"

source $CICD_TOOLS_DIR/deploy_ephemeral_env.sh
source $CICD_TOOLS_DIR/cji_smoke_test.sh

mkdir artifacts
cat << EOF > artifacts/junit-dummy.xml
<testsuite tests="1">
    <testcase classname="dummy" name="dummytest"/>
</testsuite>
EOF

RESULT=$?

if [[ $RESULT -ne 0 ]]; then
    exit $RESULT
fi

exit $RESULT
