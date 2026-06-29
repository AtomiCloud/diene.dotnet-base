#!/usr/bin/env bash
set -euo pipefail

# Load and validate the dotnet test/coverage configuration.
# Sourced by the local test/coverage helpers: `source scripts/local/dotnet-config.sh`.
# Keys live in .config/dotnet-base.test.env (override the path with DOTNET_TEST_ENV).

DOTNET_TEST_ENV="${DOTNET_TEST_ENV:-.config/dotnet-base.test.env}"

[[ -f ${DOTNET_TEST_ENV} ]] || {
  echo "❌ Test config not found: ${DOTNET_TEST_ENV}"
  exit 1
}

echo "📝 Loading test config: ${DOTNET_TEST_ENV}"
set -a
# shellcheck disable=SC1090
source "${DOTNET_TEST_ENV}"
set +a

# Fail fast on a missing key so a misconfigured file never silently weakens a gate.
for key in \
  TEST_COVERAGE_FORMAT \
  UNIT_TEST_RESULTS UNIT_COVERAGE_OUTPUT UNIT_COVERAGE_MIN UNIT_COVERAGE_INCLUDE \
  INT_TEST_RESULTS INT_COVERAGE_OUTPUT INT_COVERAGE_MIN INT_COVERAGE_INCLUDE; do
  [[ -n ${!key:-} ]] || {
    echo "❌ Missing config key: ${key}"
    exit 1
  }
done

# Only cobertura is supported: the coverage parser reads cobertura-specific attributes
# (line-rate, lines-valid) from a hardcoded coverage.cobertura.xml. Any other format silently
# yields "no coverage report"; reject it here instead so the knob can't lie.
[[ ${TEST_COVERAGE_FORMAT} == cobertura ]] || {
  echo "❌ TEST_COVERAGE_FORMAT='${TEST_COVERAGE_FORMAT}' is unsupported (only 'cobertura')"
  exit 1
}

# Constrain coverage thresholds to integers in [0,100]. The threshold check in dotnet-test.sh
# is an awk numeric compare; a non-numeric value (e.g. '100x') would degrade to a string compare
# and silently pass, and '-1' would make the gate near-always-pass.
for key in UNIT_COVERAGE_MIN INT_COVERAGE_MIN; do
  [[ ${!key} =~ ^[0-9]+$ && ${!key} -ge 0 && ${!key} -le 100 ]] || {
    echo "❌ ${key}='${!key}' must be an integer in [0,100]"
    exit 1
  }
done

# Constrain result/output paths to the TestResults/ artifact tree. The coverage run does
# `rm -rf "${RESULTS}"`, so a misconfigured value (absolute path, '..' traversal, or a source
# dir such as Lib) could delete project source. Require a relative path under TestResults/.
for key in UNIT_TEST_RESULTS UNIT_COVERAGE_OUTPUT INT_TEST_RESULTS INT_COVERAGE_OUTPUT; do
  [[ ${!key} == TestResults/?* && ${!key} != *..* ]] || {
    echo "❌ ${key}='${!key}' must be a relative path under TestResults/ (no '..')"
    exit 1
  }
done

echo "✅ Test config loaded"
