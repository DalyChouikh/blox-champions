# M1 Overhaul, Part 1: The Arena — Design Spec

- **Date:** 2026-10-25 (design approved in brainstorming); written 2026-10-26; **revised 2026-10-26** (session 21) after the owner's direction change; **amended 2026-10-27** after the owner's playtest
- **Milestone:** [M1 - Foundation & Core Match](https://github.com/DalyChouikh/blox-champions/milestone/1)
- **Status:** Revision approved by the owner (2026-10-26). The first version (d558a48, approved 2026-10-26) is built as Task 1 (#186, PR #192); this revision replaces its glass barrier, sizes, gate arches and reach check. The playtest's amendment (2026-10-27) changes the glass's look (R5) and turns the gate panels into walls (R18), only the next gate's showing.
- **Parent:** `docs/superpowers/specs/2026-10-21-m1-foundation-core-match-design.md`, decision A6 (the overhaul: Arena → Feel → Ball & rules → Presentation)
- **Reference:** `docs/reference/2026-10-25-reference-games.md` (the videos, the observations, the owner's answers; "Video 3" is the 45-minute ranked video the revision rests on)

---

## 1. Purpose and scope

### 1.1 Intended outcome

The generated arena takes Roller Champions' shape (reference: "Video 3"):
- a wide track inside **tall rideable glass walls**, which curl inward at the top (the **lips**);
- a **top set per map**: a glass roof (**closed**, like Mexico) or an invisible ceiling (**open**, like Acapulco); our map is closed;
- a thin glass **wall** across the track at each lap gate, glowing for the possessing team's next gate;
- a light **beam** on the outer glass travelling beside the ball carrier;
- the **goal ring** hanging over the track from an arm.

The owner's rule: **players and the ball never get out of the arena.** The top holds both, on either kind of map; a ball or a skater found outside anyway (a fault) is put back, as today.

### 1.2 Success criteria

1. The arena is built from `Config.Arena` alone:
   - the track 80 wide, the arena's outside 200 across (the curved ends' centerline radius 60), the straights 200 (a lap of about 777 studs);
   - on the inner side a curved bank 8 high, on the outer side a curved solid wall 28 high;
   - **rideable glass** above both, up to **120**, each wall ending in a lip that curls inward;
   - the top of `Arena.top.kind`: a glass roof at 120 (Closed, the default) or an invisible ceiling at 140 (Open).
2. Glass is a ride surface: skaters ride it and their rays find it; the ball bounces off it, and its flight ends there as on any surface.
3. The top stops skaters and the ball; it is not ridden; every ray looks through it (ground, poses, camera, the ball's ground marker); it casts no shadow.
4. A skater found past either glass face, under the floor or over the top is placed on their spawn (#181's net); the ball found there is out and respawns.
5. The gate panels, the carrier's beam and the hanging goal work as §5 says, found by their tags, with no per-frame allocation.
6. Every test passes in Studio and in CI, with zero warnings.
7. **Measured in Studio:**
   - the part count, under the pre-overhaul arena's 15,666;
   - a lap at cruise speed (about 13 s expected);
   - #176's launches into the walls and up to the top: nobody gets out;
   - the client's frame cost, and that the beam allocates nothing per frame;
   - only the two ready lines in the console.
8. The owner plays the republished game.

### 1.3 Not in this part

| Not here | Where |
|---|---|
| The camera's tilt; the walls' rule (today a skater over `minWallSpeed` holds any wall); the wall-to-wall loop; jumps, the uppercut, landings, the double jump; action spam; **how high a skater can get** | Feel |
| The ball's size, throw and pass speeds, the charge throw, its cancel and crosshair, shooting, kickoff, leavers, team switching, networking | Ball & rules |
| **The rules the owner set on 2026-10-26** (reference notes): +1/+3/+5 after 4/8/12 markers, first to 5 points wins, a 7:00 clock, Last Chance for a team holding the ball at 0:00, overtime 3:00 then a draw | Ball & rules |
| The HUD, phone buttons, replays, cutscenes | Presentation |
| Glass, wall and roof art, meshes, the stadium and crowd, a second map | Later milestone (art pass) |

**How high a skater gets today:** at `Movement.hardCap` a skater riding up the outer wall peaks at about 77 studs (measured 2026-10-26). So with today's Movement values nobody reaches the lips (they start at 108); only the ball does. The Feel part decides how skaters get higher (the owner: jumps, pump, uppercut).

---

## 2. Decisions

### 2.1 The owner's

Brainstorm 2026-10-25, the approved spec 2026-10-26, and the revision 2026-10-26 (after the full study of Video 3; each answer is logged in the reference notes).

| # | Question | Decision |
|---|---|---|
| R1 | How to change the arena | **Reshape the generated arena (approach A).** Keep the pure `Arena/Geometry` → `Builder` pipeline, everything config-driven. The art pass later swaps in models carrying the same tags. |
| R2 | Size and shape | Straights 200; the arena's outside 200 across; **the track 80 wide (R12)**. The floor, the banks and the solid walls are opaque, like RC; the glass above them is clear. *(First version: track 60, curved ends 70.)* |
| R3 | The inner side | A low curved bank (about **8** studs, a pump spot) that rises into **rideable glass up to the top**, with its own lip, on the straights and the ends. The middle behind it (40 wide) is closed off, not rideable, and seen through the glass. *(First version: a glass barrier on the bank.)* |
| R4 | The outer side | The curved solid wall (**28**) rises into **rideable glass up to 120 (R11)**, which curls inward at the top. *(First version: a glass barrier to 85.)* |
| R5 | Glass | **A ride surface** with a glass look ("the player should be able to skate on them, not just fall"). **The look (2026-10-27): clear plastic, SmoothPlastic at 85% see-through**, so players see through the glass to the other side ("specially the middle glass"): Roblox's Glass material hides every non-opaque part behind it. *(First version: a barrier, not a ride surface. Until 2026-10-27: the Glass material at 70%.)* |
| R6 | Gate markers | **A thin glass wall across the track at each gate (R18)**, glowing in the possessing team's colour on the next gate; and a **beam** on the outer glass beside the carrier. They replace today's flat corner panels. *(First version: a thin arch.)* |
| R7 | The goal | The ring **hangs over the track** at gate 2, about **¾ of the way across** toward the outer wall, facing oncoming skaters, on a decorative arm. The rim and the panel work as today. |
| R8 | The straights' step and the spawns | The step stays, scaled to the wider track; spawns as today, scaled. |
| R9 | Outside | "Outside" is past either glass face, under the floor, or over the top. The top holds skaters and the ball (R14), so only a fault puts anything outside. *(First version: no ceiling for skaters.)* |
| R10 | Keeping the ball in | **The top keeps the ball in** (R14, R17). A ball found outside is out and respawns, as today. *(First version: glass at 85, the ball out above it.)* |
| R11 | The walls' height (2026-10-26) | **120** studs for the wall and its glass, about 0.6 of a curved end's width: the proportion judged by eye in Video 3's flyovers, not measured. |
| R12 | The track's width (2026-10-26) | **60 → 80** on the straights and the ends, **into the middle**: the arena's outside stays 200 across, so the middle narrows from 80 to 40, like RC's narrow middle. |
| R13 | Wall riding (2026-10-26) | Skaters ride the glass, as in Video 3 (Mexico 14:25–14:30, Acapulco 31:16–31:22). There, speed carries a skater up the glass and gravity brings a slow one back down, so rideable glass and the Feel part's "real physics" rule fit together. |
| R14 | The top (2026-10-26) | **Set per map** (`Arena.top.kind`): **Closed**, a glass roof at the walls' top; or **Open**, an invisible ceiling above it. Both stop skaters and the ball, and neither is ridden. Both kinds are built and tested now; **our map is closed**. |
| R15 | The top of the walls (2026-10-26) | Every wall ends in a **lip** curling inward. The lip is rideable, and turns a fast skater back toward the track; the top is not, and a skater bumps off it like a ceiling. Gravity brings them down: no riding upside down. |
| R17 | The open map's ceiling (2026-10-26) | **20 studs above the walls' top** (140), stopping **the ball and skaters**. In Video 3's replay at 21:13 the ball rose above Acapulco's overhead rails before falling into the goal, so if RC has a ceiling it sits above the walls. |
| R18 | The gate panels (2026-10-26, amended 2026-10-27) | **A thin glass wall, floor to roof:** glass fills the gate's whole cross-section, from the track's surface up to the walls' top, and skaters pass through it ("just like in rc, it is a wall not an arch ... it feels more satisfying to pass through a wall"); nothing collides with it. The whole wall glows, still see-through, on the next gate. **Only that wall shows** (the owner, after its play check): every other wall is invisible, so none shows while nobody has the ball or before the team's first gate, and a passed wall disappears as the next one lights. *(2026-10-26: a panel hanging from the top down to a rounded opening.)* |

(R16, the inner side, is folded into R3.)

### 2.2 The decision this part adds to the M1 spec

| # | Question | Decision |
|---|---|---|
| A7 | The arena's enclosure (replaces A2 and A3's roof) | **Rideable glass walls with lips, closed by a per-map top.** The opaque floor, the inner bank and the outer wall rise into rideable glass up to `glass.top`, curling inward. Above them, `Arena.top` closes the arena: a glass roof (Closed) or an invisible ceiling (Open). The top stops skaters and the ball and is never ridden. A2's tube is gone. **A3's loop rule stays** (§4.3): it is the real-physics rule for the lips. |

The M1 spec's §9.1 (layout, dimensions, markers, goal placement), §9.2 (folders and tags), §9.3 (the ball's recovery) and §10.3 (outside the arena) are rewritten to match, and decision Q10's goal placement is marked superseded by R7.

### 2.3 Decisions not spelled out above (for the owner's review)

1. **Widths scale with the track** (×4/3, rounded):
   - the outer wall's foot curve 14 → 18, the step 14 → 18 wide, the upper floor 6 → 8;
   - the step stays 4 high, the bank 8, the solid outer wall 28;
   - the lower floor becomes 28 wide (was 18).

   Cost if wrong: tuning values.
2. **The lips are quarter circles of radius 12, in 4 strips each.** So the glass is vertical up to 108, and the top spans the 56 studs between the two lips' ends. Cost if wrong: two numbers.
3. **The glass and the top are slabs `surfaceThickness` thick** (1), behind their faces, outside the track, like every ride surface; `barrier.thickness` goes. Cost if wrong: none.
4. **The open top closes the gap above the lips.** Invisible vertical strips rise from each lip's end up to the ceiling, so nothing slips out between a lip and the ceiling. Cost if wrong: two strips.
5. **The top is touchable.** Roblox fires a touch only between two parts that both have `CanTouch` (Roblox's `BasePart.CanTouch` page, read 2026-10-26). The ball's flight, including a pass's lift that cancels gravity, ends on its first touch (`BallService.onTouched`). Task 1's glass was untouchable, so a ball hitting it flew on with its lift. As a ride surface the glass is touchable like the floor, and so is the top. Cost if wrong: none.
6. **The build-time reach check goes** (`Geometry/Reach`, Task 1). The top holds every skater, whatever their speed or jumps, so the check guards nothing; the Feel part needs no bound to keep. Cost if wrong: none; `Bounds.inArena` still nets a fault.
7. **A3's loop rule stays in `SkateMath`.** On an overhang, a skater stays on only while speed² × curvature reaches gravity's pull off the surface. That is real physics, and it is what the lips need (R15). What the Feel part changes is the walls' rule (`minWallSpeed`). Cost if wrong: one rule.
8. **The top's height is one rule** (`Profile.topHeight`): `glass.top` when closed, `glass.top + top.ceilingAbove` when open. Gates are that tall, and `Bounds.inArena` ends there. Cost if wrong: none.
9. **Every ray looks through the top** (RideSurfaces' `params` holds ride surfaces only, as Task 2's work has it). The camera stops in front of glass, as in front of any wall, but sees through the roof. Cost if wrong: a camera that, near the roof, could rise above it.
10. **The gate wall follows the cross-section as built** (amended 2026-10-27). It runs from the solid section at the gate (the step half blended there) up to the walls' top outline (the lips' chords and 120). Its slices break at every point of either outline, so its edges lie on the surface's and the lips' own chords; equal slices would cut across the step and the foot curve. Breaks closer than Roblox's smallest part (0.001) merge into one. It is `gatePanel.depth` (0.2) thick, behind the gate's plane, and keeps the name "gate panel" in code. The goal hangs in gate 2's plane, centred on it, so the wall must be thinner than half the goal's thinnest part (§3.3, rule 7): at 0.5 the wall's back face lay in the rim's face plane and the rim flickered (seen 2026-10-27; clean at 0.2). Cost if wrong: none. *(2026-10-26: an opening of half an ellipse, `gatePanel.openingHeight` 60, in `gatePanel.segments` 16 slices, 2 deep.)*
11. **The goal's arm comes from the outer glass.** A post rises from the rim's top up to `goal.arm.height` (40), then a beam runs out to the outer glass's face. That works on both kinds of top. Cost if wrong: none.
12. **The beam covers the vertical outer glass**, from the solid wall's top (28) up to where the lip starts (108). Cost if wrong: none.
13. **A lap at cruise speed takes about 13 s** (777 studs at 60), past the M1 spec's 10–12 s target. The Feel part tunes speeds. Cost if wrong: longer laps until then.
14. **The middle** keeps a floor slab (untagged, not rideable) at the lower floor's height, 38 wide between the inner glass slabs. Cost if wrong: one number.

---

## 3. The shape (`Config/Arena`)

### 3.1 The cross-section

`u` is the distance across from the inner glass's face, `y` the height above the lower floor. A straight with its full step, on our closed map:

```
 y
120         .----------------- roof (Closed) -----------------.        Open: invisible ceiling at 140,
108        ( lip r12                                    lip r12 )      strips up from the lips' ends
           |                                                    |
           | inner glass (rideable)        outer glass (rideable)|
           |                                                    |
 28        |                                                    |  outer wall's top (solid below)
 22        |                                                   /   foot curve (r 18)
  8        ╮ inner bank (r 8)                         ___----
  4         ╲                       ____----------- upper floor
  0          ╲_____________________/  step (18 wide, 4 high)
           u 0   8               36     54    62            80
```

| Piece | From → to (u, y) on a straight | Folder |
|---|---|---|
| Inner lip: a quarter circle, centre (12, 108) | (12, 120) → (0, 108) | Glass |
| Inner glass | (0, 108) → (0, 8) | Glass |
| Inner bank: a quarter circle, centre (8, 8) | (0, 8) → (8, 0) | Surface |
| Lower floor | (8, 0) → (36, 0) | Surface |
| Step: a cosine rise | (36, 0) → (54, 4) | Surface |
| Upper floor | (54, 4) → (62, 4) | Surface |
| Outer foot curve: centre (62, 22) | (62, 4) → (80, 22) | Surface |
| Outer wall | (80, 22) → (80, 28) | Surface |
| Outer glass | (80, 28) → (80, 108) | Glass |
| Outer lip: a quarter circle, centre (68, 108) | (80, 108) → (68, 120) | Glass |
| Closed: the roof | (68, 120) → (12, 120) | Top |
| Open: strip, ceiling, strip | (68, 120) → (68, 140) → (12, 140) → (12, 120) | Top |

Every section runs the same way around the track's "O" (inner top, down, across the floors, up the outer side, back across the top), so every slab hangs behind its face, outside the track. The curved ends have no step: the solid profile blends point by point over `profileBlendLength`, as today. The glass, the lips and the top never change along the loop.

### 3.2 Config changes

| Key | Task 1 | New |
|---|---|---|
| `straightLength` | 200 | 200 |
| `endRadius` | 70 | 60 |
| `trackWidth` | 60 | 80 |
| `outerWallHeight` / `innerBankHeight` | 28 / 8 | 28 / 8 |
| `wallCurveRadius` | 14 | 18 |
| `stepHeight` / `stepWidth` / `upperFloorWidth` | 4 / 14 / 6 | 4 / 18 / 8 |
| `stripsPerSection` (the solid profile) | 20 | 20 |
| `barrier` | `{ top = 85, thickness = 1, transparency = 0.7 }` | removed: `glass = { top = 120, lipRadius = 12, lipStrips = 4, transparency = 0.85, material = Enum.Material.SmoothPlastic }` (2026-10-27: was 0.7 with the Glass material) |
| `top` | — | `{ kind = "Closed", ceilingAbove = 20 }` (`kind` is `"Closed"` or `"Open"`; `ceilingAbove` is used by Open) |
| `marker` | `{ width, height }` | removed: `gatePanel = { depth = 0.2 }` (2026-10-27: was `{ openingHeight = 60, depth = 2, segments = 16 }`) |
| `goal.wallGap` | 1 | removed: `goal.across = 0.75` (the ring's centre, as a fraction of `trackWidth` from the inner glass) |
| `goal.arm` | — | `{ thickness = 1, height = 40 }` (where the arm's beam runs, above the lower floor) |
| `colors.marker` | (27, 42, 53) | removed (`colors.glass` colours the glass, the roof and the panels) |

`Config.UI.arenaGlow` gains `beam = { width = 2, thickness = 0.5 }`. The beam shines in the carrier's team colour with `arenaGlow.material`, like the glowing goal and gate panel.

### 3.3 Validation

**Field rules** for the new keys:
- sizes are above zero, and part sizes are within Roblox's part limits;
- `top.kind` is `"Closed"` or `"Open"`; `glass.material` is a `Material`;
- `glass.lipStrips` is a whole number of at least 1;
- `goal.across` lies between 0 and 1; every transparency lies between 0 and 1.

**Cross-field rules**, in order:
1. `trackWidth` must fit the inner bank, the outer wall's foot curve, the step, the upper floor and a lower floor (unchanged).
2. `endRadius` must leave room for the middle behind the inner glass: `endRadius − trackWidth/2 − surfaceThickness > 0`.
3. The outer wall must rise above its foot curve and the step (unchanged).
4. The glass must rise above both solid tops before its lip starts: `glass.top − glass.lipRadius > outerWallHeight` (and `> innerBankHeight`).
5. The lips must leave the top open between them: `2 · glass.lipRadius < trackWidth`.
6. `profileBlendLength` must fit within a straight and a curved end (unchanged).
7. The gate panel must be thinner than half the goal's thinnest part: `gatePanel.depth < min(goal.rimThickness, goal.panelThickness, goal.arm.thickness) / 2`. The goal's parts are centred on gate 2's plane and the wall hangs behind it, so then no face of that wall lies in a face plane of the goal (2026-10-27).

(2026-10-27: the gate panel's opening and its rule went with R18's amendment; rule 7 is new.)

**Checked by `Arena/Geometry` against the arena as built:** the goal ring's fit and its arm (§5.3).

---

## 4. The enclosure

### 4.1 Glass is a ride surface

- **Folder `Glass`**, tagged `RideSurface` like `Surface`: the two glass sections of §3.1 (each wall's vertical glass and its lip), swept around the loop.
- **Glass parts:**
  - `glass.material` (SmoothPlastic), `colors.glass`, `glass.transparency` (0.85), `CastShadow` false (120 studs of it would shade the track). Not the Glass material: it hides every non-opaque part behind it (Roblox's DevForum announcement of 2017-12-06, "Non-opaque objects are currently not visible through glass"; measured 2026-10-27: the far glass and the gate panels vanished behind it at 0.7 and 0.9, and showed with SmoothPlastic at 0.8–0.9). The Builder's one `lookLikeGlass` gives this look to the glass, a closed map's roof and the gate panels;
  - `CanCollide`, `CanQuery` and `CanTouch` true, as the floor.
- So skaters ride it (their ground and wall rays find it), the collider sweep slides along it, the camera stops in front of it as before any wall, and the ball bounces off it and ends its flight there.
- The Builder's `Barriers` folder and `Features.barriers` (Task 1) are gone.

### 4.2 The top

- **Folder `Top`**, tagged `Barrier`: the top section of §3.1, swept around the loop.
- **Looks:** Closed: the glass look of §4.1. Open: invisible (`Transparency` 1).
- **Both kinds:** `CanCollide`, `CanQuery` and `CanTouch` true, `CastShadow` false.
- **`RideSurfaces`** (Task 2's work, aimed at the top):
  - `params` holds the ride surfaces only, the one filter of every ray (the ground and wall-leap rays, the poses, the camera, the ball's ground marker): they all look through the top, and nobody lands on it;
  - **`solid`** adds the barriers: the one filter of the collider sweep (its sphere cast and its face ray), so a skater meeting the top slides along it and gravity brings them down;
  - `ready` still means "the ride surfaces are here".

### 4.3 The lips and the loop rule

A lip curls from vertical to horizontal. Riding up into it, a skater follows the curve while A3's rule holds: speed² × curvature at least gravity's pull off the surface (`SkateMath`, unchanged). A fast skater leaves the lip's end moving inward under the top, bumps off the top if they rise, and falls back to the track. A slow one drops off the lip, or the glass below it, as gravity pulls them off. The walls' own rule (`minWallSpeed`) is the Feel part's.

### 4.4 In the arena (`Bounds.inArena`, pure)

`Bounds.inArena(arena, position, margin)` is true when the point lies:
- between the two glass faces seen from above, each by `margin` (the track is the ring between two capsules around the long axis, as today);
- no lower than `margin` under the lower floor;
- no higher than `margin` over the top (`Profile.topHeight`).

Its two callers stay: **the ball** (`BallService`, out by `Ball.outOfBoundsMargin`, then respawned) and **a skater** (`MovementGuard`, placed on their spawn past `Network.guardOutsideMargin`, a carrier dropping the ball first). Since the top holds both, it decides only a fault.

---

## 5. The arena's features

### 5.1 Lap gates

As today, a gate spans the track at the start of each section, facing the travel direction. It is now `trackWidth` wide and as tall as the top (`Profile.topHeight`), so no ball in play crosses unseen.

### 5.2 Gate panels (replacing the corner markers)

- **Shape (amended 2026-10-27):** in each gate's plane, a thin glass wall fills the track's whole cross-section (R18):
  - its bottom follows the solid section at the gate (`Surface.section`): the inner bank from the inner glass's face, the floors, the step half blended there, the foot curve up to the outer glass's face;
  - its top follows the walls' top outline (`Profile.topOutline`): the inner lip, 120 between the lips' ends, the outer lip;
  - it is made of slices across the track that break at every point of either outline (§2.3, 10), each a quad in the gate's plane, `gatePanel.depth` thick behind it (a block when the quad is a rectangle, wedges otherwise, as the surface's quads).
- **Parts:** each panel is a Model `GatePanel<g>` tagged `CornerMarker` with `GateIndex` g, its pivot at the wall's middle (u = `trackWidth`/2, halfway between the surface and the top there), facing the travel direction. Its parts have the glass look, with `CanCollide`, `CanQuery` and `CanTouch` false: nothing hits, sees or touches them, so skaters pass through.
- **`ArenaParts.markers[g]`** becomes `{ parts: { BasePart }, position: Vector3 }`: every part of the panel, and its pivot's position.
  - ArenaGlow shows only the next gate's panel (R18): every part of it lit in the possessing team's colour, at its own transparency. It hides every other panel (`Transparency` 1) from the moment the arena's parts reach the client, and each panel it leaves.
  - The next-gate arrow (WorldMarkers) points at `position`.

### 5.3 The hanging goal

- **Placement:** the ring stands in gate 2's plane (`goalGateIndex`), its centre at u = `goal.across · trackWidth` (60) and `goal.heightAboveFloor` (18). Its front faces oncoming skaters, as today.
- **The rim and the panel** are built, tagged and glow as today. The panel slides up out of the ring when the goal opens.
- **Fit check** (`Features.goal`, against the profile as built at the gate). Each failure names its rule:
  - the rim's outline must stay inside the two glass faces;
  - it must clear the track's surface everywhere under it;
  - it must stay under the arm's beam (`goal.arm.height`), which must stay under the lip's start (`glass.top − glass.lipRadius`).
- **The arm:** two non-colliding, non-querying, non-touching blocks, `goal.arm.thickness` square, with `colors.goal`:
  - a post from the rim's top up to `goal.arm.height`;
  - a beam at that height from the post out to the outer glass's face.

  It is decoration: the art pass replaces it.

### 5.4 The carrier's beam (`client/CarrierBeam`, new)

- **What it is:** a tall thin glowing strip on the outer glass's inner face, from the solid wall's top (28) up to where the lip starts (108), beside the ball while someone carries it. It takes the possessing team's colour, which is the carrier's, and hides when no one carries the ball.
- **Where it is:** at the carried ball's distance along the track (`Centerline.distanceOf`), on the outer glass. It is placed with `Centerline.pose`, which gives the point (a Vector3) and the heading (an angle), neither of which allocates.
- **The part:** client-only (each client draws its own), built at `start`, Neon, with `CanCollide`, `CanQuery` and `CanTouch` false and no shadow: a skater riding the glass passes through it, and no ray sees it.
- **Each frame,** stepped by FrameController after ArenaGlow:
  - it reads `BallCarrier`, `BallPart` and the HUD's state;
  - it moves the part through `Position` and `Orientation`;
  - it writes `Color` and `Transparency` only when they change;
  - it allocates nothing.

### 5.5 Spawns and the middle

- **Team spawns:** on the lower floor's middle lane (u 22), as today.
- **Ball spawns:** on the track's middle at each curved end's apex, as today.
- **The middle:** a floor slab `surfaceThickness` thick, its top at the lower floor's height, out to the inner glass slab's back: a block between the straights and a fan of prisms under each curved end, as today. It is not a ride surface.

---

## 6. Code changes

Task 1 (PR #192) built the first version's shape. The revision changes:

### 6.1 Pure (`src/shared/Arena`)

| Module | Change |
|---|---|
| `Geometry/Profile` | The solid section as today with the new sizes; new `innerGlass`, `outerGlass` and `top` sections (§3.1), `topHeight`, and `topOutline` (the walls' top across the track, as points; `heightAt` reads a height on it). |
| `Geometry/Surface` | `build` sweeps the solid section; `rings` and `sweep` sweep the others. `section(arena, distance)` names the solid section at a distance (the step blended there), which the sweep, the goal's fit check and the gate walls share. |
| `Geometry/Features` | `glass` and `top` (swept sections) replace `barriers`; `gatePanels` replaces `markers`; `gates` as tall as the top; the new `goal` with its arm and fit check; the middle behind the inner glass slab. |
| `Geometry/Reach` | Removed (§2.3, 6). |
| `Geometry/init` | `build(config)` returns `surface`, `glass`, `top`, `infield`, `gates`, `goal` (with `arm`), `gatePanels`, `teamSpawns`, `ballSpawns`. Gravity is no longer needed. |
| `Geometry/Bounds` | `inArena` up to `Profile.topHeight`. |
| `Geometry/Centerline` | `distanceOf(arena, position)`, the inverse of `frameAt`; and `pose(arena, distance, lateral, height)`, the point (a Vector3) and the heading (an angle), on which `frameAt` and `at` build. |
| `Tags` | `Barrier` now marks the top; `RideSurface` covers the glass. |
| `TaggedLayout` | Markers may be a Model or a part. |

### 6.2 Server

- **`Arena/Builder`:** folders `Surface` and `Glass` (RideSurface), `Top` (Barrier), `Infield` (no tag), `Gates`, `Goal` (hoop, panel, arm), `GatePanels`, `Spawns`; the looks of §4.1, §4.2 and §5.2. `Barriers` and `Markers` are gone.
- **`ArenaService`:** `Geometry.build(config)`, no gravity.
- **`BallService`** and **`MovementGuard`:** `Bounds.inArena` as today.

### 6.3 Client

- **`RideSurfaces`:** `solid` and `destroy` (Task 2's work).
- **`SkateController`:** the sweep uses `solid`.
- **`ArenaParts`:** panel markers.
- **`ArenaGlow`:** lights every part of a panel.
- **`WorldMarkers`:** the arrow aims at the panel's position.
- **`CarrierBeam`:** new, in `Modules` after ArenaGlow, so the client starts 18 modules.
- **`FrameController`:** steps the beam after the arena's glow.

---

## 7. Testing

**Unit (pure):**
- **Profile:** the solid section's points and strip counts with the new sizes; the glass sections (the lip's ends, its centre, `lipStrips`); the top section of each kind; `topHeight` of each kind; the walls' top outline.
- **Surface:** `section` at a distance, the step blended there.
- **Features:**
  - glass: vertical up to the lip, the lip's end, one block per side along a straight for the vertical glass, slabs behind the faces;
  - top: closed at `glass.top` between the lips' ends; open with its strips and ceiling at `glass.top + ceilingAbove`;
  - gates: as tall as the top, of each kind;
  - gate panels: the wall from the surface to the top outline, a break at every point of both outlines, close breaks merged, the pivot at the wall's middle, `GateIndex` order;
  - the goal: lateral 60, facing oncoming skaters, each fit failure; the arm from the rim to the outer glass;
  - spawns and the middle.
- **Bounds:** inside: the floors, the bank, both glass walls, up to the top plus the margin (each kind); outside: past either glass, under the floor, over the top.
- **Centerline:** `distanceOf` round trip on both straights and both ends, the wrap at gate 1, and `pose` against `frameAt`.
- **Config:** the new defaults, each new field rule, each cross-field rule (exact messages).

**Client and server, in Edit:**
- **Builder:** folders, tags, `GateIndex`, the glass and top looks (taken from `glass.material` and `glass.transparency`, a non-default look included), touchable glass and top, no shadow on glass or the top, the middle untagged, both kinds of top.
- **RideSurfaces:** `solid` holds the top, `params` does not.
- **SkateController:** the sweep stops at the top (real parts in Edit, like the seam test), and the ground ray ignores it.
- **CameraController:** the top between the camera and the skater does not pull the camera in.
- **ArenaParts, ArenaGlow, WorldMarkers:** the panel markers; ArenaGlow hides every panel but the lit one, and never the goal.
- **CarrierBeam:** hidden without a carrier, beside the ball on the outer glass in the team's colour, writes only on change.
- **MovementGuard and BallService:** in and out by `inArena`.
- **Integration:** the arena built from the shipped config, every tag present, the ground found on the glass.

**Mutations:** one per guard, as every phase, recorded in the ledger.

**Studio checks:**
- **Launches:** #176's runs into the walls and toward the top at 120–140 studs/s; nobody gets out; record the highest point.
- **A lap at cruise:** its time.
- **The part count:** under 15,666.
- **The client's frame:** the beam's step, and allocations in a plain probe (expected 0 per frame).
- **The console:** only the two ready lines (`modules=8` / `modules=18`).
- **The owner's playtest** after a republish of `build/game.rbxl`.

---

## 8. Suggested order of tasks (the plan decides)

1. *(Done: Task 1, PR #192.)* The open-top shape at the first version's sizes, `Bounds.inArena`, the Builder's folders.
2. The top: `Arena.top`, both kinds, `RideSurfaces.solid` and the sweep; the reach check goes.
3. Rideable glass with lips, the wider track and the taller walls.
4. The gate panels: Features, the Builder, ArenaParts, ArenaGlow, WorldMarkers.
5. The hanging goal and its arm.
6. `Centerline.distanceOf` / `pose` and `CarrierBeam`.
7. The Studio checks, the M1 spec's §9–§10 text, the republish, and the owner's playtest.
