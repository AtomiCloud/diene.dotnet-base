#!/usr/bin/env bash
set -euo pipefail

# Repository setup. Pre-commit hooks are installed automatically
# by the Nix dev shell (shellHook); add project setup steps here.

# Restore repo-local .NET tools pinned in .config/dotnet-tools.json.
dotnet tool restore
