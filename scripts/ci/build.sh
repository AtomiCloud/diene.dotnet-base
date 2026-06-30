#!/usr/bin/env bash
set -euo pipefail

# Reproducible build entry point, shared by local tasks' CI counterpart and later CI.

echo "❌ Intentional negative-test failure for the build CI gate"
exit 42

echo "🔨 Building solution (Release)..."
dotnet build dotnet-base.slnx -c Release

echo "✅ Build complete"
