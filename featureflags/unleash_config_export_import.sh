#!/bin/bash


EPHEMERAL_NAMESPACE="${EPHEMERAL_NAMESPACE:-}"
EXPORT_UNLEASH_URL="${EXPORT_UNLEASH_URL:-}"
EXPORT_NAMESPACE="${EXPORT_NAMESPACE:-}"

 # This is retrieved in a later step until we convert to a job
EXPORT_ADMIN_SECRET="${EXPORT_ADMIN_SECRET:-}"
IMPORT_PAT="${IMPORT_PAT:-}"

declare -A required_env_vars
required_env_vars["EPHEMERAL_NAMESPACE"]=$EPHEMERAL_NAMESPACE
required_env_vars["EXPORT_UNLEASH_URL"]=$EXPORT_UNLEASH_URL
required_env_vars["EXPORT_NAMESPACE"]=$EXPORT_NAMESPACE
required_env_vars["EXPORT_ADMIN_SECRET"]=$EXPORT_ADMIN_SECRET
required_env_vars["IMPORT_PAT"]=$IMPORT_PAT

for var in "${required_env_vars[@]}"
do
  if {{ -z required_env_vars[var] }}; then
    printf "variable [%s] was not set" "var"
    return 1
  fi
done

mkdir featureflags

# Retrieve the admin api token from the export environment
EXPORT_SECRET=$(oc get secrets -n $EXPORT_NAMESPACE | awk '/env-ephemeral/ && /featureflags/' | awk '{print $1}')
EXPORT_ADMIN_SECRET=$(oc get secret $EXPORT_SECRET -n $EXPORT_NAMESPACE -o jsonpath='{.data.adminAccessToken}' | base64 --decode)

# Retrieve a list of toggle names to export from environment
curl -L -X GET "${EXPORT_UNLEASH_URL}/api/admin/projects/default/features" \
-H "Accept: application/json" \
-H "Authorization: ${EXPORT_ADMIN_SECRET}" > featureflags/feature_flags_toggle_names.json

UNLEASH_PROJECT_TOGGLE_NAMES=$(jq -r [.features[].name] featureflags/feature_flags_toggle_names.json)
echo $UNLEASH_PROJECT_TOGGLE_NAMES

# Export toggles
curl -L -X POST "${EXPORT_UNLEASH_URL}/api/admin/features-batch/export" \
-H "Content-Type: application/json" \
-H "Accept: application/json" \
-H "Authorization: $EXPORT_ADMIN_SECRET" \
--data-raw '{
  "environment": "development",
  "downloadFile": true,
  "features": '"${UNLEASH_PROJECT_TOGGLE_NAMES}"'
}' > featureflags/feature_flags_exported_toggles.json

# Import toggles into ephemeral environment
EXPORTED_UNLEASH_TOGGLES=$(cat tmp/feature_flags_exported_toggles.json)

curl -L -X POST  'http://localhost:4243/api/admin/features-batch/import' -H   'Content-Type: application/json' \
-H 'Accept: application/json' \
-H "Authorization: ${IMPORT_PAT}" \
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

rm -rf featureflags
