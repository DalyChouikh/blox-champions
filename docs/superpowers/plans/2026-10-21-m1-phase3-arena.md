# M1 Phase 3 — Arena Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Generate the graybox arena from config at server start (the stepped straights, the U-shaped curved ends, the walls, the solid infield, the four lap gates, the raised goal ring and panel, the corner markers and the spawns), and tag it so the Phase 2 rules engine reads its gates and goal straight from the place.

**Architecture:** A pure `Arena/Geometry` (Luau + `Vector2`/`Vector3`/`CFrame` values only) turns `Config.Arena` into a list of part descriptions ("pieces") and feature frames: a centerline loop, a cross-section profile swept along it into flat blocks and wedge pairs, and the gates, goal, markers, infield and spawns. A thin server `Arena/Builder` turns pieces into anchored parts under one unparented model and parents it last. `ArenaService` runs both at server start. `Arena/TaggedLayout` reads the tagged parts back into the `MatchEngine.ArenaLayout` the rules need.

**Tech Stack:** Luau (`--!strict`), Jest-Lua 3.10.0 in Studio through the Roblox Studio MCP, Rojo 7.7.1, StyLua 2.6.0, selene 0.32.0, luau-lsp 1.70.1 (`bash scripts/analyze.sh`).

**Spec:** `docs/superpowers/specs/2026-10-21-m1-foundation-core-match-design.md` — §9.1 (layout), §9.2 (generation, tags), §13 (no partial arena), §14 (phase 3 scope). Phase 2's `MatchEngine.ArenaLayout` and `Crossing.Rectangle`/`Crossing.Disc` are the contract the arena must satisfy.

## Verified facts this plan relies on (probed in Studio, 2026-10-21)

- **WedgePart:** in object space the slope rises toward +Z. A downward ray on a 4×4×4 wedge hits y = +1.5 at z = +1.5 and y = −1.5 at z = −1.5, with the slope normal (0, 0.71, −0.71). So the right angle of its triangular cross-section is at the back-bottom edge (y = −sy/2, z = +sz/2), the top corner is at (+sy/2, +sz/2), and the front corner at (−sy/2, −sz/2).
- **Cylinder Part:** its axis is the part's X axis. A part sized (1, 4, 4) is a disc 1 thick along X.
- **Tags and attributes:** `Instance:AddTag`/`HasTag`, `CollectionService:GetTagged` and `SetAttribute`/`GetAttribute` all work in the Edit DataModel. `workspace:Raycast` works in Edit too.
- **`Instance.new("Part")` defaults to `TopSurface = Studs` and `BottomSurface = Inlet`**, so the builder sets both to `Smooth`. The minimum part size is 0.001 studs per axis.
- **Cost:** creating 9,000 anchored parts in an unparented model took 33 ms, parenting it 81 ms, destroying it 41 ms.
- **The place:** the template `Baseplate` (top at y = 0) and `SpawnLocation` were removed at the owner's request; Workspace holds only `Camera` and `Terrain`. `workspace.FallenPartsDestroyHeight` is −500.

## Global Constraints

- Phase 1 and Phase 2 Global Constraints still apply: `--!strict` first line; StyLua, selene and `bash scripts/analyze.sh` clean; relative requires in `src/`; service-path requires in tests; `JestGlobals` only; annotate locals strict mode can't infer. Locals holding singleton unions (`Team`, `Shape`) need annotations (luau-lsp widens them to `string`).
- **Pure geometry:** files under `src/shared/Arena/Geometry/` never touch an Instance, a service or `workspace`.
- **Every size, count and color comes from config:** `Config.Arena`, `Match.teamSize`, and `UI.teamColors`.
- **Coordinates:** the arena is centered on the world origin, with the lower floor at y = 0 and the long axis along X. The track runs counter-clockwise seen from above: the travel direction's RightVector points at the outer wall. The top straight is at z = −60, and the gates are numbered in travel order starting at the top-right corner (x = 80, z = −60).
- **Tags and attribute names live only in `src/shared/Arena/Tags.luau`.** Gameplay code finds arena features only through them (spec §9.2).
- **No partial arena:** the builder validates every piece before creating any, builds the model unparented, and parents it last (spec §13).
- Branches, commits and PRs follow `CONTRIBUTING.md`. Every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, every PR body with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`. Static checks must pass before every commit.

## How tests run

`rojo serve test.project.json` stays running and connected. Run tests with the Roblox Studio MCP `execute_luau` tool (`datamodel_type = "Edit"`):

```lua
task.wait(1)
local s = require(game:GetService("ServerStorage").RunTests:Clone())({ testPathPattern = "<pattern>" })
return { success = s.success, passed = s.numPassedTests, total = s.numTotalTests, firstFailure = s.failureMessages[1] }
```

To match several files, wrap the alternatives in parentheses (`"(Centerline|Profile)"`). The suite has **162 tests** before this phase; each task states its new total. Tests that build parts (`tests/server/`, `tests/integration/`) parent them under a uniquely named folder and destroy it in `afterEach`/`afterAll`, so the open place keeps no test parts.

**Shipping:** each task branches from the previous task's branch tip, gets one PR with `Closes #<issue>`, and PRs merge in order with `gh pr merge <n> --merge` once one read of `gh pr view <n> --json headRefOid,statusCheckRollup` shows green on the head commit. After the last merge: `git fetch --prune && git checkout -B main origin/main`.

## Review Focus

1. **A rectangle that float error makes slightly imperfect** (a long straight far from the origin) must still become one block, and a real trapezoid (any curved-end strip) must never become a block, which would leave gaps or overlaps. Tests: Task 3 `makes one block for a flat rectangle…`, `splits any other quad into four wedges`, and the exact block/wedge counts in `sweeps the profile around the whole loop…`.
2. **The wedge orientation:** a wrong mapping from triangle to WedgePart flips every triangle into the wrong half of its quad and leaves holes in the floor. Tests: Task 3 `covers the triangle with two wedges…`, plus Task 6 raycasts on a straight, the step, a curved end and the blend at Gate 2.
3. **The step fading out where straights meet curves** must stay continuous, with no ledge between stations. Tests: Task 2 `blends the straights' step into the curves' flat floor…`, and the Task 6 raycast at Gate 2, where the floor at the step's middle is exactly half the step's height.
4. **Tagged parts that don't belong to this arena** (a leftover test arena, a future art model) must be ignored. Test: Task 5 `ignores tagged instances outside the root`.
5. **A build that fails partway** must leave nothing in the place. Test: Task 6 `leaves nothing behind when a piece is invalid`.

## Decisions not spelled out in the spec (for owner review)

1. **Infield (owner, 2026-10-21):** a solid block whose top is level with the inner wall top (20). It is built as one block plus a cylinder under each curved end, recessed 1 stud (`surfaceThickness`) behind the inner wall's slab so no faces overlap and nothing flickers.
2. **Step near the outer wall (owner, 2026-10-21):** new config `upperFloorWidth = 4`. With the defaults, the floor between the wall curves is: lower floor 10 wide, step 10 wide, upper floor 4 wide.
3. **Baseplate (owner, 2026-10-21):** the template Baseplate and SpawnLocation were removed. The arena is the ground, centered on the origin with its base at y = 0.
4. **Track direction is fixed counter-clockwise.** Spec §9.1 lists a `trackDirection` value, but the goal side and the wall-riding direction are designed around counter-clockwise, so it is not made configurable (one valid value).
5. **Cross-section resolution:** each wall and each flat floor gets one strip. The remaining strips (14 of `stripsPerSection = 18`) go to the two wall curves and the step in proportion to their length: 5, 4 and 5 strips. A wall curve is therefore 18° per strip.
6. **Blend between the stepped and flat shapes:** centered on each corner, `profileBlendLength / 2` (10) studs into the straight and 10 into the curve, with a cosine ease. Every station uses the same point layout, so the step's height is the only thing that changes.
7. **Sweep stations:** each straight and each curve is split into equal pieces at most `segmentLength` long (40 per straight, 48 per curve, 176 in all), so every gate sits exactly on a station.
8. **Surface parts:** a flat rectangle (every strip of a straight's interior, and the walls on the curves) becomes one Part. Every other quad becomes two triangles, each built from two WedgeParts. That makes 8,172 surface parts (1,500 blocks and 6,672 wedges), about 0.1 s to build at the measured rate.
9. **Each surface part is a slab `surfaceThickness` (1) thick, behind the riding surface,** so the surface sits exactly where the profile says.
10. **Gates:** invisible, non-colliding, non-queryable parts, as wide as the track (44) and as tall as the outer wall (28), standing on the four corner stations.
11. **Goal:**
    - `goal.ringRadius` (7) is the radius of the opening, which is also the scoring disc.
    - The rim is 16 blocks (`rimSegments`) of `rimThickness` (1).
    - The ring's edge sits `wallGap` (1) from the outer wall face.
    - `heightAboveFloor` (18) is measured from the base (y = 0).
    - The panel is a cylinder part `panelThickness` (0.5) thick covering the opening. It is collidable, because the goal starts closed; Phase 4 opens it.
12. **Corner markers:** a pillar `marker.width` × `marker.height` × `marker.width` (2 × 8 × 2) on the outer wall top at each gate.
13. **Spawns:**
    - Team spawns: `Match.teamSize` pads per team, `teamSpawnSpacing` (10) studs apart along the middle of each straight. Each pad sits at the center of the lower floor, facing the travel direction: Blue on the top straight, Orange mirrored on the bottom.
    - Ball spawns: 6 studs (`ballSpawnHeight`) above the apex of each curved end.
14. **Colors:**
    - Team colors go in `Config/UI` (spec §11.2): Blue `13, 105, 172`, Orange `218, 133, 65`.
    - Graybox colors go in `Config.Arena.colors`.
15. **`TaggedLayout.read(root)` only reads tagged instances under `root`.**
16. **`Validate.number` gains `above` (an exclusive lower bound),** which `Config.Arena` and `MatchEngine`'s arena check share.

**Not in this phase:**
- Phase 4: the panel sliding open and the ring glowing on `GoalOpened`; the next-gate glow and the carrier's arrow; ball physics and out-of-bounds respawn; integration tests that drive a real ball part.
- Phase 5: placing characters on the spawns, and the skating feel on this surface.
- Art pass: final meshes.

---

### Task 1: Arena config, team colors, exclusive number bounds

**Issue:** #42 · **Branch:** `feat/42-arena-config` · **Labels:** `feature`, `arena`

**Files:**
- Modify: `src/shared/Config/Validate.luau` (`above` option), `src/shared/Config/UI.luau` (`teamColors`), `src/shared/Config/init.luau` (Arena area), `src/shared/Rules/MatchEngine.luau` (its `positive` uses `above`)
- Create: `src/shared/Config/Arena.luau`
- Test: `tests/shared/Config/Validate.spec.luau`, `tests/shared/Config/Config.spec.luau`

**Interfaces:**
- Consumes: Phase 1/2 `Validate`, `Config`.
- Produces:
  ```lua
  Validate.number(options: { min: number?, max: number?, above: number?, integer: boolean? }?): Validator
  -- above: "<path>: must be > <above> (got <v>)"

  export type ArenaConfig = {
  	straightLength: number, endRadius: number, trackWidth: number,
  	outerWallHeight: number, infieldWallHeight: number, wallCurveRadius: number,
  	stepHeight: number, stepWidth: number, upperFloorWidth: number,
  	profileBlendLength: number, segmentLength: number, stripsPerSection: number, surfaceThickness: number,
  	goalGateIndex: number,
  	goal: { ringRadius: number, heightAboveFloor: number, panelThickness: number, rimThickness: number,
  		rimSegments: number, wallGap: number },
  	marker: { width: number, height: number },
  	teamSpawnSpacing: number, ballSpawnHeight: number,
  	colors: { surface: Color3, infield: Color3, goal: Color3, marker: Color3 },
  }
  -- UIConfig gains teamColors: { Blue: Color3, Orange: Color3 }
  -- GameConfig gains Arena: ArenaConfig; Config exports ArenaConfig.
  ```
- Defaults: the spec §9.1 values: `straightLength = 160`, `endRadius = 60`, `trackWidth = 44`, `outerWallHeight = 28`, `infieldWallHeight = 20`, `wallCurveRadius = 10`, `stepHeight = 4`, `stepWidth = 10`, `profileBlendLength = 20`, `segmentLength = 4`, `stripsPerSection = 18`, `goalGateIndex = 2`, `goal.ringRadius = 7`, `goal.heightAboveFloor = 18`, `goal.panelThickness = 0.5`. New values: `upperFloorWidth = 4`, `surfaceThickness = 1`, `goal.rimThickness = 1`, `goal.rimSegments = 16`, `goal.wallGap = 1`, `marker = { width = 2, height = 8 }`, `teamSpawnSpacing = 10`, `ballSpawnHeight = 6`, and `colors = { surface = (163, 162, 165), infield = (99, 95, 98), goal = (248, 248, 248), marker = (27, 42, 53) }` as `Color3.fromRGB`.
- Field rules:
  - `above = 0`: every length, `segmentLength`, `surfaceThickness`, `profileBlendLength`, the goal sizes, the marker sizes, `teamSpawnSpacing`, `ballSpawnHeight`.
  - `min = 0`: `stepHeight`, `goal.wallGap`.
  - Integers: `stripsPerSection` ≥ 7, `goal.rimSegments` ≥ 3, `goalGateIndex` from 1 to 4.
  - Colors: `Validate.datatype("Color3")`.
- Cross-field checks, in this order:
  1. `Arena: trackWidth must fit both wall curves, the step, the upper floor and a lower floor`: `trackWidth − 2·wallCurveRadius − stepWidth − upperFloorWidth > 0`.
  2. `Arena: endRadius must leave room for the infield behind the inner wall`: `endRadius − trackWidth/2 − surfaceThickness > 0`.
  3. `Arena: each wall must rise above the curve at its foot`: `infieldWallHeight > wallCurveRadius` and `outerWallHeight > wallCurveRadius + stepHeight`.
  4. `Arena: profileBlendLength must fit within a straight and a curved end`: `≤ straightLength` and `≤ π·endRadius`.
  5. `Arena: the goal ring must fit across the track`: `trackWidth − wallGap − 2·(ringRadius + rimThickness) ≥ 0`.
  6. `Arena: the goal ring must sit between the upper floor and the outer wall top`: `heightAboveFloor − ringRadius − rimThickness ≥ stepHeight` and `heightAboveFloor + ringRadius + rimThickness ≤ outerWallHeight`.

- [ ] **Step 1: Write the failing tests**

Append to `describe("Validate", …)`:

```lua
	it("enforces an exclusive lower bound with above", function()
		local v = Validate.number({ above = 0 })
		expect(v(0.5, "A.size")).toEqual({})
		expect(v(0, "A.size")).toEqual({ "A.size: must be > 0 (got 0)" })
	end)
```

Append to `describe("Config defaults", …)`:

```lua
	it("match the spec's arena layout", function()
		local a = Config.defaults().Arena
		expect(a.straightLength).toBe(160)
		expect(a.endRadius).toBe(60)
		expect(a.trackWidth).toBe(44)
		expect(a.outerWallHeight).toBe(28)
		expect(a.infieldWallHeight).toBe(20)
		expect(a.wallCurveRadius).toBe(10)
		expect(a.stepHeight).toBe(4)
		expect(a.stepWidth).toBe(10)
		expect(a.upperFloorWidth).toBe(4)
		expect(a.profileBlendLength).toBe(20)
		expect(a.segmentLength).toBe(4)
		expect(a.stripsPerSection).toBe(18)
		expect(a.surfaceThickness).toBe(1)
		expect(a.goalGateIndex).toBe(2)
		expect(a.goal).toEqual({
			ringRadius = 7, heightAboveFloor = 18, panelThickness = 0.5, rimThickness = 1, rimSegments = 16, wallGap = 1,
		})
		expect(a.marker).toEqual({ width = 2, height = 8 })
		expect(a.teamSpawnSpacing).toBe(10)
		expect(a.ballSpawnHeight).toBe(6)
	end)

	it("give each team and each arena part a color", function()
		local d = Config.defaults()
		expect(d.UI.teamColors).toEqual({ Blue = Color3.fromRGB(13, 105, 172), Orange = Color3.fromRGB(218, 133, 65) })
		expect(d.Arena.colors).toEqual({
			surface = Color3.fromRGB(163, 162, 165),
			infield = Color3.fromRGB(99, 95, 98),
			goal = Color3.fromRGB(248, 248, 248),
			marker = Color3.fromRGB(27, 42, 53),
		})
	end)
```

Append to `describe("Config.forMode", …)`:

```lua
	it("rejects arena sizes that cannot be built", function()
		local cases: { { overrides: { [string]: any }, message: string } } = {
			{ overrides = { trackWidth = 30 }, message = "Arena: trackWidth must fit both wall curves, the step, the upper floor and a lower floor" },
			{ overrides = { endRadius = 22 }, message = "Arena: endRadius must leave room for the infield behind the inner wall" },
			{ overrides = { infieldWallHeight = 10 }, message = "Arena: each wall must rise above the curve at its foot" },
			{ overrides = { profileBlendLength = 200 }, message = "Arena: profileBlendLength must fit within a straight and a curved end" },
			{ overrides = { goal = { wallGap = 30 } }, message = "Arena: the goal ring must fit across the track" },
			{ overrides = { goal = { heightAboveFloor = 24 } }, message = "Arena: the goal ring must sit between the upper floor and the outer wall top" },
			{ overrides = { stripsPerSection = 6 }, message = "Arena.stripsPerSection: must be >= 7 (got 6)" },
			{ overrides = { goalGateIndex = 5 }, message = "Arena.goalGateIndex: must be <= 4 (got 5)" },
		}
		for _, case in cases do
			expect(function()
				Fixtures.config({ Arena = case.overrides })
			end).toThrow(case.message)
		end
	end)
```

- [ ] **Step 2: Run to verify failure** — patterns `"Validate"` and `"Config.spec"`: the 4 new tests fail (`Arena`/`teamColors` nil, `above` ignored).
- [ ] **Step 3: Implement** the Interfaces block. `Config/Arena.luau` mirrors `Config/Match.luau` (defaults, `fields` record, `Validate.check` chain in the order above). In `MatchEngine`, replace its `positive` with `Validate.number({ above = 0 })`; its existing tests still pass, because `must be > 0` is a prefix of the new message.
- [ ] **Step 4: Run to verify pass** — both patterns green; the full suite has `passed = 166`.
- [ ] **Step 5: Commit** — `feat(config): add arena layout, team colors and exclusive number bounds`. PR title: `feat(config): arena config and team colors`.

---

### Task 2: Centerline and cross-section profile

**Issue:** #43 · **Branch:** `feat/43-centerline-profile` · **Labels:** `feature`, `arena`

**Files:**
- Create: `src/shared/Arena/Geometry/Centerline.luau`, `src/shared/Arena/Geometry/Profile.luau`
- Test: `tests/shared/Arena/Geometry/Centerline.spec.luau`, `tests/shared/Arena/Geometry/Profile.spec.luau`

**Interfaces:**
- Consumes: `Config.ArenaConfig` (Task 1).
- Produces:
  ```lua
  Centerline.length(arena: ArenaConfig): number                       -- 2·straightLength + 2π·endRadius
  Centerline.frameAt(arena, distance: number): CFrame
  -- distance wraps modulo length. Position at y = 0, LookVector = travel direction,
  -- RightVector = toward the outer wall (CFrame.lookAt(position, position + heading)).
  Centerline.at(arena, distance: number, lateral: number, height: number): CFrame
  -- frameAt(distance) * CFrame.new(lateral − trackWidth/2, height, 0); lateral is measured from the inner wall face.
  Centerline.gateDistance(arena, gateIndex: number): number          -- the start of section gateIndex
  Centerline.stations(arena): { number }                              -- ascending; see below
  Centerline.stepBlend(arena, distance: number): number               -- 1 on straights, 0 on curves, eased between

  Profile.stripCounts(arena): { number }   -- strips per piece, 7 pieces, sums to stripsPerSection
  Profile.points(arena, stepHeight: number): { Vector2 }
  -- stripsPerSection + 1 points (u = lateral from the inner wall face, y = height), from the inner wall top
  -- down, across, and up to the outer wall top.
  Profile.lowerFloorCenter(arena): number  -- u at the middle of the lower floor (Task 4's spawn lane)
  ```

Centerline sections, in travel order (S = straightLength, R = endRadius):
1. Top straight from (S/2, 0, −R) heading −X.
2. Left curve centered (−S/2, 0, 0): position = center + R·(−sin φ, 0, −cos φ), heading = (−cos φ, 0, sin φ), φ = (distance into the section)/R.
3. Bottom straight from (−S/2, 0, R) heading +X.
4. Right curve centered (S/2, 0, 0): position = center + R·(sin φ, 0, cos φ), heading = (cos φ, 0, −sin φ).

Section *i* starts at the sum of the earlier lengths, so `gateDistance(1) = 0`. Stations: each section is split into n = ceil(length / segmentLength) equal pieces, and its stations are `start + k·(length/n)` for k = 0…n−1. Station 0 of each section therefore equals `gateDistance` exactly.

`stepBlend`: let `p` be the distance to the nearest end of the section the point is in, positive on a straight and negative on a curve, and B = profileBlendLength. The result is 1 when p ≥ B/2, 0 when p ≤ −B/2, and otherwise `(1 − cos(π·(p + B/2)/B)) / 2`.

Profile pieces (W = trackWidth, rc = wallCurveRadius, h = stepHeight, uA = W − rc − upperFloorWidth − stepWidth, uB = uA + stepWidth):
1. Inner wall line: (0, infieldWallHeight) to (0, rc).
2. Inner curve: an arc about (rc, rc) from 180° to 270°.
3. Lower floor: (rc, 0) to (uA, 0).
4. Step: u = uA + t·stepWidth, y = h·(1 − cos πt)/2.
5. Upper floor: (uB, h) to (W − rc, h).
6. Outer curve: an arc about (W − rc, h + rc) from 270° to 360°.
7. Outer wall line: (W, h + rc) to (W, outerWallHeight).

Points are spaced evenly within each piece (by angle on the arcs, by t on the step) and shared at piece boundaries.

`stripCounts` gives 1 strip to each line piece (1, 3, 5, 7). It shares the remaining `stripsPerSection − 4` strips among pieces 2, 4 and 6 in proportion to their arc lengths at full `stepHeight`, measuring the step's length on a 64-segment polyline. Each curved piece gets at least 1. Leftover strips go to the largest remainders, with ties going to the earlier piece. The counts never depend on the `stepHeight` argument, which is what lets stations blend point by point.

- [ ] **Step 1: Write the failing tests**

`tests/shared/Arena/Geometry/Centerline.spec.luau`:

```lua
local arena = Config.defaults().Arena

local function near(actual: Vector3, expected: Vector3)
	expect((actual - expected).Magnitude).toBeLessThan(1e-3)
end

describe("Centerline", function()
	it("is two straights and two half circles long", function()
		expect(Centerline.length(arena)).toBeCloseTo(2 * 160 + 2 * math.pi * 60, 4)
	end)

	it("places the gates at the four corners in counter-clockwise travel order, outer wall on the right", function()
		local expected = {
			{ Vector3.new(80, 0, -60), Vector3.new(-1, 0, 0) },
			{ Vector3.new(-80, 0, -60), Vector3.new(-1, 0, 0) },
			{ Vector3.new(-80, 0, 60), Vector3.new(1, 0, 0) },
			{ Vector3.new(80, 0, 60), Vector3.new(1, 0, 0) },
		}
		for gate, pair in expected do
			local frame = Centerline.frameAt(arena, Centerline.gateDistance(arena, gate))
			near(frame.Position, pair[1])
			near(frame.LookVector, pair[2])
		end
		near(Centerline.frameAt(arena, 0).RightVector, Vector3.new(0, 0, -1))
		near(Centerline.frameAt(arena, Centerline.gateDistance(arena, 3)).RightVector, Vector3.new(0, 0, 1))
	end)

	it("turns left through each curved end, closes the loop, and offsets across the track", function()
		local apex = Centerline.frameAt(arena, 160 + 30 * math.pi)
		near(apex.Position, Vector3.new(-140, 0, 0))
		near(apex.LookVector, Vector3.new(0, 0, 1))
		near(apex.RightVector, Vector3.new(-1, 0, 0))
		near(Centerline.frameAt(arena, Centerline.length(arena)).Position, Centerline.frameAt(arena, 0).Position)
		near(Centerline.at(arena, 80, 0, 20).Position, Vector3.new(0, 20, -38))
	end)

	it("puts stations at most segmentLength apart around the whole loop, one on every gate", function()
		local stations = Centerline.stations(arena)
		expect(#stations).toBe(176)
		for gate = 1, 4 do
			expect(table.find(stations, Centerline.gateDistance(arena, gate))).never.toBeNil()
		end
		for index = 2, #stations do
			local gap = stations[index] - stations[index - 1]
			expect(gap > 0 and gap <= arena.segmentLength + 1e-9).toBe(true)
		end
		expect(Centerline.length(arena) - stations[#stations] <= arena.segmentLength + 1e-9).toBe(true)
	end)

	it("blends the straights' step into the curves' flat floor around each corner", function()
		expect(Centerline.stepBlend(arena, 80)).toBe(1)
		expect(Centerline.stepBlend(arena, 160 + 30 * math.pi)).toBe(0)
		expect(Centerline.stepBlend(arena, 160)).toBeCloseTo(0.5)
		expect(Centerline.stepBlend(arena, 150)).toBeCloseTo(1)
		expect(Centerline.stepBlend(arena, 170)).toBeCloseTo(0)
		expect(Centerline.stepBlend(arena, 155)).toBeCloseTo((1 - math.cos(math.pi * 0.75)) / 2)
		expect(Centerline.stepBlend(arena, Centerline.length(arena) - 5)).toBeCloseTo((1 - math.cos(math.pi * 0.25)) / 2)
	end)
end)
```

`tests/shared/Arena/Geometry/Profile.spec.luau`:

```lua
local arena = Config.defaults().Arena

local function near(actual: Vector2, expected: Vector2)
	expect((actual - expected).Magnitude).toBeLessThan(1e-4)
end

describe("Profile", function()
	it("gives each wall and floor one strip and shares the rest across the curves and the step by length", function()
		expect(Profile.stripCounts(arena)).toEqual({ 1, 5, 1, 4, 1, 5, 1 })
	end)

	it("runs from the inner wall top down, across the floors and the step, and up the outer wall", function()
		local p = Profile.points(arena, 4)
		expect(#p).toBe(19)
		near(p[1], Vector2.new(0, 20))
		near(p[2], Vector2.new(0, 10))
		near(p[7], Vector2.new(10, 0))
		near(p[8], Vector2.new(20, 0))
		near(p[10], Vector2.new(25, 2))
		near(p[12], Vector2.new(30, 4))
		near(p[13], Vector2.new(34, 4))
		near(p[18], Vector2.new(44, 14))
		near(p[19], Vector2.new(44, 28))
		expect(Profile.lowerFloorCenter(arena)).toBe(15)
	end)

	it("rounds each wall foot with wallCurveRadius", function()
		local p = Profile.points(arena, 4)
		for index = 2, 7 do
			expect((p[index] - Vector2.new(10, 10)).Magnitude).toBeCloseTo(10, 3)
		end
		for index = 13, 18 do
			expect((p[index] - Vector2.new(34, 14)).Magnitude).toBeCloseTo(10, 3)
		end
	end)

	it("shapes the step as one smooth rise from the lower to the upper floor", function()
		local p = Profile.points(arena, 4)
		expect(p[9].Y).toBeCloseTo(2 - math.sqrt(2), 3)
		expect(p[11].Y).toBeCloseTo(2 + math.sqrt(2), 3)
	end)

	it("keeps the same points with no step, so straights and curves blend point by point", function()
		local flat = Profile.points(arena, 0)
		expect(#flat).toBe(19)
		for index = 7, 13 do
			expect(flat[index].Y).toBeCloseTo(0, 4)
		end
		near(flat[18], Vector2.new(44, 10))
	end)
end)
```

(Both files use the standard header and require `Config` and the module under test from `ReplicatedStorage.Shared`.)

- [ ] **Step 2: Run to verify failure** — pattern `"(Centerline|Profile)"`: the suites fail to load (`Arena` is not a member of `Shared`).
- [ ] **Step 3: Implement** both modules as specified above.
- [ ] **Step 4: Run to verify pass** — `passed = 10`. The full suite has `passed = 176`.
- [ ] **Step 5: Commit** — `feat(arena): add the track centerline and cross-section profile`. PR title: `feat(arena): centerline and profile`.

---

### Task 3: Wedge triangles and the swept surface

**Issue:** #44 · **Branch:** `feat/44-arena-surface` · **Labels:** `feature`, `arena`

**Files:**
- Create: `src/shared/Arena/Geometry/Types.luau`, `src/shared/Arena/Geometry/Triangles.luau`, `src/shared/Arena/Geometry/Surface.luau`
- Test: `tests/shared/Arena/Geometry/Triangles.spec.luau`, `tests/shared/Arena/Geometry/Surface.spec.luau`

**Interfaces:**
- Consumes: `Centerline.at/stations/stepBlend`, `Profile.points` (Task 2).
- Produces:
  ```lua
  -- Geometry/Types.luau (returns a frozen empty table)
  export type Shape = "Block" | "Wedge" | "Cylinder"   -- a Cylinder's axis is its X axis (verified)
  export type Piece = { shape: Shape, cframe: CFrame, size: Vector3 }

  Triangles.wedges(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, thickness: number): { Piece }
  -- Two Wedge pieces whose triangular faces exactly cover abc on the side `normal` points to, each a slab
  -- `thickness` thick behind it; {} for a zero-area triangle.
  Surface.quadPieces(p00: Vector3, p10: Vector3, p01: Vector3, p11: Vector3, thickness: number): { Piece }
  -- p10 = next station, p01 = next profile point. One Block for a rectangle, else four Wedges.
  Surface.pieces(arena: ArenaConfig): { Piece }
  ```

**Wedge algorithm** (orientation verified above):
1. Let AB be the triangle's longest edge and C the opposite vertex. The foot D = A + ((C − A)·u)·u with u = unit(B − A). It always lies inside AB.
2. Split into the right triangles (D, A, C) and (D, B, C), each with its right angle at D.
3. Each right triangle (D, P, C) becomes one Wedge:
   - Axes: Z = unit(D − P), Y = unit(C − D), X = Y × Z.
   - Size: (thickness, |C − D|, |D − P|).
   - CFrame: `CFrame.fromMatrix((C + P)/2 − normal·thickness/2, X, Y, Z)`.
4. A half whose legs are shorter than 0.001 is skipped.

**Quad algorithm:**
- Normal: N = unit((p01 − p00) × (p10 − p00)), which points into the track for floors and walls alike.
- Rectangle test: |(p11 − p10) − (p01 − p00)| < 1e-3 and |unit(p01 − p00) · unit(p10 − p00)| < 1e-3.
- A rectangle becomes a Block: `CFrame.fromMatrix((p00 + p11)/2 − N·thickness/2, unit(p01 − p00), N)` with size (|p01 − p00|, thickness, |p10 − p00|).
- Any other quad becomes the triangles (p00, p01, p11) and (p00, p11, p10), each with the normal N.

**Sweep:** at each station d, the profile `Profile.points(arena, arena.stepHeight · stepBlend(d))` is placed with `Centerline.at(arena, d, u, y).Position`. Each pair of neighboring stations (the last pairs with the first) and each strip gives one quad.

- [ ] **Step 1: Write the failing tests**

`tests/shared/Arena/Geometry/Triangles.spec.luau`:

```lua
local function near(actual: Vector3, expected: Vector3)
	expect((actual - expected).Magnitude).toBeLessThan(1e-3)
end

-- The triangular face of a wedge on the side `normal` points to: right-angle corner, top corner, front corner.
local function face(piece: Types.Piece, normal: Vector3): { Vector3 }
	local half = piece.size / 2
	local side = if piece.cframe.RightVector:Dot(normal) > 0 then half.X else -half.X
	return {
		piece.cframe:PointToWorldSpace(Vector3.new(side, -half.Y, half.Z)),
		piece.cframe:PointToWorldSpace(Vector3.new(side, half.Y, half.Z)),
		piece.cframe:PointToWorldSpace(Vector3.new(side, -half.Y, -half.Z)),
	}
end

describe("Triangles.wedges", function()
	local a, b, c = Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(3, 0, 4)

	it("covers the triangle with two wedges that meet at the foot of its height", function()
		local wedges = Triangles.wedges(a, b, c, Vector3.yAxis, 1)
		expect(#wedges).toBe(2)
		local fronts = {}
		for _, wedge in wedges do
			local corners = face(wedge, Vector3.yAxis)
			near(corners[1], Vector3.new(3, 0, 0))
			near(corners[2], c)
			table.insert(fronts, corners[3])
		end
		table.sort(fronts, function(left: Vector3, right: Vector3): boolean
			return left.X < right.X
		end)
		near(fronts[1], a)
		near(fronts[2], b)
	end)

	it("hangs each wedge's slab behind the face, away from the normal", function()
		for _, wedge in Triangles.wedges(a, b, c, Vector3.yAxis, 1) do
			expect(wedge.shape).toBe("Wedge")
			expect(wedge.size.X).toBeCloseTo(1, 4)
			expect(wedge.cframe.Position.Y).toBeCloseTo(-0.5, 4)
		end
	end)

	it("works on a tilted plane and returns nothing for a degenerate triangle", function()
		local normal = Vector3.new(1, 1, 0).Unit
		local wedges = Triangles.wedges(Vector3.zero, Vector3.new(5, -5, 0), Vector3.new(1, -1, 6), normal, 0.5)
		expect(#wedges).toBe(2)
		for _, wedge in wedges do
			for _, corner in face(wedge, normal) do
				expect(math.abs(corner:Dot(normal))).toBeLessThan(1e-3)
			end
		end
		expect(Triangles.wedges(a, b, Vector3.new(20, 0, 0), Vector3.yAxis, 1)).toEqual({})
	end)
end)
```

`tests/shared/Arena/Geometry/Surface.spec.luau`:

```lua
local function near(actual: Vector3, expected: Vector3)
	expect((actual - expected).Magnitude).toBeLessThan(1e-3)
end

describe("Surface.quadPieces", function()
	it("makes one block for a flat rectangle, with its slab behind the surface", function()
		local pieces = Surface.quadPieces(Vector3.zero, Vector3.new(0, 0, -4), Vector3.new(5, 0, 0), Vector3.new(5, 0, -4), 1)
		expect(#pieces).toBe(1)
		expect(pieces[1].shape).toBe("Block")
		near(pieces[1].cframe.Position, Vector3.new(2.5, -0.5, -2))
		expect(pieces[1].cframe.UpVector.Y).toBeCloseTo(1, 4)
		near(pieces[1].size, Vector3.new(5, 1, 4))
	end)

	it("splits any other quad into four wedges", function()
		local pieces = Surface.quadPieces(Vector3.zero, Vector3.new(0, 0, -4), Vector3.new(5, 0, 0), Vector3.new(6, 1, -4), 1)
		expect(#pieces).toBe(4)
		for _, piece in pieces do
			expect(piece.shape).toBe("Wedge")
		end
	end)
end)

describe("Surface.pieces", function()
	it("sweeps the profile around the whole loop: blocks on flat rectangles, wedges everywhere else", function()
		local blocks, wedges = 0, 0
		for _, piece in Surface.pieces(Config.defaults().Arena) do
			if piece.shape == "Block" then
				blocks += 1
			elseif piece.shape == "Wedge" then
				wedges += 1
			end
		end
		-- Straights: 34 interior stations x 18 blocks, 6 blend stations x (8 blocks + 10 x 4 wedges).
		-- Curves: 42 flat stations x (2 wall blocks + 16 x 4 wedges), 6 blend stations x (1 block + 17 x 4 wedges).
		expect(blocks).toBe(1500)
		expect(wedges).toBe(6672)
	end)
end)
```

- [ ] **Step 2: Run to verify failure** — pattern `"(Triangles|Surface)"`: the modules are missing.
- [ ] **Step 3: Implement** the three modules with the algorithms above.
- [ ] **Step 4: Run to verify pass** — `passed = 6`. The full suite has `passed = 182`.
- [ ] **Step 5: Commit** — `feat(arena): sweep the profile into blocks and wedge triangles`. PR title: `feat(arena): swept surface`.

---

### Task 4: Gates, goal, markers, spawns, infield, and the geometry entry point

**Issue:** #45 · **Branch:** `feat/45-arena-features` · **Labels:** `feature`, `arena`

**Files:**
- Create: `src/shared/Arena/Geometry/Features.luau`, `src/shared/Arena/Geometry/init.luau`, `src/shared/Arena/Tags.luau`
- Modify: `src/shared/Arena/Geometry/Types.luau` (add `Goal`)
- Test: `tests/shared/Arena/Geometry/Features.spec.luau`, `tests/shared/Arena/Geometry.spec.luau`

**Interfaces:**
- Consumes: `Centerline`, `Profile` (Task 2); `Types.Piece` (Task 3); `Crossing.Rectangle` (Phase 2); `Team.Team`, `Team.list` (Phase 2).
- Produces:
  ```lua
  export type Goal = { frame: CFrame, openingRadius: number, rim: { Piece }, panel: Piece }  -- in Types.luau
  Features.gates(arena): { Crossing.Rectangle }
  -- Gate g: frame = frameAt(gateDistance(g)) + (0, outerWallHeight/2, 0), width = trackWidth, height = outerWallHeight.
  Features.goal(arena): Goal
  -- frame = Centerline.at(arena, gateDistance(goalGateIndex), trackWidth − wallGap − rimThickness − ringRadius,
  --         heightAboveFloor), so LookVector is the travel direction and oncoming skaters see its front.
  -- rim j (0-based): Block at frame * CFrame.Angles(0, 0, 2πj/n) * CFrame.new(0, ringRadius + rimThickness/2, 0),
  --   size (2·(ringRadius + rimThickness)·tan(π/n), rimThickness, rimThickness).
  -- panel: Cylinder at frame * CFrame.Angles(0, π/2, 0), size (panelThickness, 2·ringRadius, 2·ringRadius).
  Features.markers(arena): { Piece }
  -- Gate g: Block at Centerline.at(arena, gateDistance(g), trackWidth + surfaceThickness/2,
  --         outerWallHeight + marker.height/2), size (marker.width, marker.height, marker.width).
  Features.teamSpawns(arena, teamSize: number): { [Team]: { CFrame } }
  -- Blue on section 1 and Orange on section 3: Centerline.at(arena, middle + (i − (teamSize+1)/2)·teamSpawnSpacing,
  --   Profile.lowerFloorCenter(arena), 0) for i = 1..teamSize.
  Features.ballSpawns(arena): { CFrame }
  -- The middles of sections 2 and 4: Centerline.at(arena, middle, trackWidth/2, ballSpawnHeight).
  Features.infield(arena): { Piece }
  -- r = endRadius − trackWidth/2 − surfaceThickness. [1] Block at (0, H/2, 0) sized (straightLength, H, 2r) with
  -- H = infieldWallHeight. [2], [3]: Cylinders at (∓straightLength/2, H/2, 0) * CFrame.Angles(0, 0, π/2),
  -- sized (H, 2r, 2r).

  export type ArenaGeometry = {
  	surface: { Piece }, infield: { Piece }, gates: { Crossing.Rectangle }, goal: Goal,
  	markers: { Piece }, teamSpawns: { [Team]: { CFrame } }, ballSpawns: { CFrame },
  }
  Geometry.build(config: Config.GameConfig): ArenaGeometry  -- teamSpawns use config.Match.teamSize

  -- Arena/Tags.luau (frozen)
  Tags.LapGate, Tags.GoalHoop, Tags.GoalPanel, Tags.TeamSpawn, Tags.BallSpawn, Tags.CornerMarker
  Tags.Attribute = { GateIndex = "GateIndex", Team = "Team", OpeningRadius = "OpeningRadius" }
  ```

- [ ] **Step 1: Write the failing tests**

`tests/shared/Arena/Geometry/Features.spec.luau` (the same `near` helper as Task 3):

```lua
local arena = Config.defaults().Arena

describe("Features.gates", function()
	it("spans the track at each corner, facing the travel direction, as tall as the outer wall", function()
		local gates = Features.gates(arena)
		expect(#gates).toBe(4)
		near(gates[1].frame.Position, Vector3.new(80, 14, -60))
		near(gates[1].frame.LookVector, Vector3.new(-1, 0, 0))
		near(gates[3].frame.Position, Vector3.new(-80, 14, 60))
		expect(gates[2].width).toBe(44)
		expect(gates[2].height).toBe(28)
	end)
end)

describe("Features.goal", function()
	it("raises the ring on the outer wall at the goal gate, facing oncoming skaters", function()
		local goal = Features.goal(arena)
		near(goal.frame.Position, Vector3.new(-80, 18, -73))
		near(goal.frame.LookVector, Vector3.new(-1, 0, 0))
		expect(goal.openingRadius).toBe(7)
	end)

	it("rings the opening with the rim and covers it with the panel", function()
		local goal = Features.goal(arena)
		expect(#goal.rim).toBe(16)
		for _, piece in goal.rim do
			local offset = goal.frame:PointToObjectSpace(piece.cframe.Position)
			expect(offset.Magnitude).toBeCloseTo(7.5, 3)
			expect(offset.Z).toBeCloseTo(0, 3)
		end
		expect(goal.panel.shape).toBe("Cylinder")
		near(goal.panel.cframe.Position, goal.frame.Position)
		expect(math.abs(goal.panel.cframe.RightVector:Dot(goal.frame.LookVector))).toBeCloseTo(1, 4)
		near(goal.panel.size, Vector3.new(0.5, 14, 14))
	end)
end)

describe("Features markers, spawns and infield", function()
	it("stands a pillar on the outer wall top at each gate", function()
		local markers = Features.markers(arena)
		expect(#markers).toBe(4)
		near(markers[2].cframe.Position, Vector3.new(-80, 32, -82.5))
		near(markers[2].size, Vector3.new(2, 8, 2))
	end)

	it("lines each team up on the lower floor of its straight, mirrored across the long axis", function()
		local spawns = Features.teamSpawns(arena, 3)
		expect(#spawns.Blue).toBe(3)
		expect(#spawns.Orange).toBe(3)
		near(spawns.Blue[1].Position, Vector3.new(10, 0, -53))
		near(spawns.Blue[2].Position, Vector3.new(0, 0, -53))
		near(spawns.Blue[3].Position, Vector3.new(-10, 0, -53))
		near(spawns.Blue[1].LookVector, Vector3.new(-1, 0, 0))
		for index, blue in spawns.Blue do
			local orange = spawns.Orange[#spawns.Orange + 1 - index]
			near(orange.Position, Vector3.new(blue.Position.X, 0, -blue.Position.Z))
			near(orange.LookVector, -blue.LookVector)
		end
	end)

	it("drops the ball above the apex of each curved end, equally far from both teams", function()
		local balls = Features.ballSpawns(arena)
		expect(#balls).toBe(2)
		near(balls[1].Position, Vector3.new(-140, 6, 0))
		near(balls[2].Position, Vector3.new(140, 6, 0))
		local spawns = Features.teamSpawns(arena, 3)
		for _, ball in balls do
			expect((ball.Position - spawns.Blue[2].Position).Magnitude)
				.toBeCloseTo((ball.Position - spawns.Orange[2].Position).Magnitude, 4)
		end
	end)

	it("fills the infield up to the inner wall top, tucked behind the wall's slab", function()
		local pieces = Features.infield(arena)
		expect(#pieces).toBe(3)
		expect(pieces[1].shape).toBe("Block")
		near(pieces[1].cframe.Position, Vector3.new(0, 10, 0))
		near(pieces[1].size, Vector3.new(160, 20, 74))
		for index = 2, 3 do
			expect(pieces[index].shape).toBe("Cylinder")
			expect(math.abs(pieces[index].cframe.RightVector.Y)).toBeCloseTo(1, 4)
			near(pieces[index].size, Vector3.new(20, 74, 74))
		end
		near(pieces[2].cframe.Position, Vector3.new(-80, 10, 0))
		near(pieces[3].cframe.Position, Vector3.new(80, 10, 0))
	end)
end)
```

`tests/shared/Arena/Geometry.spec.luau`:

```lua
describe("Geometry.build", function()
	it("collects the whole arena, with one team spawn per team slot", function()
		local geometry = Geometry.build(Fixtures.config({ Match = { teamSize = 2 } }))
		expect(#geometry.surface).toBe(8172)
		expect(#geometry.infield).toBe(3)
		expect(#geometry.gates).toBe(4)
		expect(#geometry.markers).toBe(4)
		expect(#geometry.teamSpawns.Blue).toBe(2)
		expect(#geometry.teamSpawns.Orange).toBe(2)
		expect(#geometry.ballSpawns).toBe(2)
		expect(geometry.goal.openingRadius).toBe(7)
	end)
end)
```

- [ ] **Step 2: Run to verify failure** — patterns `"Features"` and `"Geometry.spec"`: the modules are missing.
- [ ] **Step 3: Implement** `Features`, `Geometry/init.luau` and `Tags` as specified above.
- [ ] **Step 4: Run to verify pass** — 7 + 1 tests. The full suite has `passed = 190`.
- [ ] **Step 5: Commit** — `feat(arena): place gates, goal, markers, spawns and the infield`. PR title: `feat(arena): arena features`.

---

### Task 5: Reading the tagged arena

**Issue:** #46 · **Branch:** `feat/46-tagged-layout` · **Labels:** `feature`, `arena`

**Files:**
- Create: `src/shared/Arena/TaggedLayout.luau`
- Test: `tests/shared/Arena/TaggedLayout.spec.luau`

**Interfaces:**
- Consumes: `Tags` (Task 4); `MatchEngine.ArenaLayout`, `Team.is` (Phase 2).
- Produces:
  ```lua
  export type TaggedArena = {
  	layout: MatchEngine.ArenaLayout,       -- gates sorted by GateIndex; goal = { frame = hoop:GetPivot(), radius = OpeningRadius }
  	goalPanel: BasePart,
  	markers: { BasePart },                 -- index = GateIndex
  	teamSpawns: { [Team]: { CFrame } },    -- each team's spawn parts' CFrames, sorted by part Name
  	ballSpawns: { CFrame },                -- sorted by part Name
  }
  TaggedLayout.read(root: Instance): TaggedArena  -- only tagged instances that are descendants of root
  ```
  A gate rectangle is `{ frame = part.CFrame, width = part.Size.X, height = part.Size.Y }`. Errors use `error(message, 0)`:
  - `TaggedLayout: LapGate GateIndex values must be 1..n without gaps or repeats (got <sorted list>)`
  - `TaggedLayout: expected exactly one GoalHoop, found <n>` and the same message for `GoalPanel`
  - `TaggedLayout: GoalHoop needs a positive OpeningRadius attribute`
  - `TaggedLayout: TeamSpawn "<name>" has Team "<value>"; expected Blue or Orange`
  - `TaggedLayout: CornerMarker GateIndex values must match the gates (got <sorted list>)`
  - `TaggedLayout: no BallSpawn found`

- [ ] **Step 1: Write the failing tests**

```lua
local ServerStorage = game:GetService("ServerStorage")

local roots: { Instance } = {}
afterEach(function()
	for _, root in roots do
		root:Destroy()
	end
	table.clear(roots)
end)

local function tagged(parent: Instance, name: string, tag: string, cframe: CFrame?, size: Vector3?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.CFrame = cframe or CFrame.identity
	part.Size = size or Vector3.one
	part:AddTag(tag)
	part.Parent = parent
	return part
end

-- A complete minimal arena, gates created in reverse so reading must sort them.
local function arenaRoot(): Folder
	local root = Instance.new("Folder")
	root.Name = "TaggedLayoutTest"
	for index = 4, 1, -1 do
		tagged(root, "Gate" .. index, Tags.LapGate, CFrame.new(100 * index, 0, 0), Vector3.new(44, 28, 0.2))
			:SetAttribute(Tags.Attribute.GateIndex, index)
		tagged(root, "Marker" .. index, Tags.CornerMarker):SetAttribute(Tags.Attribute.GateIndex, index)
	end
	local hoop = Instance.new("Model")
	hoop.Name = "GoalHoop"
	hoop.WorldPivot = CFrame.new(0, 18, -73)
	hoop:SetAttribute(Tags.Attribute.OpeningRadius, 7)
	hoop:AddTag(Tags.GoalHoop)
	hoop.Parent = root
	tagged(root, "GoalPanel", Tags.GoalPanel)
	tagged(root, "Blue1", Tags.TeamSpawn, CFrame.new(0, 0, -53)):SetAttribute(Tags.Attribute.Team, "Blue")
	tagged(root, "Orange1", Tags.TeamSpawn, CFrame.new(0, 0, 53)):SetAttribute(Tags.Attribute.Team, "Orange")
	tagged(root, "Ball1", Tags.BallSpawn, CFrame.new(-140, 6, 0))
	root.Parent = ServerStorage
	table.insert(roots, root)
	return root
end

describe("TaggedLayout.read", function()
	it("reads the gates in GateIndex order as rectangles the rules can use", function()
		local gates = TaggedLayout.read(arenaRoot()).layout.gates
		expect(#gates).toBe(4)
		for index, gate in gates do
			expect(gate.frame.Position).toEqual(Vector3.new(100 * index, 0, 0))
			expect(gate.width).toBe(44)
			expect(gate.height).toBe(28)
		end
	end)

	it("reads the goal's disc and panel, the markers and the spawns", function()
		local arena = TaggedLayout.read(arenaRoot())
		expect(arena.layout.goal.frame.Position).toEqual(Vector3.new(0, 18, -73))
		expect(arena.layout.goal.radius).toBe(7)
		expect(arena.goalPanel.Name).toBe("GoalPanel")
		expect(#arena.markers).toBe(4)
		expect(arena.markers[2].Name).toBe("Marker2")
		expect(arena.teamSpawns.Blue[1].Position).toEqual(Vector3.new(0, 0, -53))
		expect(arena.teamSpawns.Orange[1].Position).toEqual(Vector3.new(0, 0, 53))
		expect(arena.ballSpawns[1].Position).toEqual(Vector3.new(-140, 6, 0))
	end)

	it("ignores tagged instances outside the root", function()
		local root = arenaRoot()
		local stray = Instance.new("Folder")
		tagged(stray, "Gate5", Tags.LapGate):SetAttribute(Tags.Attribute.GateIndex, 5)
		stray.Parent = ServerStorage
		table.insert(roots, stray)
		expect(#TaggedLayout.read(root).layout.gates).toBe(4)
	end)

	it("rejects gates whose GateIndex values have gaps or repeats", function()
		local root = arenaRoot()
		root:FindFirstChild("Gate3"):SetAttribute(Tags.Attribute.GateIndex, 4)
		expect(function()
			TaggedLayout.read(root)
		end).toThrow("TaggedLayout: LapGate GateIndex values must be 1..n without gaps or repeats (got 1, 2, 4, 4)")
	end)

	it("rejects a missing goal and a second panel", function()
		local root = arenaRoot()
		tagged(root, "ExtraPanel", Tags.GoalPanel)
		expect(function()
			TaggedLayout.read(root)
		end).toThrow("TaggedLayout: expected exactly one GoalPanel, found 2")
		local other = arenaRoot()
		other:FindFirstChild("GoalHoop"):Destroy()
		expect(function()
			TaggedLayout.read(other)
		end).toThrow("TaggedLayout: expected exactly one GoalHoop, found 0")
	end)

	it("rejects a goal without an opening radius and a spawn with an unknown team", function()
		local root = arenaRoot()
		root:FindFirstChild("GoalHoop"):SetAttribute(Tags.Attribute.OpeningRadius, nil)
		expect(function()
			TaggedLayout.read(root)
		end).toThrow("TaggedLayout: GoalHoop needs a positive OpeningRadius attribute")
		local other = arenaRoot()
		other:FindFirstChild("Blue1"):SetAttribute(Tags.Attribute.Team, "Red")
		expect(function()
			TaggedLayout.read(other)
		end).toThrow('TaggedLayout: TeamSpawn "Blue1" has Team "Red"; expected Blue or Orange')
	end)

	it("rejects markers that don't match the gates and an arena with no ball spawn", function()
		local root = arenaRoot()
		root:FindFirstChild("Marker4"):Destroy()
		expect(function()
			TaggedLayout.read(root)
		end).toThrow("TaggedLayout: CornerMarker GateIndex values must match the gates (got 1, 2, 3)")
		local other = arenaRoot()
		other:FindFirstChild("Ball1"):Destroy()
		expect(function()
			TaggedLayout.read(other)
		end).toThrow("TaggedLayout: no BallSpawn found")
	end)
end)
```

(`FindFirstChild` results are cast with `:: Instance` where strict mode needs it; `afterEach` comes from `JestGlobals`.)

- [ ] **Step 2: Run to verify failure** — pattern `"TaggedLayout"`: the module is missing.
- [ ] **Step 3: Implement** `TaggedLayout.read`. A private helper collects `CollectionService:GetTagged(tag)` filtered by `instance:IsDescendantOf(root)`, so every tag lookup goes through one function.
- [ ] **Step 4: Run to verify pass** — `passed = 7`. The full suite has `passed = 197`.
- [ ] **Step 5: Commit** — `feat(arena): read the tagged arena into the rules' layout`. PR title: `feat(arena): tagged layout`.

---

### Task 6: Builder, ArenaService, and the arena in the place

**Issue:** #47 · **Branch:** `feat/47-arena-service` · **Labels:** `feature`, `arena`

**Files:**
- Create: `src/server/Arena/Builder.luau`, `src/server/ArenaService.luau`
- Modify: `src/server/Modules.luau` (add `ArenaService`), `README.md` (tests that build parts)
- Test: `tests/server/Arena/Builder.spec.luau`, `tests/server/ArenaService.spec.luau`, `tests/integration/Arena.spec.luau`

**Interfaces:**
- Consumes: `Geometry.build`, `ArenaGeometry`, `Tags` (Task 4); `TaggedLayout.read` (Task 5); `Config.GameConfig` (Task 1); `MatchEngine` (Phase 2).
- Produces:
  ```lua
  Builder.build(geometry: Geometry.ArenaGeometry, config: Config.GameConfig, parent: Instance): Model
  -- Model "Arena" with Folders Surface, Infield, Gates, Goal, Markers, Spawns.
  -- Validates every piece first: each size component finite and >= 0.001, each position finite, otherwise
  --   error('ArenaBuilder: <group> piece <i> is invalid (size <x, y, z>)', 0) with group one of
  --   surface / infield / goal rim / goal panel / marker. Nothing is created or parented then.
  -- Builds the model unparented and parents it to `parent` last.

  -- ArenaService (LoadableModule): name "ArenaService", dependencies { "Config" }
  ArenaService.model: Model?          -- set by init
  ArenaService.arena: TaggedArena?    -- TaggedLayout.read(model), set by init; Phase 4's MatchService reads it
  ArenaService:init(deps: { Config: Config.GameConfig })   -- builds into workspace
  ```

Part settings:
- **Every solid part:** `Anchored`, `CanCollide`, `Material = SmoothPlastic`, `TopSurface`/`BottomSurface = Smooth`. Piece shapes map to `Part` (Block), `WedgePart` (Wedge) and `Part` with `Shape = Cylinder` (Cylinder).
- **Colors:** `colors.surface`, `colors.infield`, `colors.goal` (rim and panel), `colors.marker`.
- **Gates:** `Part` named `Gate<g>`, `CFrame = gate.frame`, `Size = (width, height, 0.2)`, `Transparency = 1`, with `CanCollide`, `CanQuery` and `CanTouch` all false. Tag `LapGate`, attribute `GateIndex`.
- **Goal:**
  - `Model` named `GoalHoop` holding the `Rim<j>` parts, with `WorldPivot = goal.frame`, attribute `OpeningRadius`, and tag `GoalHoop`.
  - `GoalPanel` (the panel piece) with `Transparency = 0.3` and tag `GoalPanel`.
- **Markers:** `Marker<g>`, tag `CornerMarker`, attribute `GateIndex`.
- **Team spawns:** `<Team><i>` pads, `Size = (4, 0.2, 4)`, centered on the spawn CFrame, `Color = UI.teamColors[team]`, `Transparency = 0.4`, with `CanCollide`, `CanQuery` and `CanTouch` all false. Tag `TeamSpawn`, attribute `Team`.
- **Ball spawns:** `Ball<i>`, `Size = (1, 1, 1)`, invisible, with `CanCollide`, `CanQuery` and `CanTouch` all false. Tag `BallSpawn`.

- [ ] **Step 1: Write the failing tests**

`tests/server/Arena/Builder.spec.luau` (builds into a Folder in `ServerStorage`; no workspace needed):

```lua
local ServerStorage = game:GetService("ServerStorage")
local Builder = require(game:GetService("ServerScriptService").Server.Arena.Builder)

local config = Config.defaults()
local parent: Folder
beforeEach(function()
	parent = Instance.new("Folder")
	parent.Name = "BuilderTest"
	parent.Parent = ServerStorage
end)
afterEach(function()
	parent:Destroy()
end)

describe("Builder.build", function()
	it("builds one part per piece, grouped by what it is", function()
		local arena = Builder.build(Geometry.build(config), config, parent)
		expect(arena.Parent).toBe(parent)
		expect(#(arena:FindFirstChild("Surface") :: Folder):GetChildren()).toBe(8172)
		expect(#(arena:FindFirstChild("Infield") :: Folder):GetChildren()).toBe(3)
		expect(#(arena:FindFirstChild("Gates") :: Folder):GetChildren()).toBe(4)
		expect(#(arena:FindFirstChild("Markers") :: Folder):GetChildren()).toBe(4)
		expect(#(arena:FindFirstChild("Spawns") :: Folder):GetChildren()).toBe(8)
		local hoop = (arena:FindFirstChild("Goal") :: Folder):FindFirstChild("GoalHoop") :: Model
		expect(#hoop:GetChildren()).toBe(16)
	end)

	it("makes gates and spawns invisible to physics and queries, and solids smooth and anchored", function()
		local arena = Builder.build(Geometry.build(config), config, parent)
		local gate = (arena:FindFirstChild("Gates") :: Folder):FindFirstChild("Gate2") :: Part
		expect(gate.Transparency).toBe(1)
		expect(gate.CanCollide or gate.CanQuery or gate.CanTouch).toBe(false)
		expect(gate:GetAttribute("GateIndex")).toBe(2)
		local pad = (arena:FindFirstChild("Spawns") :: Folder):FindFirstChild("Blue1") :: Part
		expect(pad.CanCollide or pad.CanQuery or pad.CanTouch).toBe(false)
		expect(pad.Color).toEqual(config.UI.teamColors.Blue)
		for _, part in (arena:FindFirstChild("Surface") :: Folder):GetChildren() do
			local solid = part :: BasePart
			if not (solid.Anchored and solid.CanCollide and solid.TopSurface == Enum.SurfaceType.Smooth) then
				error(`{solid.Name} is not an anchored, colliding, smooth part`)
			end
		end
	end)

	it("leaves nothing behind when a piece is invalid", function()
		local geometry = Geometry.build(config)
		local broken = table.clone(geometry)
		broken.surface = table.clone(geometry.surface)
		broken.surface[2] = { shape = "Block", cframe = CFrame.identity, size = Vector3.new(0, 1, 1) }
		expect(function()
			Builder.build(broken, config, parent)
		end).toThrow("ArenaBuilder: surface piece 2 is invalid (size 0, 1, 1)")
		expect(#parent:GetChildren()).toBe(0)
	end)
end)
```

`tests/server/ArenaService.spec.luau`:

```lua
local ArenaService = require(game:GetService("ServerScriptService").Server.ArenaService)

describe("ArenaService", function()
	it("builds the arena into the workspace at init and exposes its tagged layout", function()
		ArenaService:init({ Config = Fixtures.config() })
		local model = ArenaService.model :: Model
		local ok, message = pcall(function()
			expect(model.Parent).toBe(workspace)
			expect(#(ArenaService.arena :: any).layout.gates).toBe(4)
		end)
		model:Destroy()
		if not ok then
			error(message, 0)
		end
	end)
end)
```

`tests/integration/Arena.spec.luau` builds once into a `workspace` folder (raycasts need the workspace):

```lua
local Builder = require(game:GetService("ServerScriptService").Server.Arena.Builder)

local config = Fixtures.config({ Match = { lapsToOpenGoal = 1, lapsForStreakPoint = 2 } })
local root: Folder
local arena: Model
local buildSeconds = 0

beforeAll(function()
	root = Instance.new("Folder")
	root.Name = "ArenaIntegrationTest"
	root.Parent = workspace
	local started = os.clock()
	arena = Builder.build(Geometry.build(config), config, root)
	buildSeconds = os.clock() - started
end)
afterAll(function()
	root:Destroy()
end)

local function cast(origin: Vector3, direction: Vector3): RaycastResult
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { arena }
	return workspace:Raycast(origin, direction, params) :: RaycastResult
end

describe("The generated arena", function()
	it("builds in under a second", function()
		expect(buildSeconds).toBeLessThan(1)
	end)

	it("puts the riding surface where the profile says, including the blend at a corner", function()
		local floors = {
			{ Vector3.new(30, 60, -53), 0 }, -- top straight, lower floor
			{ Vector3.new(30, 60, -70), 4 }, -- top straight, upper floor
			{ Vector3.new(30, 60, -63), 2 }, -- top straight, middle of the step
			{ Vector3.new(-80, 60, -63), 1 }, -- Gate 2: the step is half blended away
			{ Vector3.new(-130, 60, 0), 0 }, -- left curved end, flat floor
			{ Vector3.new(0, 60, 0), 20 }, -- infield top
		}
		for _, case in floors do
			local hit = cast(case[1], Vector3.new(0, -100, 0))
			expect(hit).never.toBeNil()
			expect(hit.Position.Y).toBeCloseTo(case[2], 2)
		end
		expect(cast(Vector3.new(30, 60, -63), Vector3.new(0, -100, 0)).Normal.Z).toBeGreaterThan(0)
	end)

	it("stands the walls where the profile says", function()
		local outer = cast(Vector3.new(30, 24, -60), Vector3.new(0, 0, -100))
		expect(outer.Position.Z).toBeCloseTo(-82, 2)
		local inner = cast(Vector3.new(30, 15, -60), Vector3.new(0, 0, 100))
		expect(inner.Position.Z).toBeCloseTo(-38, 2)
	end)

	it("lets the rules count a lap around the generated track and score through its goal", function()
		local tagged = TaggedLayout.read(arena)
		local engine = MatchEngine.new({ config = config, arena = tagged.layout, gravity = Fixtures.GRAVITY })
		engine:addPlayer("B1", "Blue")
		engine:start()
		engine:tick(3)
		engine:pickedUp("B1", Vector3.zero, Vector3.zero)
		local length = Centerline.length(config.Arena)
		local previous = Centerline.at(config.Arena, 1, 22, 5).Position
		for distance = 3, length + 1, 2 do
			local current = Centerline.at(config.Arena, distance, 22, 5).Position
			engine:ballMoved(previous, current)
			previous = current
		end
		local names = {}
		for _, event in engine:drainEvents() do
			table.insert(names, event.name)
		end
		expect(table.find(names, "LapCompleted")).never.toBeNil()
		expect(table.find(names, "GoalOpened")).never.toBeNil()
		local goal = tagged.layout.goal.frame
		engine:ballMoved(goal.Position - goal.LookVector * 2, goal.Position + goal.LookVector * 2)
		expect(engine:drainEvents()[1]).toMatchObject({ name = "GoalScored", team = "Blue", scorer = "B1" })
	end)
end)
```

(The files require `Config`, `Fixtures`, `Geometry`, `Centerline`, `TaggedLayout` and `MatchEngine` through `ReplicatedStorage`; `beforeAll`, `afterAll`, `beforeEach` and `afterEach` come from `JestGlobals`.)

- [ ] **Step 2: Run to verify failure** — patterns `"(Builder|ArenaService)"` and `"integration"`: the modules are missing.
- [ ] **Step 3: Implement** `Builder` and `ArenaService` as specified above. Append `ArenaService` to `src/server/Modules.luau`. In the README's Running tests section, add one sentence: tests under `tests/server` and `tests/integration` build parts under a temporary folder and remove them when they finish.
- [ ] **Step 4: Run to verify pass, then the full suite** — 3 + 1 + 4 tests. The full suite has `passed = 205`. Confirm the place keeps no test folders: `workspace` and `ServerStorage` have no `*Test` children afterwards.
- [ ] **Step 5: Playtest** — MCP `start_stop_play` (true), wait 3 s, `get_console_output`, then `execute_luau` in the `Server` DataModel returning `#workspace.Arena.Surface:GetChildren()`, then `start_stop_play` (false).
  Expected: exactly `[BloxChampions] Server ready: mode=NormalChampions, modules=1` and `[BloxChampions] Client ready: mode=NormalChampions, modules=0`, nothing else, and `8172` surface parts. Take one `screen_capture` of the arena for the PR.
- [ ] **Step 6: Commit** — `feat(arena): build the tagged arena at server start`, then `docs: note that arena tests build and remove parts`. PR title: `feat(arena): arena builder and service`.

Phase 3 is complete when the PRs for #42–#47 are merged, the full suite passes on `main` (205 tests), CI is green, and a playtest shows the arena with a clean console.
