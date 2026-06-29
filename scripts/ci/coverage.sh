#!/usr/bin/env bash
set -euo pipefail

# CI entry point: full coverage for unit and integration tests. Each run enforces its
# configured minimum and preserves the cobertura report (even on failure) for Codecov.

echo "🧪 Unit coverage..."
./scripts/local/dotnet-test.sh unit --coverage

echo "🧪 Integration coverage..."
./scripts/local/dotnet-test.sh int --coverage

echo "✅ Coverage complete"
