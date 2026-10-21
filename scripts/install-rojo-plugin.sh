#!/usr/bin/env bash
# Builds Rojo's Studio plugin at the pinned Rojo version with the upstream fix for
# rojo-rbx/rojo#1342 applied (PR #1344), and installs it in place of the stock plugin.
# Without the fix, every playtest prints three
# "ContentId: rbxassetid://203785492 failed due to: Asset type does not match requested type" errors.
#
# Remove this script and its patch once a Rojo release includes PR #1344, then run `rojo plugin install`.
set -euo pipefail

ROJO_TAG="v7.7.1" # keep in sync with rokit.toml
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/build/rojo-plugin-src"
PATCH="$ROOT/scripts/patches/rojo-plugin-preload-sounds.patch"
PLUGINS_DIR="${LOCALAPPDATA:?LOCALAPPDATA is not set (this script targets Windows)}"
PLUGINS_DIR="${PLUGINS_DIR//\\//}/Roblox/Plugins"

rm -rf "$SRC"
git clone --quiet --depth 1 --branch "$ROJO_TAG" https://github.com/rojo-rbx/rojo.git "$SRC"
git -C "$SRC" submodule --quiet update --init --recursive plugin/Packages
git -C "$SRC" apply "$PATCH"

mkdir -p "$PLUGINS_DIR"
rojo build "$SRC/plugin.project.json" --output "$PLUGINS_DIR/RojoManagedPlugin.rbxm"
echo "Installed Rojo $ROJO_TAG plugin with the preload-sounds fix to $PLUGINS_DIR/RojoManagedPlugin.rbxm"
