#!/bin/bash

# https://stackoverflow.com/a/246128
if [ -z "$CICD_LOADER_SCRIPTS_DIR" ]; then
  CICD_LOADER_SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
fi

readonly CICD_LOADER_SCRIPTS_DIR

# shellcheck source=src/shared/loader.sh
if ! source "${CICD_LOADER_SCRIPTS_DIR}/shared/loader.sh"; then
  echo "Error loading 'loader' module!"
  exit 1
fi

cicd::loader::load_module "$1"
