#!/usr/bin/env bash
set -euo pipefail

# JetBrains InspectCode dead-code analysis via dn-inspect, run on the project SDK (net10).
# Usage: dotnet-dead-code.sh [--no-test]

MODE="${1:-normal}"
RULE_FILTER="${DEAD_CODE_RULE_FILTER:-Unused|NeverInstantiated|NeverUsed|NotAccessed|NeverSubscribed|UnassignedField}"

case "${MODE}" in
normal | --no-test) ;;
*)
  echo "❌ Unknown mode '${MODE}'. Usage: dotnet-dead-code.sh [--no-test]"
  exit 1
  ;;
esac

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LABEL="$([[ ${MODE} == "--no-test" ]] && echo "no-test (production only)" || echo "normal (all projects)")"
echo "🔧 Restoring .NET tools (jb)..."
dotnet tool restore >/dev/null

WORKDIR="$(mktemp -d "${DEAD_CODE_TEMP_DIR:-${TMPDIR:-/tmp}}/dn-dead-code.XXXXXX")"
trap 'rm -rf "${WORKDIR}"' EXIT

SLN="${DN_INSPECT_TEMP_SLN:-${WORKDIR}/dead-code.sln}"
SLN_DIR="$(dirname "${SLN}")"
SLN_NAME="$(basename "${SLN}" .sln)"

echo "🧩 Building inspection solution: ${LABEL}"
mkdir -p "${SLN_DIR}"
rm -f "${SLN}"
dotnet new sln --format sln --output "${SLN_DIR}" --name "${SLN_NAME}" >/dev/null

projects=(App/App.csproj Lib/Lib.csproj)
[[ ${MODE} == "--no-test" ]] || projects+=(UnitTest/UnitTest.csproj IntTest/IntTest.csproj)

for project in "${projects[@]}"; do
  dotnet sln "${SLN}" add "${ROOT}/${project}" >/dev/null
done

echo "🔍 Running dn-inspect..."
dn-inspect "${SLN}" --filter "${RULE_FILTER}"
