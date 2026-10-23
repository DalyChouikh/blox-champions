#!/usr/bin/env bash
# Installs the Wally packages (React Luau into Packages/, Jest Roblox into DevPackages/), then makes each package's
# Wally link file re-export the package's types (wally-package-types), so strict analysis can name React's types
# (React.ReactElement, React.Binding<T>). Wally's own link files return the package but export none of its types.
# The same command for CI and local runs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

wally install
rojo sourcemap test.project.json --output sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages/
