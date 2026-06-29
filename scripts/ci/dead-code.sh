#!/usr/bin/env bash
set -euo pipefail

# CI entry point: dead-code inspection, both passes. The no-test pass excludes the test
# projects so production code reachable ONLY from tests is reported as dead.

echo "🔍 Dead-code inspection (normal)..."
./scripts/local/dotnet-dead-code.sh

echo "🔍 Dead-code inspection (no-test)..."
./scripts/local/dotnet-dead-code.sh --no-test

echo "✅ Dead-code inspection complete"
