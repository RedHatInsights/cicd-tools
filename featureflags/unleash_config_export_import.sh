#!/bin/bash

# set -x

echo -e "\nsetting required environment variables"
EPHEMERAL_NAMESPACE="${EPHEMERAL_NAMESPACE:-}"
EXPORT_UNLEASH_URL="${EXPORT_UNLEASH_URL:-}"
EXPORT_NAMESPACE="${EXPORT_NAMESPACE:-}"
EXPORT_ADMIN_SECRET="${EXPORT_ADMIN_SECRET:-}"
IMPORT_PAT="${IMPORT_PAT:-}"

echo -e "\nValidating that environment variables are set"
if [ -z "${EXPORT_UNLEASH_URL}" ]; then
    echo -e "\nenvironment variable [EPHEMERAL_NAMESPACE] was not set"
    return 1
fi

if [ -z "${EPHEMERAL_NAMESPACE}" ]; then
    echo -e "\nenvironment variable [EXPORT_UNLEASH_URL] was not set"
    return 1
fi

if [ -z "${EXPORT_NAMESPACE}" ]; then
    echo -e "\nenvironment variable [EXPORT_NAMESPACE] was not set"
    return 1
fi

if [ -z "${EXPORT_ADMIN_SECRET}" ]; then
    echo -e "\nenvironment variable [EXPORT_ADMIN_SECRET] was not set"
    return 1
fi

if [ -z "${IMPORT_PAT}" ]; then
    echo -e "\nenvironment variable [IMPORT_PAT] was not set"
    return 1
fi

echo -e "\nMaking directory for temp json files"
mkdir featureflags

echo -e "\nRetrieve the admin api token from the export environment"
EXPORT_SECRET=$(oc get secrets -n $EXPORT_NAMESPACE | awk '/env-ephemeral/ && /featureflags/' | awk '{print $1}')
EXPORT_ADMIN_SECRET=$(oc get secret $EXPORT_SECRET -n $EXPORT_NAMESPACE -o jsonpath='{.data.adminAccessToken}' | base64 --decode)

echo -e "\nRetrieve a list of toggle names to export from environment"
curl -L -X GET "${EXPORT_UNLEASH_URL}/api/admin/projects/default/features" \
-H "Accept: application/json" \
-H "Authorization: ${EXPORT_ADMIN_SECRET}" > featureflags/feature_flags_toggle_names.json

UNLEASH_PROJECT_TOGGLE_NAMES=$(jq -r [.features[].name] featureflags/feature_flags_toggle_names.json)
printf "\nlist of toggle names:\n%s\n" "$UNLEASH_PROJECT_TOGGLE_NAMES"

echo -e "\nExporting toggles from environment"
curl -L -X POST "${EXPORT_UNLEASH_URL}/api/admin/features-batch/export" \
-H "Content-Type: application/json" \
-H "Accept: application/json" \
-H "Authorization: $EXPORT_ADMIN_SECRET" \
--data-raw '{
  "environment": "development",
  "downloadFile": true,
  "features": '"${UNLEASH_PROJECT_TOGGLE_NAMES}"'
}' > featureflags/feature_flags_exported_toggles.json

echo -e "\nImport toggles into ephemeral environment"
EXPORTED_UNLEASH_TOGGLES=$(cat featureflags/feature_flags_exported_toggles.json)

curl -L -X POST  'http://localhost:4243/api/admin/features-batch/import' -H   'Content-Type: application/json' \
-H 'Accept: application/json' \
-H "Authorization: ${IMPORT_PAT}" \
--data-raw '{
  "project": "default",
  "environment": "development",
  "data": '"$EXPORTED_UNLEASH_TOGGLES"'
}'

printf "\nToggles imported into ephemeral environment:\n%s\n" "$EXPORTED_UNLEASH_TOGGLES"

echo -e "\nCleanup json files"
rm -rf featureflags
