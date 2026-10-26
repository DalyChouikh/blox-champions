# M1 Overhaul, Part 1: The Arena — Design Spec

- **Date:** 2026-10-25 (design approved in brainstorming, sections 1–3); written 2026-10-26
- **Milestone:** [M1 - Foundation & Core Match](https://github.com/DalyChouikh/blox-champions/milestone/1)
- **Status:** Approved in brainstorming; awaiting written-spec review
- **Parent:** `docs/superpowers/specs/2026-10-21-m1-foundation-core-match-design.md`, decision A6 (the overhaul: Arena → Feel → Ball & rules → Presentation)
- **Reference:** `docs/reference/2026-10-25-reference-games.md` (the videos, the observations, the owner's answers)

---

## 1. Purpose and scope

### 1.1 Intended outcome

The generated arena takes Roller Champions' shape (reference: "Track geometry", "Arena (Venice Beach)"):
- a wider, longer oval with an open top;
- an opaque floor and walls topped by glass barriers that skaters and the ball bounce off but the camera sees through;
- a glass arch across the track at each lap gate, glowing for the possessing team's next gate;
- a light beam on the outer glass travelling beside the ball carrier;
- the goal ring hanging over the track from an arm.

The owner's rule: **players and the ball never get out of the arena** ("follow RC's arena, its tall walls, and its real physics").
- **Skaters:** the arena cannot be built unless its glass rises above the highest point any skater can reach.
- **The ball:** it is in play only inside the glass. Its matching rule (no throw can clear the glass) arrives with the Ball & rules part (the owner's choice, 2026-10-26, below).

### 1.2 Success criteria

1. The arena is built from `Config.Arena` alone:
   - the track 60 wide, the curved ends' centerline radius 70, the straights 200 (a lap of about 840 studs);
   - no roof;
   - on the inner side a curved bank 8 high, on the outer side a curved wall 28 high;
   - glass on top of both, up to 85 studs above the lower floor.
2. `Geometry.build` refuses an arena whose glass top is below the highest point a skater can reach (§4.2), with a message naming both heights.
3. A skater found past either glass or under the floor is placed on their spawn (#181's net). The ball is out past either glass, under the floor or above the glass top (§4.3).
4. Glass is a **barrier**:
   - skaters and the ball collide with it, and the skating's collider sweep stops at it;
   - ground rays, poses, the camera and the ball's ground marker look through it;
   - it casts no shadow.
5. The gate arches, the carrier's beam and the hanging goal work as §5 says, found by their tags, with no per-frame allocation.
6. Every test passes in Studio and in CI, with zero warnings.
7. **Measured in Studio:**
   - the highest launches stay under the glass;
   - a lap at cruise speed takes about 14 s;
   - the part count (today 15,666);
   - the client's frame cost, and that the beam allocates nothing per frame;
   - only the two ready lines in the console.
8. The owner plays the republished game.

### 1.3 Not in this part

| Not here | Where |
|---|---|
| The camera's tilt, real physics on walls (no riding held by speed), the wall-to-wall loop, jumps, landings, the double jump, action spam | Feel |
| The ball's size, throw and pass speeds, **the ball's height rule** (owner, 2026-10-26), shooting, scoring, kickoff, leavers, team switching | Ball & rules |
| The HUD, phone buttons, replays, cutscenes | Presentation |
| Glass and wall art, meshes, the stadium and crowd, more maps | Later milestone (art pass) |

The loop-physics rule for overhangs (A3) stays in `SkateMath` until the Feel part removes it: with no roof, no ride surface overhangs, so it never applies.

---

## 2. Decisions

### 2.1 The owner's (brainstorm 2026-10-25, and 2026-10-26)

| # | Question | Decision |
|---|---|---|
| R1 | How to change the arena | **Reshape the generated arena (approach A).** Keep the pure `Arena/Geometry` → `Builder` pipeline, everything config-driven. The art pass later swaps in models carrying the same tags. |
| R2 | Size and shape | Track 44 → **60** wide, curved ends 60 → **70**, straights 160 → **200**. **No roof.** The floor, the banks and the walls are opaque, like RC; only the barriers on top are glass. |
| R3 | The inner side | A low curved bank (about **8** studs, a pump spot) topped by a tall glass barrier. The infield behind it is lower, not rideable, and seen through the glass. |
| R4 | The outer side | The curved half-pipe wall (**28**) topped by glass to about 80, measured before it is fixed: **85** (§4.2). |
| R5 | Glass | A **barrier**, not a ride surface (new tag `Barrier`). |
| R6 | Gate markers | A glass **arch** across the track at each gate, glowing in the possessing team's colour on the next gate; and a **beam** on the outer glass beside the carrier. They replace today's flat corner panels. |
| R7 | The goal | The ring **hangs over the track** at gate 2, about **¾ of the way across** toward the outer wall, facing oncoming skaters, on a decorative arm from outside. The rim and the panel work as today. |
| R8 | The straights' step and the spawns | The step stays, scaled to the wider track; spawns as today, scaled. |
| R9 | Outside | "Outside" is past either glass, or under the floor; no ceiling for skaters. |
| R10 | Keeping the ball in (2026-10-26) | Glass about 85 now, with a check that no skater can clear it. The Ball & rules part adds the same check for the ball (for example RC-like throw speeds). **Until then a ball over the glass is out and respawns, as today.** |

### 2.2 The decision this part adds to the M1 spec

| # | Question | Decision |
|---|---|---|
| A7 | The arena's enclosure (replaces A2 and A3) | **An open top with glass barriers.** The opaque floor, inner bank and outer wall end in glass up to `barrier.top`. Skaters cannot clear it (§4.2), and the ball is in play only inside it (§4.3). A2's roof and tube are gone. A3's loop-physics rule no longer applies (nothing overhangs) and is removed in the Feel part. |

The M1 spec's §9.1 (layout, dimensions, markers, goal placement), §9.2 (folders and tags), §9.3 (the ball's recovery) and §10.3 (outside the arena) are rewritten to match, and decision Q10's goal placement is marked superseded by R7.

### 2.3 Decisions not spelled out above (for the owner's review)

1. **"A ball over the glass" means above the glass top** (R10), as well as past either glass sideways. So the ball, like a skater, is in play only inside one box: between the two glass faces, above the floor and under the glass top, each by its margin. One rule (`Bounds.inArena`) serves both. It replaces today's two (`Bounds.isOut` for the ball, `Bounds.inTube` for skaters), and with it the owner's 2026-10-22 rule that the ball could fly over the infield.
   - Without it, an untargeted pass aimed straight up would rise for 15 s: a pass's lift cancels gravity until the ball touches something (read in `BallService`), and the roof that stopped it is gone.
   - Cost if wrong: until the Ball & rules part, a throw that peaks above 85 studs is out and respawns, though it would have come back down inside.
2. **The lap gates are as tall as the glass** (85). Every ball in play is below it, so no crossing is missed. Cost if wrong: none.
3. **The inner bank is a quarter circle of radius `innerBankHeight`,** vertical where it meets the glass, so bank and glass meet with no ledge. Cost if wrong: a fast skater rides the bank straight up beside the glass (to about 58 studs) instead of being thrown over the infield.
4. **One glass top for both sides** (`barrier.top` 85). The inner side needs only about 59. Cost if wrong: taller inner glass than strictly needed.
5. **The skater check lives in `Geometry.build`, with the world's gravity**, like the goal ring's fit check. Gravity is the place's `Workspace.Gravity` (196.2), read by every module that needs it; it is not a Config value, so a Config rule cannot see it. Cost if wrong: a too-low glass fails at server start and in the arena tests, not at config validation.
6. **The infield** is a solid floor slab, not rideable (no `RideSurface` tag), its top at the lower floor's height, 8 under the bank's top. Cost if wrong: one number.
7. **Widths scale with the track** (×60/44 ≈ 1.36):
   - the outer wall's foot curve 10 → 14, the step 10 → 14 wide, the upper floor 4 → 6;
   - the step stays 4 high, the pump's drop;
   - the lower floor becomes 18 wide (was 10).

   `stripsPerSection` 40 → 20: the roof took 21 of today's 40 strips. Cost if wrong: tuning values, measured in Studio.
8. **The arches are graybox:** each a Model of thin glass blocks, carrying `CornerMarker` and `GateIndex`, so ArenaGlow and the next-gate arrow keep finding them by tag. Cost if wrong: `ArenaParts`' marker record changes shape.
9. **The beam is drawn by each client for itself**, following the carried ball, moved through `Position` and `Orientation` (Vector3s, which allocate nothing). Cost if wrong: none.
10. **The goal's arm is an L of two non-colliding blocks** (a post up from the ring's top past the glass top, then a beam out over the outer glass). The art pass replaces it. Cost if wrong: none.
11. **A lap at cruise speed takes about 14 s** (839.8 studs at 60), past the M1 spec's 10–12 s target. The Feel part tunes speeds. Cost if wrong: longer laps until then.

---

## 3. The shape (`Config/Arena`)

### 3.1 The cross-section

The profile runs from the inner bank's top, down and across the floors, and up the outer wall. `u` is the distance across from the inner glass's face, `y` the height above the lower floor; a straight with its full step:

```
 y
 85 ┃                                                               ┃  glass (barrier.top)
    ┃                                                               ┃
 28 ┃                                                               ┃  outer wall top
    ┃                                                               │  outer wall
 18 ┃                                                              ╱   foot curve (r 14)
  8 ┃╮ inner bank (quarter circle, r 8)                   ____-----
  4 ┃ ╲                                 ____------------ upper floor
  0 ┃  ╲________________________ __----  step (14 wide, 4 high)
    u 0   8                     26    40      46               60
         lower floor (18)                  ^ upper floor (6)
```

| Piece | From → to (u, y) on a straight |
|---|---|
| Inner bank: a quarter circle, centre (8, 8) | (0, 8) → (8, 0) |
| Lower floor | (8, 0) → (26, 0) |
| Step: a cosine rise | (26, 0) → (40, 4) |
| Upper floor | (40, 4) → (46, 4) |
| Outer foot curve: centre (46, 18) | (46, 4) → (60, 18) |
| Outer wall | (60, 18) → (60, 28) |

The curved ends have no step, as today: the profile blends point by point over `profileBlendLength`, and only the step's height changes. The glass rises from each top: the inner glass at u = 0 from 8 to 85, the outer glass at u = 60 from 28 to 85. Each is a slab of `barrier.thickness` behind its face, outside the track.

### 3.2 Config changes

| Key | Today | New |
|---|---|---|
| `straightLength` | 160 | 200 |
| `endRadius` | 60 | 70 |
| `trackWidth` | 44 | 60 |
| `outerWallHeight` | 28 | 28 |
| `infieldWallHeight` | 28 | removed: `innerBankHeight` = 8 |
| `wallCurveRadius` (now the outer wall's foot only) | 10 | 14 |
| `stepHeight` / `stepWidth` / `upperFloorWidth` | 4 / 10 / 4 | 4 / 14 / 6 |
| `stripsPerSection` | 40 | 20 |
| `barrier` | — | `{ top = 85, thickness = 1, transparency = 0.7 }` |
| `marker` | `{ width, height }` | removed: `arch = { thickness = 0.5, depth = 2, segments = 16 }` |
| `goal.wallGap` | 1 | removed: `goal.across = 0.75` (the ring's centre, as a fraction of `trackWidth` from the inner glass) |
| `goal.arm` | — | `{ thickness = 1, above = 4, reach = 6 }` (the post's top above `barrier.top`; how far the beam reaches past the outer glass) |
| `colors.marker` | (27, 42, 53) | removed: `colors.glass` (the barriers' and the arches' resting colour) |

`Config.UI.arenaGlow` gains `beam = { width = 2, thickness = 0.5 }`. The beam shines in the carrier's team colour with `arenaGlow.material`, like the glowing goal and arch.

### 3.3 Validation

**Field rules** for the new keys:
- sizes are above zero, and part sizes are within Roblox's part limits;
- `goal.across` lies between 0 and 1, `arch.segments` is a whole number of at least 3, and `stripsPerSection` a whole number of at least 6 (one per piece of the profile);
- every transparency lies between 0 and 1.

**Cross-field rules**, in order (they replace today's):
1. `trackWidth` must fit the inner bank, the outer wall's foot curve, the step, the upper floor and a lower floor.
2. `endRadius` must leave room for the infield behind the inner glass: `endRadius − trackWidth/2 − barrier.thickness > 0`.
3. The outer wall must rise above its foot curve and the step: `outerWallHeight > wallCurveRadius + stepHeight`.
4. The glass must rise above both tops: `barrier.top > outerWallHeight` and `barrier.top > innerBankHeight`.
5. `profileBlendLength` must fit within a straight and a curved end (unchanged).

**Checked by `Arena/Geometry` against the arena as built** (they need the built surface or the world's gravity):
- the goal ring's fit (§5.3);
- the skater reach (§4.2).

---

## 4. Barriers, reach and bounds

### 4.1 Glass is a barrier

- **New tag `Barrier`** (`Arena/Tags`), on the Builder's `Barriers` folder, as `RideSurface` is on the surfaces' folders.
- **Glass parts:**
  - Material Glass, `colors.glass`, `barrier.transparency`, `CastShadow` false;
  - `CanCollide` true, so the ball and the skater's physical collider bounce off;
  - `CanQuery` true, so the collider sweep finds them;
  - `CanTouch` false.
- **`RideSurfaces`** keeps `params` (ride surfaces only) for every ray that looks for ground or a view: the skating's ground and wall-leap rays, the poses, the camera and the ball's ground marker. So all of them look through glass.
  - It gains **`solid`**: the ride surfaces and the barriers, the one `RaycastParams` the collider sweep uses (its sphere cast and its face ray).
  - `ready` still means "the ride surfaces are here".
- **`SkateController`'s sweep** (#176, #184) stops at glass as at a wall: a skater pressing into glass slides along it, never through it.

### 4.2 How high a skater can get (`Arena/Geometry/Reach`, pure)

A skater never moves faster than `Movement.hardCap`, on the ground or in the air (`SkateMath`). Every action's push is capped there too. The highest ride surface is the outer wall's top. So no skater's root rises above

`skaterTop = max(outerWallHeight, innerBankHeight) + hardCap² / (2 · gravity)`

and no part of its collider above `skaterTop + colliderDiameter / 2`. Today: 28 + 140² / 392.4 + 1 = **78.95** studs, against glass at 85.
- Measured in Play (2026-10-26): a ball-sized part launched straight up rose 47.9 studs at 140 studs/s, under the formula's 49.9. The formula is an upper bound.
- `Geometry.build(config, gravity)` raises `Arena: the glass (barrier.top 85) must rise above the highest a skater can reach (78.95)` when it does not.
- **The Feel part's double jump and jump changes must keep this bound true:** it adds their heights to `Reach`.

### 4.3 In the arena (`Bounds.inArena`, pure)

`Bounds.inArena(arena, position, margin)` is true when the point lies:
- between the two glass faces seen from above, each by `margin` (the track is the ring between two capsules around the long axis, as today);
- no lower than `margin` under the lower floor;
- no higher than `margin` over `barrier.top`.

Two callers:
- **The ball** (`BallService`) is out, and respawns as today, when it is not in the arena by `Ball.outOfBoundsMargin`.
- **A skater** (`MovementGuard`) not in the arena by `Network.guardOutsideMargin` is placed on their spawn, a carrier dropping the ball first, as today.

The glass top is out of a skater's reach (§4.2), so it never decides a skater's case.

---

## 5. The arena's features

### 5.1 Lap gates

As today, a gate spans the track at the start of each section, facing the travel direction. It is now `trackWidth` wide and `barrier.top` tall.

### 5.2 Gate arches (replacing the corner markers)

- **Shape:** at each gate, in the gate's plane, a glass half circle from the inner bank's top (u 0, y 8) over to the outer wall's top (u 60, y 28): centre (30, 18), radius 31.6, apex 49.6. It is made of `arch.segments` blocks, `arch.thickness` thick across the arc and `arch.depth` along the track.
- **Parts:** each arch is a Model `Arch<g>` tagged `CornerMarker` with `GateIndex` g. Its parts are glass with `CanCollide`, `CanQuery` and `CanTouch` false and no shadow. Nothing in the game hits or sees them.
- **`ArenaParts.markers[g]`** becomes `{ parts: { BasePart }, position: Vector3 }`: every part of the arch, and its top centre (the model's pivot).
  - ArenaGlow lights every part of the next gate's arch in the possessing team's colour, and restores each as it reached the client.
  - The next-gate arrow (WorldMarkers) points at `position`.

### 5.3 The hanging goal

- **Placement:** the ring stands in gate 2's plane (`goalGateIndex`), its centre at u = `goal.across · trackWidth` (45) and `goal.heightAboveFloor` (18). Its front faces oncoming skaters, as today.
- **The rim and the panel** are built, tagged and glow as today. The panel slides up out of the ring when the goal opens.
- **Fit check** (`Features.goal`, against the profile as built at the gate):
  - the rim's outline must stay inside the two glass faces;
  - it must clear the track's surface everywhere under it (today: 7.8 studs clear at the closest point);
  - it must stay under `barrier.top`.

  Each failure names its rule.
- **The arm:** two non-colliding, non-querying, non-touching blocks, `goal.arm.thickness` square:
  - a post from the rim's top up to `barrier.top + goal.arm.above`;
  - a beam from the post's top out over the outer glass to `goal.arm.reach` past it.

  It is decoration: the art pass replaces it.
- **A skater under the ring:** a skater on the upper floor tops out at about 5.5 studs, under the rim's lowest point at 9.8.

### 5.4 The carrier's beam (`client/CarrierBeam`, new)

- **What it is:** a tall thin glowing strip on the outer glass's inner face, from the outer wall's top to `barrier.top`, beside the ball while someone carries it. It takes the possessing team's colour, which is the carrier's, and hides when no one carries the ball.
- **Where it is:** at the carried ball's distance along the track (`Centerline.distanceOf`), on the outer glass. It is placed with `Centerline.pose`, which gives the point (a Vector3) and the heading (an angle), neither of which allocates.
- **The part:** client-only (each client draws its own), built at `start`, Neon, with `CanCollide`, `CanQuery` and `CanTouch` false and no shadow.
- **Each frame,** stepped by FrameController after ArenaGlow:
  - it reads `BallCarrier`, `BallPart` and the HUD's state;
  - it moves the part through `Position` and `Orientation`;
  - it writes `Color` and `Transparency` only when they change;
  - it allocates nothing.

### 5.5 Spawns and the infield

- **Team spawns:** on the lower floor's middle lane (u 17), as today.
- **Ball spawns:** on the track's middle at each curved end's apex, as today.
- **The infield:** a floor slab `surfaceThickness` thick, its top at the lower floor's height, out to the inner glass's back (`barrier.thickness` behind its face): a block between the straights and a fan of prisms under each curved end, as today. It is not a ride surface.

---

## 6. Code changes

### 6.1 Pure (`src/shared/Arena`)

| Module | Change |
|---|---|
| `Geometry/Profile` | The six pieces of §3.1. The roof's arc and `roofCircle`, `roofTop` and `roofEdge` are gone. `lowerFloorCenter` and `stripCounts` follow the new pieces (curved: the bank, the step and the foot curve). |
| `Geometry/Surface` | `build` returns the surface alone. |
| `Geometry/Features` | `barriers` (two vertical glass strips swept around the loop: one block per station step, merged along the straights), `arches`, the new `goal` with its arm and fit check, `gates` as tall as the glass, `infield` at the floor's height. `markers` is gone. |
| `Geometry/Reach` (new) | `skaterTop(config, gravity)`. |
| `Geometry/init` | `build(config, gravity)`: adds `barriers` and `arches` (and `goal.arm`), drops `roof` and `markers`, and checks the reach. |
| `Geometry/Bounds` | `inArena` replaces `isOut` and `inTube`. |
| `Geometry/Centerline` | `distanceOf(arena, position)`, the inverse of `frameAt`; and `pose(arena, distance, lateral, height)`, the point (a Vector3) and the heading (an angle), on which `frameAt` and `at` build. |
| `Tags` | `Barrier`. |

### 6.2 Server

- **`Arena/Builder`:**
  - folders `Surface` (RideSurface), `Barriers` (Barrier), `Infield` (no tag), `Gates`, `Goal` (hoop, panel, arm), `Arches`, `Spawns`;
  - the glass and arch looks of §4.1 and §5.2;
  - the `Roof` folder is gone.
- **`ArenaService`** passes `workspace.Gravity` (a number) to `Geometry.build`.
- **`BallService`** and **`MovementGuard`** call `Bounds.inArena`.

### 6.3 Client

- **`RideSurfaces`:** `solid`.
- **`SkateController`:** the sweep uses `solid`.
- **`ArenaParts`:** arch markers.
- **`ArenaGlow`:** lights an arch's parts.
- **`WorldMarkers`:** the arrow aims at the arch's position.
- **`CarrierBeam`:** new, in `Modules` after ArenaGlow, so the client starts 18 modules.
- **`FrameController`:** steps the beam after the arena's glow.

---

## 7. Testing

**Unit (pure):**
- **Profile:** the six pieces' end points, strip counts, the lower floor's middle.
- **Surface:** the surface only, every piece facing the track.
- **Features:**
  - barriers: their heights, the slab behind each face, rectangles merged along the straights;
  - gates: as tall as the glass;
  - arches: both ends at the two tops, the apex, the segment count, and the order of `GateIndex`;
  - the goal: lateral 45, facing oncoming skaters, and each fit failure (outside the glass, into the floor, over the glass);
  - the arm: from the rim past the glass top and out past the outer glass;
  - spawns and the infield.
- **Reach:** the formula, and `Geometry.build` refusing glass under it (message).
- **Bounds:**
  - inside: the floors, the bank, both walls, up to the glass top plus the margin;
  - outside: past either glass, under the floor, over the top.
- **Centerline:** `distanceOf` round trip on both straights and both ends, the wrap at gate 1, and `pose` against `frameAt`.
- **Config:** the new defaults, each new field rule, each cross-field rule (exact messages).

**Client and server, in Edit:**
- **Builder:** folders, tags, `GateIndex`, the glass and ghost flags, no shadow on glass, and the infield untagged.
- **RideSurfaces:** `solid` holds the barriers, `params` does not.
- **SkateController:** the sweep stops at a glass slab (real parts in Edit, like the seam test), and the ground ray ignores it.
- **CameraController:** glass between the camera and the skater does not pull the camera in.
- **ArenaParts, ArenaGlow, WorldMarkers:** the arch markers.
- **CarrierBeam:** hidden without a carrier, beside the ball on the outer glass in the team's colour, writes only on change.
- **MovementGuard and BallService:** in and out by `inArena`.
- **Integration:** the arena built from the shipped config with gravity 196.2, and every tag present.

**Mutations:** one per guard, as every phase, recorded in the ledger.

**Studio checks:**
- **Launch heights:** a skater driven up the outer wall and the inner bank at `hardCap` with Scriptable bindings, ten times each. Apex under `barrier.top`, expected about 78.
- **#176's launches again:** 18 runs into the glass at 120–140 studs/s; none gets out.
- **A lap at cruise:** its time.
- **The part count:** today 15,666; the roof alone was 8,106.
- **The client's frame:** the beam's step, and allocations in a plain probe (expected 0 per frame).
- **The console:** only the two ready lines (`modules=8` / `modules=18`).
- **The owner's playtest** after a republish of `build/game.rbxl`.

---

## 8. Suggested order of tasks (the plan decides)

1. The shape: Config, Profile and Surface without a roof, `Reach` and the check, `Bounds.inArena`, and the Builder's folders.
2. The barriers: `Barrier`, Features' glass, `RideSurfaces.solid`, the sweep.
3. The arches: Features, the Builder, ArenaParts, ArenaGlow, WorldMarkers.
4. The hanging goal and its arm.
5. `Centerline.distanceOf` / `pose` and `CarrierBeam`.
6. The Studio checks, the M1 spec's §9–§10 text, the republish, and the owner's playtest.
