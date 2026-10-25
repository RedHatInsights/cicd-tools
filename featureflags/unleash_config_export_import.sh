#!/bin/bash

set -x

echo "setting required environment variables"
EPHEMERAL_NAMESPACE="${EPHEMERAL_NAMESPACE:-}"
EXPORT_UNLEASH_URL="${EXPORT_UNLEASH_URL:-}"
EXPORT_NAMESPACE="${EXPORT_NAMESPACE:-}"
EXPORT_ADMIN_SECRET="${EXPORT_ADMIN_SECRET:-}"
IMPORT_PAT="${IMPORT_PAT:-}"
IMPORT_LOCALLY="${IMPORT_LOCALLY:-false}"
JSON_TOGGLES_PATH="${JSON_TOGGLES_PATH:-featureflags/feature_flags_exported_toggles.json}"

echo "JSON_TOGGLES_PATH: $JSON_TOGGLES_PATH"
echo "EXPORT_UNLEASH_URL: $EXPORT_UNLEASH_URL"
echo "IMPORT_LOCALLY: $IMPORT_LOCALLY"

export_toggles() {
    echo "Retrieve a list of toggle names to export from environment"
    curl -L -X GET "${EXPORT_UNLEASH_URL}/api/admin/projects/default/features" \
    -H "Accept: application/json" \
    -H "Authorization: $EXPORT_ADMIN_SECRET" > "featureflags/feature_flags_toggle_names.json"

    echo "JSON_TOGGLES_PATH: $JSON_TOGGLES_PATH"
    UNLEASH_PROJECT_TOGGLE_NAMES=$(jq -r [.features[].name] featureflags/feature_flags_toggle_names.json)
    echo "list of toggle names: $UNLEASH_PROJECT_TOGGLE_NAMES"

    echo -e "Exporting toggles from environment"
    curl -L -X POST "${EXPORT_UNLEASH_URL}/api/admin/features-batch/export" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "Authorization: $EXPORT_ADMIN_SECRET" \
    --data-raw '{
      "environment": "development",
      "downloadFile": true,
      "features": '"${UNLEASH_PROJECT_TOGGLE_NAMES}"'
    }' > "$JSON_TOGGLES_PATH"
}

validate_environment_variables() {
    echo "Validating that environment variables are set"
    if [ -z "${EXPORT_UNLEASH_URL}" ]; then
        echo "environment variable [EXPORT_UNLEASH_URL] was not set"
        return 1
    fi

    if [ -z "${EXPORT_NAMESPACE}" ]; then
        echo "environment variable [EXPORT_NAMESPACE] was not set"
        return 1
    fi

    if [ -z "${EXPORT_ADMIN_SECRET}" ]; then
        echo "environment variable [EXPORT_ADMIN_SECRET] was not set"
        return 1
    fi

    if [ -z "${EPHEMERAL_NAMESPACE}" ]; then
        echo "environment variable [EPHEMERAL_NAMESPACE] was not set"
        return 1
    fi

    if [ -z "${IMPORT_PAT}" ]; then
        echo "environment variable [IMPORT_PAT] was not set"
        return 1
    fi

    echo "\nAll required environment variables are set"
}

# if ! validate_environment_variables; then
#     exit 1
# fi

echo "Making directory for temp json files"
mkdir featureflags

if [ "${IMPORT_LOCALLY}" == false ]; then
    echo "environment variable [JSON_TOGGLES_PATH] was not set, exporting out of environment"
    export_toggles
fi

echo -e "\nImport toggles into ephemeral environment"
EXPORTED_UNLEASH_TOGGLES=$(cat $JSON_TOGGLES_PATH)

curl -L -X POST 'http://localhost:4243/api/admin/features-batch/import' -H 'Content-Type: application/json' \
-H 'Accept: application/json' \
-H "Authorization: ${IMPORT_PAT}" \
--data-raw '{
  "project": "default",
  "environment": "development",
  "data": '"$EXPORTED_UNLEASH_TOGGLES"'
}'

echo "Toggles imported into ephemeral environment: $EXPORTED_UNLEASH_TOGGLES"

echo "Cleanup json files"
rm -rf featureflags
