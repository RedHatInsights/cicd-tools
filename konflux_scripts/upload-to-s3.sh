#!/bin/bash -ex

main() {

    local aws_access_key_id="${AWS_ACCESS_KEY_ID:?AWS_ACCESS_KEY_ID env var was not defined}"
    local aws_secret_access_key="${AWS_SECRET_ACCESS_KEY:?AWS_SECRET_ACCESS_KEY env var was not defined}"
    local artifacts_key="${ARTIFACTS_KEY:?ARTIFACTS_KEY env var was not defined}"
    local aws_default_region="${AWS_DEFAULT_REGION:-us-east-1}"
    local bucket="${BUCKET:-rh-artifacts-bucket}"

    
    aws s3 cp --recursive /artifacts "s3://${bucket}/$(artifacts_key)" --quiet
    url="https://s3.console.aws.amazon.com/s3/buckets/${bucket}?region=${aws_default_region}&prefix=${artifacts_key}/&showversions=false"
    echo -n ${url//'\n'}

}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
