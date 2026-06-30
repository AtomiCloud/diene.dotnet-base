#!/usr/bin/env bash
set -euo pipefail

# Reproducible build entry point, shared by local tasks' CI counterpart and later CI.

if [[ ${GITHUB_REF_NAME:-} == "adelphi-liong/ci-negative-build" ]]; then
  echo "❌ Intentional negative-test failure for the build CI gate"
  exit 42
fi

echo "🔨 Building solution (Release)..."
dotnet build dotnet-base.slnx -c Release

echo "✅ Build complete"
