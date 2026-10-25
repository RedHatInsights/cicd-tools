#!/bin/bash -x

set -x
set -e


APP_NAME=""  # name of app-sre "application" folder this component lives in
COMPONENT_NAME=""  # name of app-sre "resourceTemplate" in deploy.yaml for this component
IMAGE=""
IQE_IMAGE=""

IQE_PLUGINS=""
IQE_MARKER_EXPRESSION=""
IQE_FILTER_EXPRESSION=""
IQE_CJI_TIMEOUT=""

# Install bonfire repo/initialize
CICD_URL=https://raw.githubusercontent.com/RedHatInsights/bonfire/master/cicd
curl -s $CICD_URL/bootstrap.sh > .cicd_bootstrap.sh && source .cicd_bootstrap.sh

echo $(date -u) "*** To start image build"
source $CICD_ROOT/build.sh

echo $(date -u) "*** To start deployment"
source ${CICD_ROOT}/_common_deploy_logic.sh
export NAMESPACE=$(bonfire namespace reserve)
export IQE_IMAGE=quay.io/cloudservices/iqe-tests:automation-analytics

bonfire deploy \
   ${APP_NAME} \
   --source appsre \
   --set-template-ref ${COMPONENT_NAME}=${GIT_COMMIT} \
   --set-image-tag $IMAGE=$IMAGE_TAG \
   --namespace ${NAMESPACE} \
   --frontends=true \
   ${COMPONENTS_ARG}

# ---------
# Test data
# ---------
### Populate test data
oc get deployments -n $NAMESPACE
#oc exec  -n $NAMESPACE deployments/automation-analytics-api-fastapi-v2 -- bash -c "./entrypoint ./tower_analytics_report/management/commands/generate_development_data.py --tenant_id 12345" # 3340852
#oc exec  -n $NAMESPACE deployments/automation-analytics-api-fastapi-v2 -- bash -c "./entrypoint ./tower_analytics_report/management/commands/generate_development_data.py --tenant_id 3340851" # 3340851
oc exec  -n $NAMESPACE deployments/automation-analytics-api-fastapi-v2 -- bash -c "./entrypoint ./tower_analytics_report/management/commands/generate_development_data.py --tenant_id 3340852" # 3340852
oc exec  -n $NAMESPACE deployments/automation-analytics-api-fastapi-v2 -- bash -c "./entrypoint ./tower_analytics_report/management/commands/run_rollups_one_time.py"

echo $(date -u) "*** To start smoke test"
CLOWD_APP_NAME=automation-analytics
COMPONENT_NAME=automation-analytics
source ${CICD_ROOT}/cji_smoke_test.sh

exit 0
