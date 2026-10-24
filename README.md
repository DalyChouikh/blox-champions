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
rokit trust rojo-rbx/rojo && rokit trust UpliftGames/wally && rokit trust JohnnyMorganz/StyLua && rokit trust Kampfkarren/selene && rokit trust JohnnyMorganz/luau-lsp && rokit trust JohnnyMorganz/wally-package-types && rokit trust astral-sh/ruff
rokit install
bash scripts/install-packages.sh
bash scripts/install-rojo-plugin.sh
```

- `rokit install` installs the exact tool versions pinned in `rokit.toml` (Rojo, Wally, StyLua, selene, luau-lsp, wally-package-types, and Ruff for the CI scripts' Python).
- `scripts/install-packages.sh` runs `wally install`, which downloads React Luau (it draws the HUD) into `Packages/` and the test framework (Jest Roblox) into `DevPackages/`; a few of Jest's helpers land in `Packages/` too. Both come from Roblox (`roblox/*` on Wally). It then makes each package's link file re-export the package's types, so the type checker knows names like `React.ReactElement`. Stop `rojo serve` before running it: it recreates folders Rojo watches.
- `scripts/install-rojo-plugin.sh` builds and installs the Rojo Studio plugin (restart Studio if it was open). It applies an upstream fix ([rojo#1344](https://github.com/rojo-rbx/rojo/pull/1344)) that stops the stock plugin from printing three `rbxassetid://203785492` errors on every playtest; once a Rojo release includes that fix, this step goes back to `rojo plugin install`.

## Daily workflow

1. Start syncing files into Studio:

   ```bash
   rojo serve test.project.json
   ```

2. In Roblox Studio, open the **Plugins** tab, click **Rojo**, then **Connect** (`localhost:34872`).
3. Edit files in `src/` and `tests/`; Rojo updates Studio automatically.

`test.project.json` includes the tests and test framework. `default.project.json` is the game without any test code. Both map `Packages/` to `ReplicatedStorage.Packages`.

## Running tests

With Rojo connected, paste this into Studio's command bar (View → Command Bar):

```lua
require(game:GetService("ServerStorage").RunTests:Clone())()
```

The Output window shows one summary line, such as `[RunTests] PASS 49/49 tests`, or a `[RunTests] FAIL …` warning naming the first failure, followed by Jest's full report. `:Clone()` makes Studio load the latest version of the runner instead of a cached copy. Studio caches the Jest package the same way: after `wally install` changes its version, restart Studio (or replace `ReplicatedStorage.DevPackages.Jest` with a clone of itself) before the next run.

To run only some tests, pass a filter, e.g. `require(game:GetService("ServerStorage").RunTests:Clone())({ testPathPattern = "Freeze" })`. A filter that matches no tests is reported as a failure. To match several files, wrap the alternatives in parentheses, e.g. `testPathPattern = "(Possession|LapTracker)"`: in Jest Roblox (3.20.1, as in 3.10) a bare `Possession|LapTracker` only matches the first alternative.

Tests under `tests/server` and `tests/integration` build parts (a whole arena, for example) in the open place, under a temporary folder they remove when they finish, so a run leaves the place as it found it.

## Cloud tests

CI's `cloud-tests` check runs the whole suite inside Roblox on every pull request and every push to `main`, once the `quality` check has passed:

1. It builds `build/test.rbxl` and uploads it to a private test game on the owner's Roblox account, **Blox Champions Tests**, as a saved version (saved, not published).
2. Roblox runs `scripts/ci/run-tests-task.luau` in that exact version through [Open Cloud Luau Execution](https://create.roblox.com/docs/cloud/reference/features/luau-execution). The task returns the runner's summary, and its log (Jest's report) is printed in the job's output.
3. The check passes only when the task completed and every test passed, with more than zero tests run.

The client that does this is `scripts/ci/cloud_tests.py`, which uses only Python's standard library.

**One-time setup** (the repository owner): run `bash scripts/ci/setup-cloud-tests.sh` in your own terminal. It walks you through creating the test game and an Open Cloud API key, then stores them in GitHub with `gh`: the secret `ROBLOX_API_KEY` and the variables `ROBLOX_TEST_UNIVERSE_ID` and `ROBLOX_TEST_PLACE_ID`. Until they exist, `cloud-tests` fails and names each missing value.

- Pull requests from forks get no secrets, so their `cloud-tests` check fails. Test such a change locally before merging it.
- Roblox expires an API key that goes unused for 60 days. If `cloud-tests` starts failing with a rejected request after a long pause, open the [API Keys page](https://create.roblox.com/dashboard/credentials?activeTab=ApiKeysTab): an **Auto-Expired** key works again after you turn its **Enable Key** toggle off and on.
- Lost the key? Keep no copy of it: on the same page, open `blox-champions-ci`, click **Regenerate Key**, and run the setup script again.

To check the client locally (Python 3.12 or newer), run the same commands as CI. The unit tests answer every request with a fake, so they need no key and make no network call.

```bash
python -m unittest discover -s scripts/ci -p "test_*.py"
ruff format --check scripts
ruff check scripts
```

## Project layout

| Folder | What lives there |
|---|---|
| `src/shared/` | Code shared by server and client (synced to `ReplicatedStorage.Shared`) |
| `src/server/` | Server scripts (synced to `ServerScriptService.Server`) |
| `src/client/` | Client scripts (synced to `StarterPlayer.StarterPlayerScripts.Client`) |
| `src/character/` | Scripts every character gets (synced to `StarterPlayer.StarterCharacterScripts`); `Animate` replaces Roblox's default animations |
| `tests/` | Jest Roblox tests (`*.spec.luau`), mirroring the `src/` folders, plus shared test data in `tests/Fixtures.luau` |
| `scripts/` | Development scripts, such as the in-Studio test runner; `scripts/ci/` holds the cloud test job |
| `docs/` | Design specs and implementation plans |

## Contributing

Branch, commit, testing, and pull-request conventions are in [CONTRIBUTING.md](CONTRIBUTING.md).
