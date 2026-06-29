#!/usr/bin/env bash
set -euo pipefail

# Load and validate the dotnet test/coverage configuration.
# Sourced by the local test/coverage helpers: `source scripts/local/dotnet-config.sh`.
# Keys live in .config/dotnet-base.test.yaml (override the path with DOTNET_TEST_CONFIG).

DOTNET_TEST_CONFIG="${DOTNET_TEST_CONFIG:-.config/dotnet-base.test.yaml}"

[[ -f ${DOTNET_TEST_CONFIG} ]] || {
  echo "❌ Test config not found: ${DOTNET_TEST_CONFIG}"
  exit 1
}
command -v yq >/dev/null || {
  echo "❌ yq is required to read ${DOTNET_TEST_CONFIG}"
  exit 1
}

yaml_string() {
  yq -er "${1} // \"\"" "${DOTNET_TEST_CONFIG}"
}

yaml_list() {
  yq -er "${1} // [] | join(\",\")" "${DOTNET_TEST_CONFIG}"
}

echo "📝 Loading test config: ${DOTNET_TEST_CONFIG}"
export TEST_COVERAGE_FORMAT
TEST_COVERAGE_FORMAT="$(yaml_string '.coverage.format')"

export UNIT_PROJECT UNIT_TEST_RESULTS UNIT_COVERAGE_OUTPUT UNIT_COVERAGE_MIN UNIT_COVERAGE_INCLUDE UNIT_COVERAGE_EXCLUDE
UNIT_PROJECT="$(yaml_string '.coverage.unit.project')"
UNIT_TEST_RESULTS="$(yaml_string '.coverage.unit.results')"
UNIT_COVERAGE_OUTPUT="$(yaml_string '.coverage.unit.output')"
UNIT_COVERAGE_MIN="$(yaml_string '.coverage.unit.minimum')"
UNIT_COVERAGE_INCLUDE="$(yaml_list '.coverage.unit.include')"
UNIT_COVERAGE_EXCLUDE="$(yaml_list '.coverage.unit.exclude')"

export INT_PROJECT INT_TEST_RESULTS INT_COVERAGE_OUTPUT INT_COVERAGE_MIN INT_COVERAGE_INCLUDE INT_COVERAGE_EXCLUDE
INT_PROJECT="$(yaml_string '.coverage.int.project')"
INT_TEST_RESULTS="$(yaml_string '.coverage.int.results')"
INT_COVERAGE_OUTPUT="$(yaml_string '.coverage.int.output')"
INT_COVERAGE_MIN="$(yaml_string '.coverage.int.minimum')"
INT_COVERAGE_INCLUDE="$(yaml_list '.coverage.int.include')"
INT_COVERAGE_EXCLUDE="$(yaml_list '.coverage.int.exclude')"

for key in \
  TEST_COVERAGE_FORMAT \
  UNIT_PROJECT UNIT_TEST_RESULTS UNIT_COVERAGE_OUTPUT UNIT_COVERAGE_MIN UNIT_COVERAGE_INCLUDE \
  INT_PROJECT INT_TEST_RESULTS INT_COVERAGE_OUTPUT INT_COVERAGE_MIN INT_COVERAGE_INCLUDE; do
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

for key in UNIT_PROJECT INT_PROJECT; do
  [[ ${!key} == *.csproj && ${!key} != /* && ${!key} != *..* && -f ${!key} ]] || {
    echo "❌ ${key}='${!key}' must be a relative .csproj path"
    exit 1
  }
done

echo "✅ Test config loaded"
