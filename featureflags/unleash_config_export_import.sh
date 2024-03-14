#!/bin/bash

# set -x

function export_toggles() {
    echo -e "\nRetrieve a list of toggle names to export from environment"
    curl -L -X GET "${EXPORT_UNLEASH_URL}/api/admin/projects/default/features" \
    -H "Accept: application/json" \
    -H "Authorization: ${EXPORT_ADMIN_SECRET}" > featureflags/feature_flags_toggle_names.json

    printf "JSON_TOGGLES_PATH: %s" "${JSON_TOGGLES_PATH}"
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
}

function validate_environment_variables() {
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

    echo -e "\nAll required environment variables are set"
}

echo -e "\nsetting required environment variables"
EPHEMERAL_NAMESPACE="${EPHEMERAL_NAMESPACE:-}"
EXPORT_UNLEASH_URL="${EXPORT_UNLEASH_URL:-}"
EXPORT_NAMESPACE="${EXPORT_NAMESPACE:-}"
EXPORT_ADMIN_SECRET="${EXPORT_ADMIN_SECRET:-}"
IMPORT_PAT="${IMPORT_PAT:-}"
IMPORT_LOCALLY="${IMPORT_LOCALLY:-false}"
JSON_TOGGLES_PATH="${JSON_TOGGLES_PATH:-'featureflags/feature_flags_exported_toggles.json'}"

validate_environment_variables

echo -e "\nMaking directory for temp json files"
mkdir featureflags

if [ "${IMPORT_LOCALLY}" == false ]; then
    echo -e "\nenvironment variable [JSON_TOGGLES_PATH] was not set,\nexporting out of environment"
    export_toggles
fi

echo -e "\nImport toggles into ephemeral environment"
EXPORTED_UNLEASH_TOGGLES=$(cat "featureflags/feature_flags_exported_toggles.json")

curl -L -X POST 'http://localhost:4243/api/admin/features-batch/import' -H 'Content-Type: application/json' \
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
