# M1 Phase 4 — Ball and Match Wiring Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Put a real ball in the generated arena and run whole matches on the server. Players are seated on balanced teams and stood on their spawns. The ball spawns, is picked up, carried, thrown and recovered, and every server frame is fed to the Phase 2 `MatchEngine`. The engine's events open the goal, reset kickoffs, end and restart matches, and reach clients through remotes.

**Architecture:**
- **Pure modules** (`Ball/BallState`, `Ball/Pickup`, `Arena/Geometry/Bounds`, `Rules/Roster`, `Skins/BallSkins`, config areas) hold every rule and are unit-tested.
- **Thin server services** (`NetService`, `BallService`, `TeamService`, `CharacterService`, `MatchService`) adapt them to parts, players and remotes. They are wired by `Loader`, with every global side effect kept in `start`.
- **One frame:** `MatchService:step(dt)` runs a server frame in the engine's documented order. Tests call `step` by hand in the Edit DataModel, with test rigs and stub players standing in for real ones.

**Tech Stack:** Luau (`--!strict`), Jest-Lua 3.10.0 in Studio through the Roblox Studio MCP, Rojo 7.7.1, StyLua 2.6.0, selene 0.32.0, luau-lsp 1.70.1 (`bash scripts/analyze.sh`).

**Spec:** `docs/superpowers/specs/2026-10-21-m1-foundation-core-match-design.md` — §4.5 (kickoff reset), §5.4 (after the match), §9.3 (ball), §9.4 (ball skin registry), §10.1–10.2 (teams, remotes), §12.2 (integration tests, 1 ms budget), §13 (errors, leaving players), §14 (phase 4). Constraints from earlier phases: the header of `src/shared/Rules/MatchEngine.luau` (frame order) and spec §7.1 (seam normals, Phase 5).

## Verified facts this plan relies on (probed in Studio, 2026-10-22)

- **Edit mode:** `RunService.Heartbeat` fires in the Edit DataModel (about 60 per second), but physics does not simulate. Tests therefore move parts by `CFrame`/`PivotTo` and call `step(dt)` themselves.
- **Welds and velocity:**
  - Setting a part's `CFrame` moves parts welded to it with a `WeldConstraint`; setting only its `Position` does not.
  - `AssemblyLinearVelocity` can be set and read back in Edit, and survives parenting to `ServerStorage`.
- **Ball shape:** a `Part` with `Shape = Ball` keeps a non-uniform `Size` if given one, so the ball's size is set to `Vector3.one * 2 * radius`.
- **Physical properties:** `PhysicalProperties.new(density, friction, elasticity)` (weights default to 1). Density is clamped to [0.0001, 100], friction to [0, 2] and elasticity to [0, 1] (Roblox docs).
- **Network ownership:** `SetNetworkOwner(nil)` works in Edit. It **errors on anchored parts and on parts welded to anchored parts**, so the ball is unwelded and unanchored before it is called.
- **Streaming:** `Model.ModelStreamingMode` is script-writable. `Persistent` models are sent whole soon after a player joins and are never streamed out. The `Workspace` streaming radii are not scriptable. This place has `StreamingEnabled = true`.
- **Places and players:** `Players.RespawnTime` is 3 in this place, and `Players.CharacterAutoLoads` is currently `true`. For an R15 rig the root's height above the floor is `0.5 * RootPart.Size.Y + HipHeight`; for R6 it is `LeftLeg.Size.Y + 0.5 * RootPart.Size.Y + HipHeight` (Roblox docs).
- **Remotes:** every `Types.Event` and `MatchStats` table has only string keys and arrays, so it is safe to send through a `RemoteEvent`.
- **Roblox events are deferred in this place.** A `Destroying` handler ran only after the test yielded (`task.wait()`), not during `Destroy()`. Tests that wait on a Roblox event yield once before asserting. The repo's own `Signal` stays synchronous.
- **Jest-Lua:** `jest.fn()` returns two values, which is why the codebase uses plain-table fakes. `jest.spyOn(object, "name")` returns one mock (`.mockImplementation`, `.mockRestore`; used once in Phase 3).

## Owner decisions (2026-10-22)

1. **The ball is hidden during the kickoff countdown.** When the countdown ends it appears at a uniformly random `BallSpawn` and drops. While hidden it is parented to `ServerStorage`, so its next spawn is never replicated early.
2. **The ball may fly over the infield.** It is out of bounds only when it is low over the infield (landing on it), past the outer wall, or below the floor.

## Global Constraints

- **Earlier constraints still apply.** Everything in the Phase 1–3 Global Constraints holds: `--!strict` first line; StyLua, selene and `bash scripts/analyze.sh` clean; relative requires in `src/`; service-path requires in tests; `JestGlobals` only; no `jest.fn()`; annotate locals strict mode can't infer.
- **Pure modules** (`src/shared/Rules`, `src/shared/Ball`, `src/shared/Arena/Geometry`, `src/shared/Skins`, `src/shared/Config`) never touch an Instance, a service or `workspace`.
- **No gameplay literals.** Every gameplay number comes from `Config.Ball`, `Config.Network`, `Config.Match` or `Config.Arena`.
- **Players are `PlayerId` strings:** `tostring(player.UserId)`. Every remote payload uses these ids.
- **Server services are `Loader` modules** with explicit `dependencies`.
  - `init(deps)` may connect to other services' signals but must not touch global Roblox state.
  - Global effects go in `start()`: `Players` events, `Players.CharacterAutoLoads`, Heartbeat.
  - Tests therefore call `init` with real or fake dependencies, then drive `step`.
  - A service that creates parts has `destroy()`, so tests leave nothing behind.
- **Frame order** (header of `MatchEngine.luau`, owner-confirmed in Phase 2): `ballMoved` (only real movement), then `thrown`, then `pickedUp` (with the ball's velocity from before the catch), then `tick(dt)`, then `drainEvents`.
- **Ball and engine invariant:** the ball can be picked up only while the engine is `Live`, and it is carried only by the engine's last holder (`MatchEngine:thrown` errors otherwise).
- **Tests:**
  - Rigs come from `Fixtures.rig`.
  - Fakes are plain tables that record calls.
  - Every part a test creates lives under a uniquely named `…Test` folder (or a service's `destroy`) and is removed in `afterEach`/`afterAll`.
- **Process:** branches, commits and PRs follow `CONTRIBUTING.md`. Every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, and every PR body with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## How tests run

The same as Phase 3: `rojo serve test.project.json` stays running and connected, and tests run through the Roblox Studio MCP `execute_luau` (`datamodel_type = "Edit"`):

```lua
task.wait(1)
local s = require(game:GetService("ServerStorage").RunTests:Clone())({ testPathPattern = "<pattern>" })
return { success = s.success, passed = s.numPassedTests, total = s.numTotalTests, firstFailure = s.failureMessages[1] }
```

The suite has **222 tests** before this phase. Each task states its new tests and the new total. A different total is a finding: find out which number is right, then rule on it and record the ruling.

## Review Focus

1. **A teleport reported as movement.** If a jump of the ball (its kickoff spawn, an out-of-bounds or idle respawn, or the snap into a catcher's hand) were reported as a `ballMoved` segment, it could cross a gate or the ring and award a lap or a goal nobody earned. Tests: Task 5 `spawns the ball loose at a ball spawn and reports only real movement`, `respawns a ball that leaves the arena or lies untouched, without reporting the jump`, and `gives the ball to the nearest player in reach…` (no movement on the frame after the catch).
2. **The carrier disagreeing with the engine.** A pickup the engine ignores (during a kickoff, a celebration or after the match) would leave the ball in someone's hand whom the engine doesn't treat as the last holder, and the next throw would error. Test: Task 7 `keeps the ball dead whenever play is not live`.
3. **A returning player switching teams.** The engine rejects a returner on a different team, so a returner whose old team is full must spectate even when the other team has room. Tests: Task 3 `keeps a returning player off the other team, even when only the other team has room`, and `promotes the longest-waiting spectator who may take a freed seat`.
4. **The carrier leaving or dying.** The ball must drop loose where they were, and their team keeps possession (spec §4.1, §13). Tests: Task 5 `drops the ball loose where its carrier is`, and Task 7 `drops the ball where a leaving carrier was, and the team keeps possession`.
5. **A save judged on the wrong velocity.** A save is judged on the ball's velocity before the catch; after welding it would be the catcher's velocity. Test: Task 5 `gives the ball to the nearest player in reach with its velocity from before the catch`.

## Decisions not spelled out in the spec (for owner review)

1. **Players and teams.**
   - Player ids are `tostring(player.UserId)`, so a returning player keeps their id.
   - Clients learn teams from a `Team` **Player attribute** (it replicates on its own). Spectators have none.
   - Seating is pure `Rules/Roster` logic: the smaller team first, with ties broken at random through an injected tie-breaker.
2. **Spectators get no character** (their camera follows the ball, spec §8.4, in Phase 7). `CharacterService` sets `Players.CharacterAutoLoads = false` and loads characters for seated players only.
3. **Kickoff placement in this phase:**
   - At every `KickoffStarted`, each seated player's character is pivoted to its slot's team spawn, root at standing height, and its root is **anchored** until `KickoffEnded`. That anchoring is the spec's "movement frozen".
   - The slot is the player's position in their team's seat order.
   - Phase 5's skating controller replaces the anchoring with its own freeze.
4. **Respawn:** a character that dies (for example through Reset) respawns after a new `Match.respawnSeconds = 3` and is placed on its team spawn. Reset stays enabled; a carrier's death drops the ball.
5. **Carrying the ball:**
   - The ball is welded to `RightHand` (R15), else `Right Arm` (R6), else `HumanoidRootPart`, centred `radius` below that part.
   - While carried it is `Massless` and non-colliding.
   - The snap into the hand is a teleport, not movement.
6. **Ball states:**
   - `Flying` turns `Loose` on the ball's first touch with a part that isn't part of a character.
   - After a goal or streak point the ball goes `Dead`: it keeps flying under physics, but nobody can pick it up.
   - At `KickoffStarted` it is hidden.
7. **Bounds:** the ball is out of bounds when its centre is:
   - more than `Ball.outOfBoundsMargin = 2` past the outer wall face (a capsule around the arena's long axis),
   - more than that margin below the floor,
   - or over the infield (inside the inner wall face) and lower than the infield top plus the margin.
8. **Ball physics and look:**
   - The physics values come from `Config.Ball`: the spec's `radius 1.5`, `elasticity 0.5`, `friction 0.3`, plus `density 0.7` (Roblox's Plastic).
   - The look comes from `Skins/BallSkins.Default`: `Color3.fromRGB(255, 196, 0)` in `SmoothPlastic`, picked to stand out against the gray track.
9. **New config check:** the ball's radius must be smaller than `Arena.goal.ringRadius`, or no goal can ever be scored.
10. **The goal opening:**
    - On `GoalOpened` the panel turns non-colliding and non-queryable, with `Transparency = 1`.
    - On `GoalClosed` it returns to `CanCollide = true`, `CanQuery = true` and `Arena.goal.panelTransparency`.
    - The panel's slide animation and the ring's team-color glow arrive with the other event-driven visuals (Phase 8).
11. **Remotes** (`Net/Remotes`, the only place they are named):
    - `RuleEvents`: one batch per frame that has events.
    - `MatchSnapshot`: `engine:snapshot()`, sent to each player who joins and to everyone when a new match starts.
    - `BallCarrier`: `{ carrier = PlayerId? }`. The spec says `Player?`; ids keep every remote on the same id scheme as `RuleEvents`.
    - `ActionRequest` arrives with `ActionService` in Phase 6.
12. **Arena streaming:** the arena model is `ModelStreamingMode.Persistent`, so every client always has all of it. This resolves Phase 3's streaming concern for Phase 5's raycasts and Phase 8's markers.
13. **Picking up:**
    - Reach is `Ball.pickupRadius + Network.pickupLagToleranceStuds`, measured from the ball's centre to each candidate's root.
    - The nearest candidate wins. Ties go to the earlier candidate, in seat order.
14. **Match lifecycle:**
    - A match starts on the first frame with at least `Match.minPlayersToStart` seated players.
    - After `MatchEnded`, `MatchService` counts `Match.postMatchSeconds` of frames, then starts a fresh engine for the next match, reseats everyone (balanced, old teams forgotten) and sends a snapshot to everyone.

**Not in this phase:**
- Throws, passes and tackles started by player input, and magnetic-pass homing (Phase 6). `BallService:throw` exists now for Phase 6 and for tests.
- Knocked-down players being unable to catch (spec §9.3). Phase 6 adds that filter to `CharacterService:holders()`, along with knockdowns.
- Skating, the collider and `MovementGuard` (Phase 5).
- The spectator camera (Phase 7).
- The HUD and every visual reaction to events (Phase 8).

---

### Task 1: Ball and network config, ball skin, arena bounds, persistent arena

**Issue:** #56 · **Branch:** `feat/56-ball-config-bounds` · **Labels:** `feature`, `ball`

**Files:**
- Create: `src/shared/Config/Ball.luau`, `src/shared/Config/Network.luau`, `src/shared/Skins/BallSkins.luau`, `src/shared/Arena/Geometry/Bounds.luau`
- Modify: `src/shared/Config/init.luau` (areas `Ball` and `Network`, plus the ball-fits-the-ring check), `src/shared/Config/Match.luau` (`respawnSeconds`), `src/server/Arena/Builder.luau` (`ModelStreamingMode`)
- Test: `tests/shared/Config/Config.spec.luau`, `tests/shared/Skins/BallSkins.spec.luau`, `tests/shared/Arena/Geometry/Bounds.spec.luau`, `tests/server/Arena/Builder.spec.luau`

**Interfaces:**
- Consumes: `Validate`, `PartSize` (Phase 3), `Config.ArenaConfig`.
- Produces:
  ```lua
  export type BallConfig = {
  	radius: number, density: number, friction: number, elasticity: number,
  	pickupRadius: number, rethrowPickupDelay: number, ballIdleResetSeconds: number, outOfBoundsMargin: number,
  }
  export type NetworkConfig = { pickupLagToleranceStuds: number }
  -- MatchConfig gains respawnSeconds: number; GameConfig gains Ball and Network; Config exports both types.
  BallSkins.DEFAULT: string                                -- "Default"
  BallSkins.get(id: string): { color: Color3, material: Enum.Material }   -- frozen; unknown id errors
  Bounds.isOut(arena: Config.ArenaConfig, position: Vector3, margin: number): boolean
  ```
- **Field rules:**
  - `radius`: above 0, at most `PartSize.MAX / 2`.
  - `density`: 0.0001 to 100. `friction`: 0 to 2. `elasticity`: 0 to 1. These are the clamp ranges, so a value is never silently changed.
  - `pickupRadius` and `ballIdleResetSeconds`: above 0.
  - `rethrowPickupDelay`, `outOfBoundsMargin`, `Network.pickupLagToleranceStuds` and `Match.respawnSeconds`: at least 0.
- **Cross-area check,** appended after the Phase 3 spawn check in `Config.schema`: `"Ball: radius must be smaller than the goal ring's opening (Arena.goal.ringRadius)"` when `Ball.radius >= Arena.goal.ringRadius`.
- **`Bounds.isOut` rule** (S = `straightLength`, R = `endRadius`, W = `trackWidth`). `d` is the horizontal distance from `position` to the arena's long axis, the segment from (−S/2, 0) to (S/2, 0) in X/Z. The ball is out when any of these holds:
  - `position.Y < -margin`
  - `d > R + W/2 + margin`
  - `d < R − W/2` and `position.Y < infieldWallHeight + margin`

- [ ] **Step 1: Write the failing tests**

Append to `describe("Config defaults", …)` and add `respawnSeconds = 3` to the existing match-rules expectations:

```lua
	it("match the spec's ball and network values", function()
		local d = Config.defaults()
		expect(d.Ball).toEqual({
			radius = 1.5,
			density = 0.7,
			friction = 0.3,
			elasticity = 0.5,
			pickupRadius = 5,
			rethrowPickupDelay = 0.4,
			ballIdleResetSeconds = 15,
			outOfBoundsMargin = 2,
		})
		expect(d.Network).toEqual({ pickupLagToleranceStuds = 2 })
		expect(d.Match.respawnSeconds).toBe(3)
	end)
```

Append to `describe("Config.forMode", …)`:

```lua
	it("rejects ball physics Roblox would clamp, and a ball too big for the goal", function()
		local cases: { { overrides: { [string]: any }, message: string } } = {
			{ overrides = { Ball = { elasticity = 1.5 } }, message = "Ball.elasticity: must be <= 1 (got 1.5)" },
			{ overrides = { Ball = { friction = -0.1 } }, message = "Ball.friction: must be >= 0 (got -0.1)" },
			{ overrides = { Ball = { density = 0 } }, message = "Ball.density: must be >= 0.0001 (got 0)" },
			{
				overrides = { Network = { pickupLagToleranceStuds = -1 } },
				message = "Network.pickupLagToleranceStuds: must be >= 0 (got -1)",
			},
			{
				overrides = { Ball = { radius = 7 } },
				message = "Ball: radius must be smaller than the goal ring's opening (Arena.goal.ringRadius)",
			},
		}
		for _, case in cases do
			expect(function()
				Fixtures.config(case.overrides)
			end).toThrow(case.message)
		end
	end)
```

`tests/shared/Skins/BallSkins.spec.luau`:

```lua
describe("BallSkins", function()
	it("holds a frozen Default skin with a color and a material", function()
		local skin = BallSkins.get(BallSkins.DEFAULT)
		expect(typeof(skin.color)).toBe("Color3")
		expect(typeof(skin.material)).toBe("EnumItem")
		expect(table.isfrozen(skin)).toBe(true)
	end)

	it("rejects an unknown skin", function()
		expect(function()
			BallSkins.get("Ghost")
		end).toThrow('BallSkins: unknown skin "Ghost"')
	end)
end)
```

`tests/shared/Arena/Geometry/Bounds.spec.luau`:

```lua
local arena = Config.defaults().Arena
local MARGIN = 2

describe("Bounds.isOut", function()
	it("keeps the ball in on the track, high over the infield, and up to the margin past the outer wall", function()
		local inside = {
			Vector3.new(0, 5, -60),
			Vector3.new(-140, 5, 0),
			Vector3.new(0, 40, 0),
			Vector3.new(0, 5, -83.5),
			Vector3.new(-163.5, 5, 0),
		}
		for _, position in inside do
			expect(Bounds.isOut(arena, position, MARGIN)).toBe(false)
		end
	end)

	it("puts the ball out past the outer wall and below the floor", function()
		for _, position in { Vector3.new(0, 5, -85), Vector3.new(-165, 5, 0), Vector3.new(30, -3, -60) } do
			expect(Bounds.isOut(arena, position, MARGIN)).toBe(true)
		end
	end)

	it("puts the ball out once it comes down onto the infield, but not while it flies over", function()
		expect(Bounds.isOut(arena, Vector3.new(0, 21.5, 0), MARGIN)).toBe(true)
		expect(Bounds.isOut(arena, Vector3.new(-100, 21.5, 10), MARGIN)).toBe(true)
		expect(Bounds.isOut(arena, Vector3.new(0, 22.5, 0), MARGIN)).toBe(false)
	end)
end)
```

Append to `describe("Builder.build", …)`:

```lua
	it("sends the whole arena to every client and never streams it out", function()
		local arena = Builder.build(Geometry.build(config), config, parent)
		expect(arena.ModelStreamingMode).toBe(Enum.ModelStreamingMode.Persistent)
	end)
```

- [ ] **Step 2: Run to verify failure.** Pattern `"(Config.spec|BallSkins|Bounds|Builder)"`. The new tests fail: `Ball` and `Network` are unknown keys, the modules are missing, and `ModelStreamingMode` is `Default`.
- [ ] **Step 3: Implement** the Interfaces block. `Config/Ball.luau` and `Config/Network.luau` mirror `Config/Match.luau` (defaults, record schema). `BallSkins` is a frozen registry built with `Freeze.deep`. In `Builder.build`, set `model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent` before parenting.
- [ ] **Step 4: Run to verify pass.** The full suite has **231** (+9).
- [ ] **Step 5: Commit:** `feat(ball): add ball and network config, the default ball skin and arena bounds`. PR title: `feat(ball): ball config, skin and bounds`.

---

### Task 2: Ball state and pickup choice

**Issue:** #57 · **Branch:** `feat/57-ball-state` · **Labels:** `feature`, `ball`

**Files:**
- Create: `src/shared/Ball/BallState.luau`, `src/shared/Ball/Pickup.luau`
- Test: `tests/shared/Ball/BallState.spec.luau`, `tests/shared/Ball/Pickup.spec.luau`

**Interfaces:**
- Consumes: `Types.PlayerId`.
- Produces (class idiom of `Rules/`):
  ```lua
  export type Status = "Dead" | "Loose" | "Flying" | "Carried"
  BallState.new(rethrowPickupDelay: number): BallState    -- starts Dead
  -- read-only fields: status: Status, carrier: PlayerId?, looseSeconds: number
  BallState.release(self)            -- Dead → Loose
  BallState.pickUp(self, player)     -- Loose | Flying → Carried
  BallState.throw(self)              -- Carried → Flying; the thrower is locked out of a catch for rethrowPickupDelay
  BallState.drop(self)               -- Carried → Loose
  BallState.land(self)               -- Flying → Loose
  BallState.respawn(self)            -- Loose | Flying → Loose
  BallState.kill(self)               -- any → Dead; clears the carrier
  BallState.tick(self, dt)           -- advances looseSeconds (while Loose or Flying) and the thrower's lockout
  BallState.canPickUp(self, player): boolean   -- Loose or Flying, and not the locked-out thrower
  -- release, throw, drop and respawn restart looseSeconds at 0.
  -- Any other transition errors: `BallState: cannot <method> while <Status>` (error level 0).

  export type Candidate = { player: PlayerId, position: Vector3 }
  Pickup.choose(ball: Vector3, candidates: { Candidate }, reach: number, allowed: (PlayerId) -> boolean): PlayerId?
  -- The nearest allowed candidate whose distance <= reach; an equal distance goes to the earlier candidate.
  ```

- [ ] **Step 1: Write the failing tests**

`tests/shared/Ball/BallState.spec.luau`:

```lua
describe("BallState", function()
	it("starts dead and goes loose when released", function()
		local ball = BallState.new(0.4)
		expect(ball.status).toBe("Dead")
		expect(ball:canPickUp("A")).toBe(false)
		ball:release()
		expect(ball.status).toBe("Loose")
		expect(ball:canPickUp("A")).toBe(true)
	end)

	it("follows a catch, a throw, a landing and a drop", function()
		local ball = BallState.new(0.4)
		ball:release()
		ball:pickUp("A")
		expect(ball.status).toBe("Carried")
		expect(ball.carrier).toBe("A")
		ball:throw()
		expect(ball.status).toBe("Flying")
		expect(ball.carrier).toBeNil()
		ball:land()
		expect(ball.status).toBe("Loose")
		ball:pickUp("B")
		ball:drop()
		expect(ball.status).toBe("Loose")
		expect(ball.carrier).toBeNil()
	end)

	it("keeps the thrower from catching their own throw for rethrowPickupDelay", function()
		local ball = BallState.new(0.4)
		ball:release()
		ball:pickUp("A")
		ball:throw()
		expect(ball:canPickUp("A")).toBe(false)
		expect(ball:canPickUp("B")).toBe(true)
		ball:tick(0.39)
		expect(ball:canPickUp("A")).toBe(false)
		ball:tick(0.02)
		expect(ball:canPickUp("A")).toBe(true)
	end)

	it("counts how long nobody has held the ball, from its release or a respawn", function()
		local ball = BallState.new(0.4)
		ball:release()
		ball:tick(2)
		expect(ball.looseSeconds).toBe(2)
		ball:respawn()
		expect(ball.looseSeconds).toBe(0)
		ball:pickUp("A")
		ball:tick(5)
		expect(ball.looseSeconds).toBe(0)
	end)

	it("goes dead from any state and refuses every catch while dead", function()
		local ball = BallState.new(0.4)
		ball:release()
		ball:pickUp("A")
		ball:kill()
		expect(ball.status).toBe("Dead")
		expect(ball.carrier).toBeNil()
		expect(ball:canPickUp("A")).toBe(false)
	end)

	it("rejects a transition its state does not allow", function()
		local ball = BallState.new(0.4)
		expect(function()
			ball:pickUp("A")
		end).toThrow("BallState: cannot pickUp while Dead")
		ball:release()
		expect(function()
			ball:throw()
		end).toThrow("BallState: cannot throw while Loose")
		expect(function()
			ball:release()
		end).toThrow("BallState: cannot release while Loose")
	end)
end)
```

`tests/shared/Ball/Pickup.spec.luau`:

```lua
local function always(_player: string): boolean
	return true
end

describe("Pickup.choose", function()
	it("picks the nearest candidate within reach, counting the edge of the reach as in", function()
		local candidates: { Pickup.Candidate } = {
			{ player = "Far", position = Vector3.new(6, 0, 0) },
			{ player = "Near", position = Vector3.new(0, 3, 0) },
			{ player = "Out", position = Vector3.new(0, 0, 7.1) },
		}
		expect(Pickup.choose(Vector3.zero, candidates, 7, always)).toBe("Near")
		expect(Pickup.choose(Vector3.zero, { { player = "Edge", position = Vector3.new(7, 0, 0) } }, 7, always)).toBe("Edge")
		expect(Pickup.choose(Vector3.zero, { candidates[3] }, 7, always)).toBeNil()
	end)

	it("skips candidates the ball refuses and breaks a tie by order", function()
		local candidates: { Pickup.Candidate } = {
			{ player = "A", position = Vector3.new(2, 0, 0) },
			{ player = "B", position = Vector3.new(-2, 0, 0) },
		}
		expect(Pickup.choose(Vector3.zero, candidates, 7, always)).toBe("A")
		expect(Pickup.choose(Vector3.zero, candidates, 7, function(player: string): boolean
			return player ~= "A"
		end)).toBe("B")
	end)
end)
```

- [ ] **Step 2: Run to verify failure.** Pattern `"(BallState|Pickup)"`: the modules are missing.
- [ ] **Step 3: Implement** both modules as specified. `choose` allocates nothing: it compares squared distances.
- [ ] **Step 4: Run to verify pass.** The full suite has **239** (+8).
- [ ] **Step 5: Commit:** `feat(ball): add the ball's state machine and the pickup choice`. PR title: `feat(ball): ball state and pickup`.

---

### Task 3: Team seating

**Issue:** #58 · **Branch:** `feat/58-roster` · **Labels:** `feature`, `rules`

**Files:**
- Create: `src/shared/Rules/Roster.luau`
- Test: `tests/shared/Rules/Roster.spec.luau`

**Interfaces:**
- Consumes: `Team.Team`, `Team.list`, `Team.opponent`, `Types.PlayerId`.
- Produces:
  ```lua
  export type Seat = { player: PlayerId, team: Team }
  Roster.new(teamSize: number, tieBreak: () -> Team): Roster
  Roster.join(self, player): Team?
  -- A returner (seated earlier this match) goes back to their old team if it has room, else spectates.
  -- A newcomer takes the team with fewer players (tieBreak() on a tie), or spectates when both are full.
  Roster.leave(self, player): { Seat }
  -- Frees the seat (a returner's team is remembered for this match). Returns the spectators seated into freed seats:
  -- the longest-waiting spectator allowed on that team (never a returner whose old team it isn't).
  Roster.teamOf(self, player): Team?
  Roster.members(self, team): { PlayerId }      -- in the order they took their seats; the index is the spawn slot
  Roster.spectators(self): { PlayerId }          -- in waiting order
  Roster.newMatch(self): { Seat }
  -- Forgets who played where and reseats everyone present (seated players in seat order, then spectators in waiting
  -- order) with the newcomer rule; returns the new seats in that order.
  -- Errors (level 0): `Roster: player "<id>" already joined`, `Roster: unknown player "<id>"`.
  ```

- [ ] **Step 1: Write the failing tests** (`tests/shared/Rules/Roster.spec.luau`; `blueFirst` always breaks ties toward Blue):

```lua
local function blueFirst(): Team.Team
	return "Blue"
end

describe("Roster", function()
	it("seats newcomers on the smaller team until both are full, then makes them spectate", function()
		local roster = Roster.new(3, blueFirst)
		for index = 1, 6 do
			roster:join("P" .. index)
		end
		expect(#roster:members("Blue")).toBe(3)
		expect(#roster:members("Orange")).toBe(3)
		expect(roster:join("P7")).toBeNil()
		expect(roster:teamOf("P7")).toBeNil()
		expect(roster:spectators()).toEqual({ "P7" })
	end)

	it("breaks a tie with the tie-breaker", function()
		local roster = Roster.new(3, function(): Team.Team
			return "Orange"
		end)
		expect(roster:join("A")).toBe("Orange")
		expect(roster:join("B")).toBe("Blue")
	end)

	it("lists each team's players in the order they took their seats", function()
		local roster = Roster.new(2, blueFirst)
		for _, id in { "A", "B", "C", "D" } do
			roster:join(id)
		end
		expect(roster:members("Blue")).toEqual({ "A", "C" })
		expect(roster:members("Orange")).toEqual({ "B", "D" })
	end)

	it("seats a returning player back on their old team", function()
		local roster = Roster.new(2, blueFirst)
		roster:join("A")
		roster:join("B")
		roster:leave("A")
		roster:join("C")
		expect(roster:join("A")).toBe("Blue")
		expect(roster:teamOf("C")).toBe("Blue")
	end)

	it("keeps a returning player off the other team, even when only the other team has room", function()
		local roster = Roster.new(2, blueFirst)
		for _, id in { "A", "B", "C", "D" } do
			roster:join(id)
		end
		roster:leave("A")
		roster:join("E")
		expect(roster:teamOf("E")).toBe("Blue")
		expect(roster:join("A")).toBeNil()
		expect(roster:leave("B")).toEqual({})
		expect(roster:join("F")).toBe("Orange")
	end)

	it("promotes the longest-waiting spectator who may take a freed seat", function()
		local roster = Roster.new(1, blueFirst)
		for _, id in { "A", "B", "C", "D" } do
			roster:join(id)
		end
		expect(roster:leave("A")).toEqual({ { player = "C", team = "Blue" } })
		expect(roster:teamOf("C")).toBe("Blue")
		expect(roster:spectators()).toEqual({ "D" })
	end)

	it("reseats everyone present for a new match and forgets who played where", function()
		local roster = Roster.new(1, blueFirst)
		roster:join("A")
		roster:join("B")
		roster:leave("A")
		expect(roster:newMatch()).toEqual({ { player = "B", team = "Blue" } })
		expect(roster:join("A")).toBe("Orange")
	end)

	it("rejects joining twice and leaving unseen", function()
		local roster = Roster.new(1, blueFirst)
		roster:join("A")
		expect(function()
			roster:join("A")
		end).toThrow('Roster: player "A" already joined')
		expect(function()
			roster:leave("Ghost")
		end).toThrow('Roster: unknown player "Ghost"')
	end)
end)
```

- [ ] **Step 2: Run to verify failure.** Pattern `"Roster"`: the module is missing.
- [ ] **Step 3: Implement** `Roster` as specified.
- [ ] **Step 4: Run to verify pass.** The full suite has **247** (+8).
- [ ] **Step 5: Commit:** `feat(rules): add team seating with balancing, returners and spectators`. PR title: `feat(rules): roster`.

---

### Task 4: Remotes

**Issue:** #59 · **Branch:** `feat/59-remotes` · **Labels:** `feature`, `infra`

**Files:**
- Create: `src/shared/Net/Remotes.luau`, `src/shared/Net/Attributes.luau`, `src/server/NetService.luau`
- Test: `tests/shared/Net/Remotes.spec.luau`, `tests/server/NetService.spec.luau`

**Interfaces:**
- Produces:
  ```lua
  Remotes.names = { RuleEvents = "RuleEvents", MatchSnapshot = "MatchSnapshot", BallCarrier = "BallCarrier" }  -- frozen
  Remotes.FOLDER = "Remotes"
  Remotes.create(parent: Instance): Folder
  -- One RemoteEvent per name in a new Folder "Remotes". Errors: `Remotes: already created under <parent:GetFullName()>`.
  Remotes.get(parent: Instance, name: string): RemoteEvent
  -- Waits for the folder and the event (WaitForChild). Errors: `Remotes: unknown remote "<name>"`.
  Attributes = { Team = "Team" }   -- frozen; replicated Player attribute names

  -- NetService (Loader module): name "NetService", no dependencies.
  NetService:init(deps)      -- Remotes.create(deps.Parent or ReplicatedStorage)
  NetService:fireAll(name: string, payload: any)
  NetService:fireTo(player: PlayerId, name: string, payload: any)
  -- fireTo finds the Player with Players:GetPlayerByUserId(tonumber(player)); a player who has left is skipped.
  -- An unknown name errors: `NetService: unknown remote "<name>"`.
  NetService:destroy()       -- removes the folder
  ```

- [ ] **Step 1: Write the failing tests**

`tests/shared/Net/Remotes.spec.luau` (each test uses a fresh `RemotesTest` folder in `ReplicatedStorage`, destroyed in `afterEach`):

```lua
describe("Remotes", function()
	it("creates one RemoteEvent per name in a Remotes folder", function()
		local folder = Remotes.create(parent)
		expect(folder.Name).toBe("Remotes")
		expect(#folder:GetChildren()).toBe(3)
		for _, name in Remotes.names do
			expect((folder:FindFirstChild(name) :: Instance).ClassName).toBe("RemoteEvent")
		end
	end)

	it("refuses to create the remotes twice", function()
		Remotes.create(parent)
		expect(function()
			Remotes.create(parent)
		end).toThrow(`Remotes: already created under {parent:GetFullName()}`)
	end)

	it("finds a remote by name and rejects an unknown one", function()
		Remotes.create(parent)
		expect(Remotes.get(parent, Remotes.names.BallCarrier).Name).toBe("BallCarrier")
		expect(function()
			Remotes.get(parent, "Ghost")
		end).toThrow('Remotes: unknown remote "Ghost"')
	end)
end)
```

`tests/server/NetService.spec.luau`:

```lua
describe("NetService", function()
	it("creates the remotes under its parent and removes them on destroy", function()
		NetService:init({ Parent = parent })
		expect(parent:FindFirstChild(Remotes.FOLDER)).never.toBeNil()
		NetService:destroy()
		expect(parent:FindFirstChild(Remotes.FOLDER)).toBeNil()
	end)

	it("rejects an unknown remote and skips a player who is not here", function()
		NetService:init({ Parent = parent })
		expect(function()
			NetService:fireAll("Ghost", {})
		end).toThrow('NetService: unknown remote "Ghost"')
		expect(function()
			NetService:fireTo("999999999", Remotes.names.MatchSnapshot, {})
		end).never.toThrow()
		NetService:destroy()
	end)
end)
```

- [ ] **Step 2: Run to verify failure.** Pattern `"(Remotes|NetService)"`: the modules are missing.
- [ ] **Step 3: Implement** as specified.
- [ ] **Step 4: Run to verify pass.** The full suite has **252** (+5).
- [ ] **Step 5: Commit:** `feat(net): define the remotes in one place and fire them by name`. PR title: `feat(net): remotes`.

---

### Task 5: BallService

**Issue:** #60 · **Branch:** `feat/60-ball-service` · **Labels:** `feature`, `ball`

**Files:**
- Create: `src/server/BallService.luau`
- Modify: `tests/Fixtures.luau` (`Fixtures.rig`)
- Test: `tests/server/BallService.spec.luau`

**Interfaces:**
- Consumes: `BallState`, `Pickup` (Task 2); `Bounds`, `BallSkins`, `Config.Ball`, `Config.Network` (Task 1); `ArenaService.arena.ballSpawns` (Phase 3).
- Produces:
  ```lua
  export type Holder = { player: PlayerId, root: BasePart, hand: BasePart }
  export type BallFrame = {
  	moved: boolean, from: Vector3, to: Vector3,   -- real movement since the last step; false right after a teleport
  	thrower: PlayerId?,                           -- a throw since the last step, reported once
  	picker: PlayerId?, pickupPosition: Vector3, pickupVelocity: Vector3,   -- this step's catch; position and velocity just before it
  	respawned: boolean,
  }
  -- BallService (Loader module): name "BallService", dependencies { "Config", "ArenaService" }; deps.Random optional
  BallService.part: BasePart        -- "Ball": Shape Ball, Size 2·radius, physics from Config.Ball, look from BallSkins.Default
  BallService.state: BallState
  BallService:init(deps)            -- creates the ball hidden (parented to ServerStorage), Dead
  BallService:hide()                -- Dead and parented to ServerStorage (the kickoff countdown)
  BallService:spawn()               -- teleports to a uniformly random ball spawn in workspace; Loose; server-owned
  BallService:kill()                -- Dead where it is (physics goes on); a carried ball is dropped first
  BallService:throw(player, velocity: Vector3)   -- the carrier only: unweld, Flying, velocity; reported by the next step
  BallService:drop()                -- the carrier lets go: Loose where it is, keeping its velocity
  BallService:onTouched(hit: BasePart)   -- Flying → Loose when hit is not part of a character (a model with a Humanoid)
  BallService:step(dt, holders: { Holder }): BallFrame   -- returns one reused record
  BallService:destroy()
  ```
- **`step` algorithm**, which the plan pins for Review Focus 1 and 5:
  1. If the ball is hidden, return a record with `moved = false` and nothing else set.
  2. Read the ball's position. Report `from`/`to` as movement unless a teleport happened since the last step. A teleport is `spawn`, a respawn, or the snap into a hand.
  3. Call `state:tick(dt)`. Report and clear a pending thrower.
  4. While the ball is Loose or Flying:
     - If `Bounds.isOut(arena, position, outOfBoundsMargin)` or `state.looseSeconds >= ballIdleResetSeconds`, respawn it at a random ball spawn (a teleport; `respawned = true`).
     - Otherwise run `Pickup.choose(position, holders' root positions, pickupRadius + pickupLagToleranceStuds, state:canPickUp)`. On a catch, record the position and `AssemblyLinearVelocity` before welding, weld the ball to the holder's hand (a teleport), and call `state:pickUp`.
- **Carried ball:** `CFrame = hand.CFrame * CFrame.new(0, -radius, 0)`, a `WeldConstraint`, `Massless = true` and `CanCollide = false`.
- **Releasing the ball** (`throw`, `drop`, `kill` while carried): destroy the weld, set `Massless = false` and `CanCollide = true`, then `SetNetworkOwner(nil)`. The ball must be unanchored and unwelded first (verified).
- **`throw` by anyone but the carrier** errors: `BallService: only the carrier can throw (carrier: <id or none>, thrower: <id>)`.
- **`Fixtures.rig(parent: Instance, name: string, cframe: CFrame, rigType: Enum.HumanoidRigType?): Model`** is a test character:
  - **R15 (default):** `HumanoidRootPart` (2, 2, 1), plus `RightHand` (1, 1, 1) at `root * CFrame.new(1.5, -0.5, -0.5)`. The `Humanoid` has `RigType = R15` and `HipHeight = 2`.
  - **R6:** `Right Arm` (1, 2, 1) at `root * CFrame.new(1.5, 0, 0)` and `Left Leg` (1, 2, 1) at `root * CFrame.new(-0.5, -2, 0)`, with `HipHeight = 0`.
  - Every limb is welded to the root with a `WeldConstraint`. Nothing is anchored, and `PrimaryPart = root`.

- [ ] **Step 1: Write the failing tests** (`tests/server/BallService.spec.luau`).

  **Setup:** a `BallServiceTest` folder in `workspace` per test. `BallService:init({ Config = config, ArenaService = { arena = { ballSpawns = SPAWNS } } })` with `SPAWNS = { CFrame.new(-140, 6, 0), CFrame.new(140, 6, 0) }`. `afterEach` calls `BallService:destroy()` and destroys the folder.

  **Helpers:** `holder(name, rig): BallService.Holder` returns `{ player = name, root = rig.HumanoidRootPart, hand = rig.RightHand }`, and `isSpawn(position)` is true within 1e-3 of either spawn. The tests:

```lua
	it("makes a ball of the configured size, physics and skin, hidden until it spawns", function()
		local ball = BallService.part
		expect(ball.Shape).toBe(Enum.PartType.Ball)
		expect(ball.Size).toEqual(Vector3.one * 3)
		local physics = ball.CustomPhysicalProperties :: PhysicalProperties
		expect(physics.Density).toBeCloseTo(0.7, 4)
		expect(physics.Friction).toBeCloseTo(0.3, 4)
		expect(physics.Elasticity).toBeCloseTo(0.5, 4)
		expect(ball.Color).toEqual(BallSkins.get(BallSkins.DEFAULT).color)
		expect(ball.Parent).toBe(ServerStorage)
		expect(BallService.state.status).toBe("Dead")
		expect(BallService:step(1 / 60, {}).moved).toBe(false)
	end)

	it("spawns the ball loose at a ball spawn and reports only real movement", function()
		BallService:spawn()
		local ball = BallService.part
		expect(ball.Parent).toBe(workspace)
		expect(isSpawn(ball.Position)).toBe(true)
		expect(BallService.state.status).toBe("Loose")
		expect(BallService:step(1 / 60, {}).moved).toBe(false)
		local start = ball.Position
		ball.CFrame = CFrame.new(start + Vector3.new(4, 0, 0))
		local frame = BallService:step(1 / 60, {})
		expect(frame.moved).toBe(true)
		near(frame.from, start)
		near(frame.to, start + Vector3.new(4, 0, 0))
	end)

	it("gives the ball to the nearest player in reach with its velocity from before the catch", function()
		BallService:spawn()
		local at = BallService.part.Position
		BallService.part.AssemblyLinearVelocity = Vector3.new(20, 0, 0)
		local closest = Fixtures.rig(folder, "Near", CFrame.new(at + Vector3.new(3, 0, 0)))
		local farther = Fixtures.rig(folder, "Far", CFrame.new(at + Vector3.new(6, 0, 0)))
		local outside = Fixtures.rig(folder, "Out", CFrame.new(at + Vector3.new(0, 0, 7.5)))
		local frame = BallService:step(1 / 60, { holder("Far", farther), holder("Near", closest), holder("Out", outside) })
		expect(frame.picker).toBe("Near")
		near(frame.pickupPosition, at)
		near(frame.pickupVelocity, Vector3.new(20, 0, 0))
		expect(BallService.state.carrier).toBe("Near")
		expect(BallService.part.CanCollide).toBe(false)
		expect(BallService.part.Massless).toBe(true)
		expect(BallService:step(1 / 60, {}).moved).toBe(false)
		closest:PivotTo(closest:GetPivot() + Vector3.new(10, 0, 0))
		local hand = closest:FindFirstChild("RightHand") :: BasePart
		expect((BallService.part.Position - hand.Position).Magnitude).toBeCloseTo(1.5, 3)
	end)

	it("keeps the thrower from catching their own throw, and reports the throw once", function()
		BallService:spawn()
		local rig = Fixtures.rig(folder, "A", CFrame.new(BallService.part.Position))
		BallService:step(1 / 60, { holder("A", rig) })
		BallService:throw("A", Vector3.new(0, 0, 30))
		expect(BallService.state.status).toBe("Flying")
		near(BallService.part.AssemblyLinearVelocity, Vector3.new(0, 0, 30))
		expect(BallService.part.CanCollide).toBe(true)
		local frame = BallService:step(1 / 60, { holder("A", rig) })
		expect(frame.thrower).toBe("A")
		expect(frame.picker).toBeNil()
		expect(BallService:step(1 / 60, { holder("A", rig) }).thrower).toBeNil()
		expect(BallService:step(0.4, { holder("A", rig) }).picker).toBe("A")
		expect(function()
			BallService:throw("B", Vector3.zero)
		end).toThrow("BallService: only the carrier can throw (carrier: A, thrower: B)")
	end)

	it("respawns a ball that leaves the arena or lies untouched, without reporting the jump", function()
		BallService:spawn()
		BallService:step(1 / 60, {})
		BallService.part.CFrame = CFrame.new(0, 5, -90)
		local out = BallService:step(1 / 60, {})
		expect(out.moved).toBe(true)
		near(out.to, Vector3.new(0, 5, -90))
		expect(out.respawned).toBe(true)
		expect(isSpawn(BallService.part.Position)).toBe(true)
		expect(BallService:step(1 / 60, {}).moved).toBe(false)
		expect(BallService:step(15, {}).respawned).toBe(true)
		expect(BallService.state.looseSeconds).toBe(0)
	end)

	it("drops the ball loose where its carrier is", function()
		BallService:spawn()
		local rig = Fixtures.rig(folder, "A", CFrame.new(BallService.part.Position))
		BallService:step(1 / 60, { holder("A", rig) })
		local carriedAt = BallService.part.Position
		BallService:drop()
		expect(BallService.state.status).toBe("Loose")
		expect(BallService.state.carrier).toBeNil()
		expect(BallService.part.CanCollide).toBe(true)
		rig:PivotTo(rig:GetPivot() + Vector3.new(10, 0, 0))
		near(BallService.part.Position, carriedAt)
	end)

	it("lands a thrown ball when it touches the arena, not a player", function()
		BallService:spawn()
		local rig = Fixtures.rig(folder, "A", CFrame.new(BallService.part.Position))
		BallService:step(1 / 60, { holder("A", rig) })
		BallService:throw("A", Vector3.new(0, 10, 0))
		BallService:onTouched(rig:FindFirstChild("HumanoidRootPart") :: BasePart)
		expect(BallService.state.status).toBe("Flying")
		local floor = Instance.new("Part")
		floor.Parent = folder
		BallService:onTouched(floor)
		expect(BallService.state.status).toBe("Loose")
	end)

	it("hides the ball and refuses every catch until it spawns again", function()
		BallService:spawn()
		local rig = Fixtures.rig(folder, "A", CFrame.new(BallService.part.Position))
		BallService:hide()
		expect(BallService.part.Parent).toBe(ServerStorage)
		expect(BallService.state.status).toBe("Dead")
		local frame = BallService:step(1 / 60, { holder("A", rig) })
		expect(frame.picker).toBeNil()
		expect(frame.moved).toBe(false)
	end)

	it("keeps a dead ball where it is but lets nobody pick it up", function()
		BallService:spawn()
		local at = BallService.part.Position
		local rig = Fixtures.rig(folder, "A", CFrame.new(at))
		BallService:kill()
		expect(BallService.part.Parent).toBe(workspace)
		expect(BallService:step(1 / 60, { holder("A", rig) }).picker).toBeNil()
	end)
```

- [ ] **Step 2: Run to verify failure.** Pattern `"BallService"`: the module and `Fixtures.rig` are missing.
- [ ] **Step 3: Implement** `BallService` and `Fixtures.rig` as specified. `step` reuses one `BallFrame` record and one candidates array, so a quiet frame allocates no tables. Connect `part.Touched` to `onTouched` in `init`.
- [ ] **Step 4: Run to verify pass.** The full suite has **261** (+9).
- [ ] **Step 5: Commit:** `feat(ball): add the ball service: spawn, catch, carry, throw, drop and recovery`. PR title: `feat(ball): ball service`.

---

### Task 6: TeamService and CharacterService

**Issue:** #61 · **Branch:** `feat/61-teams-characters` · **Labels:** `feature`, `rules`

**Files:**
- Create: `src/server/TeamService.luau`, `src/server/CharacterService.luau`
- Test: `tests/server/TeamService.spec.luau`, `tests/server/CharacterService.spec.luau`

**Interfaces:**
- Consumes: `Roster` (Task 3), `Attributes.Team` (Task 4), `BallService.Holder` (Task 5), `ArenaService.arena.teamSpawns` (Phase 3), `Signal`.
- Produces:
  ```lua
  -- TeamService (Loader module): name "TeamService", dependencies { "Config" }
  TeamService:init(deps)              -- Roster.new(Match.teamSize, tie-break with Random.new())
  TeamService:start()                 -- Players.PlayerAdded → join, PlayerRemoving → leave, joins players already here
  TeamService:join(player: Player)    -- seat or spectate; sets/clears the Team attribute; fires joined, then seated
  TeamService:leave(player: Player)   -- fires unseated for the leaver, seated for each promoted spectator
  TeamService:newMatch()              -- Roster.newMatch(); fires seated for every seat and unseated for each new spectator
  TeamService:teamOf(player: PlayerId): Team?
  TeamService:slotOf(player: PlayerId): (Team?, number?)   -- team and 1-based index in Roster.members
  TeamService:seatedCount(): number
  TeamService.joined: Signal<PlayerId>; TeamService.seated: Signal<PlayerId, Team>; TeamService.unseated: Signal<PlayerId>

  -- CharacterService (Loader module): name "CharacterService", dependencies { "Config", "ArenaService", "TeamService" }
  CharacterService:init(deps)
  CharacterService:start()            -- Players.CharacterAutoLoads = false; seated → load the character; unseated →
                                      -- remove it; Humanoid.Died → load again after Match.respawnSeconds
  CharacterService:adopt(player: PlayerId, character: Model)   -- registers a character (CharacterAdded, and tests)
  CharacterService:place(player: PlayerId, frozen: boolean)    -- pivots to the slot's team spawn at standing height
  CharacterService:placeAll(frozen: boolean)
  CharacterService:freezeAll(frozen: boolean)                  -- anchors or frees every root
  CharacterService:holders(): { BallService.Holder }           -- living characters; hand = RightHand, else Right Arm,
                                                              -- else HumanoidRootPart; one reused list
  CharacterService.characterRemoved: Signal<PlayerId>          -- a registered character is destroyed or dies
  CharacterService.standingHeight(character: Model): number     -- the R15/R6 formulas above
  ```
- **Stub players in tests** are plain tables, since Roblox can't create a `Player` in Edit:
  ```lua
  local function stubPlayer(userId: number): any
  	local attributes: { [string]: any } = {}
  	return {
  		UserId = userId,
  		SetAttribute = function(_self: any, key: string, value: any) attributes[key] = value end,
  		GetAttribute = function(_self: any, key: string): any return attributes[key] end,
  	}
  end
  ```

- [ ] **Step 1: Write the failing tests**

`tests/server/TeamService.spec.luau` (`TeamService:init({ Config = Fixtures.config({ Match = { teamSize = 1 } }) })` per test):

```lua
	it("seats joining players, marks their team on the player and announces it", function()
		local joined, seated = {}, {}
		TeamService.joined:Connect(function(id: string) table.insert(joined, id) end)
		TeamService.seated:Connect(function(id: string, team: string) table.insert(seated, id .. ":" .. team) end)
		local a, b, c = stubPlayer(1), stubPlayer(2), stubPlayer(3)
		for _, player in { a, b, c } do
			TeamService:join(player)
		end
		expect(joined).toEqual({ "1", "2", "3" })
		expect(#seated).toBe(2)
		expect(a:GetAttribute(Attributes.Team)).toBe(TeamService:teamOf("1"))
		expect(TeamService:teamOf("1")).never.toBe(TeamService:teamOf("2"))
		expect(c:GetAttribute(Attributes.Team)).toBeNil()
		expect(TeamService:seatedCount()).toBe(2)
	end)

	it("gives a leaving player's seat to a spectator and clears the leaver's team", function()
		local a, b, c = stubPlayer(1), stubPlayer(2), stubPlayer(3)
		for _, player in { a, b, c } do
			TeamService:join(player)
		end
		local aTeam = TeamService:teamOf("1")
		local unseated = {}
		TeamService.unseated:Connect(function(id: string) table.insert(unseated, id) end)
		TeamService:leave(a)
		expect(unseated).toEqual({ "1" })
		expect(a:GetAttribute(Attributes.Team)).toBeNil()
		expect(TeamService:teamOf("3")).toBe(aTeam)
		expect(c:GetAttribute(Attributes.Team)).toBe(aTeam)
	end)

	it("reseats everyone for a new match and announces every seat", function()
		local a, b = stubPlayer(1), stubPlayer(2)
		TeamService:join(a)
		TeamService:join(b)
		local seated = {}
		TeamService.seated:Connect(function(id: string) table.insert(seated, id) end)
		TeamService:newMatch()
		table.sort(seated)
		expect(seated).toEqual({ "1", "2" })
		expect(a:GetAttribute(Attributes.Team)).toBe(TeamService:teamOf("1"))
	end)

	it("gives each seated player a slot on their team", function()
		TeamService:join(stubPlayer(1))
		local team, slot = TeamService:slotOf("1")
		expect(team).toBe(TeamService:teamOf("1"))
		expect(slot).toBe(1)
		local ghostTeam, ghostSlot = TeamService:slotOf("Ghost")
		expect(ghostTeam).toBeNil()
		expect(ghostSlot).toBeNil()
	end)
```

`tests/server/CharacterService.spec.luau`:
- **Setup:** a `CharacterServiceTest` folder in `workspace`, and a fake `TeamService`: `{ slotOf = function(_self, id) local slot = SLOTS[id]; if slot then return slot[1], slot[2] end; return nil, nil end }`, with `SLOTS = { A = { "Blue", 2 }, B = { "Orange", 1 }, C = { "Blue", 1 } }`.
- **Arena:** `ArenaService = { arena = { teamSpawns = { Blue = { CFrame.new(10, 0, -53), CFrame.new(0, 0, -53) }, Orange = { CFrame.new(-10, 0, 53), CFrame.new(0, 0, 53) } } } }`.

```lua
	it("stands a character on its slot's team spawn, root at standing height, R15 and R6 alike", function()
		local r15 = Fixtures.rig(folder, "A", CFrame.new(0, 50, 0))
		local r6 = Fixtures.rig(folder, "B", CFrame.new(0, 50, 0), Enum.HumanoidRigType.R6)
		CharacterService:adopt("A", r15)
		CharacterService:adopt("B", r6)
		CharacterService:place("A", false)
		CharacterService:place("B", false)
		near((r15.PrimaryPart :: BasePart).Position, Vector3.new(0, 3, -53))     -- Blue slot 2: 0.5·2 + 2
		near((r6.PrimaryPart :: BasePart).Position, Vector3.new(-10, 3, 53))     -- Orange slot 1: 2 + 0.5·2 + 0
		expect(CharacterService.standingHeight(r6)).toBe(3)
	end)

	it("freezes characters for the kickoff countdown and frees them after", function()
		local rig = Fixtures.rig(folder, "A", CFrame.new(0, 50, 0))
		CharacterService:adopt("A", rig)
		CharacterService:placeAll(true)
		expect((rig.PrimaryPart :: BasePart).Anchored).toBe(true)
		CharacterService:freezeAll(false)
		expect((rig.PrimaryPart :: BasePart).Anchored).toBe(false)
	end)

	it("lists living characters that can hold the ball, with their hand", function()
		local r15 = Fixtures.rig(folder, "A", CFrame.new(0, 3, 0))
		local r6 = Fixtures.rig(folder, "B", CFrame.new(5, 3, 0), Enum.HumanoidRigType.R6)
		local dead = Fixtures.rig(folder, "C", CFrame.new(10, 3, 0))
		;(dead:FindFirstChildOfClass("Humanoid") :: Humanoid).Health = 0
		for id, rig in { A = r15, B = r6, C = dead } do
			CharacterService:adopt(id, rig)
		end
		local hands: { [string]: string } = {}
		for _, holder in CharacterService:holders() do
			hands[holder.player] = holder.hand.Name
		end
		expect(hands).toEqual({ A = "RightHand", B = "Right Arm" })
	end)

	it("announces a character that goes away and stops listing it", function()
		local rig = Fixtures.rig(folder, "A", CFrame.new(0, 3, 0))
		CharacterService:adopt("A", rig)
		local removed = {}
		CharacterService.characterRemoved:Connect(function(id: string) table.insert(removed, id) end)
		rig:Destroy()
		task.wait() -- Destroying is deferred
		expect(removed).toEqual({ "A" })
		expect(#CharacterService:holders()).toBe(0)
	end)
```

- [ ] **Step 2: Run to verify failure.** Pattern `"(TeamService|CharacterService)"`: the modules are missing.
- [ ] **Step 3: Implement** both services as specified. `TeamService:join` and `leave` derive the id with `tostring(player.UserId)`. `CharacterService.place` uses `character:PivotTo(spawn * CFrame.new(0, standingHeight(character), 0))` and sets `Anchored = frozen` on the root.
- [ ] **Step 4: Run to verify pass.** The full suite has **269** (+8).
- [ ] **Step 5: Commit:** `feat(rules): seat players on teams and stand their characters on the spawns`. PR title: `feat(rules): team and character services`.

---

### Task 7: MatchService, the frame loop and the playable match

**Issue:** #62 · **Branch:** `feat/62-match-service` · **Labels:** `feature`, `rules`

**Files:**
- Create: `src/server/MatchService.luau`
- Modify: `src/server/Modules.luau`, in order: `ArenaService`, `NetService`, `BallService`, `TeamService`, `CharacterService`, `MatchService`
- Test: `tests/integration/Match.spec.luau`

**Interfaces:**
- Consumes: everything above, plus `MatchEngine` (Phase 2) and `ArenaService` (Phase 3).
- Produces:
  ```lua
  -- MatchService (Loader module): name "MatchService",
  -- dependencies { "Config", "ArenaService", "NetService", "BallService", "TeamService", "CharacterService" }; deps.Random optional
  MatchService:init(deps)     -- creates the first engine; connects TeamService.joined/seated/unseated and
                              -- CharacterService.characterRemoved
  MatchService:start()        -- RunService.Heartbeat → step
  MatchService.engine: MatchEngine
  MatchService:step(dt)
  ```
- **`step(dt)`, in this order:**
  1. If the engine is `Waiting` and `TeamService:seatedCount() >= Match.minPlayersToStart`, call `engine:start()`.
  2. `frame = BallService:step(dt, CharacterService:holders())`.
  3. If `frame.moved`, call `engine:ballMoved(frame.from, frame.to)`.
  4. If `frame.thrower`, call `engine:thrown(frame.thrower)`.
  5. If `frame.picker`, call `engine:pickedUp(frame.picker, frame.pickupPosition, frame.pickupVelocity)`.
  6. Call `engine:tick(dt)`, then react to each drained event in order.
  7. If there were any events, `NetService:fireAll(RuleEvents, events)`.
  8. If `BallService.state.carrier` changed this frame, `NetService:fireAll(BallCarrier, { carrier = carrier })`.
  9. While the match is over, count down `postMatchSeconds` and then start the next match (below).
- **Reactions:**
  - `KickoffStarted`: `BallService:hide()`, `CharacterService:placeAll(true)`.
  - `KickoffEnded`: `BallService:spawn()`, `CharacterService:freezeAll(false)`.
  - `GoalOpened` / `GoalClosed`: set the goal panel open or closed (decision 10).
  - `GoalScored`, `StreakPointScored`, `MatchEnded`: `BallService:kill()`.
- **Signals:**
  - `seated(id, team)`: `engine:addPlayer`, unless the match is over (the next match seats everyone).
  - `unseated(id)` and `characterRemoved(id)`: if `id` carries the ball, `BallService:drop()`. `unseated` also calls `engine:removePlayer(id)` for ids the engine knows.
  - `joined(id)`: `NetService:fireTo(id, MatchSnapshot, engine:snapshot())`.
- **Next match:** a new `MatchEngine`, `TeamService:newMatch()` (which re-adds everyone through `seated`), `NetService:fireAll(MatchSnapshot, engine:snapshot())`, and the ball hidden.

- [ ] **Step 1: Write the failing tests** (`tests/integration/Match.spec.luau`).

  **Shared setup:**
  - `ArenaService:init` builds the real arena once (`beforeAll`), and `afterAll` destroys `ArenaService.model`.
  - Per test, a `MatchTest` folder in `workspace` holds the rigs. `BallService`, `TeamService`, `CharacterService` and `MatchService` are `init`ed with the test's config, `Random = Random.new(1)`, and a fake `NetService` that records `{ name, payload, to }`. `afterEach` destroys the ball and the folder.
  - Players are `stubPlayer`s joined through the real `TeamService`, whose rigs are `adopt`ed into the real `CharacterService`.

  **Helpers:**
  - `frames(seconds)` steps `MatchService` in 1/60 s frames.
  - `seat(n)` joins stubs 1..n and adopts a rig for each, returning `rigs, players`.
  - `kickoff()` steps until `KickoffEnded`.
  - `carry(rig, fromDistance, toDistance)` pivots the rig along `Centerline.at(arena, d, 22, 3)` in 2-stud frames.
  - `events()` returns the names of every event broadcast through `RuleEvents`, in order; `eventsNamed(name)` returns only those with `name`.

  **Configs:**
  - `{ Match = { lapsToOpenGoal = 1, lapsForStreakPoint = 2 } }`
  - plus `pointsToWin = 1` and `postMatchSeconds = 2` for the new-match test.

```lua
	it("starts once a player is seated, keeps the ball hidden through the countdown, then drops it at a ball spawn", function()
		local rigs = seat(1)
		frames(1 / 60)
		expect(events()).toEqual({ "MatchStarted", "KickoffStarted" })
		expect(BallService.part.Parent).toBe(ServerStorage)
		expect((rigs[1].PrimaryPart :: BasePart).Anchored).toBe(true)
		frames(config.Match.kickoffCountdownSeconds + 0.05)
		expect(table.find(events(), "KickoffEnded")).never.toBeNil()
		expect(BallService.part.Parent).toBe(workspace)
		expect(BallService.state.status).toBe("Loose")
		expect((rigs[1].PrimaryPart :: BasePart).Anchored).toBe(false)
	end)

	it("counts a lap carried around the generated track and opens the goal", function()
		local rigs = seat(1)
		kickoff()
		local start = ballDistance()                      -- the apex distance of the curved end the ball spawned at
		carry(rigs[1], start, start)                      -- step onto the ball: the catch
		expect(table.find(events(), "PossessionChanged")).never.toBeNil()
		carry(rigs[1], start, start + Centerline.length(config.Arena) + 2)
		expect(table.find(events(), "LapCompleted")).never.toBeNil()
		expect(table.find(events(), "GoalOpened")).never.toBeNil()
		local panel = ArenaService.arena.goalPanel
		expect(panel.CanCollide or panel.CanQuery).toBe(false)
		expect(panel.Transparency).toBe(1)
	end)

	it("scores through the open goal, then hides the ball and closes the goal for the next kickoff", function()
		local rig = openGoal()                            -- seat(1), kickoff, catch and one lap, as above
		carry(rig, current(rig), Centerline.gateDistance(config.Arena, config.Arena.goalGateIndex) - 3)
		local goal = ArenaService.arena.layout.goal.frame
		BallService:throw("1", goal.LookVector * 60)
		throughRing(goal)                                 -- ball CFrame to goal − Look·2, step, then goal + Look·2, step
		expect(table.find(events(), "GoalScored")).never.toBeNil()
		expect(BallService.state.status).toBe("Dead")
		frames(config.Match.celebrationSeconds + 0.05)
		expect(#eventsNamed("KickoffStarted")).toBe(2)
		expect(BallService.part.Parent).toBe(ServerStorage)
		expect(ArenaService.arena.goalPanel.CanCollide).toBe(true)
	end)

	it("drops the ball where a leaving carrier was, and the team keeps possession", function()
		local rigs, players = seat(2)
		kickoff()
		catchWith(rigs[1])                                -- player "1" catches
		local team = TeamService:teamOf("1")
		TeamService:leave(players[1])
		frames(1 / 60)
		expect(BallService.state.status).toBe("Loose")
		expect(MatchService.engine:snapshot().possessingTeam).toBe(team)
	end)

	it("keeps the ball dead whenever play is not live", function()
		local rig = scoreOnce()                           -- as in the scoring test, stopped right after GoalScored
		rig:PivotTo(CFrame.new(BallService.part.Position))
		frames(1 / 60)
		expect(BallService.state.carrier).toBeNil()
		expect(#eventsNamed("PossessionChanged")).toBe(1)
	end)

	it("starts a new match with everyone reseated after the post-match pause", function()
		-- config with pointsToWin = 1 and postMatchSeconds = 2
		local first = MatchService.engine
		scoreOnce()
		expect(table.find(events(), "MatchEnded")).never.toBeNil()
		frames(2.05)
		expect(MatchService.engine).never.toBe(first)
		expect(lastFired(Remotes.names.MatchSnapshot).to).toBeNil()            -- sent to everyone
		expect(MatchService.engine:snapshot().state).toBe("Kickoff")
	end)

	it("sends each frame's events as one batch and a snapshot to each player who joins", function()
		seat(1)
		frames(1 / 60)
		local batches = fired(Remotes.names.RuleEvents)
		expect(#batches).toBe(1)
		expect(#batches[1].payload).toBe(2)
		expect(lastFired(Remotes.names.MatchSnapshot).to).toBe("1")
	end)

	it("tells everyone who carries the ball", function()
		local rigs = seat(1)
		kickoff()
		catchWith(rigs[1])
		expect(lastFired(Remotes.names.BallCarrier).payload).toEqual({ carrier = "1" })
		BallService:throw("1", Vector3.new(0, 20, 0))
		frames(1 / 60)
		expect(lastFired(Remotes.names.BallCarrier).payload).toEqual({})
	end)

	it("runs a frame for six players in under a millisecond", function()
		local rigs = seat(6)
		kickoff()
		catchWith(rigs[1])
		local from = ballDistance()
		local started, total = 0, 0
		for step = 1, 600 do
			rigs[1]:PivotTo(Centerline.at(config.Arena, from + step * 0.5, 22, 3))
			started = os.clock()
			MatchService:step(1 / 60)
			total += os.clock() - started
		end
		expect(total / 600).toBeLessThan(0.001)
	end)
```

  The helpers (`ballDistance`, `current`, `catchWith`, `openGoal`, `scoreOnce`, `throughRing`, `fired`, `lastFired`, `events`, `eventsNamed`) are small local functions in the spec, built from the setup above. Each one pivots rigs or the ball by `CFrame` and steps frames.

- [ ] **Step 2: Run to verify failure.** Pattern `"integration"`: `MatchService` is missing.
- [ ] **Step 3: Implement** `MatchService` as specified and append the modules to `src/server/Modules.luau` in the order above.
- [ ] **Step 4: Run to verify pass.** Pattern `"integration"`, then the full suite: **278** (+9). Confirm `workspace` and `ServerStorage` keep no test folders and no stray `Ball`.
- [ ] **Step 5: Playtest.** Use MCP `start_stop_play(true)`, then wait 5 s.
  - **Console:** `get_console_output` shows exactly `[BloxChampions] Server ready: mode=NormalChampions, modules=6` and `[BloxChampions] Client ready: mode=NormalChampions, modules=0`, nothing else.
  - **Server DataModel** (`execute_luau`), which returns JSON:
    - the local player's `Team` attribute is `"Blue"` or `"Orange"`;
    - `MatchService.engine:snapshot().state == "Live"`;
    - the ball is in `workspace`, with `GetNetworkOwner() == nil`;
    - the player's root is within 1 stud (horizontally) of their slot's team spawn.
  - **Rolling over the seams:** move the ball to `Centerline.at(arena, gateDistance(3) + 40, 15, 1.5)` (the bottom straight's lower floor, away from the player) with `AssemblyLinearVelocity = Vector3.new(40, 0, 0)`. Sample its Y over 60 Heartbeats. Expected: it travels more than 20 studs and `max |Y − 1.5| < 0.25`, so it rolls over the station seams without hopping.
  - **The closed panel:** with the goal closed, launch the ball from 6 studs in front of the ring at the ring's centre, at 60 studs/s along `LookVector`. After 1 s its position relative to the ring's frame has `Z > 0`: it bounced back in front of the panel.
  - **Client DataModel:** `ReplicatedStorage.Remotes` has the three `RemoteEvent`s, and `LocalPlayer:GetAttribute("Team")` matches the server.
  - Then `start_stop_play(false)`.

  A failed physics check is a finding. Diagnose it (`superpowers:systematic-debugging`), and fix it test-first where a unit test can pin it, or in config.
- [ ] **Step 6: Commit:** `feat(rules): run matches on the server: frame loop, kickoffs, goals and the next match`. PR title: `feat(rules): match service`.

Phase 4 is complete when the PRs for #56–#62 are merged, the full suite passes on `main`, CI is green, and the playtest checks above pass with a clean console.
