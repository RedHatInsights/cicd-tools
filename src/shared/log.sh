#!/bin/bash

# logging helper funtions

CICD_LOG_DEBUG=${CICD_LOG_DEBUG:-}

if [[ -n "$CICD_LOG_MODULE_LOADED" ]]; then
  cicd::log::debug "log module already loaded, skipping"
  return 0
fi

cicd::log::debug() {
  if cicd::log::_debug_mode; then
    cicd::log::info "$*"
  fi
}

cicd::log::_debug_mode() {
  [[ -n "$CICD_LOG_DEBUG" ]]
}

cicd::log::info() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*"
}

cicd::log::err() {
  echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $*" >&2
}

cicd::log::debug "log module loaded"
CICD_LOG_MODULE_LOADED='true'
