#!/usr/bin/env bash
set -euo pipefail

# JetBrains InspectCode dead-code analysis, run on the project SDK (net10).
# Two passes:
#   normal     — all projects (tests included)
#   --no-test  — production projects only, so code used ONLY by tests surfaces as dead
# InspectCode needs a solution, but the repo ships a .slnx; by default we generate a throwaway
# classic .sln per run in a temp dir (override the dir with DEAD_CODE_TEMP_DIR). Set
# DN_INSPECT_TEMP_SLN to write the temp solution to an explicit (git-ignored) path instead —
# this preserves the override the spec documents for `dn-inspect`. The atomi dn-inspect wrapper
# ships SDK 8 and cannot target net10, so we drive `dotnet jb inspectcode` directly via the
# repo-pinned `jb` tool (.config/dotnet-tools.json).
# Findings are filtered to the dead-code rule family (unused / never-used / never-instantiated /
# not-accessed symbols); override the regex with DEAD_CODE_RULE_FILTER. Style and naming rules
# are out of scope here — those belong to `pls lint`.
# Usage: dotnet-dead-code.sh [--no-test]

MODE="${1:-normal}"
RULE_FILTER="${DEAD_CODE_RULE_FILTER:-Unused|NeverInstantiated|NeverUsed|NotAccessed|NeverSubscribed|UnassignedField}"

# Reject unknown modes instead of silently inspecting all projects — a typo must not quietly
# skip the production-only (no-test) pass.
case "${MODE}" in
normal | --no-test) ;;
*)
  echo "❌ Unknown mode '${MODE}'. Usage: dotnet-dead-code.sh [--no-test]"
  exit 1
  ;;
esac

echo "🔧 Restoring .NET tools (jb)..."
dotnet tool restore >/dev/null

WORKDIR="$(mktemp -d "${DEAD_CODE_TEMP_DIR:-${TMPDIR:-/tmp}}/dn-dead-code.XXXXXX")"
trap 'rm -rf "${WORKDIR}"' EXIT

# DN_INSPECT_TEMP_SLN, when set, names an explicit (ignored) solution path; otherwise the temp
# solution is created inside WORKDIR and cleaned up on exit.
SLN="${DN_INSPECT_TEMP_SLN:-${WORKDIR}/dead-code.sln}"
SLN_DIR="$(dirname "${SLN}")"
SLN_NAME="$(basename "${SLN}" .sln)"
REPORT="${WORKDIR}/inspect.sarif"

LABEL="$([[ ${MODE} == "--no-test" ]] && echo "no-test (production only)" || echo "normal (all projects)")"
echo "🧩 Building inspection solution: ${LABEL}"
mkdir -p "${SLN_DIR}"
rm -f "${SLN}"
dotnet new sln --format sln --output "${SLN_DIR}" --name "${SLN_NAME}" >/dev/null

# Production projects always; test projects only on the normal pass.
dotnet sln "${SLN}" add App/App.csproj Lib/Lib.csproj >/dev/null
[[ ${MODE} == "--no-test" ]] || dotnet sln "${SLN}" add UnitTest/UnitTest.csproj IntTest/IntTest.csproj >/dev/null

echo "🔍 Running inspectcode..."
# RunAnalyzers=false skips the project's Roslyn (Microsoft.CodeAnalysis.NetAnalyzers) pass,
# which InspectCode's bundled toolset cannot load; ReSharper's own dead-code inspections,
# which this gate relies on, still run. verbosity=OFF silences InspectCode's noisy non-fatal
# analyzer-load logging — the SARIF report (validated below) is the source of truth.
dotnet jb inspectcode "${SLN}" --format=Sarif --output="${REPORT}" --properties:RunAnalyzers=false --verbosity=OFF

# Trust the report only if it is present and valid JSON, so a crashed run never masquerades
# as "no findings".
[[ -s ${REPORT} ]] || {
  echo "❌ inspectcode produced no SARIF report"
  exit 1
}
jq -e . "${REPORT}" >/dev/null || {
  echo "❌ inspectcode SARIF report is not valid JSON"
  exit 1
}

count="$(jq --arg f "${RULE_FILTER}" '[.runs[].results[] | select(.ruleId | test($f; "i"))] | length' "${REPORT}")"

[[ ${count} -eq 0 ]] && {
  echo "✅ No dead-code findings (${LABEL})"
  exit 0
}

echo "📊 ${count} dead-code finding(s) (${LABEL}):"
jq -r --arg f "${RULE_FILTER}" '.runs[].results[]
  | select(.ruleId | test($f; "i"))
  | "  \(.locations[0].physicalLocation.artifactLocation.uri // "?"):\(.locations[0].physicalLocation.region.startLine // "?") [\(.ruleId)] \(.message.text)"' \
  "${REPORT}"
exit 1
