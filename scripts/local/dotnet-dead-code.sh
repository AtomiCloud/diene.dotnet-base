#!/usr/bin/env bash
set -euo pipefail

# JetBrains InspectCode dead-code analysis via dn-inspect, run on the project SDK (net10).
# Production projects only, so code reachable only from tests is reported as dead.

RULE_FILTER="${DEAD_CODE_RULE_FILTER:-Unused|NeverInstantiated|NeverUsed|NotAccessed|NeverSubscribed|UnassignedField}"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "🔧 Restoring .NET tools (jb)..."
dotnet tool restore >/dev/null

echo "🔍 Running dn-inspect: production projects"
dn-inspect \
  --projects "${ROOT}/App/App.csproj" "${ROOT}/Lib/Lib.csproj" \
  --filter "${RULE_FILTER}"
