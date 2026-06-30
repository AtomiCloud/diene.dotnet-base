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
echo "🔧 Restoring .NET tools (jb)..."
dotnet tool restore >/dev/null

if [[ ${MODE} == "--no-test" ]]; then
  echo "🔍 Running dn-inspect: no-test (production only)"
  dn-inspect \
    --projects "${ROOT}/App/App.csproj" "${ROOT}/Lib/Lib.csproj" \
    --filter "${RULE_FILTER}"
  exit
fi

echo "🔍 Running dn-inspect: normal (all projects)"
dn-inspect "${ROOT}/dotnet-base.slnx" --filter "${RULE_FILTER}"
