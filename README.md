# Blox Champions

[![CI](https://github.com/DalyChouikh/blox-champions/actions/workflows/ci.yml/badge.svg)](https://github.com/DalyChouikh/blox-champions/actions/workflows/ci.yml)

A 3v3 roller-skate ball game for Roblox, inspired by Ubisoft's Roller Champions: skate laps with the ball to open the goal, then score. The design for the first milestone lives in [the M1 spec](docs/superpowers/specs/2026-10-21-m1-foundation-core-match-design.md), and progress is tracked in [GitHub milestones](https://github.com/DalyChouikh/blox-champions/milestones).

## Prerequisites

- Windows 10/11
- [Roblox Studio](https://create.roblox.com/)
- [Git](https://git-scm.com/)
- [Rokit](https://github.com/rojo-rbx/rokit), the toolchain manager. Install it from PowerShell:

  ```powershell
  Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
  ```

  Open a new terminal afterwards so `rokit` is on your PATH.

## First-time setup

From the repository folder:

```bash
rokit trust rojo-rbx/rojo && rokit trust UpliftGames/wally && rokit trust JohnnyMorganz/StyLua && rokit trust Kampfkarren/selene && rokit trust JohnnyMorganz/luau-lsp
rokit install
wally install
bash scripts/install-rojo-plugin.sh
```

- `rokit install` installs the exact tool versions pinned in `rokit.toml` (Rojo, Wally, StyLua, selene, luau-lsp).
- `wally install` downloads the test framework (Jest-Lua) into `DevPackages/`.
- `scripts/install-rojo-plugin.sh` builds and installs the Rojo Studio plugin (restart Studio if it was open). It applies an upstream fix ([rojo#1344](https://github.com/rojo-rbx/rojo/pull/1344)) that stops the stock plugin from printing three `rbxassetid://203785492` errors on every playtest; once a Rojo release includes that fix, this step goes back to `rojo plugin install`.

## Daily workflow

1. Start syncing files into Studio:

   ```bash
   rojo serve test.project.json
   ```

2. In Roblox Studio, open the **Plugins** tab, click **Rojo**, then **Connect** (`localhost:34872`).
3. Edit files in `src/` and `tests/`; Rojo updates Studio automatically.

`test.project.json` includes the tests and test framework. `default.project.json` is the game without any test code.

## Running tests

With Rojo connected, paste this into Studio's command bar (View → Command Bar):

```lua
require(game:GetService("ServerStorage").RunTests:Clone())()
```

The Output window shows one summary line, such as `[RunTests] PASS 49/49 tests`, or a `[RunTests] FAIL …` warning naming the first failure, followed by Jest's full report. `:Clone()` makes Studio load the latest version of the runner instead of a cached copy.

To run only some tests, pass a filter, e.g. `require(game:GetService("ServerStorage").RunTests:Clone())({ testPathPattern = "Freeze" })`. A filter that matches no tests is reported as a failure. To match several files, wrap the alternatives in parentheses, e.g. `testPathPattern = "(Possession|LapTracker)"`: in Jest-Lua 3.10 a bare `Possession|LapTracker` only matches the first alternative.

## Project layout

| Folder | What lives there |
|---|---|
| `src/shared/` | Code shared by server and client (synced to `ReplicatedStorage.Shared`) |
| `src/server/` | Server scripts (synced to `ServerScriptService.Server`) |
| `src/client/` | Client scripts (synced to `StarterPlayer.StarterPlayerScripts.Client`) |
| `tests/` | Jest-Lua tests (`*.spec.luau`), mirroring the `src/` folders, plus shared test data in `tests/Fixtures.luau` |
| `scripts/` | Development scripts, such as the in-Studio test runner |
| `docs/` | Design specs and implementation plans |

## Contributing

Branch, commit, testing, and pull-request conventions are in [CONTRIBUTING.md](CONTRIBUTING.md).
