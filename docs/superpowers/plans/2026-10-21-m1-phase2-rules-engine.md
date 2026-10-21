# M1 Phase 2 — Rules Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure, fully tested rules of a Normal Champions match — possession, laps, goal, streak point, clock, overtime, Last Chance, score tab, assists, saves, MVP — composed into one deterministic `MatchEngine` that later phases feed with ball and player facts.

**Architecture:** Plain Luau modules in `src/shared/Rules/` (plus `src/shared/Ball/Trajectory.luau`) with no Instance access: only Luau, Roblox value types (`Vector3`, `CFrame`), config, and each other. Small single-purpose modules (Possession, LapTracker, GoalJudge, …) hold state and answer questions; `MatchEngine` orchestrates them, owns the match state machine, and appends typed events to a buffer that the caller drains once per tick. `ScoreKeeper` is a reducer over that event stream, so team scores and the score tab have one source of truth.

**Tech Stack:** Luau (`--!strict`), Jest-Lua 3.10.0 run in Studio through the Roblox Studio MCP, Rojo 7.7.1, StyLua 2.6.0, selene 0.32.0, luau-lsp 1.70.1.

**Spec:** `docs/superpowers/specs/2026-10-21-m1-foundation-core-match-design.md` — §4 (rules of play), §5 (clock and match end), §6 (score tab, assists, saves, MVP), §12.2 (performance budget), §14 (phase 2 scope).

## Global Constraints

- Everything in Phase 1's Global Constraints still applies: `--!strict` first line, StyLua/selene/luau-lsp clean, relative requires inside `src/`, service-path requires in tests, `JestGlobals` only, no `jest.fn()`, annotate test locals strict mode cannot infer.
- **Pure rules:** files in `src/shared/Rules/` and `src/shared/Ball/` never call `game:GetService`, read `workspace`, or touch an Instance. They require only siblings, `Config` (for types and values) and `Util`.
- **No literals for gameplay values:** every number comes from `Config` (`Match`, `Scoring`, `UI`) or from a constructor argument; tests supply values through `Fixtures.config(overrides)`.
- **Players are `PlayerId` strings**; teams are the `Team` type `"Blue" | "Orange"` (Task 2).
- **Event names and payload fields are exactly the `Event` union in Task 2.** Events are tables with a `name` discriminant.
- **Stateful modules use one class idiom:**
  ```lua
  local LapTracker = {}
  LapTracker.__index = LapTracker
  type Fields = { streak: number, progress: number, gateCount: number, _gates: { Crossing.Rectangle }, _nextGate: number? }
  export type LapTracker = typeof(setmetatable({} :: Fields, LapTracker))
  function LapTracker.new(gates: { Crossing.Rectangle }): LapTracker ... end
  function LapTracker.accept(self: LapTracker, gateIndex: number): number? ... end
  ```
  Public fields are read-only by convention; private fields start with `_`.
- **Errors** that signal a programming mistake use `error(message, 0)` with the module name as prefix (e.g. `MatchEngine: unknown player "Ghost"`), like `Loader`.
- **Hot path:** `MatchEngine:tick` and `MatchEngine:ballMoved` allocate nothing on ticks where no event happens; `drainEvents` returns one shared frozen empty table on those ticks.
- Issues, branches, commits and PRs follow `CONTRIBUTING.md`; every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`; every PR body ends with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## How tests run (used by every task)

Prerequisite once per session: `rojo serve test.project.json` running in the background and Studio's Rojo plugin connected (the owner clicks **Connect**). New top-level folders inside `src/shared` or `tests` need no restart; new top-level mappings in a project file do.

Run with the Roblox Studio MCP `execute_luau` tool, `datamodel_type = "Edit"`:

```lua
task.wait(1) -- let Rojo sync the files just written
local s = require(game:GetService("ServerStorage").RunTests:Clone())({ testPathPattern = "<pattern>" })
return { success = s.success, passed = s.numPassedTests, total = s.numTotalTests, firstFailure = s.failureMessages[1] }
```

Omit the options table for the full suite. The suite has **49 tests** before this phase; each task states its new total.

**Static checks before every commit** (same as CI):

```bash
stylua src tests scripts && stylua --check src tests scripts && selene src tests scripts
rojo sourcemap test.project.json --output sourcemap.json
luau-lsp analyze --platform=roblox --sourcemap=sourcemap.json --definitions=@roblox=globalTypes.d.luau --base-luaurc=.luaurc --ignore="DevPackages/**" --ignore="Packages/**" src tests scripts
mkdir -p build && rojo build default.project.json --output build/game.rbxl && rojo build test.project.json --output build/test.rbxl
```

Expected: no output from StyLua/selene beyond their success lines, `luau-lsp analyze` reports no errors, both builds exit 0.

## Shipping each task (Rojo-safe)

1. Branch from the tip of the previous task's branch (`git checkout -b <branch>`), so the working tree never loses files while Rojo watches it.
2. Static checks, then the task's commit.
3. `git push -u origin <branch>` and `gh pr create --base main --title "<title>" --body-file <file>` where the body follows `.github/pull_request_template.md`, contains `Closes #<issue>`, and ends with the Claude Code line. Then `mcp__ccd_pr__get_status` (bind the PR if needed). Never poll CI.
4. Merge PRs in task order once green: confirm with one `gh pr view <n> --json headRefOid,statusCheckRollup` that the green check is for the head commit, then `gh pr merge <n> --merge` (no `--delete-branch`) and `git push origin --delete <branch>`.
5. After the last merge: `git fetch --prune && git checkout -B main origin/main` (the trees are identical, so nothing Rojo watches is deleted), then `git branch -D` the task branches.

## Review Focus

1. **A ball resting exactly on a gate or ring plane between two ticks** (one segment ends on the plane, the next starts there) — must count once, never twice and never zero times. Test: Task 2 `counts a ball that stops exactly on the plane once, not again when it moves on`.
2. **A mode override that sets a list** (e.g. `UI.clockWarnings = { 10 }` or `{}`) — must replace the default list, not merge into it item by item (which would silently keep `30`). Test: Task 1 `replaces a list from an override instead of merging it item by item`.
3. **One ball segment that both completes the goal-opening lap at Gate 2 and passes through the ring** (the ring sits on Gate 2) — the panel was still closed when the ball reached it, so no goal. Test: Task 9 `judges the ring before the gates a segment crosses, so the lap that opens the goal cannot score`.
4. **A defender in body contact with the same thrown ball for several ticks** — one save, not one per tick. Test: Task 9 `makes a defender's touch on a thrown ball headed into the open goal one block save`.
5. **Facts that arrive at the wrong time or name the wrong player** (before kickoff ends, during a celebration, after the match ended, an id never added, a player who left) — out-of-state facts and departed players are ignored, unknown ids fail fast naming the id. Tests: Task 9 `ignores ball facts before the kickoff ends`, `resets for a kickoff after the celebration and ignores play during it`, `ends the match as soon as a team reaches pointsToWin`, `rejects unknown players and ignores departed ones, keeping their stats`.

## Decisions not spelled out in the spec (for owner review)

1. **Last Chance `maxDeficit` means "at most".** The owner's required behavior — behind by 1, has the ball, clock hits 0:00 → Last Chance — is the default (`maxDeficit = 1`). If it is ever raised, a trailing-team point that does not tie keeps Last Chance going after the kickoff.
2. **Players are string ids** (`PlayerId`), so M2 bots fit the same rules as Roblox players.
3. **Ring before gates within one ball segment:** the goal is judged with its state at the start of the segment (matches the physical panel, see Review Focus 3).
4. **A defender action that is both a block and a steal save is one save of kind `"Block"`.**
5. **One block save per throw:** after a block, further touches of that ball are not saves until it is thrown again.
6. **MVP is chosen among players still in the match.** Departed players keep their stats on the score tab.
7. **Assist window** is measured from the moment the scorer received the ball from the assister to the goal; the scorer re-picking up their own loose ball does not restart it.
8. **A tick that ends a timed phase** (kickoff countdown, celebration) does not spill its leftover time into the next phase.
9. **Engine state is two fields:** `state` (`Waiting | Kickoff | Live | Celebration | Ended`) and `period` (`Regulation | LastChance | Overtime`). Spec §4.6 lists LastChance and Overtime as states; splitting avoids a Kickoff/Live/Celebration copy per period.
10. **Contacts carry the ball's position and velocity** (`pickedUp/touched(player, ballPosition, ballVelocity)`), so Phase 4 can pass the velocity from before the contact changed it.
11. **Gravity is an engine option** (`gravity: Vector3`), because pure rules may not read `workspace.Gravity`.
12. **`knockedDown(attacker, victim)` is an engine input** (spec §4.6 omits it; §4.7 and §6.1 need it). Only opponents count.
13. **Events are drained, not returned per call:** `engine:drainEvents()` once per tick. Both `GoalScored.assister` and `AssistAwarded` are emitted (spec catalogue); assist points come only from `AssistAwarded`.
14. **A clock warning at or above the match duration never fires** (warnings fire when the clock moves from above the threshold to at/below it).
15. **Clock warnings live in a new `Config/UI.luau`** (spec §5.1 names `UI.clockWarnings`); Phase 8 adds the HUD strings and colors to the same file.

**Not in this phase:** respawning players and dropping the ball at a random `BallSpawn` on kickoff (§4.5), the goal panel's physics (§4.3), the 15 s post-match screen and starting the next match (§5.4), and sending events/snapshots over remotes (§10.2) are Phase 3–4 work that consumes this engine.

---

### Task 1: Config — list validation, list-replacing overrides, UI clock warnings, shared test fixtures

**Issue:** #18 · **Branch:** `feat/18-config-lists-ui` · **Labels:** `feature`, `infra`

**Files:**
- Modify: `src/shared/Config/Validate.luau` (add `list`, `isList`)
- Create: `src/shared/Config/UI.luau`
- Modify: `src/shared/Config/init.luau` (UI area; lists replace on merge)
- Create: `tests/Fixtures.luau`
- Modify: `tests/shared/Config/Validate.spec.luau`, `tests/shared/Config/Config.spec.luau`, `tests/shared/Util/Bootstrap.spec.luau` (use `Fixtures`)
- Modify: `README.md` (project layout rows), `.github/pull_request_template.md` (test command uses `RunTests:Clone()`, as the README does)

**Interfaces:**
- Consumes: Phase 1 `Validate`, `Config`, `Freeze`.
- Produces:
  ```lua
  Validate.list(item: Validator): Validator
  -- non-table: "<path>: expected table, got <type>"; keys not exactly 1..n: "<path>: must be a list";
  -- each item validated at "<path>[<i>]".
  Validate.isList(value: { [any]: any }): boolean -- keys are exactly the integers 1..n (an empty table counts)

  -- Config/UI.luau returns { defaults: UIConfig, schema: Validate.Validator }
  export type UIConfig = { clockWarnings: { number } } -- default { 60, 30 }
  -- schema: Validate.check(Validate.list(Validate.number({ min = 1, integer = true })), noDuplicates, "must not contain duplicates")

  -- Config/init.luau
  export type UIConfig = UI.UIConfig
  export type GameConfig = { Match: MatchConfig, Scoring: ScoringConfig, UI: UIConfig }
  -- Merge rule (added): an override value replaces a default that is a list (Validate.isList) instead of merging into it.

  -- tests/Fixtures.luau → ReplicatedStorage.Tests.Fixtures (not a spec file, so Jest never runs it)
  Fixtures.mode(overrides: { [string]: any }?): Config.Mode -- id/displayName "Test", itemsEnabled false
  Fixtures.config(overrides: { [string]: any }?): Config.GameConfig -- Config.forMode(Fixtures.mode(overrides))
  ```

- [ ] **Step 1: Write the failing tests**

Append to the `describe("Validate", …)` block in `tests/shared/Config/Validate.spec.luau`:

```lua
	it("validates every item of a list with an indexed path", function()
		local v = Validate.list(Validate.number({ min = 1 }))
		expect(v({}, "UI.clockWarnings")).toEqual({})
		expect(v({ 3, 0 }, "UI.clockWarnings")).toEqual({ "UI.clockWarnings[2]: must be >= 1 (got 0)" })
	end)

	it("rejects non-tables and tables that are not lists", function()
		local v = Validate.list(Validate.number())
		expect(v(5, "L")).toEqual({ "L: expected table, got number" })
		expect(v({ a = 1 }, "L")).toEqual({ "L: must be a list" })
		expect(v({ [1] = 1, [3] = 3 }, "L")).toEqual({ "L: must be a list" })
	end)
```

In `tests/shared/Config/Config.spec.luau`: delete the local `mode` helper, add `local Fixtures = require(ReplicatedStorage.Tests.Fixtures)`, and replace every `Config.forMode(mode(X))` with `Fixtures.config(X)`. Add to `describe("Config defaults", …)`:

```lua
	it("match the spec's UI values", function()
		expect(Config.defaults().UI.clockWarnings).toEqual({ 60, 30 })
	end)
```

and to `describe("Config.forMode", …)`:

```lua
	it("replaces a list from an override instead of merging it item by item", function()
		expect(Fixtures.config({ UI = { clockWarnings = { 10 } } }).UI.clockWarnings).toEqual({ 10 })
		expect(Fixtures.config({ UI = { clockWarnings = {} } }).UI.clockWarnings).toEqual({})
	end)

	it("rejects duplicate clock warnings", function()
		expect(function()
			Fixtures.config({ UI = { clockWarnings = { 30, 30 } } })
		end).toThrow("UI.clockWarnings: must not contain duplicates")
	end)

	it("rejects a clock warning that is not a whole number of seconds", function()
		expect(function()
			Fixtures.config({ UI = { clockWarnings = { 60, 2.5 } } })
		end).toThrow("UI.clockWarnings[2]: must be an integer (got 2.5)")
	end)
```

In `tests/shared/Util/Bootstrap.spec.luau`, replace the inline bad mode with `Fixtures.mode({ Match = { teamSize = 0 } })` (same assertions).

- [ ] **Step 2: Run to verify failure**

Run with `testPathPattern = "Config"`.
Expected: `success = false`; failures say `attempt to call a nil value (field 'list')` and `Fixtures` is not a valid member of `Tests` (or `UI` is nil).

- [ ] **Step 3: Implement**

- `Validate.isList`: count the keys; the table is a list when every key is an integer in `1..count`.
- `Validate.list`: type check, then `isList`, then each item in index order.
- `Config/UI.luau`: defaults, type, schema as in Interfaces; `noDuplicates` builds a set of seen values.
- `Config/init.luau`: add `UI` to `GameConfig`, the schema record, and the `build` defaults; in `deepMerge`, merge only when both sides are tables **and** the default is not a list.
- `tests/Fixtures.luau`: the two functions in Interfaces.
- `README.md` project layout: add rows `src/server/` (server scripts → `ServerScriptService.Server`), `src/client/` (client scripts → `StarterPlayer.StarterPlayerScripts.Client`), and extend the `tests/` row with "shared test data in `tests/Fixtures.luau`".

- [ ] **Step 4: Run to verify pass, then the full suite**

`testPathPattern = "Config"` → `success = true`, `passed = 28` (Validate 12 + Config 16 — the `Config` pattern matches both files).
Full suite → `success = true`, `passed = 55`, `total = 55`.

- [ ] **Step 5: Commit**

```bash
git add src/shared/Config tests/Fixtures.luau tests/shared/Config tests/shared/Util/Bootstrap.spec.luau
git commit -m "feat(config): add list validation, list-replacing overrides and UI clock warnings"
git add README.md .github/pull_request_template.md
git commit -m "docs: list server, client and fixtures folders and clone the test runner in the PR template"
```
PR title: `feat(config): lists, UI clock warnings and test fixtures`.

---

### Task 2: Rules foundation — `Team`, event types, `Crossing`

**Issue:** #19 · **Branch:** `feat/19-rules-foundation` · **Labels:** `feature`, `rules`

**Files:**
- Create: `src/shared/Rules/Team.luau`, `src/shared/Rules/Types.luau`, `src/shared/Rules/Crossing.luau`
- Test: `tests/shared/Rules/Team.spec.luau`, `tests/shared/Rules/Crossing.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces:
  ```lua
  -- Rules/Team.luau
  export type Team = "Blue" | "Orange"
  Team.list: { Team } -- frozen { "Blue", "Orange" }; also the score tab's group order
  Team.opponent(team: Team): Team

  -- Rules/Types.luau (types only; returns a frozen empty table)
  export type PlayerId = string
  export type MatchState = "Waiting" | "Kickoff" | "Live" | "Celebration" | "Ended"
  export type Period = "Regulation" | "LastChance" | "Overtime"
  export type SaveKind = "Block" | "Steal"
  export type PlayerStats = {
  	player: PlayerId, team: Team, joinOrder: number, present: boolean,
  	score: number, goals: number, assists: number, saves: number, steals: number,
  }
  export type MatchStats = { scores: { [Team]: number }, players: { PlayerStats } }
  export type Event =
  	{ name: "MatchStarted" }
  	| { name: "KickoffStarted", countdownSeconds: number }
  	| { name: "KickoffEnded" }
  	| { name: "PossessionChanged", team: Team, player: PlayerId, previousTeam: Team? }
  	| { name: "GateCrossed", team: Team, gateIndex: number, progress: number }
  	| { name: "LapCompleted", team: Team, streak: number, holder: PlayerId }
  	| { name: "GoalOpened", team: Team }
  	| { name: "GoalClosed" }
  	| { name: "GoalScored", team: Team, scorer: PlayerId, assister: PlayerId? }
  	| { name: "StreakPointScored", team: Team, holder: PlayerId }
  	| { name: "AssistAwarded", player: PlayerId }
  	| { name: "SaveMade", player: PlayerId, kind: SaveKind }
  	| { name: "Steal", player: PlayerId, fromTeam: Team }
  	| { name: "TackleKnockdown", attacker: PlayerId, victim: PlayerId }
  	| { name: "ClockWarning", secondsLeft: number }
  	| { name: "LastChanceStarted", team: Team }
  	| { name: "OvertimeStarted" }
  	| { name: "MatchEnded", winner: Team, mvp: PlayerId?, stats: MatchStats }

  -- Rules/Crossing.luau
  -- A shape lies in its frame's XY plane, centered on frame.Position (width along RightVector, height
  -- along UpVector). A crossing counts only when moving along frame.LookVector: the segment starts behind
  -- the plane (signed distance along LookVector < 0) and ends on or in front of it (>= 0). Edges are inclusive.
  export type Rectangle = { frame: CFrame, width: number, height: number }
  export type Disc = { frame: CFrame, radius: number }
  Crossing.throughRectangle(rectangle: Rectangle, from: Vector3, to: Vector3): number? -- fraction t in (0, 1] along the segment, nil if no counted crossing
  Crossing.throughDisc(disc: Disc, from: Vector3, to: Vector3): number?
  Crossing.withinDisc(disc: Disc, point: Vector3): boolean -- distance from the disc's axis <= radius; distance from its plane is ignored
  ```

- [ ] **Step 1: Write the failing tests**

`tests/shared/Rules/Team.spec.luau`:

```lua
describe("Team", function()
	it("lists both teams in a fixed order, frozen", function()
		expect(Team.list).toEqual({ "Blue", "Orange" })
		expect(table.isfrozen(Team.list)).toBe(true)
	end)

	it("returns each team's opponent", function()
		expect(Team.opponent("Blue")).toBe("Orange")
		expect(Team.opponent("Orange")).toBe("Blue")
	end)
end)
```

`tests/shared/Rules/Crossing.spec.luau`:

```lua
local FACING_X = CFrame.lookAt(Vector3.zero, Vector3.xAxis)

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

describe("Crossing.throughRectangle", function()
	local rect: Crossing.Rectangle = { frame = FACING_X, width = 10, height = 6 }

	it("returns where along the segment it crosses forward inside the rectangle", function()
		expect(Crossing.throughRectangle(rect, v(-1, 0, 0), v(3, 0, 0))).toBeCloseTo(0.25)
	end)

	it("ignores backward crossings and segments that stay on one side", function()
		expect(Crossing.throughRectangle(rect, v(1, 0, 0), v(-1, 0, 0))).toBeNil()
		expect(Crossing.throughRectangle(rect, v(-3, 0, 0), v(-1, 0, 0))).toBeNil()
		expect(Crossing.throughRectangle(rect, v(1, 0, 0), v(2, 0, 0))).toBeNil()
	end)

	it("ignores crossings outside the rectangle and includes its edges", function()
		expect(Crossing.throughRectangle(rect, v(-1, 0, 6), v(1, 0, 6))).toBeNil()
		expect(Crossing.throughRectangle(rect, v(-1, 4, 0), v(1, 4, 0))).toBeNil()
		expect(Crossing.throughRectangle(rect, v(-1, 3, 5), v(1, 3, 5))).toBeCloseTo(0.5)
	end)

	it("counts a ball that stops exactly on the plane once, not again when it moves on", function()
		expect(Crossing.throughRectangle(rect, v(-1, 0, 0), v(0, 0, 0))).toBe(1)
		expect(Crossing.throughRectangle(rect, v(0, 0, 0), v(1, 0, 0))).toBeNil()
	end)

	it("uses the frame's position and facing", function()
		local facingNegativeZ: Crossing.Rectangle =
			{ frame = CFrame.lookAt(v(10, 5, 0), v(10, 5, -1)), width = 2, height = 2 }
		expect(Crossing.throughRectangle(facingNegativeZ, v(10, 5, 1), v(10, 5, -1))).toBeCloseTo(0.5)
		expect(Crossing.throughRectangle(facingNegativeZ, v(10, 5, -1), v(10, 5, 1))).toBeNil()
	end)
end)

describe("Crossing.throughDisc", function()
	it("counts forward crossings within the radius only", function()
		local disc: Crossing.Disc = { frame = FACING_X, radius = 7 }
		expect(Crossing.throughDisc(disc, v(-1, 0, 6.9), v(1, 0, 6.9))).toBeCloseTo(0.5)
		expect(Crossing.throughDisc(disc, v(-1, 5, 5), v(1, 5, 5))).toBeNil()
		expect(Crossing.throughDisc(disc, v(1, 0, 0), v(-1, 0, 0))).toBeNil()
	end)
end)

describe("Crossing.withinDisc", function()
	it("measures distance from the disc's axis and ignores distance from its plane", function()
		local disc: Crossing.Disc = { frame = FACING_X, radius = 5 }
		expect(Crossing.withinDisc(disc, v(0, 3, 4))).toBe(true)
		expect(Crossing.withinDisc(disc, v(0, 4, 4))).toBe(false)
		expect(Crossing.withinDisc(disc, v(2, 3, 4))).toBe(true)
	end)
end)
```

(Both files start with the standard header: `--!strict`, `ReplicatedStorage`, `JestGlobals` → `describe, it, expect`, and the module require.)

- [ ] **Step 2: Run to verify failure**

`testPathPattern = "Rules"` → `success = false`; `Rules` is not a valid member of `Shared`.

- [ ] **Step 3: Implement**

`Crossing`: one private `forwardFraction(frame, from, to): (number?, Vector3?)` using `frame:PointToObjectSpace` (local `-Z` is the signed distance along `LookVector`) returns `t = sFrom / (sFrom - sTo)` and the local hit point (`localFrom:Lerp(localTo, t)`); the shape functions add the inclusive bounds check on the hit point's X/Y. `Types.luau` returns `table.freeze({})`.

- [ ] **Step 4: Run to verify pass, then the full suite**

`testPathPattern = "Rules"` → `success = true`, `passed = 9`. Full suite → `passed = 64`.

- [ ] **Step 5: Commit**

```bash
git add src/shared/Rules tests/shared/Rules
git commit -m "feat(rules): add teams, event types and forward plane crossings"
```
PR title: `feat(rules): teams, event types and crossings`.

---

### Task 3: `Possession` and `LapTracker` (spec §4.1–§4.2)

**Issue:** #20 · **Branch:** `feat/20-possession-laps` · **Labels:** `feature`, `rules`

**Files:**
- Create: `src/shared/Rules/Possession.luau`, `src/shared/Rules/LapTracker.luau`
- Modify: `tests/Fixtures.luau` (arena geometry)
- Test: `tests/shared/Rules/Possession.spec.luau`, `tests/shared/Rules/LapTracker.spec.luau`

**Interfaces:**
- Consumes: `Team.Team`, `Types.PlayerId`, `Crossing.Rectangle`, `Crossing.throughRectangle` (Task 2).
- Produces:
  ```lua
  Possession.new(): Possession
  possession.team: Team?              -- possessing team; nil = neutral
  possession.lastHolder: PlayerId?    -- always a player of `team` once someone has picked up
  possession:pickUp(player: PlayerId, team: Team): boolean -- sets lastHolder; true when the possessing team changed
  possession:reset()                   -- neutral, no last holder

  LapTracker.new(gates: { Crossing.Rectangle }): LapTracker -- error "LapTracker: at least one gate is required"
  laps.gateCount: number
  laps.streak: number    -- completed laps
  laps.progress: number  -- gates accepted in the current lap, 0..gateCount-1
  laps:crossedGates(from: Vector3, to: Vector3): { number }? -- gates crossed forward, in the order the segment meets them; nil if none
  laps:accept(gateIndex: number): number? -- nil if ignored; else progress 1..gateCount, where gateCount means a lap
                                           -- completed (streak + 1, progress back to 0)
  laps:reset()                             -- streak 0, progress 0, sequence cleared

  -- tests/Fixtures.luau additions (a straight synthetic "track": gates face +X so a +X segment crosses them forward)
  Fixtures.GRAVITY: Vector3                 -- Vector3.new(0, -196.2, 0), Roblox's default workspace.Gravity
  Fixtures.gate(x: number): Crossing.Rectangle -- 40 x 40 at (x, 0, 0), facing +X
  Fixtures.gates(): { Crossing.Rectangle }  -- gates 1-4 at x = 100, 200, 300, 400
  Fixtures.ring(): Crossing.Disc            -- radius 3 at (200, 15, 0) facing +X: on Gate 2's plane and inside its rectangle, like the arena's goal
  Fixtures.arena(): { gates: { Crossing.Rectangle }, goal: Crossing.Disc }
  Fixtures.throughGate(index: number): (Vector3, Vector3) -- (100 * index - 1, 0, 0) -> (100 * index + 1, 0, 0)
  Fixtures.throughRing(): (Vector3, Vector3)               -- (199, 15, 0) -> (201, 15, 0); also crosses Gate 2
  ```

Lap rules (spec §4.2): the first accepted crossing after a reset may be any gate and sets the sequence; afterwards only `gate % gateCount + 1` of the last accepted gate counts.

- [ ] **Step 1: Write the failing tests**

`tests/shared/Rules/Possession.spec.luau`:

```lua
describe("Possession", function()
	it("starts neutral", function()
		local possession = Possession.new()
		expect(possession.team).toBeNil()
		expect(possession.lastHolder).toBeNil()
	end)

	it("gives possession to the first team to pick up the ball", function()
		local possession = Possession.new()
		expect(possession:pickUp("B1", "Blue")).toBe(true)
		expect(possession.team).toBe("Blue")
		expect(possession.lastHolder).toBe("B1")
	end)

	it("keeps possession on a teammate pickup and changes it on an opponent pickup", function()
		local possession = Possession.new()
		possession:pickUp("B1", "Blue")
		expect(possession:pickUp("B2", "Blue")).toBe(false)
		expect(possession.team).toBe("Blue")
		expect(possession.lastHolder).toBe("B2")
		expect(possession:pickUp("O1", "Orange")).toBe(true)
		expect(possession.team).toBe("Orange")
		expect(possession.lastHolder).toBe("O1")
	end)

	it("returns to neutral on reset", function()
		local possession = Possession.new()
		possession:pickUp("B1", "Blue")
		possession:reset()
		expect(possession.team).toBeNil()
		expect(possession.lastHolder).toBeNil()
	end)
end)
```

`tests/shared/Rules/LapTracker.spec.luau` (also requires `Fixtures`):

```lua
describe("LapTracker", function()
	it("starts the sequence at the first gate crossed, then accepts only the next gate in order", function()
		local laps = LapTracker.new(Fixtures.gates())
		expect(laps:accept(3)).toBe(1)
		expect(laps:accept(1)).toBeNil()
		expect(laps:accept(4)).toBe(2)
		expect(laps:accept(4)).toBeNil()
		expect(laps:accept(1)).toBe(3)
		expect(laps.streak).toBe(0)
		expect(laps:accept(2)).toBe(4)
		expect(laps.streak).toBe(1)
		expect(laps.progress).toBe(0)
	end)

	it("keeps the sequence across laps", function()
		local laps = LapTracker.new(Fixtures.gates())
		for _ = 1, 2 do
			for gate = 1, 4 do
				laps:accept(gate)
			end
		end
		expect(laps.streak).toBe(2)
		expect(laps:accept(2)).toBeNil()
		expect(laps:accept(1)).toBe(1)
	end)

	it("clears the streak, progress and sequence on reset", function()
		local laps = LapTracker.new(Fixtures.gates())
		for gate = 1, 4 do
			laps:accept(gate)
		end
		laps:accept(1)
		laps:reset()
		expect(laps.streak).toBe(0)
		expect(laps.progress).toBe(0)
		expect(laps:accept(3)).toBe(1)
	end)

	it("lists the gates a segment crosses forward, in the order the segment meets them", function()
		local laps = LapTracker.new(Fixtures.gates())
		expect(laps:crossedGates(Fixtures.throughGate(2))).toEqual({ 2 })
		expect(laps:crossedGates(Vector3.new(50, 0, 0), Vector3.new(450, 0, 0))).toEqual({ 1, 2, 3, 4 })
		expect(laps:crossedGates(Vector3.new(110, 0, 0), Vector3.new(190, 0, 0))).toBeNil()
		local from, to = Fixtures.throughGate(2)
		expect(laps:crossedGates(to, from)).toBeNil()

		local reversed = LapTracker.new({ Fixtures.gate(300), Fixtures.gate(100) })
		expect(reversed:crossedGates(Vector3.new(50, 0, 0), Vector3.new(350, 0, 0))).toEqual({ 2, 1 })
	end)

	it("requires at least one gate", function()
		expect(function()
			LapTracker.new({})
		end).toThrow("LapTracker: at least one gate is required")
	end)
end)
```

- [ ] **Step 2: Run to verify failure**

`testPathPattern = "Possession|LapTracker"` → `success = false`; `Possession` / `LapTracker` are not valid members of `Rules`.

- [ ] **Step 3: Implement** `Possession`, `LapTracker` and the Fixtures additions as in Interfaces. `crossedGates` returns `nil` without allocating when no gate is crossed; with two or more hits it sorts them by their crossing fraction.

- [ ] **Step 4: Run to verify pass, then the full suite**

`testPathPattern = "Possession|LapTracker"` → `passed = 9`. Full suite → `passed = 73`.

- [ ] **Step 5: Commit**

```bash
git add src/shared/Rules tests/Fixtures.luau tests/shared/Rules
git commit -m "feat(rules): add possession and in-order lap tracking"
```
PR title: `feat(rules): possession and lap tracker`.

---

### Task 4: `GoalJudge` (spec §4.3)

**Issue:** #21 · **Branch:** `feat/21-goal-judge` · **Labels:** `feature`, `rules`

**Files:**
- Create: `src/shared/Rules/GoalJudge.luau`
- Test: `tests/shared/Rules/GoalJudge.spec.luau`

**Interfaces:**
- Consumes: `Crossing.Disc`, `Crossing.throughDisc`, `Team.Team`; `Fixtures.ring`, `Fixtures.throughRing`, `Fixtures.throughGate` (Task 3).
- Produces:
  ```lua
  GoalJudge.new(ring: Crossing.Disc, lapsToOpenGoal: number): GoalJudge
  goal.openFor: Team?                                 -- nil = closed
  goal:lapCompleted(team: Team, streak: number): boolean -- opens for `team` when closed and streak >= lapsToOpenGoal; true if it just opened
  goal:close(): boolean                                -- true if it was open
  goal:scored(from: Vector3, to: Vector3): boolean     -- open and the segment passes through the ring front-to-back
  ```

- [ ] **Step 1: Write the failing tests**

```lua
describe("GoalJudge", function()
	it("starts closed and does not score while closed", function()
		local goal = GoalJudge.new(Fixtures.ring(), 4)
		expect(goal.openFor).toBeNil()
		expect(goal:scored(Fixtures.throughRing())).toBe(false)
	end)

	it("opens once for a team whose streak reaches lapsToOpenGoal", function()
		local goal = GoalJudge.new(Fixtures.ring(), 4)
		expect(goal:lapCompleted("Blue", 3)).toBe(false)
		expect(goal.openFor).toBeNil()
		expect(goal:lapCompleted("Blue", 4)).toBe(true)
		expect(goal.openFor).toBe("Blue")
		expect(goal:lapCompleted("Blue", 5)).toBe(false)
		expect(goal.openFor).toBe("Blue")
	end)

	it("scores only when the ball passes front-to-back through the ring while open", function()
		local goal = GoalJudge.new(Fixtures.ring(), 1)
		goal:lapCompleted("Orange", 1)
		local from, to = Fixtures.throughRing()
		expect(goal:scored(to, from)).toBe(false)
		expect(goal:scored(Fixtures.throughGate(2))).toBe(false)
		expect(goal:scored(from, to)).toBe(true)
	end)

	it("reports whether closing changed anything", function()
		local goal = GoalJudge.new(Fixtures.ring(), 1)
		goal:lapCompleted("Blue", 1)
		expect(goal:close()).toBe(true)
		expect(goal.openFor).toBeNil()
		expect(goal:close()).toBe(false)
	end)
end)
```

- [ ] **Step 2: Run to verify failure** — `testPathPattern = "GoalJudge"` → `GoalJudge` is not a valid member of `Rules`.
- [ ] **Step 3: Implement** `GoalJudge` as in Interfaces.
- [ ] **Step 4: Run to verify pass** — `passed = 4`. Full suite → `passed = 77`.
- [ ] **Step 5: Commit**

```bash
git add src/shared/Rules/GoalJudge.luau tests/shared/Rules/GoalJudge.spec.luau
git commit -m "feat(rules): add goal judge that opens after the lap target"
```
PR title: `feat(rules): goal judge`.

---

### Task 5: `Trajectory` and `SaveDetector` (spec §6.3)

**Issue:** #22 · **Branch:** `feat/22-trajectory-saves` · **Labels:** `feature`, `rules`, `ball`

**Files:**
- Create: `src/shared/Ball/Trajectory.luau`, `src/shared/Rules/SaveDetector.luau`
- Test: `tests/shared/Ball/Trajectory.spec.luau`, `tests/shared/Rules/SaveDetector.spec.luau`

**Interfaces:**
- Consumes: `Crossing.Disc`, `Crossing.withinDisc`, `Types.SaveKind`; `Fixtures.ring`, `Fixtures.GRAVITY`.
- Produces:
  ```lua
  Trajectory.positionAt(position: Vector3, velocity: Vector3, gravity: Vector3, t: number): Vector3
  Trajectory.forwardCrossingTime(position: Vector3, velocity: Vector3, gravity: Vector3, frame: CFrame, maxTime: number): number?
  -- earliest t in [0, maxTime] where the gravity-only path crosses frame's plane moving along frame.LookVector

  SaveDetector.new(ring: Crossing.Disc, gravity: Vector3, lookaheadSeconds: number): SaveDetector
  detector:classify(contact: "Pickup" | "Touch", ballThrown: boolean, ballPosition: Vector3, ballVelocity: Vector3): Types.SaveKind?
  -- Called only for a contact by the team defending an open goal (the engine checks that).
  -- "Block" when the ball was thrown and its path passes through the ring within the lookahead;
  -- otherwise "Steal" for a pickup; otherwise nil.
  ```

`forwardCrossingTime` algorithm (with `n = frame.LookVector`): signed distance `s(t) = s0 + b·t + ½·a·t²` where `s0 = (position − frame.Position)·n`, `b = velocity·n`, `a = gravity·n`. If `|a| < 1e-9`, the only candidate is `t = −s0 / b` when `b > 0`. Otherwise solve the quadratic; candidates are the real roots in `[0, maxTime]` in ascending order; return the first where `s'(t) = b + a·t > 0`.

- [ ] **Step 1: Write the failing tests**

`tests/shared/Ball/Trajectory.spec.luau`:

```lua
local SIMPLE_GRAVITY = Vector3.new(0, -10, 0)
local FACING_X = CFrame.lookAt(Vector3.new(10, 0, 0), Vector3.new(11, 0, 0))
local FACING_UP = CFrame.lookAt(Vector3.new(0, 10, 0), Vector3.new(0, 11, 0), Vector3.zAxis)

describe("Trajectory.positionAt", function()
	it("follows constant gravity", function()
		local p = Trajectory.positionAt(Vector3.new(0, 10, 0), Vector3.new(10, 20, 0), Fixtures.GRAVITY, 0.5)
		expect(p.X).toBeCloseTo(5)
		expect(p.Y).toBeCloseTo(-4.525)
		expect(p.Z).toBeCloseTo(0)
	end)
end)

describe("Trajectory.forwardCrossingTime", function()
	it("solves a straight path when gravity runs along the plane", function()
		expect(Trajectory.forwardCrossingTime(Vector3.zero, Vector3.new(20, 0, 0), Fixtures.GRAVITY, FACING_X, 2))
			.toBeCloseTo(0.5)
	end)

	it("returns the forward crossing of an arc, not the later backward one", function()
		expect(Trajectory.forwardCrossingTime(Vector3.zero, Vector3.new(0, 30, 0), SIMPLE_GRAVITY, FACING_UP, 10))
			.toBeCloseTo(3 - math.sqrt(7))
	end)

	it("ignores crossings against the facing, in the past, or after maxTime", function()
		expect(Trajectory.forwardCrossingTime(Vector3.new(0, 20, 0), Vector3.zero, SIMPLE_GRAVITY, FACING_UP, 5))
			.toBeNil()
		expect(Trajectory.forwardCrossingTime(Vector3.new(12, 0, 0), Vector3.new(5, 0, 0), Fixtures.GRAVITY, FACING_X, 5))
			.toBeNil()
		expect(Trajectory.forwardCrossingTime(Vector3.zero, Vector3.new(20, 0, 0), Fixtures.GRAVITY, FACING_X, 0.4))
			.toBeNil()
	end)
end)
```

`tests/shared/Rules/SaveDetector.spec.luau` (the on-target ball reaches x = 200 after 0.1 s, 0.98 studs below the ring's center):

```lua
local ON_TARGET_POSITION, ON_TARGET_VELOCITY = Vector3.new(190, 15, 0), Vector3.new(100, 0, 0)

local function detector(lookaheadSeconds: number?): SaveDetector.SaveDetector
	return SaveDetector.new(Fixtures.ring(), Fixtures.GRAVITY, lookaheadSeconds or 1.5)
end

describe("SaveDetector", function()
	it("calls a touch on a thrown ball headed through the ring a block", function()
		expect(detector():classify("Touch", true, ON_TARGET_POSITION, ON_TARGET_VELOCITY)).toBe("Block")
	end)

	it("needs the ball to have been thrown for a block", function()
		expect(detector():classify("Touch", false, ON_TARGET_POSITION, ON_TARGET_VELOCITY)).toBeNil()
	end)

	it("ignores a thrown ball that would miss the ring", function()
		expect(detector():classify("Touch", true, ON_TARGET_POSITION, Vector3.new(100, 0, 50))).toBeNil()
	end)

	it("ignores a ball that would reach the ring after the lookahead", function()
		-- Arcs up and back down to (200, 15, 0) at t = 2 s.
		local position, velocity = Vector3.new(0, 15, 0), Vector3.new(100, 196.2, 0)
		expect(detector(1.5):classify("Touch", true, position, velocity)).toBeNil()
		expect(detector(2.5):classify("Touch", true, position, velocity)).toBe("Block")
	end)

	it("calls a defender's pickup a steal save, and a pickup that is also a block one block", function()
		expect(detector():classify("Pickup", false, Vector3.zero, Vector3.zero)).toBe("Steal")
		expect(detector():classify("Pickup", true, ON_TARGET_POSITION, ON_TARGET_VELOCITY)).toBe("Block")
	end)
end)
```

- [ ] **Step 2: Run to verify failure** — `testPathPattern = "Trajectory|SaveDetector"` → `Ball` / `SaveDetector` missing.
- [ ] **Step 3: Implement** `Trajectory` (algorithm above) and `SaveDetector` (`forwardCrossingTime(…, ring.frame, lookahead)` then `Crossing.withinDisc(ring, positionAt(…))`).
- [ ] **Step 4: Run to verify pass** — `passed = 9`. Full suite → `passed = 86`.
- [ ] **Step 5: Commit**

```bash
git add src/shared/Ball tests/shared/Ball src/shared/Rules/SaveDetector.luau tests/shared/Rules/SaveDetector.spec.luau
git commit -m "feat(rules): predict ball flight and detect block and steal saves"
```
PR title: `feat(rules): trajectory and save detector`.

---

### Task 6: `AssistTracker` and `ScoreKeeper` (spec §6.1, §6.2, §6.4, §6.5)

**Issue:** #23 · **Branch:** `feat/23-assists-score-keeper` · **Labels:** `feature`, `rules`

**Files:**
- Create: `src/shared/Rules/AssistTracker.luau`, `src/shared/Rules/ScoreKeeper.luau`
- Test: `tests/shared/Rules/AssistTracker.spec.luau`, `tests/shared/Rules/ScoreKeeper.spec.luau`

**Interfaces:**
- Consumes: `Config.GameConfig` (Task 1), `Team`, `Types.PlayerId`, `Types.Event`, `Types.PlayerStats`, `Types.MatchStats` (Task 2).
- Produces:
  ```lua
  AssistTracker.new(windowSeconds: number): AssistTracker
  assists:pickedUp(player: PlayerId, now: number) -- a new holder; the same player again keeps the original handoff time
  assists:assister(scorer: PlayerId, now: number): PlayerId? -- previous different holder if scorer is the current holder
                                                             -- and now - handoff time <= window
  assists:reset()

  ScoreKeeper.new(config: Config.GameConfig): ScoreKeeper
  keeper:addPlayer(player: PlayerId, team: Team) -- new entry with the next joinOrder, or re-activates a departed one
                                                -- (stats and joinOrder kept, team updated);
                                                -- error 'ScoreKeeper: player "<id>" is already in the match'
  keeper:removePlayer(player: PlayerId)         -- present = false, stats kept; error 'ScoreKeeper: unknown player "<id>"'
  keeper:player(player: PlayerId): PlayerStats? -- live entry (read-only by convention), nil if never added
  keeper:apply(event: Event)                    -- see table below; any other event changes nothing
  keeper:teamScores(): { [Team]: number }       -- copy
  keeper:stats(): MatchStats                    -- deep copy; players grouped in Team.list order, then score desc, then joinOrder asc
  keeper:mvp(team: Team): PlayerId?             -- present players of `team`: score, goals, saves, assists (all desc), joinOrder asc
  ```

| Event | Team score | Player | Stat |
|---|---|---|---|
| `GoalScored` | `+Match.pointValue.goal` | scorer `+Scoring.points.goal` | `goals + 1` |
| `StreakPointScored` | `+Match.pointValue.streak` | holder `+points.streakPoint` | — |
| `AssistAwarded` | — | player `+points.assist` | `assists + 1` |
| `SaveMade` | — | player `+points.save` | `saves + 1` |
| `Steal` | — | player `+points.steal` | `steals + 1` |
| `LapCompleted` | — | holder `+points.lapCompleted` | — |
| `TackleKnockdown` | — | attacker `+points.tackleKnockdown` | — |

- [ ] **Step 1: Write the failing tests**

`tests/shared/Rules/AssistTracker.spec.luau`:

```lua
describe("AssistTracker", function()
	it("credits the previous holder when the scorer received the ball within the window", function()
		local assists = AssistTracker.new(8)
		assists:pickedUp("A", 0)
		assists:pickedUp("S", 2)
		expect(assists:assister("S", 10)).toBe("A")
		expect(assists:assister("S", 10.5)).toBeNil()
	end)

	it("keeps the handoff time when the scorer picks up their own loose ball again", function()
		local assists = AssistTracker.new(8)
		assists:pickedUp("A", 0)
		assists:pickedUp("S", 2)
		assists:pickedUp("S", 6)
		expect(assists:assister("S", 10)).toBe("A")
		expect(assists:assister("S", 10.5)).toBeNil()
	end)

	it("credits the last different holder", function()
		local assists = AssistTracker.new(8)
		assists:pickedUp("A", 0)
		assists:pickedUp("B", 1)
		assists:pickedUp("S", 2)
		expect(assists:assister("S", 3)).toBe("B")
	end)

	it("gives no assist for a solo play, a scorer who is not the holder, or after a reset", function()
		local assists = AssistTracker.new(8)
		assists:pickedUp("S", 0)
		expect(assists:assister("S", 1)).toBeNil()
		assists:pickedUp("A", 1)
		expect(assists:assister("S", 2)).toBeNil()
		assists:reset()
		assists:pickedUp("S", 3)
		expect(assists:assister("S", 4)).toBeNil()
	end)
end)
```

`tests/shared/Rules/ScoreKeeper.spec.luau` (requires `Config`, `Fixtures`, `ScoreKeeper`, `Types`):

```lua
local function keeper(overrides: { [string]: any }?): ScoreKeeper.ScoreKeeper
	local scores = ScoreKeeper.new(Fixtures.config(overrides))
	scores:addPlayer("B1", "Blue")
	scores:addPlayer("B2", "Blue")
	scores:addPlayer("O1", "Orange")
	return scores
end

local function mvpAfter(events: { Types.Event }): string?
	local scores = keeper()
	for _, event in events do
		scores:apply(event)
	end
	return scores:mvp("Blue")
end

describe("ScoreKeeper", function()
	it("starts with zero scores and empty stats in join order", function()
		local scores = keeper()
		expect(scores:teamScores()).toEqual({ Blue = 0, Orange = 0 })
		expect(scores:player("O1")).toEqual({
			player = "O1", team = "Orange", joinOrder = 3, present = true,
			score = 0, goals = 0, assists = 0, saves = 0, steals = 0,
		})
		expect(scores:player("Nobody")).toBeNil()
	end)

	it("scores goals, assists and streak points", function()
		local scores = keeper()
		scores:apply({ name = "GoalScored", team = "Blue", scorer = "B1", assister = "B2" })
		expect(scores:teamScores()).toEqual({ Blue = 1, Orange = 0 })
		expect(scores:player("B1")).toMatchObject({ score = 100, goals = 1 })
		expect(scores:player("B2")).toMatchObject({ score = 0, assists = 0 })
		scores:apply({ name = "AssistAwarded", player = "B2" })
		expect(scores:player("B2")).toMatchObject({ score = 50, assists = 1 })
		scores:apply({ name = "StreakPointScored", team = "Blue", holder = "B2" })
		expect(scores:teamScores()).toEqual({ Blue = 2, Orange = 0 })
		expect(scores:player("B2")).toMatchObject({ score = 150, goals = 0 })
	end)

	it("scores saves, steals, laps and knockdowns", function()
		local scores = keeper()
		scores:apply({ name = "SaveMade", player = "O1", kind = "Block" })
		scores:apply({ name = "Steal", player = "O1", fromTeam = "Blue" })
		scores:apply({ name = "TackleKnockdown", attacker = "O1", victim = "B1" })
		scores:apply({ name = "LapCompleted", team = "Blue", streak = 1, holder = "B1" })
		expect(scores:player("O1")).toMatchObject({ score = 80, saves = 1, steals = 1 })
		expect(scores:player("B1")).toMatchObject({ score = 10 })
		expect(scores:teamScores()).toEqual({ Blue = 0, Orange = 0 })
	end)

	it("uses the configured point values", function()
		local scores = keeper({ Match = { pointValue = { goal = 2 } }, Scoring = { points = { goal = 7 } } })
		scores:apply({ name = "GoalScored", team = "Orange", scorer = "O1" })
		expect(scores:teamScores()).toEqual({ Blue = 0, Orange = 2 })
		expect(scores:player("O1")).toMatchObject({ score = 7 })
	end)

	it("ignores events that carry no points", function()
		local scores = keeper()
		scores:apply({ name = "GoalOpened", team = "Blue" })
		scores:apply({ name = "KickoffStarted", countdownSeconds = 3 })
		expect(scores:stats()).toEqual(keeper():stats())
	end)

	it("keeps a departed player's stats and restores them when the player returns", function()
		local scores = keeper()
		scores:apply({ name = "GoalScored", team = "Blue", scorer = "B1" })
		scores:removePlayer("B1")
		expect(scores:player("B1")).toMatchObject({ present = false, score = 100 })
		scores:addPlayer("B1", "Orange")
		expect(scores:player("B1")).toMatchObject({ present = true, team = "Orange", score = 100, joinOrder = 1 })
	end)

	it("rejects adding a player twice and removing an unknown player", function()
		local scores = keeper()
		expect(function()
			scores:addPlayer("B1", "Blue")
		end).toThrow('ScoreKeeper: player "B1" is already in the match')
		expect(function()
			scores:removePlayer("X")
		end).toThrow('ScoreKeeper: unknown player "X"')
	end)

	it("lists stats grouped by team, then by score, as a copy", function()
		local scores = ScoreKeeper.new(Config.defaults())
		scores:addPlayer("O1", "Orange")
		scores:addPlayer("B1", "Blue")
		scores:addPlayer("B2", "Blue")
		scores:apply({ name = "GoalScored", team = "Blue", scorer = "B2" })
		local stats = scores:stats()
		expect(stats.scores).toEqual({ Blue = 1, Orange = 0 })
		local order = {}
		for _, entry in stats.players do
			table.insert(order, entry.player)
		end
		expect(order).toEqual({ "B2", "B1", "O1" })
		stats.players[1].score = 999
		expect(scores:player("B2")).toMatchObject({ score = 100 })
	end)
end)

describe("ScoreKeeper:mvp", function()
	it("picks the top scorer of the team", function()
		expect(mvpAfter({
			{ name = "GoalScored", team = "Blue", scorer = "B1" },
			{ name = "SaveMade", player = "B2", kind = "Block" },
		})).toBe("B1")
	end)

	it("breaks score ties by goals, then saves, then assists, then join order", function()
		local streakB1: Types.Event = { name = "StreakPointScored", team = "Blue", holder = "B1" }
		local saveB1: Types.Event = { name = "SaveMade", player = "B1", kind = "Block" }
		local saveB2: Types.Event = { name = "SaveMade", player = "B2", kind = "Block" }
		local assistB2: Types.Event = { name = "AssistAwarded", player = "B2" }
		expect(mvpAfter({ { name = "GoalScored", team = "Blue", scorer = "B2" }, saveB1, saveB1 })).toBe("B2")
		expect(mvpAfter({ saveB2, saveB2, streakB1 })).toBe("B2")
		expect(mvpAfter({ assistB2, assistB2, streakB1 })).toBe("B2")
		expect(mvpAfter({ saveB1, saveB2 })).toBe("B1")
	end)

	it("ignores departed players and returns nil when nobody on the team is present", function()
		local scores = keeper()
		scores:apply({ name = "GoalScored", team = "Blue", scorer = "B1" })
		scores:apply({ name = "SaveMade", player = "B2", kind = "Block" })
		scores:removePlayer("B1")
		expect(scores:mvp("Blue")).toBe("B2")
		scores:removePlayer("B2")
		expect(scores:mvp("Blue")).toBeNil()
	end)
end)
```

- [ ] **Step 2: Run to verify failure** — `testPathPattern = "AssistTracker|ScoreKeeper"` → modules missing.
- [ ] **Step 3: Implement** both modules as in Interfaces; `apply` reads point values once from the config captured in `new`.
- [ ] **Step 4: Run to verify pass** — `passed = 15`. Full suite → `passed = 101`.
- [ ] **Step 5: Commit**

```bash
git add src/shared/Rules tests/shared/Rules
git commit -m "feat(rules): track assists and keep team scores, player stats and MVP"
```
PR title: `feat(rules): assist tracker and score keeper`.

---

### Task 7: `MatchClock` (spec §5.1)

**Issue:** #24 · **Branch:** `feat/24-match-clock` · **Labels:** `feature`, `rules`

**Files:**
- Create: `src/shared/Rules/MatchClock.luau`
- Test: `tests/shared/Rules/MatchClock.spec.luau`

**Interfaces:**
- Consumes: nothing.
- Produces:
  ```lua
  MatchClock.new(durationSeconds: number, warnings: { number }): MatchClock -- copies and sorts warnings (the list may be frozen)
  clock.secondsLeft: number      -- regulation time left, never below 0
  clock.overtimeSeconds: number  -- time played in overtime
  clock.inOvertime: boolean
  clock:advance(dt: number, onWarning: (secondsLeft: number) -> ()): boolean
  -- Regulation: counts down, calls onWarning for every threshold w with before > w >= after (highest first),
  -- returns true only on the call that reaches 0. Overtime: counts up, returns false. At 0 outside overtime: no-op, false.
  clock:startOvertime()
  ```

- [ ] **Step 1: Write the failing tests**

```lua
local function collector(): ({ number }, (secondsLeft: number) -> ())
	local warnings: { number } = {}
	return warnings, function(secondsLeft: number)
		table.insert(warnings, secondsLeft)
	end
end

describe("MatchClock", function()
	it("counts down from the duration", function()
		local clock = MatchClock.new(300, { 60, 30 })
		local _, onWarning = collector()
		expect(clock.secondsLeft).toBe(300)
		expect(clock:advance(10, onWarning)).toBe(false)
		expect(clock.secondsLeft).toBe(290)
	end)

	it("reports each warning once, when the clock reaches it", function()
		local clock = MatchClock.new(300, { 60, 30 })
		local warnings, onWarning = collector()
		clock:advance(239, onWarning)
		expect(warnings).toEqual({})
		clock:advance(1, onWarning)
		expect(warnings).toEqual({ 60 })
		clock:advance(0.5, onWarning)
		clock:advance(29.5, onWarning)
		expect(warnings).toEqual({ 60, 30 })
	end)

	it("reports several warnings crossed in one step, highest first, from a frozen list in any order", function()
		local clock = MatchClock.new(300, table.freeze({ 30, 60 }))
		local warnings, onWarning = collector()
		clock:advance(280, onWarning)
		expect(warnings).toEqual({ 60, 30 })
	end)

	it("never reports a warning at or above the duration", function()
		local clock = MatchClock.new(60, { 60, 30 })
		local warnings, onWarning = collector()
		clock:advance(60, onWarning)
		expect(warnings).toEqual({ 30 })
	end)

	it("returns true once when time runs out and stops at zero", function()
		local clock = MatchClock.new(300, {})
		local _, onWarning = collector()
		expect(clock:advance(299, onWarning)).toBe(false)
		expect(clock:advance(5, onWarning)).toBe(true)
		expect(clock.secondsLeft).toBe(0)
		expect(clock:advance(1, onWarning)).toBe(false)
		expect(clock.secondsLeft).toBe(0)
	end)

	it("counts up in overtime without warnings", function()
		local clock = MatchClock.new(300, { 60, 30 })
		local warnings, onWarning = collector()
		clock:advance(300, onWarning)
		clock:startOvertime()
		expect(clock.inOvertime).toBe(true)
		expect(clock:advance(12.5, onWarning)).toBe(false)
		expect(clock.overtimeSeconds).toBe(12.5)
		expect(warnings).toEqual({ 60, 30 })
	end)
end)
```

- [ ] **Step 2: Run to verify failure** — `testPathPattern = "MatchClock"` → module missing.
- [ ] **Step 3: Implement** with a sorted copy of the warnings and an index of the next unreported one (no allocation per call).
- [ ] **Step 4: Run to verify pass** — `passed = 6`. Full suite → `passed = 107`.
- [ ] **Step 5: Commit**

```bash
git add src/shared/Rules/MatchClock.luau tests/shared/Rules/MatchClock.spec.luau
git commit -m "feat(rules): add match clock with warnings and overtime"
```
PR title: `feat(rules): match clock`.

---

### Task 8: `MatchOutcome` and `LastChance` (spec §5.2–§5.3)

**Issue:** #25 · **Branch:** `feat/25-outcome-last-chance` · **Labels:** `feature`, `rules`

**Files:**
- Create: `src/shared/Rules/MatchOutcome.luau`, `src/shared/Rules/LastChance.luau`
- Test: `tests/shared/Rules/MatchOutcome.spec.luau`, `tests/shared/Rules/LastChance.spec.luau`

**Interfaces:**
- Consumes: `Team`, `Types.Period`.
- Produces:
  ```lua
  export type TimeUp = "Overtime" | "LastChance" | "Win"
  MatchOutcome.afterPoint(period: Period, scores: { [Team]: number }, scoringTeam: Team, pointsToWin: number): Team?
  -- Overtime: the scoring team wins. Otherwise the scoring team wins if it reached pointsToWin. Else nil.
  MatchOutcome.atTimeUp(scores: { [Team]: number }, possessingTeam: Team?, lastChance: { enabled: boolean, maxDeficit: number }): (TimeUp, Team?)
  -- Tied: ("Overtime", nil). Trailing by <= maxDeficit, Last Chance enabled, trailing team possessing:
  -- ("LastChance", trailing). Otherwise ("Win", leader).

  LastChance.endsOnPickup(trailing: Team, pickupTeam: Team): boolean -- a leading-team pickup ends the match
  LastChance.afterPoint(scores: { [Team]: number }, trailing: Team): "Overtime" | "Continue" -- tied: Overtime
  ```

- [ ] **Step 1: Write the failing tests**

`tests/shared/Rules/MatchOutcome.spec.luau`:

```lua
local LAST_CHANCE = { enabled = true, maxDeficit = 1 }

local function timeUp(
	scores: { [Team.Team]: number },
	possessingTeam: Team.Team?,
	lastChance: { enabled: boolean, maxDeficit: number }
): { any }
	return { MatchOutcome.atTimeUp(scores, possessingTeam, lastChance) }
end

describe("MatchOutcome.afterPoint", function()
	it("declares a winner only when a team reaches pointsToWin", function()
		expect(MatchOutcome.afterPoint("Regulation", { Blue = 5, Orange = 3 }, "Blue", 5)).toBe("Blue")
		expect(MatchOutcome.afterPoint("Regulation", { Blue = 4, Orange = 3 }, "Blue", 5)).toBeNil()
		expect(MatchOutcome.afterPoint("LastChance", { Blue = 3, Orange = 3 }, "Blue", 5)).toBeNil()
	end)

	it("ends overtime on the next point", function()
		expect(MatchOutcome.afterPoint("Overtime", { Blue = 2, Orange = 3 }, "Orange", 5)).toBe("Orange")
	end)
end)

describe("MatchOutcome.atTimeUp", function()
	it("goes to overtime when the scores are tied", function()
		expect(timeUp({ Blue = 2, Orange = 2 }, "Blue", LAST_CHANCE)).toEqual({ "Overtime" })
	end)

	it("gives Last Chance to a team one point behind that has the ball", function()
		expect(timeUp({ Blue = 2, Orange = 3 }, "Blue", LAST_CHANCE)).toEqual({ "LastChance", "Blue" })
	end)

	it("lets the leader win when the trailing team does not have the ball", function()
		expect(timeUp({ Blue = 2, Orange = 3 }, "Orange", LAST_CHANCE)).toEqual({ "Win", "Orange" })
		expect(timeUp({ Blue = 2, Orange = 3 }, nil, LAST_CHANCE)).toEqual({ "Win", "Orange" })
	end)

	it("lets the leader win when the deficit exceeds maxDeficit or Last Chance is disabled", function()
		expect(timeUp({ Blue = 1, Orange = 3 }, "Blue", LAST_CHANCE)).toEqual({ "Win", "Orange" })
		expect(timeUp({ Blue = 1, Orange = 3 }, "Blue", { enabled = true, maxDeficit = 2 }))
			.toEqual({ "LastChance", "Blue" })
		expect(timeUp({ Blue = 2, Orange = 3 }, "Blue", { enabled = false, maxDeficit = 1 }))
			.toEqual({ "Win", "Orange" })
	end)
end)
```

`tests/shared/Rules/LastChance.spec.luau`:

```lua
describe("LastChance", function()
	it("ends the match when a leading-team player picks up the ball", function()
		expect(LastChance.endsOnPickup("Blue", "Orange")).toBe(true)
		expect(LastChance.endsOnPickup("Blue", "Blue")).toBe(false)
	end)

	it("goes to overtime when the trailing team ties, and continues while it is still behind", function()
		expect(LastChance.afterPoint({ Blue = 3, Orange = 3 }, "Blue")).toBe("Overtime")
		expect(LastChance.afterPoint({ Blue = 2, Orange = 3 }, "Blue")).toBe("Continue")
	end)
end)
```

- [ ] **Step 2: Run to verify failure** — `testPathPattern = "MatchOutcome|LastChance"` → modules missing.
- [ ] **Step 3: Implement** both modules as in Interfaces (`Team.opponent` gives the other side).
- [ ] **Step 4: Run to verify pass** — `passed = 8`. Full suite → `passed = 115`.
- [ ] **Step 5: Commit**

```bash
git add src/shared/Rules tests/shared/Rules
git commit -m "feat(rules): decide match outcomes, overtime and Last Chance"
```
PR title: `feat(rules): match outcome and Last Chance`.

---

### Task 9: `MatchEngine` — match flow and play (spec §4.4–§4.7, §6)

**Issue:** #26 · **Branch:** `feat/26-match-engine` · **Labels:** `feature`, `rules`

**Files:**
- Create: `src/shared/Rules/MatchEngine.luau`
- Test: `tests/shared/Rules/MatchEngine.spec.luau`

**Interfaces:**
- Consumes: every module from Tasks 1–8 (signatures in their Interfaces blocks).
- Produces:
  ```lua
  export type ArenaLayout = { gates: { Crossing.Rectangle }, goal: Crossing.Disc }
  export type EngineOptions = { config: Config.GameConfig, arena: ArenaLayout, gravity: Vector3 }
  export type Snapshot = {
  	state: Types.MatchState, period: Types.Period,
  	secondsLeft: number, overtimeSeconds: number,
  	scores: { [Team]: number },
  	possessingTeam: Team?, lastHolder: PlayerId?,
  	streak: number, lapProgress: number,
  	goalOpenFor: Team?,
  }
  MatchEngine.new(options: EngineOptions): MatchEngine -- state "Waiting", period "Regulation"
  engine:addPlayer(player: PlayerId, team: Team)       -- ScoreKeeper:addPlayer
  engine:removePlayer(player: PlayerId)                -- ScoreKeeper:removePlayer
  engine:start()                                       -- error "MatchEngine: start() called in state <state>" unless Waiting
  engine:tick(dt: number)                              -- error "MatchEngine: dt must be a non-negative number" (also for NaN)
  engine:ballMoved(from: Vector3, to: Vector3)         -- one tick of ball motion; the caller never reports a teleport as a segment
  engine:pickedUp(player: PlayerId, ballPosition: Vector3, ballVelocity: Vector3)
  engine:touched(player: PlayerId, ballPosition: Vector3, ballVelocity: Vector3) -- any non-pickup contact
  engine:thrown(player: PlayerId)
  engine:knockedDown(attacker: PlayerId, victim: PlayerId)
  engine:drainEvents(): { Types.Event }               -- pending events in order; the same frozen empty table when none
  engine:snapshot(): Snapshot
  engine:stats(): Types.MatchStats                    -- ScoreKeeper:stats()
  ```

**Behavior** (the order of emitted events is part of the contract; every `emit` also calls `ScoreKeeper:apply`):

- Every player-taking input first resolves the player: never added → `error('MatchEngine: unknown player "<id>"', 0)`; departed → ignored. Then any input other than `addPlayer`/`removePlayer`/`start`/`tick` is ignored unless `state == "Live"`. `tick` is ignored in `Waiting` and `Ended`; it adds `dt` to the engine time `now` used for assists.
- `start`: `MatchStarted`, then a **kickoff reset**: possession, laps and assists reset; goal closed (`GoalClosed` only if it was open); thrown flag cleared; `state = "Kickoff"` for `Match.kickoffCountdownSeconds`; `KickoffStarted { countdownSeconds }`.
- `tick` in `Kickoff` / `Celebration`: subtract `dt` from the phase timer; at `<= 0`, Kickoff → `KickoffEnded`, `state = "Live"`; Celebration → kickoff reset.
- `ballMoved` (Live): (1) if `goal:scored(from, to)` → **goal** and stop. (2) With a possessing team, for each gate of `laps:crossedGates` in order: `progress = laps:accept(gate)`; if accepted emit `GateCrossed`; when `progress == laps.gateCount` emit `LapCompleted { team, streak, holder = lastHolder }`, then `GoalOpened { team }` if `goal:lapCompleted` returns true, then if `streak >= Match.lapsForStreakPoint` emit `StreakPointScored { team, holder }` → **point** and stop.
- **Goal:** `GoalScored { team = possessingTeam, scorer = lastHolder, assister = assists:assister(scorer, now) }`, then `AssistAwarded { player }` when there is an assister → **point**.
- **Point:** close the goal (`GoalClosed` if open); `MatchOutcome.afterPoint(period, scores, team, Match.pointsToWin)` → winner → **end match**; otherwise `state = "Celebration"` for `Match.celebrationSeconds`. (Task 10 adds the Last Chance branch.)
- `pickedUp` (Live): (1) if the goal is open and the player's team is not `goal.openFor`: `SaveMade { player, kind = saves:classify("Pickup", thrown, ballPosition, ballVelocity) }`. (2) Clear the thrown flag. (3) `previous = possession.team`; if `possession:pickUp` changed the team: reset laps and assists, emit `PossessionChanged { team, player, previousTeam = previous }`, then `Steal { player, fromTeam = previous }` if `previous ~= nil`, then close the goal. (4) `assists:pickedUp(player, now)`.
- `touched` (Live): if the goal is open, the player's team is not `goal.openFor`, and the ball was thrown: `kind = saves:classify("Touch", true, …)`; if `"Block"`, emit `SaveMade` and clear the thrown flag (one save per throw).
- `thrown` (Live): set the thrown flag.
- `knockedDown` (Live): if the teams differ, `TackleKnockdown { attacker, victim }`.
- **End match:** `state = "Ended"`, `MatchEnded { winner, mvp = scores:mvp(winner), stats = scores:stats() }`.

- [ ] **Step 1: Write the failing tests**

`tests/shared/Rules/MatchEngine.spec.luau`:

```lua
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local MatchEngine = require(ReplicatedStorage.Shared.Rules.MatchEngine)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

local ZERO = Vector3.zero
local ON_TARGET_POSITION, ON_TARGET_VELOCITY = Vector3.new(190, 15, 0), Vector3.new(100, 0, 0)
local SHORT_STREAK = { Match = { lapsToOpenGoal = 1, lapsForStreakPoint = 2 } }

local function newEngine(overrides: { [string]: any }?): MatchEngine.MatchEngine
	local engine = MatchEngine.new({
		config = Fixtures.config(overrides),
		arena = Fixtures.arena(),
		gravity = Fixtures.GRAVITY,
	})
	engine:addPlayer("B1", "Blue")
	engine:addPlayer("B2", "Blue")
	engine:addPlayer("O1", "Orange")
	engine:addPlayer("O2", "Orange")
	return engine
end

local function liveEngine(overrides: { [string]: any }?): MatchEngine.MatchEngine
	local engine = newEngine(overrides)
	engine:start()
	engine:tick(3)
	engine:drainEvents()
	return engine
end

local function names(events: { Types.Event }): { string }
	local result = {}
	for _, event in events do
		table.insert(result, event.name)
	end
	return result
end

local function crossGates(engine: MatchEngine.MatchEngine, gates: { number })
	for _, index in gates do
		engine:ballMoved(Fixtures.throughGate(index))
	end
end

local function lap(engine: MatchEngine.MatchEngine)
	crossGates(engine, { 1, 2, 3, 4 })
end

describe("MatchEngine flow", function()
	it("starts with a kickoff countdown and goes live when it ends", function()
		local engine = newEngine()
		engine:start()
		expect(engine:drainEvents()).toEqual({
			{ name = "MatchStarted" },
			{ name = "KickoffStarted", countdownSeconds = 3 },
		})
		engine:tick(2.5)
		expect(engine:drainEvents()).toEqual({})
		engine:tick(0.5)
		expect(engine:drainEvents()).toEqual({ { name = "KickoffEnded" } })
		expect(engine:snapshot().state).toBe("Live")
	end)

	it("ignores ball facts before the kickoff ends", function()
		local engine = newEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		engine:start()
		engine:drainEvents()
		engine:pickedUp("B1", ZERO, ZERO)
		engine:ballMoved(Fixtures.throughGate(1))
		expect(engine:drainEvents()).toEqual({})
		expect(engine:snapshot().possessingTeam).toBeNil()
	end)

	it("rejects a second start and a negative or NaN tick", function()
		local engine = newEngine()
		engine:start()
		expect(function()
			engine:start()
		end).toThrow("MatchEngine: start() called in state Kickoff")
		expect(function()
			engine:tick(-1)
		end).toThrow("MatchEngine: dt must be a non-negative number")
		expect(function()
			engine:tick(0 / 0)
		end).toThrow("MatchEngine: dt must be a non-negative number")
	end)

	it("returns the same frozen empty list when nothing happened", function()
		local engine = liveEngine()
		engine:tick(1)
		local first = engine:drainEvents()
		expect(first).toBe(engine:drainEvents())
		expect(table.isfrozen(first)).toBe(true)
	end)
end)

describe("MatchEngine possession and laps", function()
	it("gives possession on the first pickup and makes an opponent pickup a steal that resets the streak", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		expect(engine:drainEvents()).toEqual({ { name = "PossessionChanged", team = "Blue", player = "B1" } })
		crossGates(engine, { 1, 2 })
		engine:drainEvents()
		engine:pickedUp("O1", ZERO, ZERO)
		expect(engine:drainEvents()).toEqual({
			{ name = "PossessionChanged", team = "Orange", player = "O1", previousTeam = "Blue" },
			{ name = "Steal", player = "O1", fromTeam = "Blue" },
		})
		local snapshot = engine:snapshot()
		expect(snapshot.streak).toBe(0)
		expect(snapshot.lapProgress).toBe(0)
	end)

	it("keeps possession through a pass", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		engine:drainEvents()
		engine:thrown("B1")
		engine:pickedUp("B2", ZERO, ZERO)
		expect(engine:drainEvents()).toEqual({})
		local snapshot = engine:snapshot()
		expect(snapshot.possessingTeam).toBe("Blue")
		expect(snapshot.lastHolder).toBe("B2")
	end)

	it("counts gates only for a possessing team, forward and in order", function()
		local engine = liveEngine()
		engine:ballMoved(Fixtures.throughGate(1))
		expect(engine:drainEvents()).toEqual({})
		engine:pickedUp("B1", ZERO, ZERO)
		engine:drainEvents()
		crossGates(engine, { 2, 4, 3 })
		local from, to = Fixtures.throughGate(4)
		engine:ballMoved(to, from)
		expect(engine:drainEvents()).toEqual({
			{ name = "GateCrossed", team = "Blue", gateIndex = 2, progress = 1 },
			{ name = "GateCrossed", team = "Blue", gateIndex = 3, progress = 2 },
		})
	end)

	it("completes a lap after four gates in order, crediting the last holder", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		engine:thrown("B1")
		engine:pickedUp("B2", ZERO, ZERO)
		engine:drainEvents()
		lap(engine)
		local events = engine:drainEvents()
		expect(names(events)).toEqual({ "GateCrossed", "GateCrossed", "GateCrossed", "GateCrossed", "LapCompleted" })
		expect(events[5]).toEqual({ name = "LapCompleted", team = "Blue", streak = 1, holder = "B2" })
		expect(engine:stats().players[1]).toMatchObject({ player = "B2", score = 10 })
	end)
end)

describe("MatchEngine goals and points", function()
	it("opens the goal after lapsToOpenGoal laps and scores a goal through it with an assist", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		engine:thrown("B1")
		engine:pickedUp("B2", ZERO, ZERO)
		for _ = 1, 3 do
			lap(engine)
		end
		engine:drainEvents()
		lap(engine)
		local events = engine:drainEvents()
		expect(events[#events]).toEqual({ name = "GoalOpened", team = "Blue" })
		engine:ballMoved(Fixtures.throughRing())
		expect(engine:drainEvents()).toEqual({
			{ name = "GoalScored", team = "Blue", scorer = "B2", assister = "B1" },
			{ name = "AssistAwarded", player = "B1" },
			{ name = "GoalClosed" },
		})
		local snapshot = engine:snapshot()
		expect(snapshot.scores).toEqual({ Blue = 1, Orange = 0 })
		expect(snapshot.state).toBe("Celebration")
	end)

	it("credits the attacking team when a defender deflects the ball in", function()
		local engine = liveEngine(SHORT_STREAK)
		engine:pickedUp("B1", ZERO, ZERO)
		lap(engine)
		engine:touched("O1", ZERO, ZERO)
		engine:drainEvents()
		engine:ballMoved(Fixtures.throughRing())
		expect(engine:drainEvents()[1]).toEqual({ name = "GoalScored", team = "Blue", scorer = "B1" })
	end)

	it("never scores a ball passing back-to-front through the ring", function()
		local engine = liveEngine(SHORT_STREAK)
		engine:pickedUp("B1", ZERO, ZERO)
		lap(engine)
		engine:drainEvents()
		local from, to = Fixtures.throughRing()
		engine:ballMoved(to, from)
		expect(engine:drainEvents()).toEqual({})
	end)

	it("judges the ring before the gates a segment crosses, so the lap that opens the goal cannot score", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		for _ = 1, 3 do
			crossGates(engine, { 3, 4, 1, 2 })
		end
		crossGates(engine, { 3, 4, 1 })
		engine:drainEvents()
		engine:ballMoved(Fixtures.throughRing())
		expect(engine:drainEvents()).toEqual({
			{ name = "GateCrossed", team = "Blue", gateIndex = 2, progress = 4 },
			{ name = "LapCompleted", team = "Blue", streak = 4, holder = "B1" },
			{ name = "GoalOpened", team = "Blue" },
		})
		crossGates(engine, { 3, 4, 1 })
		engine:drainEvents()
		engine:ballMoved(Fixtures.throughRing())
		expect(names(engine:drainEvents())).toEqual({ "GoalScored", "GoalClosed" })
	end)

	it("scores a streak point at lapsForStreakPoint and closes the goal", function()
		local engine = liveEngine(SHORT_STREAK)
		engine:pickedUp("B1", ZERO, ZERO)
		lap(engine)
		engine:drainEvents()
		lap(engine)
		local events = engine:drainEvents()
		expect(names(events)).toEqual({
			"GateCrossed", "GateCrossed", "GateCrossed", "GateCrossed",
			"LapCompleted", "StreakPointScored", "GoalClosed",
		})
		expect(events[6]).toEqual({ name = "StreakPointScored", team = "Blue", holder = "B1" })
		expect(engine:snapshot().scores).toEqual({ Blue = 1, Orange = 0 })
		expect(engine:stats().players[1]).toMatchObject({ player = "B1", score = 120 })
	end)

	it("resets for a kickoff after the celebration and ignores play during it", function()
		local engine = liveEngine(SHORT_STREAK)
		engine:pickedUp("B1", ZERO, ZERO)
		lap(engine)
		lap(engine)
		engine:drainEvents()
		engine:pickedUp("O1", ZERO, ZERO)
		engine:tick(2.5)
		expect(engine:drainEvents()).toEqual({})
		engine:tick(0.5)
		expect(engine:drainEvents()).toEqual({ { name = "KickoffStarted", countdownSeconds = 3 } })
		local snapshot = engine:snapshot()
		expect(snapshot.state).toBe("Kickoff")
		expect(snapshot.possessingTeam).toBeNil()
		expect(snapshot.lastHolder).toBeNil()
		expect(snapshot.streak).toBe(0)
		expect(snapshot.goalOpenFor).toBeNil()
	end)

	it("ends the match as soon as a team reaches pointsToWin", function()
		local engine = liveEngine({ Match = { pointsToWin = 1, lapsToOpenGoal = 1, lapsForStreakPoint = 2 } })
		engine:pickedUp("B1", ZERO, ZERO)
		engine:thrown("B1")
		engine:pickedUp("B2", ZERO, ZERO)
		lap(engine)
		engine:drainEvents()
		engine:ballMoved(Fixtures.throughRing())
		local events = engine:drainEvents()
		expect(names(events)).toEqual({ "GoalScored", "AssistAwarded", "GoalClosed", "MatchEnded" })
		local ended: any = events[4]
		expect(ended.winner).toBe("Blue")
		expect(ended.mvp).toBe("B2")
		expect(ended.stats.scores).toEqual({ Blue = 1, Orange = 0 })
		expect(engine:snapshot().state).toBe("Ended")
		engine:tick(10)
		engine:pickedUp("O1", ZERO, ZERO)
		expect(engine:drainEvents()).toEqual({})
	end)
end)

describe("MatchEngine saves and knockdowns", function()
	it("makes a defender's touch on a thrown ball headed into the open goal one block save", function()
		local engine = liveEngine(SHORT_STREAK)
		engine:pickedUp("B1", ZERO, ZERO)
		lap(engine)
		engine:thrown("B1")
		engine:drainEvents()
		engine:touched("B2", ON_TARGET_POSITION, ON_TARGET_VELOCITY)
		engine:touched("O1", ON_TARGET_POSITION, ON_TARGET_VELOCITY)
		engine:touched("O2", ON_TARGET_POSITION, ON_TARGET_VELOCITY)
		expect(engine:drainEvents()).toEqual({ { name = "SaveMade", player = "O1", kind = "Block" } })
	end)

	it("makes a defender's pickup at an open goal a steal save, counted once when it is also a block", function()
		local engine = liveEngine(SHORT_STREAK)
		engine:pickedUp("B1", ZERO, ZERO)
		lap(engine)
		engine:drainEvents()
		engine:pickedUp("O1", ZERO, ZERO)
		expect(engine:drainEvents()).toEqual({
			{ name = "SaveMade", player = "O1", kind = "Steal" },
			{ name = "PossessionChanged", team = "Orange", player = "O1", previousTeam = "Blue" },
			{ name = "Steal", player = "O1", fromTeam = "Blue" },
			{ name = "GoalClosed" },
		})
		lap(engine)
		engine:thrown("O1")
		engine:drainEvents()
		engine:pickedUp("B1", ON_TARGET_POSITION, ON_TARGET_VELOCITY)
		local events = engine:drainEvents()
		expect(names(events)).toEqual({ "SaveMade", "PossessionChanged", "Steal", "GoalClosed" })
		expect(events[1]).toEqual({ name = "SaveMade", player = "B1", kind = "Block" })
	end)

	it("scores knockdowns between opponents and ignores teammates", function()
		local engine = liveEngine()
		engine:knockedDown("O1", "B1")
		engine:knockedDown("B1", "B2")
		expect(engine:drainEvents()).toEqual({ { name = "TackleKnockdown", attacker = "O1", victim = "B1" } })
	end)
end)

describe("MatchEngine players", function()
	it("rejects unknown players and ignores departed ones, keeping their stats", function()
		local engine = liveEngine()
		expect(function()
			engine:pickedUp("Ghost", ZERO, ZERO)
		end).toThrow('MatchEngine: unknown player "Ghost"')
		engine:knockedDown("O1", "B1")
		engine:removePlayer("O1")
		engine:pickedUp("O1", ZERO, ZERO)
		engine:knockedDown("O1", "B2")
		expect(engine:drainEvents()).toEqual({ { name = "TackleKnockdown", attacker = "O1", victim = "B1" } })
		expect(engine:snapshot().possessingTeam).toBeNil()
		local departed: Types.PlayerStats? = nil
		for _, entry in engine:stats().players do
			if entry.player == "O1" then
				departed = entry
			end
		end
		expect(departed).toMatchObject({ present = false, score = 10 })
	end)
end)
```

- [ ] **Step 2: Run to verify failure** — `testPathPattern = "MatchEngine"` → `MatchEngine` is not a valid member of `Rules`.
- [ ] **Step 3: Implement** `MatchEngine` per the Behavior list. Construct the `MatchClock` in `new` so `snapshot()` reports `secondsLeft = Match.durationSeconds`; Task 10 starts advancing it.
- [ ] **Step 4: Run to verify pass** — `passed = 19`. Full suite → `passed = 134`.
- [ ] **Step 5: Commit**

```bash
git add src/shared/Rules/MatchEngine.luau tests/shared/Rules/MatchEngine.spec.luau
git commit -m "feat(rules): compose the rules into a deterministic match engine"
```
PR title: `feat(rules): match engine`.

---

### Task 10: `MatchEngine` — clock, overtime, Last Chance, performance (spec §5, §12.2)

**Issue:** #27 · **Branch:** `feat/27-engine-endgame` · **Labels:** `feature`, `rules`

**Files:**
- Modify: `src/shared/Rules/MatchEngine.luau`
- Modify: `tests/shared/Rules/MatchEngine.spec.luau` (new `describe` blocks and two helpers)

**Interfaces:**
- Consumes: Task 9's engine; `MatchClock` (Task 7); `MatchOutcome`, `LastChance` (Task 8); `Config.UI.clockWarnings`, `Match.durationSeconds`, `Match.clockPausesDuringKickoff`, `Match.lastChance`.
- Produces: no new API; the behavior below.

**Behavior** (added to Task 9's list):

- `tick`: the clock runs in `Live`, and also in `Kickoff` and `Celebration` when `Match.clockPausesDuringKickoff` is false. Within one tick the clock runs **before** the phase timer; if it ends the match, the phase timer is skipped. Each warning emits `ClockWarning { secondsLeft }`.
- **Time up** (`clock:advance` returned true): `MatchOutcome.atTimeUp(scores, possession.team, Match.lastChance)` → `"Overtime"`: `period = "Overtime"`, `clock:startOvertime()`, `OvertimeStarted`; `"LastChance"`: `period = "LastChance"`, remember the trailing team, `LastChanceStarted { team }`; `"Win"`: end match. Play continues without a kickoff.
- **Point** during `LastChance` with no winner: `LastChance.afterPoint(scores, trailing)` → `"Overtime"`: `period = "Overtime"`, `clock:startOvertime()`, `OvertimeStarted` (before the celebration starts); `"Continue"`: stays in Last Chance. Either way the celebration and kickoff follow.
- **Pickup** during `LastChance`: after the possession events, `LastChance.endsOnPickup(trailing, team)` → end match with `team` as winner.

- [ ] **Step 1: Write the failing tests**

Add below `lap` in `tests/shared/Rules/MatchEngine.spec.luau`:

```lua
-- Needs lapsToOpenGoal = 1: picks up, laps once, throws through the ring.
local function scoreGoal(engine: MatchEngine.MatchEngine, player: string)
	engine:pickedUp(player, ZERO, ZERO)
	lap(engine)
	engine:ballMoved(Fixtures.throughRing())
end

local function resumePlay(engine: MatchEngine.MatchEngine)
	engine:tick(3) -- celebration
	engine:tick(3) -- kickoff countdown
end

-- Orange leads 1-0, Blue has the ball, and the clock has just hit 0:00.
local function lastChanceEngine(overrides: { [string]: any }?): MatchEngine.MatchEngine
	local engine = liveEngine(overrides or SHORT_STREAK)
	scoreGoal(engine, "O1")
	resumePlay(engine)
	engine:pickedUp("B1", ZERO, ZERO)
	engine:tick(300)
	engine:drainEvents()
	return engine
end
```

Append:

```lua
describe("MatchEngine clock", function()
	it("runs the clock only during live play by default", function()
		local engine = newEngine(SHORT_STREAK)
		engine:start()
		engine:tick(3)
		expect(engine:snapshot().secondsLeft).toBe(300)
		engine:tick(10)
		scoreGoal(engine, "B1")
		resumePlay(engine)
		expect(engine:snapshot().secondsLeft).toBe(290)
	end)

	it("also runs the clock during kickoffs when clockPausesDuringKickoff is false", function()
		local engine = newEngine({ Match = { clockPausesDuringKickoff = false } })
		engine:start()
		engine:tick(2)
		expect(engine:snapshot().secondsLeft).toBe(298)
	end)

	it("emits a ClockWarning at each configured threshold", function()
		local engine = liveEngine()
		engine:tick(240)
		expect(engine:drainEvents()).toEqual({ { name = "ClockWarning", secondsLeft = 60 } })
		engine:tick(30)
		expect(engine:drainEvents()).toEqual({ { name = "ClockWarning", secondsLeft = 30 } })
	end)
end)

describe("MatchEngine end of regulation", function()
	it("goes to golden-goal overtime on a tie without a kickoff, and the next point wins", function()
		local engine = liveEngine(SHORT_STREAK)
		engine:tick(300)
		expect(names(engine:drainEvents())).toEqual({ "ClockWarning", "ClockWarning", "OvertimeStarted" })
		local snapshot = engine:snapshot()
		expect(snapshot.state).toBe("Live")
		expect(snapshot.period).toBe("Overtime")
		engine:tick(5)
		expect(engine:snapshot().overtimeSeconds).toBe(5)
		scoreGoal(engine, "O1")
		local events = engine:drainEvents()
		local ended: any = events[#events]
		expect(ended.name).toBe("MatchEnded")
		expect(ended.winner).toBe("Orange")
	end)

	it("lets the leader win at 0:00 when the trailing team does not have the ball", function()
		local engine = liveEngine(SHORT_STREAK)
		scoreGoal(engine, "O1")
		resumePlay(engine)
		engine:drainEvents()
		engine:tick(300)
		local events = engine:drainEvents()
		local ended: any = events[#events]
		expect(ended.name).toBe("MatchEnded")
		expect(ended.winner).toBe("Orange")
	end)

	it("gives the trailing team with the ball a Last Chance; tying sends the match to overtime after a kickoff", function()
		local engine = liveEngine(SHORT_STREAK)
		scoreGoal(engine, "O1")
		resumePlay(engine)
		engine:pickedUp("B1", ZERO, ZERO)
		engine:drainEvents()
		engine:tick(300)
		expect(engine:drainEvents()[3]).toEqual({ name = "LastChanceStarted", team = "Blue" })
		expect(engine:snapshot().period).toBe("LastChance")
		lap(engine)
		engine:drainEvents()
		engine:ballMoved(Fixtures.throughRing())
		expect(names(engine:drainEvents())).toEqual({ "GoalScored", "GoalClosed", "OvertimeStarted" })
		resumePlay(engine)
		expect(names(engine:drainEvents())).toEqual({ "KickoffStarted", "KickoffEnded" })
		local snapshot = engine:snapshot()
		expect(snapshot.state).toBe("Live")
		expect(snapshot.period).toBe("Overtime")
	end)

	it("ends Last Chance with a win for the leader when a leading-team player picks up the ball", function()
		local engine = lastChanceEngine()
		engine:pickedUp("O1", ZERO, ZERO)
		local events = engine:drainEvents()
		expect(names(events)).toEqual({ "PossessionChanged", "Steal", "MatchEnded" })
		local ended: any = events[3]
		expect(ended.winner).toBe("Orange")
	end)

	it("keeps Last Chance going while the trailing team keeps the ball, even when it is loose", function()
		local engine = lastChanceEngine()
		engine:thrown("B1")
		engine:touched("O1", ZERO, ZERO)
		engine:pickedUp("B2", ZERO, ZERO)
		engine:tick(5)
		expect(engine:drainEvents()).toEqual({})
		local snapshot = engine:snapshot()
		expect(snapshot.state).toBe("Live")
		expect(snapshot.period).toBe("LastChance")
		expect(snapshot.secondsLeft).toBe(0)
	end)

	it("with maxDeficit 2, keeps Last Chance after a point that leaves the team behind", function()
		local engine = liveEngine({ Match = { lapsToOpenGoal = 1, lapsForStreakPoint = 2, lastChance = { maxDeficit = 2 } } })
		scoreGoal(engine, "O1")
		resumePlay(engine)
		scoreGoal(engine, "O1")
		resumePlay(engine)
		engine:pickedUp("B1", ZERO, ZERO)
		engine:tick(300)
		scoreGoal(engine, "B1")
		resumePlay(engine)
		expect(table.find(names(engine:drainEvents()), "OvertimeStarted")).toBeNil()
		expect(engine:snapshot().period).toBe("LastChance")
		engine:pickedUp("O1", ZERO, ZERO)
		local events = engine:drainEvents()
		local ended: any = events[#events]
		expect(ended.name).toBe("MatchEnded")
		expect(ended.winner).toBe("Orange")
	end)

	it("resolves 0:00 during a kickoff when the clock keeps running", function()
		local engine = liveEngine({ Match = { lapsToOpenGoal = 1, lapsForStreakPoint = 2, clockPausesDuringKickoff = false } })
		engine:tick(293) -- liveEngine's kickoff already used 3 s: 4 s left
		scoreGoal(engine, "O1")
		engine:tick(3) -- celebration ends with 1 s left
		engine:drainEvents()
		engine:tick(1)
		local events = engine:drainEvents()
		expect(names(events)).toEqual({ "MatchEnded" })
		local ended: any = events[1]
		expect(ended.winner).toBe("Orange")
	end)
end)

describe("MatchEngine performance", function()
	it("keeps a live tick with ball movement far below the 1 ms server budget", function()
		local engine = liveEngine()
		engine:pickedUp("B1", ZERO, ZERO)
		engine:drainEvents()
		-- Crosses Gate 1's plane outside its rectangle, so every geometry check runs and nothing counts.
		local from, to = Vector3.new(99, 0, 50), Vector3.new(101, 0, 50)
		local iterations = 10000
		local started = os.clock()
		for _ = 1, iterations do
			engine:tick(1 / 60)
			engine:ballMoved(from, to)
		end
		local averageMilliseconds = (os.clock() - started) / iterations * 1000
		expect(averageMilliseconds).toBeLessThan(0.05)
		expect(engine:drainEvents()).toEqual({})
	end)
end)
```

- [ ] **Step 2: Run to verify failure** — `testPathPattern = "MatchEngine"` → the 10 new clock and end-of-regulation tests fail (the clock never advances); the 19 Task 9 tests pass. The performance test already passes on Task 9's code, so prove it can fail: temporarily change its threshold to `0`, see it fail, restore `0.05`.
- [ ] **Step 3: Implement** the Behavior list in `MatchEngine.luau`. The `onWarning` callback passed to `clock:advance` is a closure created once in `new`, never per tick.
- [ ] **Step 4: Run to verify pass, then the full suite** — `testPathPattern = "MatchEngine"` → `passed = 30`. Full suite → `passed = 145`, `total = 145`.
- [ ] **Step 5: Playtest boot check** — MCP `start_stop_play` (true), wait 3 s, `get_console_output`, `start_stop_play` (false). Expected exactly `[BloxChampions] Server ready: mode=NormalChampions, modules=0` and `[BloxChampions] Client ready: mode=NormalChampions, modules=0` (the config now includes `UI`; nothing else is wired yet) and no warnings or errors.
- [ ] **Step 6: Commit**

```bash
git add src/shared/Rules/MatchEngine.luau tests/shared/Rules/MatchEngine.spec.luau
git commit -m "feat(rules): add clock, overtime and Last Chance to the match engine"
```
PR title: `feat(rules): clock, overtime and Last Chance in the engine`.

Phase 2 is complete when PRs for #18–#27 are merged, the full suite passes on `main` (145 tests), and CI is green on `main`.
