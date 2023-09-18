#!/usr/bin/env bash

COVERAGE_DIRECTORY="$PWD/coverage"
BATS_CMD='bats'
TESTS_DIRECTORY='test'
IGNORE_TAGS='!no-kcov'
KCOV_CMD='kcov'

get_kcov() {
  local url='https://github.com/SimonKagstrom/kcov/releases/download/v40/kcov-amd64.tar.gz'
  curl -sL "$url" | tar -xz usr/local/bin/kcov --strip-components=3
}

if [ "$CI" = 'true' ]; then
    get_kcov || exit 1
    KCOV_CMD='./kcov'
fi

if [ -d "$COVERAGE_DIRECTORY" ]; then
  rm -rf "$COVERAGE_DIRECTORY"
fi

"$KCOV_CMD" --include-pattern cicd-tools/src \
    "$COVERAGE_DIRECTORY" \
    "$BATS_CMD" \
    --filter-tags "$IGNORE_TAGS" \
    "$TESTS_DIRECTORY"
