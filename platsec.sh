#!/bin/bash

IMAGE_NAME="${1:-$IMAGE_NAME}"
ARTIFACTS_DIR="${2:-$(pwd)/vuln_artifacts}"
IMAGE_TO_SCAN=''

download_install_script() {

  local command="$1"
  local destination="$2"

  curl -sSfL "https://raw.githubusercontent.com/anchore/${command}/main/install.sh" | sh -s -- -b "$destination"
}

setup() {

  if [ -z "$IMAGE_NAME" ]; then
    echo "You need to provide an image to scan"
    return 1
  fi

  set -e

  # shellcheck source=/dev/null
  source <(curl -sSL https://raw.githubusercontent.com/RedHatInsights/cicd-tools/main/src/bootstrap.sh) image_builder
  export CICD_IMAGE_BUILDER_IMAGE_NAME="$IMAGE_NAME"
  IMAGE_TO_SCAN=$(cicd::image_builder::get_full_image_name)
  set +e

  if ! [ -d "$ARTIFACTS_DIR" ]; then
    if ! mkdir -p "$ARTIFACTS_DIR"; then
      echo "Error creating artifacts dir: '$ARTIFACTS_DIR'"
      return 1
    fi
  fi

  local SCRIPTS_DIR
  SCRIPTS_DIR=$(mktemp -d)
  export PATH="$PATH:$SCRIPTS_DIR"

  if ! cicd::common::command_is_present "syft"; then
    download_install_script syft "$SCRIPTS_DIR"
  fi

  if ! cicd::common::command_is_present "grype"; then
    download_install_script grype "$SCRIPTS_DIR"
  fi
}

if ! setup; then
  echo "Error while initializing"
  exit 1
fi

syft -v "${IMAGE_TO_SCAN}" >"${ARTIFACTS_DIR}/syft-sbom-results.txt"
grype -v -o table --scope all-layers "${IMAGE_TO_SCAN}" >"${ARTIFACTS_DIR}/grype-vuln-results-full.txt"
grype -v -o table --only-fixed --fail-on high "${IMAGE_TO_SCAN}" >"${ARTIFACTS_DIR}/grype-vuln-results-fixable.txt"
