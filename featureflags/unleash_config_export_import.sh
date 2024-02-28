#!/bin/sh

set -x

# Pass in the name of the ephemeral namespace that will receive the imported toggles
export EPHEMERAL_NAMESPACE="$1"

###########################################################################################
# In order to run this script, the following needs needs to be provided
#
# These will get removed from script when we convert to using a Kubernetes job
###########################################################################################

# EXPORT
STAGE_UNLEASH_URL=""
STAGE_UNLEASH_ADMIN_API_TOKEN=""          # This is retrieved in a later step until we convert to a job
STAGE_UNLEASH_NAMESPACE=""
STAGE_UNLEASH_SECRET_NAME=""              # This is retrieved in a later step until we convert to a job

# IMPORT
EE_UNLEASH_URL=""
EE_UNLEASH_PERSONAL_ACCESS_TOKEN=""


echo "\n
###########################################################################################
# Get name of FF pod from the ephemeral envionment
###########################################################################################
"
EPHEMERAL_FF_POD=$(oc get pods -n $STAGE_UNLEASH_NAMESPACE | awk '/env-ephemeral/ && /featureflags/' | awk '{print $1}')


echo "\n
###########################################################################################
# Retrieve admin API token from namespace secrets in Stage cluster
###########################################################################################
"
STAGE_FF_SECRET_NAME=$(oc get secrets -n $STAGE_UNLEASH_NAMESPACE | awk '/env-ephemeral/ && /featureflags/' | awk '{print $1}')
export STAGE_UNLEASH_ADMIN_API_TOKEN=$(oc get secret $STAGE_FF_SECRET_NAME -n $STAGE_UNLEASH_NAMESPACE -o jsonpath='{.data.adminAccessToken}' | base64 --decode)


echo "\n
###########################################################################################
# Retrieve a list of toggle names
###########################################################################################
"
curl -L -X GET "${STAGE_UNLEASH_URL}/api/admin/projects/default/features" \
-H "Accept: application/json" \
-H "Authorization: ${STAGE_UNLEASH_ADMIN_API_TOKEN}" > feature_flags_toggle_names.json

UNLEASH_PROJECT_TOGGLE_NAMES=$(jq -r [.features[].name] feature_flags_toggle_names.json)
echo $UNLEASH_PROJECT_TOGGLE_NAMES


echo "\n
###########################################################################################
# Export toggles from Unleash pod in Stage cluster
###########################################################################################
"
curl -L -X POST "${STAGE_UNLEASH_URL}/api/admin/features-batch/export" \
-H "Content-Type: application/json" \
-H "Accept: application/json" \
-H "Authorization: $STAGE_UNLEASH_ADMIN_API_TOKEN" \
--data-raw '{
  "environment": "development",
  "downloadFile": true,
  "features": '"${UNLEASH_PROJECT_TOGGLE_NAMES}"'
}' > feature_flags_exported_toggles.json


echo "\n
###########################################################################################
# Import toggles in to ephemeral environment
###########################################################################################
"
EXPORTED_UNLEASH_TOGGLES=$(cat feature_flags_exported_toggles.json)

curl -L -X POST  'http://localhost:4243/api/admin/features-batch/import' -H   'Content-Type: application/json' \
-H 'Accept: application/json' \
-H "Authorization: ${EE_UNLEASH_PERSONAL_ACCESS_TOKEN}" \
--data-raw '{
  "project": "default",
  "environment": "development",
  "data": '"$EXPORTED_UNLEASH_TOGGLES"'
}'

echo "\n
###########################################################################################
# Cleanup json files
###########################################################################################
"
find . -name \*.json -type f -delete
