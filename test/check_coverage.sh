#!/bin/bash

minimum_coverage=${minimum_coverage:-90.01}
coverage_report='coverage/bats/coverage.json'
value=$(jq -r '.percent_covered' < $coverage_report)

reformat_decimal_to_int() {
  printf "%0.2f" "$1" | sed 's/\.//'
}

echo "Coverage: $value%" | tee "$GITHUB_STEP_SUMMARY"

if (( $(reformat_decimal_to_int "$value") < $(reformat_decimal_to_int "$minimum_coverage") )); then
 echo "  is below required minimum coverage ($minimum_coverage%)." | tee -a "$GITHUB_STEP_SUMMARY"
 exit 1
fi
