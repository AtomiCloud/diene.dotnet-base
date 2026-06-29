#!/usr/bin/env bash
set -euo pipefail

# Run unit or integration tests on the project SDK.
# Modes: normal (default), --watch (dev/watch), --coverage (full coverage + threshold).
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

# The path is dynamic ($0-relative); the source= hint documents the target, and SC1091 is
# disabled because the pre-commit shellcheck hook runs without -x and cannot follow it.
# shellcheck source=scripts/local/dotnet-config.sh disable=SC1091
source "$(dirname "$0")/dotnet-config.sh"

# Resolve the per-kind config (unit -> UNIT_*, int -> INT_*).
case "${KIND}" in
unit)
  PROJECT="${UNIT_PROJECT}"
  RESULTS="${UNIT_TEST_RESULTS}"
  COV_OUT="${UNIT_COVERAGE_OUTPUT}"
  COV_MIN="${UNIT_COVERAGE_MIN}"
  COV_INC="${UNIT_COVERAGE_INCLUDE}"
  COV_EXC="${UNIT_COVERAGE_EXCLUDE:-}"
  ;;
int)
  PROJECT="${INT_PROJECT}"
  RESULTS="${INT_TEST_RESULTS}"
  COV_OUT="${INT_COVERAGE_OUTPUT}"
  COV_MIN="${INT_COVERAGE_MIN}"
  COV_INC="${INT_COVERAGE_INCLUDE}"
  COV_EXC="${INT_COVERAGE_EXCLUDE:-}"
  ;;
esac

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
  DataCollectionRunSettings.DataCollectors.DataCollector.Configuration.Format="${TEST_COVERAGE_FORMAT}" \
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
