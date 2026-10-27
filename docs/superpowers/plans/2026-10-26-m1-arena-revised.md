# M1 Overhaul, Part 1: The Arena (revised) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The arena becomes Roller Champions' enclosure:
- a wider track inside tall rideable glass walls that curl inward at the top;
- a per-map top (a glass roof, or an invisible ceiling) that holds every skater and the ball;
- glass panels hanging at the gates, the goal hanging from an arm, and a beam beside the ball carrier.

**Architecture:**
- **The pipeline stays.** The pure `Arena/Geometry` describes every piece from `Config.Arena`, and `server/Arena/Builder` turns the pieces into tagged parts. Client modules find what they light by tag.
- **Every cross-section lives in `Profile`.** It holds the solid section, the two glass sections with their lips, the top section of each kind, `topHeight` and the walls' top outline. `Surface.rings`/`Surface.sweep` sweep each of them around the loop, so they share one merge rule.
- **Two tags, two filters.** `RideSurface` (the floors, banks, walls and glass) goes into every ray (`RideSurfaces.params`). `Barrier` (the top) goes only into the collider sweep (`RideSurfaces.solid`).
- **One bounds rule** (`Bounds.inArena`, the box under `Profile.topHeight`) nets the ball and skaters. There is no reach check: the top holds everyone.

**Tech Stack:** Luau (`--!strict`), Rojo 7.7.1, StyLua 2.6.0, selene 0.32.0, luau-lsp 1.70.1, Jest Roblox 3.20.1, React Luau 17.3.13; CI with Python 3 (standard library) and Ruff 0.17.2.

**Spec:** `docs/superpowers/specs/2026-10-25-m1-arena-design.md` (revision approved 2026-10-26, main 979ce49).
- **It replaces the first plan's Tasks 2–6.** The first plan (`docs/superpowers/plans/2026-10-26-m1-arena.md`) stays as the record of Task 1 (#186, PR #192, built), and this plan stacks on it.
- It amends the M1 spec (decision A7).
- The reference is `docs/reference/2026-10-25-reference-games.md` ("Video 3").

**Execution:** Native (the owner's choice for this phase, 2026-10-26).

## Verified facts this plan relies on (2026-10-26)

1. **Task 1's arena** (PR #192, Studio probe on a clone of `Shared`):
   - 9,660 parts: surface 9,182 (150 blocks, 9,032 wedges), barriers 224, infield 221, goal 17, spawns 8, gates 4, markers 4;
   - `Geometry.build` takes 12.9 ms;
   - the suite is **680** tests; Task 2's uncommitted work adds 3 (focused run 48/48, 6 mutations caught; ledger).
2. **The new solid profile** (`Profile.stripCounts`'s rule, run in Python on the new sizes):
   - `{ 4, 1, 5, 1, 8, 1 }` strips for the bank, lower floor, step, upper floor, foot curve and outer wall: 21 points;
   - the joins are (0, 8), (8, 0), (36, 0), (54, 4), (62, 4), (80, 22), (80, 28);
   - the lower floor's middle is u 22.
3. **Stations:**
   - straights: 50 steps of 4;
   - curved ends: 48 steps of π·60/48 = 3.927 (`Centerline.sectionStations`);
   - the lap is 776.99 studs.
4. **The lips** (r 12, 4 strips):
   - the outer lip's points are (80, 108), (79.087, 112.592), (76.485, 116.485), (72.592, 119.087), (68, 120);
   - the inner lip mirrors them about u 40.
5. **Heights:**
   - a skater at `hardCap` peaks at about 77 studs (session 19, measured);
   - the lips start at 108.
6. **The step's blend at gate 2:**
   - the step is 3.1756 high at distance 196, 2 at 200 and 0.843 at 203.927;
   - its third strip spans t 0.4–0.6 of the step;
   - so the floor at u 45 lies within 0.69–2.08 just before the gate and 0.29–1.31 just after it (the same bounds as today's test).
7. **Roblox:**
   - "If true, other touching parts must also have CanTouch set to true for touch events to fire" (`BasePart.CanTouch`, read 2026-10-26);
   - `BallService.onTouched` ends a flight, and a pass's lift, on any non-character touch;
   - `Vector3` is native; writing `Position` and `Orientation` allocates nothing (earlier phases).
8. **Code read today:**
   - `RideSurfaces.params` serves every client ray; Task 2's uncommitted `solid` adds `Barrier`, and `SkateController.collide` sweeps on it;
   - `TaggedLayout` reads `CornerMarker` as parts; `ArenaParts.markers[g]` feeds `ArenaGlow` and `WorldMarkers`;
   - FrameController renders in this order: input overlays, camera, touch, HUD store, HUD, world markers, arena glow, name tags.
9. **Expected part count after Task 3** (to be measured):
   - surface about 8,000, glass 3,284 (the lips' 3,072 wedges dominate), top 386, middle 193, goal, gates, markers, spawns;
   - about 12,000 in all, under the pre-overhaul 15,666.

## Global Constraints

- **Everything from Phases 1–9 holds:**
  - `--!strict`; StyLua, selene and `bash scripts/analyze.sh` clean;
  - lines at most 120 columns, comments included;
  - relative requires in `src/`, service-path requires in tests, `JestGlobals` only;
  - selene rejects `assert(x)` without a message.
- **The pure core touches no Instance:** `src/shared/{Rules,Ball,Skate,Actions,Arena/Geometry,Config,Net/RateLimiter,Net/Schemas,Util,Camera,Input,Hud}`.
- **No gameplay or style literals** outside `src/shared/Config/*`. Algorithm bounds may be module constants with a reason.
- **Names and rules spelled once:**
  - `Profile.topHeight` (gates, bounds);
  - `Profile.top`, `Profile.innerGlass`, `Profile.outerGlass`, `Profile.topOutline`;
  - `Bounds.inArena` (the ball and skaters);
  - `Tags.Barrier` (the top) beside `Tags.RideSurface` (floors, banks, walls, glass);
  - `RideSurfaces.solid` (the sweep) beside `RideSurfaces.params` (every ray);
  - `Centerline.pose` (under `frameAt` and `at`).
- **Client modules are `Loader` modules** with an explicit exported type (`start: (...)?` when there is none) and an injectable `init(deps)`. FrameController is the one frame order.
- **No per-frame allocation** in `CarrierBeam.step`: measured in a plain probe, not in Jest.
- **Tests:**
  - instances live under a uniquely named `…Test` folder, removed in `afterEach`;
  - compare names or booleans, never an Instance that might fail;
  - after a RED run, check `workspace` for leftover `*Test` folders;
  - one mutation per guard, in Studio's Sources or scratch copies, never in Rojo-watched files.
- **Process:**
  - one issue and one stacked branch per task, `CONTRIBUTING.md` naming, one type label plus one area label;
  - commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, PR bodies with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`;
  - leave `- [ ] CI green` unticked;
  - merges are squash-only, after the owner's OK, replaying each next branch onto the new main.

## How tests run

- **Setup:** `rojo serve test.project.json` stays connected; tests run through `execute_luau` (Edit), the summary stored in `shared`.
- **Before trusting a run,** check that every script's Source equals its file (the sourcemap length list).
- **Totals:** the suite has **680 tests** at PR #192. Each task states its new total; a different total is a finding to rule on.
- **Ready lines:** the playtest console must read exactly `[BloxChampions] Server ready: mode=NormalChampions, modules=8` and `[BloxChampions] Client ready: mode=NormalChampions, modules=17`. From Task 6 on, the client's line reads `modules=18`.

## Review Focus

1. **A ball thrown hard into the roof** bounces back down, and its flight (a pass's lift included) ends on the touch: it never glides along the roof.
   - Task 2, Builder: `closes the arena with a top that skaters and the ball bounce off and touch, which no ray sees`.
   - Task 2, play check: a ball launched up ends its flight under the roof.
2. **A mode that switches `top.kind` to Open:**
   - the gates and `Bounds.inArena` rise to the ceiling;
   - the ceiling and its strips are invisible but stop the ball and skaters;
   - nothing slips out between a lip and the ceiling.
   - Tests: Task 2's `Features` and `Bounds` open cases, Task 2's Builder top test.
3. **A skater riding the glass around a curved end** (chords and wedges): the ground ray finds the glass, not a seam's side face.
   - Task 3, integration: `finds the glass from inside the track on a curved end, facing in`.
4. **An art model's corner marker that is a single part, not a Model,** still works for the server's check, the glow and the arrow.
   - Task 4, TaggedLayout: `reads a corner marker that is a model or a part`.
   - Task 4, ArenaParts: the same two shapes.
5. **The carrier skating around a curved end:** the beam stays upright on the outer glass, facing across the track, and hides the moment the ball is thrown.
   - Task 6, CarrierBeam: `moves with the ball around a curved end, upright and facing across the track` and `hides the beam while nobody carries the ball`.

## Decisions not spelled out in the spec (for owner review)

1. **Task 2 closes Task 1's arena first** (a roof at today's `barrier.top`, 85, across the glass faces), and Task 3 then lifts it onto the lips. So every task leaves an arena nobody can leave, and Task 2's uncommitted work (`RideSurfaces.solid`) lands with the top it serves. Cost if wrong: one task's re-pinned numbers.
2. **`Profile.top` runs from the outer side to the inner side** (continuing the "O" past the outer wall), so `Surface.sweep` hangs its slab above the roof, outside the track, as for every other section. Cost if wrong: none.
3. **`Geometry.build(config)` loses its gravity parameter, and `ArenaService` its `deps.Gravity`,** with the reach check (Task 2). Cost if wrong: none.
4. **Task 2's client tests describe a barrier, not glass** (the arena's top), and the SkateController test flies the collider up into a ceiling slab. They keep their meaning when the glass leaves the `Barrier` tag in Task 3. Cost if wrong: none.
5. **`Profile.topOutline(arena, u)` follows the lips as built** (straight between their points), so a gate panel's top edge meets the lip's chords and never pokes through. Cost if wrong: none.
6. **`ArenaParts.Parts.markers` becomes `{ [number]: Marker }`**, with `Marker = { parts: { BasePart }, position: Vector3 }`: the panel's parts (or the part itself), and the pivot's position (the opening's apex). Cost if wrong: one record.
7. **`Fixtures.hudArena` builds each marker as a Model of two parts** with its pivot set; one test adds a single-part marker. Cost if wrong: none.
8. **The goal's old placement tests are re-pinned in Task 3,** because the r-18 foot curve changes what fits:
   - a 4-segment rim cannot fit under the 28-stud wall top any more, so the segment loop runs `{ 5, 6, 16 }`;
   - the across case uses `wallGap = 70`, and the clear low ring 19.5.

   Task 5 replaces these tests. Cost if wrong: none.
9. **`CarrierBeam` is its own module,** and hides by `Transparency` 1, written on change only (as the first plan). Cost if wrong: none.

**Not in this part:** everything in the spec's §1.3 (Feel, Ball & rules, Presentation, art).

## File Structure

```
src/shared/Config/Arena.luau                  top, glass (replaces barrier), new sizes, gatePanel, goal.across/arm, rules
src/shared/Config/UI.luau                     arenaGlow.beam
src/shared/Arena/Tags.luau                    Barrier = the top; RideSurface includes the glass
src/shared/Arena/TaggedLayout.luau            markers as PVInstances
src/shared/Arena/Geometry/{init,Profile,Features,Bounds,Centerline,Types}.luau
src/shared/Arena/Geometry/Reach.luau          removed (Task 2)
src/server/Arena/Builder.luau                 folders Surface/Glass/Top/Infield/Gates/Goal/GatePanels/Spawns
src/server/ArenaService.luau                  no gravity
src/client/{RideSurfaces,SkateController,CameraController,ArenaParts,ArenaGlow,WorldMarkers,FrameController,Modules}.luau
src/client/CarrierBeam.luau                   new
tests/…                                        as each task lists
docs/superpowers/specs/2026-10-21-m1-foundation-core-match-design.md   §9.1–§9.3, §10.3, A2/A3/Q10 notes (Task 7)
docs/playtests/2026-10-26-m1-arena.md          the Studio checks and the owner's playtest (Task 7)
```

---

### Task 2: The arena's top (labels `feature`, `arena`)

**Issue:** #187 (reworded) · **Branch:** `feat/187-arena-top` (today's local `feat/187-glass-barrier`, renamed) · **Stacked on:** Task 1 (PR #192)

**Files:**
- Modify:
  - `src/shared/Config/Arena.luau`;
  - `src/shared/Arena/Tags.luau`;
  - `src/shared/Arena/Geometry/{init,Profile,Features,Bounds}.luau`;
  - `src/server/Arena/Builder.luau`, `src/server/ArenaService.luau`;
  - `src/client/{RideSurfaces,SkateController,CameraController}.luau` (Task 2's uncommitted work, re-aimed).
- Delete: `src/shared/Arena/Geometry/Reach.luau`, `tests/shared/Arena/Geometry/Reach.spec.luau`.
- Test:
  - `tests/shared/Config/Config.spec.luau`;
  - `tests/shared/Arena/Geometry/{Profile,Features,Bounds}.spec.luau`, `tests/shared/Arena/Geometry.spec.luau`;
  - `tests/server/Arena/Builder.spec.luau`, `tests/server/{ArenaService,BallService}.spec.luau`;
  - `tests/integration/Arena.spec.luau`;
  - `tests/client/{RideSurfaces,SkateController,CameraController}.spec.luau`.

**Interfaces:**
- **Produces:**
  ```lua
  -- Config.Arena.top = { kind = "Closed", ceilingAbove = 20 }   -- kind: "Closed" | "Open"; ceilingAbove a part size
  export type TopKind = "Closed" | "Open"                        -- Config/Arena
  Profile.top(arena: ArenaConfig): { Vector2 }      -- Closed: {(w, T), (0, T)}; Open: {(w, T), (w, T + c), (0, T + c), (0, T)}
  Profile.topHeight(arena: ArenaConfig): number     -- T (Closed) or T + c (Open); T = barrier.top until Task 3
  Features.top(arena: ArenaConfig): { Piece }       -- Profile.top swept around the loop, slabs surfaceThickness thick
  Geometry.build(config: Config.GameConfig): ArenaGeometry   -- adds top; no gravity, no reach check
  RideSurfaces.solid: RaycastParams                 -- Include: every RideSurface and Barrier, as of the last refresh
  RideSurfaces.destroy(self)                        -- stops following the tags (tests)
  ```
- **Removed:** `Reach`, `Geometry.build`'s gravity, `ArenaService`'s `deps.Gravity`.
- **Builder:**
  - folder `Top` tagged `Barrier`;
  - Closed: Material Glass, `colors.glass`, `barrier.transparency`; Open: `Transparency` 1;
  - both: `CanCollide`, `CanQuery`, `CanTouch` true, `CastShadow` false;
  - `validate` lists `top`.
- **Gates** are `Profile.topHeight` tall. **`Bounds.inArena`** ends at `Profile.topHeight + margin`.
- **Tags:** `Barrier`'s comment names the top (and, until Task 3, the glass).
- **Comments:**
  - nothing says the top is open;
  - SkateController's `CONTACT_PASSES` reads "a wall or a barrier, the floor it meets, and a third at a corner".

- [ ] **Step 1: Write the failing tests:**
  - **`Config.spec`:**
    - `match the spec's arena layout` expects `top = { kind = "Closed", ceilingAbove = 20 }`;
    - the rejection cases gain `top = { kind = "Lid" }` → `Arena.top.kind: must be one of Closed, Open (got "Lid")`;
    - the part-size cases gain `top = { ceilingAbove = 3000 }` → `Arena.top.ceilingAbove: must be <= 2048 (got 3000)`.
  - **`Profile.spec`** (+1) `closes the top across the track at the walls' top, or above it with an open map's ceiling`:
    - defaults: `Profile.top` is `{ (60, 85), (0, 85) }` and `topHeight` 85;
    - Open: `{ (60, 85), (60, 105), (0, 105), (0, 85) }` and `topHeight` 105.
  - **`Features.spec`** (+1):
    - the gates test reads `… as tall as the top` (height 85, frame y 42.5); with Open, height 105;
    - **new** `closes the arena with the top: a roof between the glass faces, or an open map's ceiling and its strips`:
      - Closed: 442 pieces, 2 blocks (one per straight) and 440 wedges (four per station step, 55 steps around each end); every face lies at y 85 between u 0 and 60, its slab above it;
      - Open: 666 pieces; the strips' faces lie at u 60 and u 0 from 85 to 105, and the ceiling's at y 105 between them.
  - **`Bounds.spec`:** the inside cases gain an open arena's (0, 106.5, 60); the outside cases gain an open arena's (0, 108, 60). The closed cases stay.
  - **`Geometry.spec`** (−1):
    - `collects the whole arena…` checks `#geometry.top` (442);
    - the refusal test is removed, with every `Geometry.build(…, GRAVITY)` call in the suite.
  - **`Reach.spec`** (−1): deleted with `Reach`.
  - **`ArenaService.spec`** (−1): the gravity refusal test is removed.
  - **`Builder.spec`** (+1):
    - the count test expects `Top` with `#geometry.top` parts;
    - **new** `closes the arena with a top that skaters and the ball bounce off and touch, which no ray sees`: the `Top` folder has `Barrier`; a closed part is glass (Material, colour, transparency); every part has `CanCollide`, `CanQuery` and `CanTouch` true and `CastShadow` false; with Open, `Transparency` 1;
    - the light test adds the top.
  - **`BallService.spec`:** the over-the-top respawn case reads `Profile.topHeight(config.Arena) + 5`.
  - **`integration/Arena.spec`:** `stands the walls, the glass and the roof…` adds a ray up from (30, 40, −70) that hits y 85 in the `Top` folder.
  - **`RideSurfaces.spec`** (+1, Task 2's uncommitted test) `keeps the barriers out of every ray, and in the collider's sweep`: comments say "barrier (the arena's top)".
  - **`SkateController.spec`** (+1) `slides under a barrier its collider reaches, which no ground ray sees`:
    - a ceiling slab tagged `Barrier` 0.5 studs above the collider's top;
    - the skater flying at (0, 72, −96) ends the step with no upward velocity, its −Z speed kept (`toBeCloseTo`, 1);
    - the tilted sheet half (no ground ray sees a barrier) stays as written.
  - **`CameraController.spec`** (+1) `looks through a barrier behind the skater` (Task 2's uncommitted test, reworded).
- [ ] **Step 2:** Run `testPathPattern = "(Arena|Config|BallService|MovementGuard|RideSurfaces|SkateController|CameraController)"`. Expected: FAIL (`top` unknown, `Profile.top` missing, `solid` nil).
- [ ] **Step 3:** Implement. Header comments: Profile, Features, Geometry, Bounds, Builder, Tags and ArenaService describe a closed arena (a roof, or an open map's ceiling); none mentions `Reach`, and none says the top is open.
- [ ] **Step 4:** Run, then the full suite. Expected: **683 tests** (680 + 1 Profile + 1 Features − 1 Geometry − 1 Reach − 1 ArenaService + 1 Builder + 3 client), all passing.
- [ ] **Step 5: Mutations,** each restored:
  - the open top without its strips → the Features open case;
  - `topHeight` ignoring Open → the Profile test, the Features gates' open case and the Bounds open cases;
  - the top's slab hung below its face → the Features closed case;
  - the top tagged `RideSurface` → the Builder top test;
  - the top untouchable → the Builder top test;
  - the top casting shadows → the light test;
  - an open top drawn visible → the Builder top test;
  - `solid` without barriers → the RideSurfaces and SkateController tests;
  - `params` with barriers → the RideSurfaces, SkateController and camera tests;
  - the face ray, or the sweep cast, on `params` → the SkateController test;
  - `solid` not following the Barrier tag → the RideSurfaces test.
- [ ] **Step 6: Play check (Studio):**
  - the console shows the two ready lines;
  - a probe launches the ball straight up at 230 studs/s under the roof: it bounces off the roof, its status leaves Flying on the touch, and it stays in play;
  - a probe launches the live skater up at `hardCap` beside the glass: its apex stays under 85;
  - screenshots of the roof (Edit capture).
- [ ] **Step 7:** Static checks (`checks.sh`). Commit `feat(arena): close the arena with a top, a glass roof or an open map's ceiling`.

---

### Task 3: Rideable glass with lips, a wider track and taller walls (labels `feature`, `arena`)

**Issue:** #193 · **Branch:** `feat/193-rideable-glass` · **Stacked on:** Task 2

**Files:**
- Modify:
  - `src/shared/Config/Arena.luau`;
  - `src/shared/Arena/Tags.luau`;
  - `src/shared/Arena/Geometry/{init,Profile,Features}.luau`;
  - `src/server/Arena/Builder.luau`.
- Test:
  - `tests/shared/Config/Config.spec.luau`;
  - `tests/shared/Arena/Geometry/{Profile,Surface,Features,Bounds,Centerline}.spec.luau`, `tests/shared/Arena/Geometry.spec.luau`;
  - `tests/server/Arena/Builder.spec.luau`;
  - `tests/integration/{Arena,Match}.spec.luau`.

**Interfaces:**
- **Consumes:** `Profile.top`, `Profile.topHeight`, `Features.top`, the `Top` folder (Task 2).
- **Produces:**
  ```lua
  -- Config.Arena: endRadius 60, trackWidth 80, wallCurveRadius 18, stepWidth 18, upperFloorWidth 8;
  -- barrier removed; glass = { top = 120, lipRadius = 12, lipStrips = 4, transparency = 0.7 }
  Profile.innerGlass(arena: ArenaConfig): { Vector2 }  -- the inner lip's lipStrips + 1 points from (r, top), then (0, innerBankHeight)
  Profile.outerGlass(arena: ArenaConfig): { Vector2 }  -- (w, outerWallHeight), then the outer lip's points from (w, top − r) to (w − r, top)
  -- Profile.top now runs between the lips' ends: (w − r, top) … (r, top); topHeight from glass.top
  Features.glass(arena: ArenaConfig): { Piece }   -- both glass sections swept, slabs surfaceThickness thick
  -- ArenaGeometry: surface, glass, top, infield, gates, goal, markers, teamSpawns, ballSpawns (no barriers)
  ```
- **Removed:** `Features.barriers`, `ArenaGeometry.barriers`, the `Barriers` folder, `Arena.barrier`.
- **The lips:**
  - quarter circles of radius `glass.lipRadius`, centred (r, top − r) and (w − r, top − r);
  - each has `lipStrips + 1` points evenly spaced by angle, from vertical to horizontal.
- **Builder:**
  - folder `Glass` tagged `RideSurface`, with the glass look of spec §4.1: Material Glass, `colors.glass`, `glass.transparency`, `CastShadow` false, `CanCollide`, `CanQuery` and `CanTouch` true;
  - `Top`'s closed look takes `glass.transparency`.
- **Config rules** (spec §3.3, exact messages):
  - rule 2 uses `surfaceThickness`: `endRadius must leave room for the infield behind the inner glass`;
  - rule 4: `the glass must rise above the inner bank's and the outer wall's tops before its lip`;
  - rule 5: `the lips must leave the top open between them`.
- **`Features.infield`** sits behind the inner glass slab (`surfaceThickness`).
- **Tags:** `RideSurface` names "the floors, the banks, the walls and the glass"; `Barrier` "the arena's top".

- [ ] **Step 1: Write the failing tests:**
  - **`Config.spec`:**
    - `match the spec's arena layout` expects the new values above;
    - rule 1's case is `trackWidth = 52`;
    - rule 2's thickness case is `{ endRadius = 41.2, surfaceThickness = 1.5 }`;
    - rule 4: `glass = { top = 40 }`, and the bank half `{ innerBankHeight = 30, glass = { top = 41 } }`;
    - rule 5: `glass = { lipRadius = 40 }`;
    - field cases `glass = { lipStrips = 0 }` → `Arena.glass.lipStrips: must be >= 1 (got 0)`, and `glass = { top = 3000 }` → `Arena.glass.top: must be <= 2048 (got 3000)` (replacing the `barrier.thickness` case).
  - **`Profile.spec`** (+1):
    - strip counts `{ 4, 1, 5, 1, 8, 1 }`, 21 points;
    - the joins (0, 8), (8, 0), (36, 0), (54, 4), (62, 4), (80, 22), (80, 28); `lowerFloorCenter` 22;
    - the bank's points 8 from (8, 8), the foot curve's 18 from (62, 22);
    - the step's points p8 and p10 at t 0.4 and 0.8;
    - flat: points 5–12 at y 0, p20 (80, 18);
    - **new** `curls each glass wall into a lip at the top, ending where the top begins`: `outerGlass` is (80, 28), (80, 108), (79.087, 112.592), (76.485, 116.485), (72.592, 119.087), (68, 120) within 1e-3; `innerGlass` mirrors it, from (12, 120) to (0, 8);
    - the top test re-pinned: Closed `{ (68, 120), (12, 120) }`; Open `{ (68, 120), (68, 140), (12, 140), (12, 120) }`; `topHeight` 120 and 140.
  - **`Surface.spec`:**
    - the two `Surface.build` tests pin the counts the new build gives (read once, ledger);
    - whole blocks are the bank's 4 strips and the lower floor, per straight; the "between" blocks (176 long) are the step's 5, the upper floor, the foot's 8 and the wall;
    - the lower floor block at (0, −0.5, −42).
  - **`Features.spec`** (+1):
    - the barrier tests become `rises from both solid tops into rideable glass up to the lips, each a slab behind its face` and **new** `sweeps the vertical glass as one block per station step and per side along each straight, and each lip in lipStrips strips`. Totals: vertical glass 4 + 192 blocks, lips 16 blocks + 3,072 wedges;
    - gates: gate 1 at (100, 60, −60), gate 3 at (−100, 60, 60), width 80, height 120 (Open 140);
    - top: Closed 2 blocks + 384 wedges at y 120 between u 12 and 68; Open adds the strips (u 68 and 12, 120 → 140);
    - the goal (wallGap placement until Task 5): frame (−100, 18, −91); the segment loop `{ 5, 6, 16 }` at height 20; the across case `wallGap = 70`; the clear low ring 19.5;
    - the markers stay at (−100, 24, −99.5);
    - spawns Blue (10, 0, −42), (0, 0, −42), (−10, 0, −42); balls (−160, 6, 0) and (160, 6, 0);
    - the infield block (0, −0.5, 0) of (200, 1, 38), and the fans within 19 of each end's centre, meeting the inner glass slab's back at every station.
  - **`Bounds.spec`:**
    - inside: (0, 2.5, 42), (0, 8, 20.5), (0, 60, 99), (0, 121.5, 70), (−160, 2.5, 0), (0, −1.5, 42); Open (0, 141.5, 70);
    - outside: (0, 60, 103), (−203, 5, 0), (0, 60, 17), (0, 30, 0), (0, −3, 42), (0, 123, 60); Open (0, 143, 60).
  - **`Centerline.spec`:** re-pinned to the new defaults (gates at x ±100, z ∓60; length 776.99). No test added or removed.
  - **`Geometry.spec`:** `collects…` expects `glass` (3,284), `top` (386) and `infield` (193) and no `barriers`.
  - **`Builder.spec`:**
    - the count test reads `Glass` (and no `Barriers`);
    - the glass test becomes `makes the glass a ride surface that looks like glass, which skaters, the ball and touches all meet`;
    - `tags the riding surfaces…` expects `{ "Glass", "Surface" }`;
    - the light test covers `Glass` and `Top`;
    - the invalid-piece test uses `glass`.
  - **`integration/Arena.spec`** (+0):
    - floors: lower (30, 60, −42) → 0, upper (30, 60, −78) → 4, mid-step (30, 60, −65) → 2, gate 2 (−100, 60, −65) → 1, curved end (−160, 60, 0) → 0, the middle (0, 60, 0) → 0 and (−110, 60, 10) → 0;
    - the step-normal ray at (30, 60, −61.4);
    - holes: distance 241.2 across u { 22, 37.8, 41.4, 45, 48.6, 52.2, 58 } → 0; at u 45, distance 198 within (0.69, 2.08) and 202 within (0.28, 1.31);
    - walls: the solid wall at y 25 → z −100 (`Surface`); the outer glass at y 60 → z −100 (`Glass`); the inner glass at y 60 → z −20 (`Glass`); the outer lip at y 115 → z −97.48 (`Glass`, 2 places); the roof straight up from (30, 60, −60) → y 120 (`Top`);
    - **`finds the glass from inside the track on a curved end, facing in`** (in the walls test). A ray at y 60 points from the left end's centre (−100, 60, 0) toward the middle of the chord just past the apex (1.875° on, half a 3.75° station step: not a seam). It starts 40 studs out, on the track's middle, and hits the glass 99.95 studs from the centre, in `Glass`, its normal pointing back at the centre (dot > 0.99).
  - **`integration/Match.spec`:** unchanged (`MIDDLE = trackWidth / 2`); its perf loop stays on the upper floor (`MIDDLE + 13` is u 53, on the step's top: moved to `MIDDLE + 18`, u 58, the upper floor).
- [ ] **Step 2:** Run `testPathPattern = "(Arena|Config|Centerline|Match)"`. Expected: FAIL (the new keys unknown, `Profile.outerGlass` missing, the counts).
- [ ] **Step 3:** Implement. Header comments: Profile describes the solid section, the glass with its lips and the top; Features, Builder, Tags and Config say "rideable glass"; nothing says the glass is a barrier.
- [ ] **Step 4:** Run, then the full suite. Expected: **685 tests** (+1 Profile, +1 Features), all passing.
- [ ] **Step 5: Mutations,** each restored:
  - the lip curling outward → the Profile lip test;
  - the lip's points evenly spaced in u instead of by angle → the Profile lip test;
  - `Profile.top` from the glass faces, not the lips' ends → the Profile top test and the Features top test;
  - the glass tagged `Barrier` → the Builder tag test;
  - the glass untouchable → the Builder glass test;
  - the glass casting shadows → the light test;
  - the infield behind a 2-stud slab → the infield tests;
  - rule 4 without the lip → its rejection;
  - rule 5 removed → its rejection.
- [ ] **Step 6: Play check (Studio):**
  - the console shows the two ready lines;
  - the built arena's part count (expected about 12,000, under 15,666), and `Geometry.build`'s time;
  - a lap at a held 60 studs/s along the centerline (the session-20 probe): its time, expected about 13 s;
  - the live skater driven up the outer glass at `hardCap` (Scriptable bindings): it rides the glass (grounded on a `Glass` part), peaks under the lips, and comes back to the floor;
  - #176's runs: 18 launches into the walls at 120–140 studs/s from y 25–60; nobody gets out;
  - screenshots of a straight and a curved end (Edit captures).
- [ ] **Step 7:** Static checks. Commit `feat(arena): rideable glass walls with lips, a wider track and taller walls`.

---

### Task 4: Glass panels at the gates (labels `feature`, `arena`)

**Issue:** #188 (reworded) · **Branch:** `feat/188-gate-panels` · **Stacked on:** Task 3

**Files:**
- Modify:
  - `src/shared/Config/Arena.luau` (`marker` → `gatePanel`, `colors.marker` removed, rule 6);
  - `src/shared/Arena/Geometry/{init,Profile,Features}.luau`;
  - `src/shared/Arena/TaggedLayout.luau`;
  - `src/server/Arena/Builder.luau`;
  - `src/client/{ArenaParts,ArenaGlow,WorldMarkers}.luau`;
  - `tests/Fixtures.luau`.
- Test:
  - `tests/shared/Config/Config.spec.luau`;
  - `tests/shared/Arena/Geometry/{Profile,Features}.spec.luau`, `tests/shared/Arena/TaggedLayout.spec.luau`;
  - `tests/server/Arena/Builder.spec.luau`;
  - `tests/client/{ArenaParts,ArenaGlow,WorldMarkers}.spec.luau`.

**Interfaces:**
- **Consumes:** `colors.glass`, `glass.transparency`, the lips (Task 3).
- **Produces:**
  ```lua
  -- Config.Arena.gatePanel = { openingHeight = 60, depth = 2, segments = 16 }  (segments: whole, >= 3)
  Profile.topOutline(arena: ArenaConfig, u: number): number  -- the walls' top as built: the lips' chords, glass.top between
  Features.gatePanels(arena: ArenaConfig): { { pieces: { Piece }, apex: CFrame } }  -- by gate index; replaces markers
  -- ArenaGeometry.gatePanels replaces markers
  -- TaggedArena.markers: { PVInstance }   (a Model or a part, by GateIndex)
  export type Marker = { parts: { BasePart }, position: Vector3 }   -- ArenaParts
  -- ArenaParts.Parts.markers: { [number]: Marker }
  -- Fixtures.HudArena.markers: { Model }  (two parts each, pivot set)
  ```
- **The panel** (spec §5.2):
  - slice k of `segments` spans u from `k·w/segments` to `(k+1)·w/segments`, in the gate's plane;
  - its bottom edge is on the opening, `y = outerWallHeight + (openingHeight − outerWallHeight)·sqrt(1 − ((u − w/2)/(w/2))²)`;
  - its top edge is on `Profile.topOutline`;
  - each slice is a quad given to `Surface.quadPieces` with `gatePanel.depth` as its thickness;
  - `apex` is `Centerline.at(gateDistance, w/2, openingHeight)` (the gate's frame, facing the travel direction).
- **Config rule 6:** `the gate panel's opening must stand between the outer wall's top and the lips`.
- **The Builder:**
  - folder `GatePanels`; Model `GatePanel<g>` (`WorldPivot = apex`) tagged `CornerMarker`, attribute `GateIndex`;
  - parts with the glass look, `CanCollide`, `CanQuery` and `CanTouch` false, `CastShadow` false;
  - the `Markers` folder is gone.
- **TaggedLayout:** `byGateIndex` takes the cast to apply. Gates use parts; markers use `PVInstance`, with the failure `CornerMarker "<name>" must be a model or a part`.
- **ArenaParts:** a marker's parts are its BasePart descendants, or itself when it is a part; `position = marker:GetPivot().Position`.
- **ArenaGlow:** lights and restores every part of a marker; `_looks` keeps each part's first look as today.
- **WorldMarkers:** aims at `marker.position`.

- [ ] **Step 1: Write the failing tests:**
  - **`Config.spec`:**
    - `match the spec's arena layout` expects `gatePanel` and no `marker`;
    - the colours test drops `marker`;
    - the rejection cases gain `gatePanel = { segments = 2 }` → `Arena.gatePanel.segments: must be >= 3 (got 2)`, and rule 6's `gatePanel = { openingHeight = 110 }`;
    - the part-size test gains `gatePanel = { depth = 2500 }`.
  - **`Profile.spec`** (+1) `follows the walls' top as built across the track: the lips' chords, and glass.top between them`:
    - `topOutline` gives 108 at u 0 and 80, 120 at u 12, 40 and 68, and 116.485 at u 76.485;
    - at u 6, it is the chord's value between (3.515, 116.485) and (7.408, 119.087).
  - **`Features.spec`** (+1):
    - `hangs a flat panel…` becomes `fills each gate with glass from the walls' top down to a rounded opening`. For gate 1, in the gate's frame (x = u − 40):
      - every face corner lies within `gatePanel.depth` of the gate's plane;
      - the lowest corners are y 28 at x ±40 and y 60 at x 0;
      - the highest are 120 for |x| ≤ 28, and 108 at x ±40;
    - **new** `builds each panel from gatePanel.segments slices, in gate order`: 64 pieces per panel (no slice is a rectangle), 4 panels whose apexes are `Centerline.at(gateDistance(g), 40, 60)`.
  - **`TaggedLayout.spec`** (+1):
    - `reads the goal's disc and panel, the markers and the spawns` with model markers;
    - **new** `reads a corner marker that is a model or a part`;
    - the non-part rejection case now tags a Folder as `CornerMarker` → `CornerMarker "X" must be a model or a part`.
  - **`Builder.spec`** (+1):
    - the count test reads `GatePanels` (4 models of 64 parts) instead of `Markers`;
    - **new** `makes each gate's panel a model carrying CornerMarker and its GateIndex, of glass nothing hits, sees or touches`.
  - **`ArenaParts.spec`:** the first test expects `markers[2].parts` (two parts) and `markers[2].position` (the pivot). A single-part marker gives `{ part }` and its position.
  - **`ArenaGlow.spec`:** `lights every part of the next gate's panel for the team with the ball, and none before their first gate`.
  - **`WorldMarkers.spec`:** `points the carrier to their team's next gate, and nobody else` aims at the marker model's pivot.
- [ ] **Step 2:** Run `testPathPattern = "(Arena|Config|TaggedLayout|ArenaParts|ArenaGlow|WorldMarkers)"`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run, then the full suite. Expected: **689 tests** (+1 Profile, +1 Features, +1 TaggedLayout, +1 Builder).
- [ ] **Step 5: Mutations:**
  - the opening as a straight line between the feet → the Features shape test;
  - the top edge at glass.top across the whole track → the shape test (108 at the faces);
  - `topOutline` on the lip's circle, not its chords → the Profile outline test;
  - slices not following `gatePanel.segments` → the slices test;
  - panel parts that collide → the Builder panel test;
  - markers read as parts only → the TaggedLayout model test;
  - ArenaParts taking the model as a part → the ArenaParts test;
  - ArenaGlow lighting only the first part → the ArenaGlow test;
  - the arrow aimed at the first part → the WorldMarkers test.
- [ ] **Step 6: Play check (Studio):** with the ball carried by a probe:
  - the next gate's panel glows in the team's colour, and the arrow points at its apex;
  - a skater passes through the opening untouched;
  - screenshots;
  - the console shows the two ready lines.
- [ ] **Step 7:** Static checks. Commit `feat(arena): glass panels hang across the gates, lit for the next one`.

---

### Task 5: The goal hangs over the track (labels `feature`, `arena`)

**Issue:** #189 · **Branch:** `feat/189-hanging-goal` · **Stacked on:** Task 4

**Files:**
- Modify:
  - `src/shared/Config/Arena.luau` (`goal.wallGap` → `goal.across`, `goal.arm`);
  - `src/shared/Arena/Geometry/{Features,Types}.luau`;
  - `src/server/Arena/Builder.luau`.
- Test: `tests/shared/Config/Config.spec.luau`, `tests/shared/Arena/Geometry/Features.spec.luau`, `tests/server/Arena/Builder.spec.luau`; `tests/integration/Match.spec.luau` if its goal approach needs it.

**Interfaces:**
- **Produces:**
  ```lua
  -- Config.Arena.goal: ringRadius 7, heightAboveFloor 18, panelThickness 0.5, panelTransparency 0.3, rimThickness 1,
  -- rimSegments 16, across = 0.75 (0..1, the ring's centre as a fraction of trackWidth from the inner glass),
  -- arm = { thickness = 1, height = 40 }
  export type Goal = { frame: CFrame, openingRadius: number, rim: { Piece }, panel: Piece, arm: { Piece } }
  ```
- **Placement:** the ring's centre is at `Centerline.at(arena, gateDistance(goalGateIndex), across · trackWidth, heightAboveFloor)`, facing the travel direction (today's frame rule).
- **Fit failures** (exact messages, in order):
  - `Arena: the goal ring must stay inside the glass` (the rim's corners beyond u 0 or u w);
  - `Arena: the goal ring must clear the track's surface at the goal gate`;
  - `Arena: the goal ring must hang under its arm` (the rim's top reaching `arm.height`);
  - `Arena: the goal's arm must stay under the lips` (`arm.height` reaching `glass.top − lipRadius`).
- **The arm:**
  - a post `arm.thickness` square from the rim's top (`heightAboveFloor + ringRadius + rimThickness`) up to `arm.height`;
  - a beam at `arm.height` from the post's centre out to the outer glass's face (u w);
  - both in the gate's plane.

  Builder: ghost parts (no collision, query or touch, visible, `colors.goal`), in the `Goal` folder.

- [ ] **Step 1: Write the failing tests:**
  - **`Config.spec`:**
    - the goal defaults expect `across` and `arm`, and no `wallGap`;
    - the rejection cases gain `goal = { across = 1.2 }` → `Arena.goal.across: must be <= 1 (got 1.2)`;
    - the `wallGap` case is gone.
  - **`Features.spec`** (+1):
    - `raises the ring on the outer wall…` becomes `hangs the ring over the track at the goal gate, goal.across of the way to the outer glass, facing oncoming skaters`: frame (−100, 18, −80), LookVector (−1, 0, 0);
    - the wallGap test becomes `keeps the rim inside the glass, judged by its corners, whatever its number of segments`. With `heightAboveFloor = 60` and `arm = { height = 80 }` (clear of the floor and the arm), set `across = 0.89375`: the ring's centre is at u 71.5, its inscribed circle 0.5 inside the outer glass. It fits for rimSegments 4 and 16 (a face toward the glass) and fails for 5 and 6 (a corner toward it, reaching 9.405 and 9.238);
    - `rejects a ring outside the glass or over its arm`: `across = 0.05` and `0.95` → inside-the-glass failure; `arm = { height = 25 }` → the arm failure;
    - `rejects a low ring whose rim would cut into the floor under it`: `heightAboveFloor = 9`;
    - **new** `hangs the ring from an arm: a post from the rim's top, and a beam out to the outer glass, under the lips`: the post's centre at u 60, y 33, 14 tall; the beam's at u 70, y 40, 20 long; `arm = { height = 110 }` → the lips failure.
  - **`Builder.spec`** (+1): **new** `builds the goal's arm from blocks nothing hits, sees or touches`; the count test adds 2 arm parts.
- [ ] **Step 2:** Run `testPathPattern = "(Arena|Config|Match)"`. Expected: FAIL.
- [ ] **Step 3:** Implement. Features' goal comments describe the hanging ring; the old "on the carrier's right shoulder" and "wallGap" text is gone.
- [ ] **Step 4:** Run, then the full suite. Expected: **691 tests** (+2).
- [ ] **Step 5: Mutations:**
  - the ring placed by `wallGap`'s old rule → the hanging test;
  - the inside-the-glass check on the inscribed circle, not the corners → the segments test;
  - the arm check removed → its rejection;
  - the lips check removed → its rejection;
  - an arm that collides → the Builder arm test;
  - the arm's beam stopping short of the outer glass → the arm test.
- [ ] **Step 6: Play check (Studio):**
  - a skater passes under the ring on the upper floor, measured clear;
  - a probe-carried ball through the open ring scores (the console shows the goal events, then the two ready lines only);
  - screenshots.
- [ ] **Step 7:** Static checks. Commit `feat(arena): hang the goal ring over the track from an arm`.

---

### Task 6: The carrier's beam (labels `feature`, `ui`)

**Issue:** #190 · **Branch:** `feat/190-carrier-beam` · **Stacked on:** Task 5

**Files:**
- Create: `src/client/CarrierBeam.luau`, `tests/client/CarrierBeam.spec.luau`.
- Modify:
  - `src/shared/Arena/Geometry/Centerline.luau`;
  - `src/shared/Config/UI.luau`;
  - `src/client/{FrameController,Modules}.luau`.
- Test: `tests/shared/Arena/Geometry/Centerline.spec.luau`, `tests/shared/Config/Config.spec.luau`, `tests/client/FrameController.spec.luau`.

**Interfaces:**
- **Consumes:** `BallCarrier.carrier`, `BallPart:get()`, `HudStore.state.match.possessingTeam`, `Config.Arena`, `Config.UI.teamColors`.
- **Produces:**
  ```lua
  -- Centerline (pure)
  Centerline.pose(arena: ArenaConfig, distance: number, lateral: number, height: number): (Vector3, number)
  -- the point, and the heading's yaw in radians (atan2 of -heading.X, -heading.Z: Roblox's Orientation Y)
  Centerline.distanceOf(arena: ArenaConfig, position: Vector3): number   -- 0 <= d < length; inverse of frameAt
  -- frameAt and at are built on pose (one rule).
  -- Config.UI.arenaGlow.beam = { width = 2, thickness = 0.5 }
  export type CarrierBeam = {
      name: string, dependencies: { string }, init: (self, deps) -> (), start: (self) -> (),
      step: (self, dt: number) -> (), destroy: (self) -> (), part: BasePart,
  }
  -- deps: Config, BallCarrier, BallPart, HudStore; deps.Parent replaces workspace in tests.
  ```
- **The part:**
  - a Part built at `start` (Anchored, Neon via `arenaGlow.material`, `CanCollide`, `CanQuery` and `CanTouch` false, `CastShadow` false);
  - size (`beam.thickness`, `glass.top − glass.lipRadius − outerWallHeight` = 80, `beam.width`);
  - placed at `lateral = trackWidth − beam.thickness / 2`, `height = (outerWallHeight + glass.top − glass.lipRadius) / 2` (68).
- **`step`:**
  - with a carrier and a ball part, `d = distanceOf(ball.Position)`, then `pose`;
  - writes `Position` and `Orientation` (`Vector3.new(0, deg(yaw), 0)`), and the team colour when it changes;
  - `Transparency` 0;
  - otherwise `Transparency` 1, written on change only.
- **FrameController** renders it after `arenaGlow`. `Modules` lists it after ArenaGlow.

- [ ] **Step 1: Write the failing tests:**
  - **`Centerline.spec`** (+2):
    - `finds how far along the track a point is, on both straights and around both ends`: for distances 0, 50, 230, 400, 560 and 700, `distanceOf(at(d, 40, 5).Position)` is d (`toBeCloseTo`, 3); a point at distance length − 0.01 wraps near length;
    - `poses a point and its heading in plain numbers, the same as frameAt`: at 0, 250 and 700 the point equals `at(…).Position`, and the yaw gives `frameAt`'s LookVector.
  - **`Config.spec`:** the UI defaults expect `arenaGlow.beam`; the rejection cases gain `UI = { arenaGlow = { beam = { width = 0 } } }` → `UI.arenaGlow.beam.width: must be > 0 (got 0)`.
  - **`CarrierBeam.spec`** (new, +5), with fakes for BallCarrier, BallPart (a part in the test folder) and HudStore:
    - `hides the beam while nobody carries the ball`;
    - `stands the beam on the outer glass beside the carried ball, in the possessing team's colour`: position and size from config, colour Orange;
    - `moves with the ball around a curved end, upright and facing across the track`: the part's UpVector is (0, 1, 0), and its RightVector or LookVector lies across the track there (`toBeCloseTo`, 3);
    - `writes the colour and the transparency only when they change`: `GetPropertyChangedSignal` counts;
    - `steps in under 0.1 ms`: an untimed step, then 600.
  - **`FrameController.spec`:** the render order includes the beam after the arena's glow.
- [ ] **Step 2:** Run `testPathPattern = "(Centerline|Config|CarrierBeam|FrameController)"`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run, then the full suite. Expected: **698 tests** (+7).
- [ ] **Step 5: Mutations:**
  - `distanceOf` without the second half's turn → the Centerline test;
  - the yaw's sign flipped → the pose test and the CarrierBeam curve test;
  - the beam on the inner glass → the stands test;
  - shown without a carrier → the hides test;
  - writes every frame → the write test;
  - not stepped by FrameController → the FrameController test.
- [ ] **Step 6: Play check (Studio):**
  - a probe-carried ball around a full lap: the beam follows on the outer glass and hides on a throw;
  - **allocations:** `CarrierBeam.step` over 1,000 frames in a plain Edit probe (outside Jest), expected 0 KB;
  - its time per step;
  - the console shows `modules=18`.
- [ ] **Step 7:** Static checks. Commit `feat(ui): a beam on the outer glass travels beside the ball carrier`.

---

### Task 7: The record, the M1 spec, the playtest (labels `test`, `arena`)

**Issue:** #191 (the checklist below) · **Branch:** `test/191-arena-playtest` · **Stacked on:** Task 6

- [ ] **Step 1: The M1 spec**, docs only:
  - §2 marks A2 and Q10's placement superseded by A7 and R7, and A3 kept for the lips (Arena spec 2.3, 7);
  - §9.1 gets the new layout diagram, dimensions, gate panels, goal placement and lap length;
  - §9.2 gets the folders and tags (`Glass` as a ride surface, `Top` as the barrier);
  - §9.3: the ball is out when not inside the arena's box;
  - §10.3: outside = not inside the arena's box.

  These sections cite the Arena spec.
- [ ] **Step 2: Republish:**
  - rebuild `build/game.rbxl` from the stack's head and read it back (the 13 place settings);
  - the owner publishes it into "Blox Champions" (Update existing experience).
- [ ] **Step 3: The owner's playtest** (PC, phone if possible). Each finding becomes its own issue and a stacked, test-first fix, as in Phase 9:
  - the arena's look and size, skating a lap;
  - pumping off the bank and the step;
  - riding the glass up and coming back down;
  - nobody and no ball getting out, the roof stopping both;
  - the panels lighting for the next gate, and the arrow;
  - the beam beside the carrier;
  - scoring through the hanging ring;
  - the camera never stopped by the roof.
- [ ] **Step 4:** Commit `docs/playtests/2026-10-26-m1-arena.md` with every Studio check of Tasks 1–6 (the measured numbers) and the owner's playtest, each with its result and any finding's issue. Its PR closes this task's issue.

---

## After the tasks

- **The fresh end-of-phase reviewer:** exactly one, a general-purpose agent on `opus`, given the Arena spec, both plans, this Review Focus and the ledger's rulings.
- **The review-fixes issue and PR:** every finding of every severity fixed test-first; every "declined to judge" line gets a `Final: Ruling:`.
- **Merges:** both CI checks green and the owner's OK; squash, in order (PR #192 first), replaying each next branch onto the new main.
- **The phase summary to the owner:**
  - what changed;
  - every ruling with its cost;
  - the measured numbers (part count, lap time, launch heights, the beam's cost);
  - the playtest.

  Then ask before deleting the ledger folder.
- **Next:** the Feel part starts with its own brainstorm. Read `docs/reference/2026-10-25-reference-games.md` first.

---

## Addendum (2026-10-27): the playtest's findings

During Task 7 Step 3 the owner asked for two changes, and the spec was amended for them on 2026-10-27 (R5's look, R18 a wall, §2.3 #10, §3.2, §3.3, §4.1, §5.2); then for two more (the walls' thickness and only the next one showing; laps starting at the goal's gate, Task 7d). Each is its own issue and a stacked, test-first fix before Task 7's record, as in Phase 9.

- **Order:** `feat/190-carrier-beam` ← Task 7a ← Task 7b ← Task 7c ← Task 7d ← `test/191-arena-playtest`. Task 7's docs commit (e7c599b, local only) is replayed onto Task 7c's branch in a scratch worktree, its M1 spec text brought in line with the fixes (session 24: 5f23193), and again onto Task 7d's.
- **Totals:** Task 6 ended at **697** (one under this plan's 698, by session 22's ruling on Task 3). Task 7a: **698**. Task 7b: **700**. Task 7c: **701**. Task 7d: **703**. Task 7's record adds none.
- **Amended after Task 7b's play check (2026-10-27, the owner):** the walls are 0.2 thick (at 0.5 the goal gate's wall shared the rim's face plane and the rim flickered), with config rule 7; and only the next gate's wall shows (Task 7c, #202).
- **Amended during the playtest of PlaceVersion 9 (2026-10-27, the owner):** every streak starts at the goal's gate, so its wall lights on the pickup and a lap ends just before the goal (Task 7d, #205; the M1 spec's §4.2, the Arena spec's R18 and §5.1). The goal still opens after `lapsToOpenGoal` (4) laps until the Ball & rules part (the owner's choice).
- **The play checks** use the published game's light: the dev place's Lighting effects are set aside for screenshots and restored after (the built game has none).

### Task 7a: See-through glass (labels `feature`, `arena`)

**Issue:** #199 · **Branch:** `feat/199-see-through-glass` · **Stacked on:** Task 6

**Files:** modify `src/shared/Config/Arena.luau`, `src/server/Arena/Builder.luau`; test `tests/shared/Config/Config.spec.luau`, `tests/server/Arena/Builder.spec.luau`.

**Interfaces:**
```lua
-- Config.Arena.glass = { top = 120, lipRadius = 12, lipStrips = 4, transparency = 0.85,
--   material = Enum.Material.SmoothPlastic }   (material: Validate.enumItem(Enum.Material))
-- Builder's lookLikeGlass(part, arena): Material = glass.material, Transparency = glass.transparency, CastShadow false
```

- [ ] **Step 1: Write the failing tests:**
  - **`Config.spec`:** `match the spec's arena layout` expects the new `glass`; the rejection cases gain `glass = { material = "Glass" }` → `Arena.glass.material: must be a Material (got "Glass")`.
  - **`Builder.spec`:** one local `looksLikeGlass(part, arena)` serves the glass, roof and panel tests, comparing `glass.material` and `glass.transparency`; (+1) **new** `takes the glass's look from config: the walls, a closed map's roof and the gate panels`, built with `glass = { material = Enum.Material.Glass, transparency = 0.5 }`.
- [ ] **Step 2:** Run `testPathPattern = "(Config|Builder)"`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run, then the full suite. Expected: **698 tests**.
- [ ] **Step 5: Mutations:**
  - `lookLikeGlass` leaving the material (the part keeps `newPart`'s SmoothPlastic) → the new config test;
  - the transparency fixed at 0.85 → the new config test;
  - the material's field rule dropped → the Config rejection;
  - the roof or the panels not given the look → the top test, the panel test.
- [ ] **Step 6: Play check (Studio):** the playtest's comparison view across the middle shows the far glass and the far gate panel through the near glass; screenshots; the console shows the two ready lines.
- [ ] **Step 7:** Static checks. Commit `feat(arena): clear glass that shows the far side of the track`.

### Task 7b: Glass walls at the gates (labels `feature`, `arena`)

**Issue:** #200 · **Branch:** `feat/200-gate-walls` · **Stacked on:** Task 7a

**Files:**
- Modify: `src/shared/Config/Arena.luau`; `src/shared/Arena/Geometry/{Profile,Surface,Features,Types}.luau`; `src/server/Arena/Builder.luau`; the "opening's apex" wording in `src/client/ArenaParts.luau`, `tests/Fixtures.luau`, `tests/shared/Arena/TaggedLayout.spec.luau`, `tests/client/WorldMarkers.spec.luau`.
- Test: `tests/shared/Config/Config.spec.luau`; `tests/shared/Arena/Geometry/{Profile,Surface,Features}.spec.luau`; `tests/server/Arena/Builder.spec.luau`.

**Interfaces:**
```lua
-- Config.Arena.gatePanel = { depth = 0.2 }   (openingHeight, segments and rule 6 removed; rule 7 added)
Profile.topOutline(arena: ArenaConfig): { Vector2 }  -- the walls' top as built, in u order: the inner lip, the outer lip
Surface.section(arena: ArenaConfig, distance: number): { Vector2 }  -- the solid section, the step blended at distance
export type GatePanel = { pieces: { Piece }, pivot: CFrame }  -- pivot replaces apex
```

- **The wall** (spec §5.2): its bottom is `Surface.section(arena, gateDistance)`, its top `Profile.topOutline(arena)`.
  - Its breaks are every point's u of both outlines, in order; one within `PartSize.MIN` of the break before it is dropped, and the last is always `trackWidth`.
  - Between two breaks, a quad from `Profile.heightAt(bottom, u)` up to `Profile.heightAt(top, u)` goes to `Surface.quadPieces` with `gatePanel.depth`.
  - Its pivot: `Centerline.at(gateDistance, w/2, (bottom(w/2) + top(w/2)) / 2)`.
  - `Surface.build` and `Features`' goal fit check use `Surface.section` too.
- **Expected counts at the defaults:** 28 breaks, so 27 slices. Two are rectangles (the lower floor under the roof, u 12–36; the upper floor, u 54–62), so a wall is 2 blocks and 25 × 4 wedges = 102 pieces: 408 parts in all (the panels had 256).

- [ ] **Step 1: Write the failing tests:**
  - **`Config.spec`:** `gatePanel = { depth = 0.2 }`; the `segments` cases and rule 6's two cases go; the depth part-size case stays; rule 7's case `gatePanel = { depth = 0.25 }` (half the goal panel's 0.5) → `Arena: the gate panel must be thinner than half the goal's thinnest part, so its faces never meet the goal's`.
  - **`Profile.spec`** `follows the walls' top as built across the track`: `heightAt(topOutline(arena), u)` gives today's values, and the outline runs from (0, 108) to (80, 108).
  - **`Surface.spec`** (+1) **new** `gives the solid section at a distance, with the straights' step blended there`: the full step on a straight, none at a curved end's apex, half at a gate.
  - **`Features.spec`:**
    - `fills each gate with glass from the track's surface up to the walls' top` (replaces the opening test). For gate 1, in the gate's frame:
      - every corner lies within `gatePanel.depth` of the gate's plane, and between the section and the outline;
      - every point of both outlines is a corner of the wall's face;
      - the lowest corners are 8 at u 0, 22 at u 80 and 0 on the lower floor; the highest are 120 inside the lips and 108 at both faces.
    - `builds each wall from a slice between every two breaks, in gate order` (replaces the segments test): 102 pieces per wall; each pivot at the wall's middle, facing the travel direction.
    - (+1) **new** `merges breaks closer than Roblox's smallest part`: with `glass.lipRadius = wallCurveRadius − PartSize.MIN / 2`, the outer lip's end lands half a smallest part past the foot curve's start; every piece is a size Roblox builds.
  - **`Builder.spec`:** each panel holds `#geometry.gatePanels[g].pieces` parts, pivoted at `pivot`; the invalid-piece case uses the new record.
- [ ] **Step 2:** Run `testPathPattern = "(Arena|Config)"`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run, then the full suite. Expected: **700 tests**.
- [ ] **Step 5: Mutations:**
  - equal slices instead of breaks → the shape test (the outlines' points);
  - the bottom flat at 0 → the shape test; the top at `glass.top` everywhere → the shape test (108 at the faces);
  - no merge → the merge test; the last break dropped → the shape test (u 80);
  - the pivot at a fixed height → the slices test;
  - `Surface.section` without the blend → the Surface test;
  - the depth ignored → the shape test;
  - rule 7 dropped, or `<=` for `<` → the Config rejection.
- [ ] **Step 6: Play check (Studio):** with the ball carried by a probe, the next gate's wall glows across the whole track and the arrow points at its middle; a skater passes through untouched; the goal gate's wall beside the ring; the part count; screenshots; the console shows the two ready lines.
- [ ] **Step 7:** Static checks. Commit `feat(arena): each gate becomes a thin glass wall across the track`.

### Task 7c: Only the next gate's wall shows (labels `feature`, `arena`)

**Issue:** #202 · **Branch:** `feat/202-only-next-wall` · **Stacked on:** Task 7b

**Files:** modify `src/client/ArenaGlow.luau`; test `tests/client/ArenaGlow.spec.luau`.

- **ArenaGlow** (spec §5.2): each part's remembered look gains its `transparency`. Every marker is hidden (`Transparency` 1) from the moment the arena's parts are found. The next gate's marker shows lit: the team's colour, `arenaGlow.material` and each part's own transparency. The marker it leaves hides again. The hoop and the goal panel never hide.

- [ ] **Step 1: Write the failing tests** (`ArenaGlow.spec`; the fixture's panes get the glass's transparency in `beforeEach`):
  - `shows only the next gate's panel, lit for the team with the ball, and none before their first gate` (replaces the lighting test): hidden before the first gate; nextGate 2 lights marker 2 at its own transparency and keeps the others hidden; nextGate 3 hides marker 2; Orange relights marker 3; no team hides it;
  - (+1) **new** `hides every gate's panel from the start, and never the goal`;
  - `keeps each part's first look when the arena's parts are found again while they glow` also refreshes while a panel is hidden, and the panel then shows at its first transparency, not hidden.
- [ ] **Step 2:** Run `testPathPattern = "ArenaGlow"`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run, then the full suite. Expected: **701 tests**.
- [ ] **Step 5: Mutations:** shown at a fixed transparency; not hidden at the start; a passed panel left showing; the hoop hidden too; the hidden transparency remembered on a refresh.
- [ ] **Step 6: Play check (Studio):** in play only the lit wall shows, none before the first gate; screenshots; the console shows the two ready lines.
- [ ] **Step 7:** Static checks. Commit `feat(arena): only the next gate's wall shows, lit for the team`.

### Task 7d: Every lap starts at the goal's gate (labels `feature`, `rules`)

**Issue:** #205 · **Branch:** `feat/205-laps-start-at-goal` · **Stacked on:** Task 7c

**Files:**
- Modify: `src/shared/Rules/LapTracker.luau`; `src/shared/Rules/MatchEngine.luau` (the start gate, the snapshot's `nextGate`); the "before their first gate" comments in `src/client/ArenaGlow.luau` and `src/client/WorldMarkers.luau`; `tests/Fixtures.luau` (`matchSnapshot`'s `nextGate` defaults to the goal's gate, as after a kickoff).
- Test: `tests/shared/Rules/{LapTracker,MatchEngine}.spec.luau`; `tests/integration/Match.spec.luau`; `tests/client/{ArenaGlow,WorldMarkers}.spec.luau`.

**Interfaces:**
```lua
LapTracker.new(gates: { Crossing.Rectangle }, startGate: number): LapTracker
-- nextGate: number - startGate on new and on every reset; accept takes nextGate only (the "any gate first" branch goes)
-- a start gate that is not a whole number in 1..#gates: "LapTracker: the start gate must be one of the 4 gates (got 5)"
-- MatchEngine.new: LapTracker.new(arena.gates, config.Arena.goalGateIndex); Snapshot.nextGate: number (was number?)
```

- [ ] **Step 1: Write the failing tests:**
  - **`LapTracker.spec`** (start gate 3, not the first gate, so a tracker that starts at gate 1 fails):
    - `starts every streak at its start gate, then accepts only the next gate in order` (replaces "starts the sequence at the first gate crossed"): gates 1 and 4 count nothing; 3, 4, 1, 2 give progress 1–4 and the lap;
    - `keeps the sequence across laps`: two laps from the start gate, then the start gate counts and the gate before it does not;
    - `names its start gate as the next gate from the start, then each next one in turn` (replaces "names the next gate once a streak's first gate is crossed");
    - `starts again at its start gate on reset, clearing the streak and progress` (replaces "clears the streak, progress and sequence on reset");
    - (+1) **new** `requires a start gate among its gates`: 0, 5 and 1.5 each → the message above.
  - **`MatchEngine.spec`:**
    - the `lap` helper runs from the goal's gate (`goalGateIndex` from the fixture's config), so every lap-based test keeps its meaning; the steal test crosses the lap's first two gates;
    - `reports the score tab, the gate count and the next gate in its snapshot`: the goal's gate before anyone has the ball, the gate after it once crossed;
    - `counts gates only for a possessing team, forward and in order`: a crossing of another gate before the goal's counts nothing;
    - `judges the ring before the gates a segment crosses, so the lap that opens the goal cannot score`: the opening lap now ends at Gate 1, so one segment from before Gate 1 through the ring (the fixture's ring lies on Gate 2's plane) completes it, and the goal does not score in that segment;
    - (+1) **new** `starts every streak at the goal's gate, after the kickoff and after a steal`, with `Arena = { goalGateIndex = 3 }`: the snapshot names gate 3 after the kickoff; after B1's pickup gate 2 counts nothing and gate 3 gives progress 1; after O1's steal the next gate is 3 again.
  - **`integration/Match.spec`:** `openGoal` carries the ball on to the goal's gate, then once round to 3 studs before it, so the lap that opens the goal ends ready to shoot; `scoreOnce` and the body-touch test no longer carry the ball back. (`integration/Arena.spec`'s lap starts just past Gate 1 and runs 2 → 3 → 4 → 1: unchanged.)
  - **`ArenaGlow.spec`:** `shows only the next gate's panel, lit for the team with the ball, the goal gate's from the pickup` (replaces "... and none before their first gate"): no wall while nobody has the ball; the goal gate's wall lit for Blue on the pickup; then as today.
  - **`WorldMarkers.spec`:** `points the carrier to their team's next gate, and nobody else`: the check of a carrier before their first gate (no arrow) goes with that state; on the pickup the arrow points at the goal gate's wall.
- [ ] **Step 2:** Run `testPathPattern = "(LapTracker|MatchEngine|Match|ArenaGlow|WorldMarkers)"`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run, then the full suite. Expected: **703 tests**.
- [ ] **Step 5: Mutations:**
  - the tracker starting at gate 1, or reset leaving `nextGate` where it was → the LapTracker start / reset tests;
  - `accept` taking any gate while the lap's progress is 0 (the old rule) → the start test;
  - the start gate's guard dropped, `>` for `>=` at `#gates`, or the whole-number check dropped → the guard test;
  - MatchEngine passing gate 2 or gate 1 instead of `goalGateIndex` → the new MatchEngine test.
- [ ] **Step 6: Play check (Studio):** with a probe-handed ball, the goal gate's wall lights at once and the arrow points at it; carried 2 → 3 → 4 → 1, a `LapCompleted` (a Client probe on `RuleEvents`); the console shows the two ready lines.
- [ ] **Step 7:** Static checks. Commit `feat(rules): every lap starts at the goal's gate`.

### Task 7, continued

After Task 7d: Task 7's docs commit (5f23193) is replayed onto Task 7d's branch, then Step 2's republish, the rest of Step 3 (the checklist), and Step 4's record with every finding and its issue (#199, #200, #202, #205).
