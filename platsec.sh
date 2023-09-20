#!/bin/bash

IMAGE_NAME="${1:-$IMAGE_NAME}"
ARTIFACTS_DIR="${2:-vuln-artifacts}"

export CICD_IMAGE_BUILDER_IMAGE_NAME="$IMAGE_NAME"

source <(curl -sSL https://raw.githubusercontent.com/RedHatInsights/cicd-tools/main/src/bootstrap.sh) image_builder 

IMAGE_TO_SCAN=$(cicd::image_builder::get_full_image_name)

rm -fr $ARTIFACTS_DIR && mkdir -p $ARTIFACTS_DIR

function download (){
    curl -sSfL https://raw.githubusercontent.com/anchore/$1/main/install.sh | sh -s -- -b ./bins
}

if ! ./bins/syft; then
    download syft
fi

if ! ./bins/grype; then
    download grype
fi

#install and run syft
./bins/syft -v ${IMAGE_TO_SCAN} > "${ARTIFACTS_DIR}/syft-sbom-results.txt"

#install and run grype
./bins/grype -v -o table --scope all-layers ${IMAGE_TO_SCAN} > "${ARTIFACTS_DIR}/grype-vuln-results-full.txt"
./bins/grype -v -o table --only-fixed --fail-on high ${IMAGE_TO_SCAN} > "${ARTIFACTS_DIR}/grype-vuln-results-fixable.txt"

