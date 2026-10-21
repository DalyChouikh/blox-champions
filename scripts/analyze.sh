#!/usr/bin/env bash
# Strict type check (luau-lsp) of src, tests and scripts: the same command for CI and local runs.
#
# luau-lsp's command-line client cannot watch files, so whenever a sourcemap is loaded it logs
# "[WARN] client does not allow didChangeWatchedFiles registration - automatic updating on sourcemap
# changes disabled" (luau-lsp 1.70.1, src/platform/roblox/RobloxLanguageServer.cpp), and no option turns
# it off. That one line is dropped; every other line and luau-lsp's exit code are kept.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Roblox type definitions for the luau-lsp version pinned in rokit.toml (gitignored, fetched when missing).
if [ ! -f globalTypes.d.luau ]; then
	version="$(sed -n 's/^luau-lsp = ".*@\(.*\)"$/\1/p' rokit.toml)"
	curl -sSfL -o globalTypes.d.luau \
		"https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/$version/scripts/globalTypes.d.luau"
fi

rojo sourcemap test.project.json --output sourcemap.json

luau-lsp analyze \
	--platform=roblox \
	--sourcemap=sourcemap.json \
	--definitions=@roblox=globalTypes.d.luau \
	--base-luaurc=.luaurc \
	--ignore="DevPackages/**" \
	--ignore="Packages/**" \
	src tests scripts 2>&1 |
	{ grep -v -F "client does not allow didChangeWatchedFiles registration" || true; }
