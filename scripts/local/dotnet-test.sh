#!/usr/bin/env bash
set -euo pipefail

# Run unit or integration tests on the project SDK.
# Modes: normal (default), --watch (dev/watch), --coverage (full coverage + threshold).
# Per-kind config (project, results, coverage include/exclude, threshold) lives in
# .config/dotnet-base.test.yaml (override the path with DOTNET_TEST_CONFIG).
# Coverage and test-result artifacts are preserved even when tests fail, so a red run
# still feeds Codecov. Usage: dotnet-test.sh <unit|int> [--watch|--coverage]

KIND="${1:-}"
MODE="${2:-normal}"

[[ ${KIND} == "unit" || ${KIND} == "int" ]] || {
  echo "❌ Usage: dotnet-test.sh <unit|int> [--watch|--coverage]"
  exit 1
}

# Reject unknown modes instead of silently falling through to normal tests — a typo like
# `--cov` must not quietly skip coverage/threshold enforcement.
case "${MODE}" in
normal | --watch | --coverage) ;;
*)
  echo "❌ Unknown mode '${MODE}'. Usage: dotnet-test.sh <unit|int> [--watch|--coverage]"
  exit 1
  ;;
esac

# Read the per-kind config straight from the YAML (unit and int share the same shape).
CONFIG="${DOTNET_TEST_CONFIG:-.config/dotnet-base.test.yaml}"
[[ -f ${CONFIG} ]] || {
  echo "❌ Test config not found: ${CONFIG}"
  exit 1
}
command -v yq >/dev/null || {
  echo "❌ yq is required to read ${CONFIG}"
  exit 1
}
yaml() { yq -er "${1} // \"\"" "${CONFIG}"; }
yaml_list() { yq -er "${1} // [] | join(\",\")" "${CONFIG}"; }

COV_FORMAT="$(yaml '.coverage.format')"
PROJECT="$(yaml ".coverage.${KIND}.project")"
RESULTS="$(yaml ".coverage.${KIND}.results")"
COV_OUT="$(yaml ".coverage.${KIND}.output")"
COV_MIN="$(yaml ".coverage.${KIND}.minimum")"
COV_INC="$(yaml_list ".coverage.${KIND}.include")"
COV_EXC="$(yaml_list ".coverage.${KIND}.exclude")"

# Fail loudly on missing required config rather than running with empty paths/projects.
for key in PROJECT RESULTS COV_OUT COV_MIN; do
  [[ -n ${!key} ]] || {
    echo "❌ Missing .coverage.${KIND} config for ${key} in ${CONFIG}"
    exit 1
  }
done

[[ ${COV_FORMAT} == cobertura ]] || {
  echo "❌ Coverage format '${COV_FORMAT}' is unsupported (only 'cobertura')"
  exit 1
}

[[ ${PROJECT} == *.csproj && ${PROJECT} != /* && ${PROJECT} != *..* && -f ${PROJECT} ]] || {
  echo "❌ ${KIND} project '${PROJECT}' must be a relative .csproj path"
  exit 1
}

for path in "${RESULTS}" "${COV_OUT}"; do
  [[ ${path} == TestResults/?* && ${path} != *..* ]] || {
    echo "❌ ${KIND} artifact path '${path}' must be under TestResults/ with no '..'"
    exit 1
  }
done

# Validate the threshold so the awk numeric compare can't silently degrade to a string
# compare (e.g. '100x' would always pass).
[[ ${COV_MIN} =~ ^[0-9]+$ && ${COV_MIN} -ge 0 && ${COV_MIN} -le 100 ]] || {
  echo "❌ ${KIND} coverage minimum '${COV_MIN}' must be an integer in [0,100]"
  exit 1
}

# Dev/watch mode hands off to `dotnet watch test` and never returns.
[[ ${MODE} == "--watch" ]] && {
  echo "👀 Watching ${KIND} tests..."
  exec dotnet watch --project "${PROJECT}" test
}

# Normal mode: run tests, always keep the trx result, propagate the test exit code.
[[ ${MODE} == "--coverage" ]] || {
  echo "🧪 Running ${KIND} tests..."
  mkdir -p "${RESULTS}"
  set +e
  dotnet test "${PROJECT}" -c Release --logger "trx;LogFileName=${KIND}.trx" --results-directory "${RESULTS}"
  code=$?
  set -e
  echo "📦 Test results preserved in ${RESULTS}"
  exit "${code}"
}

# Coverage mode: collect coverage, preserve the report, then enforce the threshold.
echo "🧪 Running ${KIND} tests with coverage (min ${COV_MIN}%)..."
rm -rf "${RESULTS}"
mkdir -p "${COV_OUT}"

set +e
dotnet test "${PROJECT}" -c Release \
  --logger "trx;LogFileName=${KIND}.trx" \
  --results-directory "${RESULTS}" \
  --collect:"XPlat Code Coverage" \
  -- \
  DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format="${COV_FORMAT}" \
  DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Include="${COV_INC}" \
  DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Exclude="${COV_EXC}"
code=$?
set -e

# Preserve the coverage report regardless of the outcome (Codecov needs it on red runs too).
report="$(find "${RESULTS}" -path "${COV_OUT}" -prune -o -name 'coverage.cobertura.xml' -print | sort | tail -n 1)"
report_out="${COV_OUT}/coverage.cobertura.xml"
[[ -n ${report} ]] && cp "${report}" "${report_out}" && echo "📦 Coverage report: ${report_out}"

# Fail (after preserving the report) when the tests themselves failed.
[[ ${code} -eq 0 ]] || {
  echo "❌ ${KIND} tests failed (exit ${code}); coverage report preserved"
  exit "${code}"
}

# Enforce the configured line-coverage threshold.
[[ -n ${report} ]] || {
  echo "❌ No coverage report produced"
  exit 1
}
# Guard against a hollow gate: an empty *_COVERAGE_INCLUDE makes coverlet emit line-rate="1"
# with lines-valid="0", which would pass at a vacuous 100% measuring nothing.
valid="$(grep -m1 -oE 'lines-valid="[0-9]+"' "${report_out}" | grep -oE '[0-9]+')"
[[ ${valid:-0} -gt 0 ]] || {
  echo "❌ Coverage measured 0 lines — check the ${KIND} coverage Include matches a built assembly"
  exit 1
}
rate="$(grep -m1 -oE 'line-rate="[0-9.]+"' "${report_out}" | grep -oE '[0-9.]+')"
pct="$(awk -v r="${rate}" 'BEGIN { printf "%.2f", r * 100 }')"
echo "📊 ${KIND} line coverage: ${pct}% (min ${COV_MIN}%)"
awk -v p="${pct}" -v m="${COV_MIN}" 'BEGIN { exit !(p >= m) }' || {
  echo "❌ Coverage ${pct}% is below the ${COV_MIN}% minimum"
  exit 1
}
echo "✅ ${KIND} coverage ${pct}% meets the ${COV_MIN}% minimum"
