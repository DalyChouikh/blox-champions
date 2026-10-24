#!/usr/bin/env bash
# CI: installs Rokit with Rokit's own installer (its scripts/install.sh, pinned to the v1.2.0 tag's commit), then the
# tools pinned in rokit.toml. GITHUB_TOKEN must be set (CI passes github.token): the installer and Rokit read GitHub's
# API, whose limit for unauthenticated calls CI runners share. Under GitHub Actions, ~/.rokit/bin also goes on the
# PATH of the job's later steps ($GITHUB_PATH).
#
# For CI only: `rokit authenticate` refuses to replace a token it already holds, and a fresh runner holds none. Local
# setup is in README.md.
set -euo pipefail

ROKIT_VERSION="1.2.0"
# The commit the v1.2.0 tag points to (gh api repos/rojo-rbx/rokit/git/ref/tags/v1.2.0).
ROKIT_COMMIT="3b803035635c29c752f6ea1d2befc1473b96c51a"
ROKIT_BIN="$HOME/.rokit/bin"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
: "${GITHUB_TOKEN:?GITHUB_TOKEN must be set (CI passes github.token)}"

# On PATH before Rokit runs: `rokit install` warns to restart the terminal when it is not.
export PATH="$ROKIT_BIN:$PATH"
if [ -n "${GITHUB_PATH:-}" ]; then
	echo "$ROKIT_BIN" >>"$GITHUB_PATH"
fi

# The installer downloads Rokit into the current folder and runs `rokit self-install` there, so it runs in a
# scratch folder.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
curl -sSfL -o "$work/install.sh" "https://raw.githubusercontent.com/rojo-rbx/rokit/$ROKIT_COMMIT/scripts/install.sh"
(cd "$work" && GITHUB_PAT="$GITHUB_TOKEN" bash install.sh "$ROKIT_VERSION")

cd "$ROOT"
rokit authenticate github --token "$GITHUB_TOKEN"
rokit install --no-trust-check
