# M1 Phase 1 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the Blox Champions codebase — pinned toolchain, Rojo projects, Jest-Lua tests running in Studio, CI, and the shared foundation modules (Freeze, Signal, Loader, config validation, game config + Normal Champions mode, bootstrap) — so every later phase starts from tested infrastructure.

**Architecture:** Files on disk sync into Studio via Rojo. Production code lives in `src/` (mapped to ReplicatedStorage / ServerScriptService / StarterPlayerScripts); tests live in `tests/` and only enter the DataModel through `test.project.json`. Jest-Lua 3.10.0 runs the suite inside Studio's Edit DataModel, invoked through the Roblox Studio MCP `execute_luau` tool. CI runs format, lint, type-check, and builds on every PR.

**Tech Stack:** Luau (`--!strict`), Rojo 7.7.1, Rokit 1.2.0, Wally 0.3.2, StyLua 2.6.0, selene 0.32.0, luau-lsp 1.70.1, Jest-Lua 3.10.0, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-21-m1-foundation-core-match-design.md` (§3 architecture, §4–§6 rule values used by config, §12 tooling/testing/workflow, §14 phase 1 scope).

## Global Constraints

- Every `.luau` file's first line is `--!strict`; `.luaurc` sets `"languageMode": "strict"`.
- Tool versions are exactly: Rojo `7.7.1`, Wally `0.3.2`, StyLua `2.6.0`, selene `0.32.0`, luau-lsp `1.70.1`; Jest `jsdotlua/jest@3.10.0`, JestGlobals `jsdotlua/jest-globals@3.10.0` (dev-dependencies only). No runtime Wally dependencies in Phase 1.
- Formatting: StyLua with `syntax = "Luau"`, tabs, `column_width = 120`, `line_endings = "Unix"`. Git stores LF (`.gitattributes`).
- Requires: code in `src/` requires siblings relative to `script` (e.g. `require(script.Parent.Freeze)`); tests require through absolute service paths (e.g. `require(ReplicatedStorage.Shared.Util.Freeze)`). No string requires.
- Tests: `tests/**/<Name>.spec.luau`, mirroring `src/` paths; all Jest functions come from `JestGlobals` (`describe`, `it`, `expect`, `beforeEach`). Do not use `jest.fn()` (Jest-Lua returns two values); record calls with closures. Tests are strict too: annotate locals whose type strict mode cannot infer (e.g. `local signal: Signal.Signal<string, string> = Signal.new()`, `local value: any`).
- Config values are exactly those in spec §4–§6 (listed in Task 6).
- Git: one branch and one PR per task/issue, PR body contains `Closes #<issue>`, Conventional Commits, every commit ends with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. From Task 2 on, CI must be green before merging into `main`.
- Name strings: game name `BloxChampions` in log prefixes; mode id `NormalChampions`, display name `Normal Champions`.

## How tests run (used by every task)

Prerequisite (once per work session): `rojo serve test.project.json` is running and Studio's Rojo plugin is connected to it (default port 34872).

Run the suite with the Roblox Studio MCP tool `execute_luau`, `datamodel_type = "Edit"`:

```lua
return require(game:GetService("ServerStorage").RunTests)({ testPathPattern = "<pattern>" })
```

It returns a `Summary` table (Task 1). Omit `testPathPattern` to run everything. Verified facts behind this (2026-10-21, Studio 0.743): in the Edit context `debug.loadmodule` exists but raises "debug.loadmodule is not enabled", `loadstring` works, and `jsdotlua/jest-runtime@3.10.0` falls back to `loadstring(module.Source)` when `debug.loadmodule` fails — so no Studio FFlag change is needed.

## Review Focus

1. **A typo in a mode's config override** (e.g. `lapsToOpenGaol`) — must fail at boot naming the exact key, never be silently ignored. Test: Task 6 `rejects an override key that does not exist`.
2. **Config values of the right type but contradictory** (e.g. `lapsForStreakPoint` ≤ `lapsToOpenGoal`, `minPlayersToStart` > 2 × `teamSize`, NaN or infinite numbers) — must fail with a readable message. Tests: Task 5 `rejects NaN and infinite numbers`, Task 6 cross-field tests.
3. **One subscriber throwing inside a Signal** (e.g. a HUD bug) — must not stop the other subscribers (e.g. scoring). Test: Task 3 `keeps calling remaining handlers when one errors`.
4. **Handlers disconnecting or connecting during `Fire`** — a handler disconnected mid-fire must not run; one connected mid-fire must wait for the next fire. Tests: Task 3 `skips a handler disconnected during the same fire`, `does not call a handler connected during fire until the next fire`.
5. **Running tests when the environment is not ready or a filter matches nothing** (Rojo not connected, `wally install` not run, typo in `testPathPattern`) — must return `success = false` with a message saying what to do, never a false pass. The zero-match case is verified in Task 1 Step 9; the missing-environment branch is specified in Task 1 Step 4 and checked in code review.

---

### Task 1: Toolchain, Rojo projects, Jest harness, and `Freeze`

**Issue:** #1 · **Branch:** `chore/1-toolchain-test-harness` · **Labels:** `chore`, `infra`

**Files:**
- Create: `.gitattributes`, `.gitignore`, `rokit.toml`, `wally.toml`, `stylua.toml`, `selene.toml`, `.luaurc`
- Create: `default.project.json`, `test.project.json`
- Create: `scripts/RunTests.luau`, `tests/jest.config.luau`
- Create: `src/shared/Util/Freeze.luau`
- Test: `tests/shared/Util/Freeze.spec.luau`
- Create: `README.md`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `RunTests(options: { testNamePattern: string?, testPathPattern: string? }?) -> Summary` where `Summary = { success: boolean, numTotalTests: number, numPassedTests: number, numFailedTests: number, numFailedTestSuites: number, failureMessages: { string } }` (ModuleScript at `ServerStorage.RunTests`, test project only).
  - `Freeze.deep<T>(value: T) -> T` at `ReplicatedStorage.Shared.Util.Freeze`.
  - DataModel layout (test project): `ReplicatedStorage.Shared` ← `src/shared`, `ReplicatedStorage.Tests` ← `tests`, `ReplicatedStorage.DevPackages` ← `DevPackages`, `ServerStorage.RunTests` ← `scripts/RunTests.luau`. Production project: only `ReplicatedStorage.Shared` ← `src/shared` (Task 7 adds server/client).

- [ ] **Step 1: One-time machine setup (ask the user before running each install)**

Install Rokit (Windows PowerShell, official installer from the Rokit README):
```powershell
Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression
```
Expected: `rokit --version` prints `rokit 1.2.0` (open a new terminal so PATH updates).

- [ ] **Step 2: Repo hygiene and tool manifests**

`.gitattributes`: `* text=auto eol=lf` (Step 11 runs `git add --renormalize .` so already-committed docs are stored with LF).

`.gitignore` entries: `/Packages/`, `/DevPackages/`, `/build/`, `sourcemap.json`, `globalTypes.d.luau`, `*.rbxl`, `*.rbxlx`, `*.rbxl.lock`, `*.rbxlx.lock`.

`rokit.toml`:
```toml
[tools]
rojo = "rojo-rbx/rojo@7.7.1"
wally = "UpliftGames/wally@0.3.2"
stylua = "JohnnyMorganz/StyLua@2.6.0"
selene = "Kampfkarren/selene@0.32.0"
luau-lsp = "JohnnyMorganz/luau-lsp@1.70.1"
```

`wally.toml`:
```toml
[package]
name = "dalychouikh/blox-champions"
version = "0.1.0"
registry = "https://github.com/UpliftGames/wally-index"
realm = "shared"

[dev-dependencies]
Jest = "jsdotlua/jest@3.10.0"
JestGlobals = "jsdotlua/jest-globals@3.10.0"
```

`stylua.toml`: `syntax = "Luau"`, `column_width = 120`, `line_endings = "Unix"`, `indent_type = "Tabs"`, `indent_width = 4`, `quote_style = "AutoPreferDouble"`, `call_parentheses = "Always"`.

`selene.toml`: `std = "roblox"`.

`.luaurc`: `{ "languageMode": "strict" }`.

- [ ] **Step 3: Install tools and packages**

Run (local machine; `rokit trust` avoids the interactive trust prompt):
```bash
rokit trust rojo-rbx/rojo && rokit trust UpliftGames/wally && rokit trust JohnnyMorganz/StyLua && rokit trust Kampfkarren/selene && rokit trust JohnnyMorganz/luau-lsp
rokit install
wally install
rojo --version
```
Expected: `Rojo 7.7.1`; folders `DevPackages/Jest` and `DevPackages/JestGlobals` exist.

- [ ] **Step 4: Rojo projects, runner, Jest config**

`default.project.json`: name `blox-champions`, `$className: DataModel`, `ReplicatedStorage.Shared` → `src/shared`.

`test.project.json`: name `blox-champions-test`, same tree plus `ReplicatedStorage.Tests` → `tests`, `ReplicatedStorage.DevPackages` → `DevPackages`, `ServerStorage.RunTests` → `scripts/RunTests.luau`.

`tests/jest.config.luau`: `return { testMatch = { "**/*.spec" } }`.

Create the empty folder `src/shared/Util/` now so the `$path` targets exist for the build below (Rojo maps it to an empty Folder until Step 8 adds `Freeze.luau`).

`scripts/RunTests.luau` returns the `RunTests` function from the Interfaces block:
- If `ReplicatedStorage:FindFirstChild("DevPackages")` or `ReplicatedStorage:FindFirstChild("Tests")` is missing, return `success = false`, all counts `0`, and `failureMessages = { "Test environment missing: <DevPackages|Tests>. Run `wally install` and serve test.project.json with Rojo." }` without calling Jest.
- Otherwise call `require(ReplicatedStorage.DevPackages.Jest).runCLI(ReplicatedStorage.Tests, { ci = true, verbose = false, testNamePattern = options.testNamePattern, testPathPattern = options.testPathPattern }, { ReplicatedStorage.Tests }):awaitStatus()`.
- `status == "Rejected"` → `success = false`, `failureMessages = { tostring(result) }`.
- `"Resolved"` → copy `numTotalTests`, `numPassedTests`, `numFailedTests`, `numFailedTestSuites` from `result.results`; collect each non-empty `result.results.testResults[i].failureMessage` (and `testExecError.message` when present); `success = numFailedTestSuites == 0 and numFailedTests == 0 and numTotalTests > 0` (zero tests found is a failure — catches pattern typos).

Verify the builds:
```bash
rojo build default.project.json --output build/game.rbxl
rojo build test.project.json --output build/test.rbxl
```
Expected: both exit 0.

- [ ] **Step 5: Connect Studio (user action, once per session)**

```bash
rojo plugin install
rojo serve test.project.json
```
The user opens Studio, clicks the Rojo plugin's **Connect** (localhost:34872). Expected: `ReplicatedStorage.Shared`, `ReplicatedStorage.Tests`, `ReplicatedStorage.DevPackages`, `ServerStorage.RunTests` appear in Explorer.

- [ ] **Step 6: Write the failing test `tests/shared/Util/Freeze.spec.luau`**

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Freeze = require(ReplicatedStorage.Shared.Util.Freeze)

describe("Freeze.deep", function()
	it("freezes a table and every nested table, returning the same table", function()
		local t = { a = 1, nested = { b = 2, deeper = { c = 3 } }, list = { 1, 2 } }
		local result = Freeze.deep(t)
		expect(result).toBe(t)
		expect(table.isfrozen(t)).toBe(true)
		expect(table.isfrozen(t.nested)).toBe(true)
		expect(table.isfrozen(t.nested.deeper)).toBe(true)
		expect(table.isfrozen(t.list)).toBe(true)
	end)

	it("makes writes throw", function()
		local t: any = Freeze.deep({ a = 1 })
		expect(function()
			t.a = 2
		end).toThrow()
	end)

	it("returns non-table values unchanged", function()
		expect(Freeze.deep(5)).toBe(5)
		expect(Freeze.deep("x")).toBe("x")
		expect(Freeze.deep(true)).toBe(true)
	end)

	it("freezes children of a table that was already frozen", function()
		local child = { y = 2 }
		local t = Freeze.deep(table.freeze({ child = child }))
		expect(table.isfrozen(t)).toBe(true)
		expect(table.isfrozen(child)).toBe(true)
	end)

	it("handles cycles without infinite recursion", function()
		local a: any = {}
		a.self = a
		expect(function()
			Freeze.deep(a)
		end).never.toThrow()
		expect(table.isfrozen(a)).toBe(true)
	end)
end)
```

- [ ] **Step 7: Run it to verify it fails**

Run (MCP `execute_luau`, Edit): `return require(game:GetService("ServerStorage").RunTests)({ testPathPattern = "Freeze" })`
Expected: `success = false`, `numFailedTestSuites = 1`, a failure message saying `Freeze` is not a valid member of the `Util` folder (module not created yet).

- [ ] **Step 8: Implement `Freeze.deep<T>(value: T) -> T` in `src/shared/Util/Freeze.luau`**

Depth-first with a `visited` set: for a table, recurse into every value that is a table, then `table.freeze` it if `not table.isfrozen`. Non-tables return unchanged.

- [ ] **Step 9: Run tests to verify they pass, then check the runner's failure modes**

Run: `return require(game:GetService("ServerStorage").RunTests)({ testPathPattern = "Freeze" })`
Expected: `success = true`, `numPassedTests = 5`, `numFailedTests = 0`.

Run: `return require(game:GetService("ServerStorage").RunTests)({ testPathPattern = "DoesNotExist" })`
Expected: `success = false`, `numTotalTests = 0` (Review Focus 5).

- [ ] **Step 10: README**

`README.md` sections: what the project is (one paragraph + link to the spec); prerequisites (Windows, Roblox Studio, Git, Rokit with the Step 1 command); first-time setup (Step 3 commands + `rojo plugin install`); daily workflow (`rojo serve test.project.json`, click Connect); running tests (the Studio command-bar line from "How tests run"); project layout (the `src/`, `tests/`, `scripts/`, `docs/` folders, one line each).

- [ ] **Step 11: Format, lint, commit, PR**

```bash
stylua src tests scripts && stylua --check src tests scripts && selene src tests scripts
git checkout -b chore/1-toolchain-test-harness
git add --renormalize .
git add .gitattributes .gitignore rokit.toml wally.toml stylua.toml selene.toml .luaurc
git commit -m "chore: pin toolchain and normalize line endings"
git add default.project.json test.project.json scripts/RunTests.luau tests/jest.config.luau tests/shared/Util/Freeze.spec.luau src/shared/Util/Freeze.luau
git commit -m "feat(test): add Rojo projects, Jest runner and deep Freeze utility"
git add README.md
git commit -m "docs: add setup and test instructions to README"
git push -u origin chore/1-toolchain-test-harness
gh pr create --title "chore: toolchain, Rojo projects and Jest harness" --body "Closes #1" --milestone "M1 - Foundation & Core Match"
```
Expected: `stylua --check` and `selene` print no errors; PR created. Merge after review (no CI exists yet for this PR).

---

### Task 2: CI workflow, contributing guide, GitHub templates

**Issue:** #2 · **Branch:** `chore/2-ci-and-templates` · **Labels:** `chore`, `infra`, `docs`

**Files:**
- Create: `.github/workflows/ci.yml`
- Create: `CONTRIBUTING.md`, `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/task.yml`, `.github/ISSUE_TEMPLATE/bug.yml`, `.github/ISSUE_TEMPLATE/config.yml`
- Modify: `README.md` (CI badge, link to CONTRIBUTING)

**Interfaces:**
- Consumes: Task 1 manifests and projects.
- Produces: required CI check named `quality` on every PR and push to `main`.

- [ ] **Step 1: Run every CI command locally and confirm it passes**

```bash
curl -sSfL -o globalTypes.d.luau https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.d.luau
rojo sourcemap test.project.json --output sourcemap.json
stylua --check src tests scripts
selene src tests scripts
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions=@roblox=globalTypes.d.luau --base-luaurc=.luaurc --ignore="DevPackages/**" --ignore="Packages/**" src tests scripts
rojo build default.project.json --output build/game.rbxl
rojo build test.project.json --output build/test.rbxl
```
Expected: every command exits 0. If `luau-lsp analyze` reports errors whose file paths are inside `DevPackages`, keep the `--ignore` globs; errors in `src`, `tests`, or `scripts` are fixed in code.

- [ ] **Step 2: `.github/workflows/ci.yml`**

Workflow `CI`, triggers `pull_request` and `push` to `main`, one job `quality` on `ubuntu-latest`. Steps in order: `actions/checkout@v7`; `CompeyDev/setup-rokit@v0.2.1` (default inputs; it runs Rokit against `rokit.toml`); `wally install`; then the Step 1 commands in the same order.

- [ ] **Step 3: Contributing guide and templates**

`CONTRIBUTING.md`: branch names `<type>/<issue>-<slug>` (types `feat`, `fix`, `chore`, `docs`, `test`); Conventional Commits with examples `test(rules): lap streak resets on opponent pickup` / `feat(rules): …`; one PR per issue with `Closes #<n>`; CI green before merge; TDD order (failing test → minimal code → refactor); `--!strict` and StyLua/selene rules from Global Constraints; how to run tests (link to README).

`pull_request_template.md`: sections "Closes #", "What changed", "How it was tested" (checkboxes: unit tests pass in Studio, CI green, playtest checklist if gameplay).

`ISSUE_TEMPLATE/task.yml`: form with fields Summary (required), Acceptance criteria (required), Plan/spec link; default labels none. `bug.yml`: fields What happened, Expected, Steps to reproduce (required), Device (dropdown: PC, Mobile, Gamepad), labels `bug`. `config.yml`: `blank_issues_enabled: false`.

- [ ] **Step 4: Commit, push, open PR, confirm CI**

```bash
git checkout main && git pull && git checkout -b chore/2-ci-and-templates
git add .github/workflows/ci.yml
git commit -m "ci: add format, lint, type-check and build workflow"
git add CONTRIBUTING.md .github/pull_request_template.md .github/ISSUE_TEMPLATE README.md
git commit -m "docs: add contributing guide and issue/PR templates"
git push -u origin chore/2-ci-and-templates
gh pr create --title "chore: CI workflow and contribution templates" --body "Closes #2" --milestone "M1 - Foundation & Core Match"
```
Expected: the `quality` check passes on the PR. Merge after it is green.

---

### Task 3: `Signal`

**Issue:** #3 · **Branch:** `feat/3-signal` · **Labels:** `feature`, `infra`

**Files:**
- Create: `src/shared/Util/Signal.luau`
- Test: `tests/shared/Util/Signal.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces:
  ```lua
  export type Connection = { Connected: boolean, Disconnect: (self: Connection) -> () }
  export type Signal<T...> = {
  	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
  	Once: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
  	Fire: (self: Signal<T...>, T...) -> (),
  	DisconnectAll: (self: Signal<T...>) -> (),
  }
  Signal.new<T...>(onHandlerError: ((message: string) -> ())?) -> Signal<T...>
  ```
  Handlers run synchronously, in connection order. Default `onHandlerError` is `warn`.

- [ ] **Step 1: Write the failing tests**

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Signal = require(ReplicatedStorage.Shared.Util.Signal)

describe("Signal", function()
	it("calls handlers in connection order with the fired arguments", function()
		local log = {}
		local signal: Signal.Signal<string, string> = Signal.new()
		signal:Connect(function(a, b)
			table.insert(log, "first:" .. a .. b)
		end)
		signal:Connect(function(a, b)
			table.insert(log, "second:" .. a .. b)
		end)
		signal:Fire("x", "y")
		expect(log).toEqual({ "first:xy", "second:xy" })
	end)

	it("stops calling a disconnected handler and marks it disconnected", function()
		local calls = 0
		local signal: Signal.Signal<()> = Signal.new()
		local connection = signal:Connect(function()
			calls += 1
		end)
		signal:Fire()
		connection:Disconnect()
		connection:Disconnect()
		signal:Fire()
		expect(calls).toBe(1)
		expect(connection.Connected).toBe(false)
	end)

	it("runs a Once handler only one time", function()
		local calls = 0
		local signal: Signal.Signal<()> = Signal.new()
		local connection = signal:Once(function()
			calls += 1
		end)
		signal:Fire()
		signal:Fire()
		expect(calls).toBe(1)
		expect(connection.Connected).toBe(false)
	end)

	it("skips a handler disconnected during the same fire", function()
		local log = {}
		local signal: Signal.Signal<()> = Signal.new()
		local second: any
		signal:Connect(function()
			table.insert(log, "first")
			second:Disconnect()
		end)
		second = signal:Connect(function()
			table.insert(log, "second")
		end)
		signal:Fire()
		expect(log).toEqual({ "first" })
	end)

	it("does not call a handler connected during fire until the next fire", function()
		local log = {}
		local signal: Signal.Signal<()> = Signal.new()
		local added = false
		signal:Connect(function()
			table.insert(log, "outer")
			if not added then
				added = true
				signal:Connect(function()
					table.insert(log, "inner")
				end)
			end
		end)
		signal:Fire()
		expect(log).toEqual({ "outer" })
		signal:Fire()
		expect(log).toEqual({ "outer", "outer", "inner" })
	end)

	it("keeps calling remaining handlers when one errors and reports the error", function()
		local reported = {}
		local signal: Signal.Signal<()> = Signal.new(function(message: string)
			table.insert(reported, message)
		end)
		local reachedSecond = false
		signal:Connect(function()
			error("boom")
		end)
		signal:Connect(function()
			reachedSecond = true
		end)
		signal:Fire()
		expect(reachedSecond).toBe(true)
		expect(#reported).toBe(1)
		expect(string.find(reported[1], "boom", 1, true) ~= nil).toBe(true)
	end)

	it("DisconnectAll disconnects every handler", function()
		local calls = 0
		local signal: Signal.Signal<()> = Signal.new()
		local a = signal:Connect(function()
			calls += 1
		end)
		local b = signal:Connect(function()
			calls += 1
		end)
		signal:DisconnectAll()
		signal:Fire()
		expect(calls).toBe(0)
		expect(a.Connected).toBe(false)
		expect(b.Connected).toBe(false)
	end)
end)
```

- [ ] **Step 2: Run to verify failure**

Run: `return require(game:GetService("ServerStorage").RunTests)({ testPathPattern = "Signal" })`
Expected: `success = false`; failure mentions `Signal` missing from `Util`.

- [ ] **Step 3: Implement `Signal` in `src/shared/Util/Signal.luau`**

Store connections in an array. `Fire` iterates over a snapshot copy of the array taken at fire start and skips any connection whose `Connected` is false at the moment it would run. Each handler runs via `xpcall(handler, debug.traceback, ...)`; on failure pass the traceback string to `onHandlerError`. `Once` disconnects before calling the handler.

- [ ] **Step 4: Run to verify pass**

Run: `return require(game:GetService("ServerStorage").RunTests)({ testPathPattern = "Signal" })`
Expected: `success = true`, `numPassedTests = 7`.

- [ ] **Step 5: Commit and PR**

```bash
git checkout main && git pull && git checkout -b feat/3-signal
stylua src tests && selene src tests
git add tests/shared/Util/Signal.spec.luau src/shared/Util/Signal.luau
git commit -m "feat(util): add synchronous Signal with isolated handler errors"
git push -u origin feat/3-signal
gh pr create --title "feat(util): Signal" --body "Closes #3" --milestone "M1 - Foundation & Core Match"
```
Expected: CI `quality` green; merge.

---

### Task 4: `Loader`

**Issue:** #4 · **Branch:** `feat/4-loader` · **Labels:** `feature`, `infra`

**Files:**
- Create: `src/shared/Util/Loader.luau`
- Test: `tests/shared/Util/Loader.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces:
  ```lua
  export type LoadableModule = {
  	name: string,
  	dependencies: { string }?,
  	init: ((self: any, deps: { [string]: any }) -> ())?,
  	start: ((self: any) -> ())?,
  }
  Loader.start(modules: { LoadableModule }, provided: { [string]: any }?) -> { [string]: LoadableModule }
  ```
  A dependency name resolves to a `provided` value (e.g. `"Config"`) or to an earlier module. `init(deps)` receives only declared dependencies. All `init`s run in list order, then all `start`s in list order. Returns modules by name.
- Exact error messages (tests match these substrings):
  - `Loader: duplicate module name "<name>"`
  - `Loader: module name "<name>" collides with a provided value`
  - `Loader: module "<a>" depends on unknown module "<b>"`
  - `Loader: module "<a>" depends on "<b>", which is declared after it`
  - `Loader: module "<a>" failed in init: <error>` / `Loader: module "<a>" failed in start: <error>`

- [ ] **Step 1: Write the failing tests**

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Loader = require(ReplicatedStorage.Shared.Util.Loader)

local function recorder(log: { string }, name: string, dependencies: { string }?)
	return {
		name = name,
		dependencies = dependencies,
		receivedDeps = nil :: any,
		init = function(self, deps)
			self.receivedDeps = deps
			table.insert(log, name .. ".init")
		end,
		start = function(_self)
			table.insert(log, name .. ".start")
		end,
	}
end

describe("Loader.start", function()
	it("inits every module in order, then starts every module in order", function()
		local log = {}
		Loader.start({ recorder(log, "A"), recorder(log, "B") })
		expect(log).toEqual({ "A.init", "B.init", "A.start", "B.start" })
	end)

	it("passes only declared dependencies, including provided values", function()
		local log = {}
		local a = recorder(log, "A")
		local c = recorder(log, "C")
		local b = recorder(log, "B", { "A", "Config" })
		local config = { value = 1 }
		Loader.start({ a, c, b }, { Config = config })
		expect(b.receivedDeps.A).toBe(a)
		expect(b.receivedDeps.Config).toBe(config)
		expect(b.receivedDeps.C).toBeNil()
	end)

	it("returns the modules by name", function()
		local log = {}
		local a = recorder(log, "A")
		local registry = Loader.start({ a })
		expect(registry.A).toBe(a)
	end)

	it("accepts modules without init or start", function()
		expect(function()
			Loader.start({ { name = "Plain" } })
		end).never.toThrow()
	end)

	it("rejects duplicate names", function()
		expect(function()
			Loader.start({ { name = "A" }, { name = "A" } })
		end).toThrow('Loader: duplicate module name "A"')
	end)

	it("rejects a module name that collides with a provided value", function()
		expect(function()
			Loader.start({ { name = "Config" } }, { Config = {} })
		end).toThrow('Loader: module name "Config" collides with a provided value')
	end)

	it("rejects unknown dependencies", function()
		expect(function()
			Loader.start({ { name = "A", dependencies = { "Missing" } } })
		end).toThrow('Loader: module "A" depends on unknown module "Missing"')
	end)

	it("rejects dependencies declared later in the list", function()
		expect(function()
			Loader.start({ { name = "A", dependencies = { "B" } }, { name = "B" } })
		end).toThrow('Loader: module "A" depends on "B", which is declared after it')
	end)

	it("names the module that fails in init and starts nothing", function()
		local log = {}
		local broken = {
			name = "Broken",
			init = function()
				error("bad init")
			end,
		}
		expect(function()
			Loader.start({ recorder(log, "A"), broken })
		end).toThrow('Loader: module "Broken" failed in init: ')
		expect(log).toEqual({ "A.init" })
	end)

	it("names the module that fails in start", function()
		local broken = {
			name = "Broken",
			start = function()
				error("bad start")
			end,
		}
		expect(function()
			Loader.start({ broken })
		end).toThrow('Loader: module "Broken" failed in start: ')
	end)
end)
```

- [ ] **Step 2: Run to verify failure**

Run: `return require(game:GetService("ServerStorage").RunTests)({ testPathPattern = "Loader" })`
Expected: `success = false`; failure mentions `Loader` missing.

- [ ] **Step 3: Implement `Loader.start` in `src/shared/Util/Loader.luau`**

Validate everything (names, collisions, dependency existence and order) before calling any `init`. Wrap each `init`/`start` call in `pcall` and rethrow with the exact message prefix plus the original error text.

- [ ] **Step 4: Run to verify pass**

Run: `return require(game:GetService("ServerStorage").RunTests)({ testPathPattern = "Loader" })`
Expected: `success = true`, `numPassedTests = 10`.

- [ ] **Step 5: Commit and PR**

```bash
git checkout main && git pull && git checkout -b feat/4-loader
stylua src tests && selene src tests
git add tests/shared/Util/Loader.spec.luau src/shared/Util/Loader.luau
git commit -m "feat(util): add Loader with ordered init/start and explicit dependencies"
git push -u origin feat/4-loader
gh pr create --title "feat(util): Loader" --body "Closes #4" --milestone "M1 - Foundation & Core Match"
```
Expected: CI green; merge.

---

### Task 5: Config validation DSL (`Validate`)

**Issue:** #5 · **Branch:** `feat/5-config-validation` · **Labels:** `feature`, `infra`

**Files:**
- Create: `src/shared/Config/Validate.luau`
- Test: `tests/shared/Config/Validate.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces:
  ```lua
  export type Validator = (value: any, path: string) -> { string } -- list of error messages; empty = valid
  Validate.number(options: { min: number?, max: number?, integer: boolean? }?) -> Validator
  Validate.boolean() -> Validator
  Validate.string(options: { oneOf: { string }? }?) -> Validator
  Validate.table() -> Validator -- any table; contents unchecked
  Validate.record(fields: { [string]: Validator }) -> Validator -- exact keys: unknown and missing keys are errors
  Validate.check(inner: Validator, predicate: (value: any) -> boolean, message: string) -> Validator -- predicate runs only if inner has no errors
  Validate.assertValid(value: any, validator: Validator, rootPath: string) -> () -- throws "Invalid config:\n  - <e1>\n  - <e2>"
  ```
- Path rules: record fields append `.<key>`; when the current path is `""`, the field path is just `<key>`.
- Exact messages:
  - `<path>: expected <number|boolean|string|table>, got <typeof(value)>`
  - `<path>: must not be NaN` · `<path>: must be finite`
  - `<path>: must be >= <min> (got <v>)` · `<path>: must be <= <max> (got <v>)` · `<path>: must be an integer (got <v>)`
  - `<path>: must be one of <a>, <b> (got "<v>")`
  - `<path>.<key>: unknown key` · `<path>.<key>: missing`
  - check: `<path>: <message>`

- [ ] **Step 1: Write the failing tests**

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Validate = require(ReplicatedStorage.Shared.Config.Validate)

describe("Validate", function()
	it("accepts valid numbers and reports type mismatches", function()
		local v = Validate.number()
		expect(v(3, "Match.pointsToWin")).toEqual({})
		expect(v("5", "Match.pointsToWin")).toEqual({ "Match.pointsToWin: expected number, got string" })
	end)

	it("rejects NaN and infinite numbers", function()
		local v = Validate.number()
		expect(v(0 / 0, "X.n")).toEqual({ "X.n: must not be NaN" })
		expect(v(math.huge, "X.n")).toEqual({ "X.n: must be finite" })
	end)

	it("enforces min, max and integer", function()
		local v = Validate.number({ min = 1, max = 6, integer = true })
		expect(v(0, "Match.teamSize")).toEqual({ "Match.teamSize: must be >= 1 (got 0)" })
		expect(v(7, "Match.teamSize")).toEqual({ "Match.teamSize: must be <= 6 (got 7)" })
		expect(v(2.5, "Match.teamSize")).toEqual({ "Match.teamSize: must be an integer (got 2.5)" })
	end)

	it("validates booleans and strings with oneOf", function()
		expect(Validate.boolean()(1, "B")).toEqual({ "B: expected boolean, got number" })
		local s = Validate.string({ oneOf = { "Hold", "Toggle" } })
		expect(s("Hold", "Input.mode")).toEqual({})
		expect(s("Press", "Input.mode")).toEqual({ 'Input.mode: must be one of Hold, Toggle (got "Press")' })
	end)

	it("accepts any table for Validate.table and rejects non-tables", function()
		expect(Validate.table()({ anything = 1 }, "Mode.overrides")).toEqual({})
		expect(Validate.table()(1, "Mode.overrides")).toEqual({ "Mode.overrides: expected table, got number" })
	end)

	it("requires exact record keys and collects every error", function()
		local v = Validate.record({ a = Validate.number(), b = Validate.boolean() })
		local errors = v({ a = "x", c = 1 }, "Root")
		table.sort(errors)
		expect(errors).toEqual({
			"Root.a: expected number, got string",
			"Root.b: missing",
			"Root.c: unknown key",
		})
	end)

	it("uses bare keys when the path is empty", function()
		local v = Validate.record({ Match = Validate.record({}) })
		expect(v({ Mtach = {} }, "")).toEqual({ "Match: missing", "Mtach: unknown key" })
	end)

	it("applies a check only when the inner validator passes", function()
		local inner = Validate.record({ low = Validate.number(), high = Validate.number() })
		local v = Validate.check(inner, function(value)
			return value.high > value.low
		end, "high must be greater than low")
		expect(v({ low = 1, high = 2 }, "R")).toEqual({})
		expect(v({ low = 3, high = 2 }, "R")).toEqual({ "R: high must be greater than low" })
		expect(v({ low = 3 }, "R")).toEqual({ "R.high: missing" })
	end)

	it("assertValid throws a message listing every error, and passes silently when valid", function()
		local v = Validate.record({ a = Validate.number(), b = Validate.number() })
		expect(function()
			Validate.assertValid({ a = "x", b = "y" }, v, "Cfg")
		end).toThrow("Invalid config:\n  - Cfg.a: expected number, got string\n  - Cfg.b: expected number, got string")
		expect(function()
			Validate.assertValid({ a = 1, b = 2 }, v, "Cfg")
		end).never.toThrow()
	end)
end)
```

Note: the "uses bare keys" and "assertValid" expectations require errors in **sorted key order**; the record validator iterates field names sorted alphabetically, then unknown keys sorted alphabetically.

- [ ] **Step 2: Run to verify failure**

Run: `return require(game:GetService("ServerStorage").RunTests)({ testPathPattern = "Validate" })`
Expected: `success = false`; failure mentions `Validate` missing.

- [ ] **Step 3: Implement `Validate` in `src/shared/Config/Validate.luau`**

Number formatting in messages uses `tostring(v)`. Record validator: report the type mismatch alone (no field errors) when the value is not a table; otherwise validate declared fields in sorted order, then report unknown keys in sorted order. `assertValid` calls `error(message, 2)` only when the list is non-empty.

- [ ] **Step 4: Run to verify pass**

Run: `return require(game:GetService("ServerStorage").RunTests)({ testPathPattern = "Validate" })`
Expected: `success = true`, `numPassedTests = 9`.

- [ ] **Step 5: Commit and PR**

```bash
git checkout main && git pull && git checkout -b feat/5-config-validation
stylua src tests && selene src tests
git add tests/shared/Config/Validate.spec.luau src/shared/Config/Validate.luau
git commit -m "feat(config): add validation DSL with exact, path-qualified errors"
git push -u origin feat/5-config-validation
gh pr create --title "feat(config): validation DSL" --body "Closes #5" --milestone "M1 - Foundation & Core Match"
```
Expected: CI green; merge.

---

### Task 6: Game config (Match, Scoring) and Normal Champions mode

**Issue:** #6 · **Branch:** `feat/6-game-config` · **Labels:** `feature`, `infra`, `rules`

**Files:**
- Create: `src/shared/Config/Match.luau`, `src/shared/Config/Scoring.luau`, `src/shared/Config/init.luau`
- Create: `src/shared/Modes/NormalChampions.luau`
- Test: `tests/shared/Config/Config.spec.luau`

**Interfaces:**
- Consumes: `Freeze.deep` (Task 1), `Validate.*` (Task 5).
- Produces:
  ```lua
  -- Config/Match.luau and Config/Scoring.luau each return { defaults: <T>, schema: Validate.Validator }
  export type MatchConfig = {
  	teamSize: number, minPlayersToStart: number, pointsToWin: number, durationSeconds: number,
  	lapsToOpenGoal: number, lapsForStreakPoint: number,
  	pointValue: { goal: number, streak: number },
  	celebrationSeconds: number, kickoffCountdownSeconds: number, clockPausesDuringKickoff: boolean,
  	postMatchSeconds: number,
  	lastChance: { enabled: boolean, maxDeficit: number },
  }
  export type ScoringConfig = {
  	points: { goal: number, streakPoint: number, assist: number, save: number, lapCompleted: number, steal: number, tackleKnockdown: number },
  	assistWindowSeconds: number, saveLookaheadSeconds: number,
  }
  export type GameConfig = { Match: MatchConfig, Scoring: ScoringConfig }
  export type Mode = { id: string, displayName: string, itemsEnabled: boolean, overrides: { [string]: any } }
  Config.defaults() -> GameConfig        -- validated, deep-frozen, same table every call
  Config.forMode(mode: Mode) -> GameConfig -- validates the mode, deep-merges overrides onto defaults, validates, deep-freezes
  Config.schema: Validate.Validator      -- record { Match = ..., Scoring = ... }, validated with rootPath ""
  ```
  Merge rule: tables in both sides merge key by key; any other override value replaces the default. Defaults are never mutated.
- Default values (spec §4–§6, exact):
  - Match: `teamSize = 3`, `minPlayersToStart = 1`, `pointsToWin = 5`, `durationSeconds = 300`, `lapsToOpenGoal = 4`, `lapsForStreakPoint = 12`, `pointValue = { goal = 1, streak = 1 }`, `celebrationSeconds = 3`, `kickoffCountdownSeconds = 3`, `clockPausesDuringKickoff = true`, `postMatchSeconds = 15`, `lastChance = { enabled = true, maxDeficit = 1 }`.
  - Scoring: `points = { goal = 100, streakPoint = 100, assist = 50, save = 50, lapCompleted = 10, steal = 20, tackleKnockdown = 10 }`, `assistWindowSeconds = 8`, `saveLookaheadSeconds = 1.5`.
- Schema rules: Match — `teamSize` integer 1–6; `minPlayersToStart` integer ≥ 1; `pointsToWin`, `lapsToOpenGoal`, `lapsForStreakPoint`, `pointValue.goal`, `pointValue.streak`, `lastChance.maxDeficit` integers ≥ 1; `durationSeconds` > 0 (min 1); `celebrationSeconds`, `kickoffCountdownSeconds`, `postMatchSeconds` ≥ 0; checks `Match: lapsForStreakPoint must be greater than lapsToOpenGoal` and `Match: minPlayersToStart must be <= 2 × teamSize`. Scoring — every `points.*` integer ≥ 0; `assistWindowSeconds` ≥ 0.1; `saveLookaheadSeconds` ≥ 0.1.
- Mode (`Modes/NormalChampions.luau`): `{ id = "NormalChampions", displayName = "Normal Champions", itemsEnabled = false, overrides = {} }`. Mode validation: `Validate.assertValid(mode, Validate.record({ id = Validate.string(), displayName = Validate.string(), itemsEnabled = Validate.boolean(), overrides = Validate.table() }), "Mode")`.

- [ ] **Step 1: Write the failing tests**

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local NormalChampions = require(ReplicatedStorage.Shared.Modes.NormalChampions)

local function mode(overrides: { [string]: any })
	return { id = "Test", displayName = "Test", itemsEnabled = false, overrides = overrides }
end

describe("Config defaults", function()
	it("match the spec's match rules", function()
		local m = Config.defaults().Match
		expect(m.teamSize).toBe(3)
		expect(m.minPlayersToStart).toBe(1)
		expect(m.pointsToWin).toBe(5)
		expect(m.durationSeconds).toBe(300)
		expect(m.lapsToOpenGoal).toBe(4)
		expect(m.lapsForStreakPoint).toBe(12)
		expect(m.pointValue).toEqual({ goal = 1, streak = 1 })
		expect(m.celebrationSeconds).toBe(3)
		expect(m.kickoffCountdownSeconds).toBe(3)
		expect(m.clockPausesDuringKickoff).toBe(true)
		expect(m.postMatchSeconds).toBe(15)
		expect(m.lastChance).toEqual({ enabled = true, maxDeficit = 1 })
	end)

	it("match the spec's scoring values", function()
		local s = Config.defaults().Scoring
		expect(s.points).toEqual({
			goal = 100, streakPoint = 100, assist = 50, save = 50, lapCompleted = 10, steal = 20, tackleKnockdown = 10,
		})
		expect(s.assistWindowSeconds).toBe(8)
		expect(s.saveLookaheadSeconds).toBe(1.5)
	end)

	it("are valid and deeply frozen", function()
		local d = Config.defaults()
		expect(#Config.schema(d, "")).toBe(0)
		expect(table.isfrozen(d)).toBe(true)
		expect(table.isfrozen(d.Match.lastChance)).toBe(true)
	end)
end)

describe("Config.forMode", function()
	it("returns the defaults for Normal Champions", function()
		expect(NormalChampions.id).toBe("NormalChampions")
		expect(NormalChampions.displayName).toBe("Normal Champions")
		expect(NormalChampions.itemsEnabled).toBe(false)
		expect(Config.forMode(NormalChampions)).toEqual(Config.defaults())
	end)

	it("deep-merges nested overrides without touching the defaults", function()
		local c = Config.forMode(mode({ Match = { lastChance = { maxDeficit = 2 } } }))
		expect(c.Match.lastChance).toEqual({ enabled = true, maxDeficit = 2 })
		expect(c.Match.pointsToWin).toBe(5)
		expect(Config.defaults().Match.lastChance.maxDeficit).toBe(1)
		expect(table.isfrozen(c.Match)).toBe(true)
	end)

	it("rejects an override key that does not exist", function()
		expect(function()
			Config.forMode(mode({ Match = { lapsToOpenGaol = 3 } }))
		end).toThrow("Match.lapsToOpenGaol: unknown key")
	end)

	it("rejects an override with the wrong type", function()
		expect(function()
			Config.forMode(mode({ Match = { pointsToWin = "5" } }))
		end).toThrow("Match.pointsToWin: expected number, got string")
	end)

	it("rejects a streak target that does not exceed the goal-opening laps", function()
		expect(function()
			Config.forMode(mode({ Match = { lapsForStreakPoint = 4 } }))
		end).toThrow("Match: lapsForStreakPoint must be greater than lapsToOpenGoal")
	end)

	it("rejects more required players than two full teams", function()
		expect(function()
			Config.forMode(mode({ Match = { minPlayersToStart = 7 } }))
		end).toThrow("Match: minPlayersToStart must be <= 2 × teamSize")
	end)

	it("rejects a malformed mode", function()
		expect(function()
			Config.forMode({ id = "X", displayName = "X", itemsEnabled = "no", overrides = {} } :: any)
		end).toThrow("Mode.itemsEnabled: expected boolean, got string")
	end)
end)
```

- [ ] **Step 2: Run to verify failure**

Run: `return require(game:GetService("ServerStorage").RunTests)({ testPathPattern = "Config.spec" })`
Expected: `success = false`; failure mentions `Config` cannot be required (no `init.luau` yet).

- [ ] **Step 3: Implement `Config/Match.luau`, `Config/Scoring.luau`, `Modes/NormalChampions.luau`, `Config/init.luau`**

Values and schema rules exactly as in the Interfaces block. `Config.defaults()` builds once at module load (`Validate.assertValid(defaults, Config.schema, "")` then `Freeze.deep`). `forMode` deep-copies defaults, merges, validates, freezes.

- [ ] **Step 4: Run to verify pass**

Run: `return require(game:GetService("ServerStorage").RunTests)({ testPathPattern = "Config.spec" })`
Expected: `success = true`, `numPassedTests = 10`.

- [ ] **Step 5: Commit and PR**

```bash
git checkout main && git pull && git checkout -b feat/6-game-config
stylua src tests && selene src tests
git add tests/shared/Config/Config.spec.luau src/shared/Config src/shared/Modes
git commit -m "feat(config): add Match and Scoring config with Normal Champions mode"
git push -u origin feat/6-game-config
gh pr create --title "feat(config): game config and Normal Champions mode" --body "Closes #6" --milestone "M1 - Foundation & Core Match"
```
Expected: CI green; merge.

---

### Task 7: Bootstrap and server/client entry points

**Issue:** #7 · **Branch:** `feat/7-bootstrap` · **Labels:** `feature`, `infra`

**Files:**
- Create: `src/shared/Util/Bootstrap.luau`
- Create: `src/server/Main.server.luau`, `src/server/Modules.luau`, `src/client/Main.client.luau`, `src/client/Modules.luau`
- Modify: `default.project.json`, `test.project.json` (add `ServerScriptService.Server` ← `src/server`, `StarterPlayer.StarterPlayerScripts.Client` ← `src/client`)
- Test: `tests/shared/Util/Bootstrap.spec.luau`

**Interfaces:**
- Consumes: `Config.forMode`, `Config.Mode`, `Config.GameConfig` (Task 6); `Loader.start`, `Loader.LoadableModule` (Task 4).
- Produces:
  ```lua
  export type BootOptions = {
  	realm: "Server" | "Client",
  	mode: Config.Mode,
  	modules: { Loader.LoadableModule },
  	log: ((message: string) -> ())?, -- default print
  }
  Bootstrap.run(options: BootOptions) -> (Config.GameConfig, { [string]: Loader.LoadableModule })
  ```
  Resolves config first (so invalid config throws before any module `init`), then `Loader.start(modules, { Config = config })`, then logs exactly `[BloxChampions] <realm> ready: mode=<mode.id>, modules=<#modules>`.
  `src/server/Modules.luau` and `src/client/Modules.luau` each return `{}` (ordered module lists that later phases append to). Each `Main` script calls `Bootstrap.run` with its realm, `NormalChampions`, and its `Modules` list.

- [ ] **Step 1: Write the failing tests**

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Bootstrap = require(ReplicatedStorage.Shared.Util.Bootstrap)
local Config = require(ReplicatedStorage.Shared.Config)
local NormalChampions = require(ReplicatedStorage.Shared.Modes.NormalChampions)

describe("Bootstrap.run", function()
	it("resolves config, gives it to modules, and logs the ready line", function()
		local lines = {}
		local received: any = nil
		local probe = {
			name = "Probe",
			dependencies = { "Config" },
			init = function(_self, deps)
				received = deps.Config
			end,
		}
		local config, registry = Bootstrap.run({
			realm = "Server",
			mode = NormalChampions,
			modules = { probe },
			log = function(message)
				table.insert(lines, message)
			end,
		})
		expect(config).toEqual(Config.defaults())
		expect(received).toBe(config)
		expect(registry.Probe).toBe(probe)
		expect(lines).toEqual({ "[BloxChampions] Server ready: mode=NormalChampions, modules=1" })
	end)

	it("fails on invalid config before any module initializes", function()
		local initialized = false
		local probe = {
			name = "Probe",
			init = function()
				initialized = true
			end,
		}
		expect(function()
			Bootstrap.run({
				realm = "Client",
				mode = { id = "Bad", displayName = "Bad", itemsEnabled = false, overrides = { Match = { teamSize = 0 } } },
				modules = { probe },
				log = function() end,
			})
		end).toThrow("Match.teamSize: must be >= 1 (got 0)")
		expect(initialized).toBe(false)
	end)
end)
```

- [ ] **Step 2: Run to verify failure**

Run: `return require(game:GetService("ServerStorage").RunTests)({ testPathPattern = "Bootstrap" })`
Expected: `success = false`; failure mentions `Bootstrap` missing.

- [ ] **Step 3: Implement `Bootstrap.run`, the two `Modules` lists, the two `Main` scripts, and the project mappings**

As specified in the Interfaces block.

- [ ] **Step 4: Run to verify pass, then the full suite**

Run: `return require(game:GetService("ServerStorage").RunTests)({ testPathPattern = "Bootstrap" })`
Expected: `success = true`, `numPassedTests = 2`.

Run: `return require(game:GetService("ServerStorage").RunTests)()`
Expected: `success = true`, `numPassedTests = 43` (Freeze 5 + Signal 7 + Loader 10 + Validate 9 + Config 10 + Bootstrap 2), `numFailedTests = 0`.

- [ ] **Step 5: Verify boot in a Studio playtest**

Use MCP `start_stop_play` (`is_start = true`), then `get_console_output`, then `start_stop_play` (`is_start = false`).
Expected console lines: `[BloxChampions] Server ready: mode=NormalChampions, modules=0` and `[BloxChampions] Client ready: mode=NormalChampions, modules=0`, and no errors.

- [ ] **Step 6: Commit and PR**

```bash
git checkout main && git pull && git checkout -b feat/7-bootstrap
stylua src tests && selene src tests
git add tests/shared/Util/Bootstrap.spec.luau src/shared/Util/Bootstrap.luau
git commit -m "feat(util): add Bootstrap that validates config before starting modules"
git add src/server src/client default.project.json test.project.json
git commit -m "feat: add server and client entry points"
git push -u origin feat/7-bootstrap
gh pr create --title "feat: bootstrap and entry points" --body "Closes #7" --milestone "M1 - Foundation & Core Match"
```
Expected: CI green; merge. Phase 1 is complete when all seven PRs are merged and the full suite passes on `main`.
