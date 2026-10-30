# M1 — Foundation & Core Match (Normal Champions) — Design Spec

- **Date:** 2026-10-21
- **Milestone:** [M1 - Foundation & Core Match](https://github.com/DalyChouikh/blox-champions/milestone/1)
- **Status:** Approved in brainstorming (sections 1–9); awaiting written-spec review
- **Game:** Blox Champions — a 3v3 roller-skate ball game on Roblox modeled on Ubisoft's Roller Champions

---

## 1. Purpose and scope

### 1.1 Intended outcome

A playable, fully tested **Normal Champions** 3v3 match on a graybox arena: players skate with momentum, carry and throw the ball, complete laps to open the goal, score, tackle, and finish a match with a score tab and MVP. M1 also lays the foundation (toolchain, project layout, config system, test harness, CI, GitHub workflow) that every later milestone builds on.

### 1.2 Success criteria (Definition of Done for M1)

1. A full match can be played in Studio's multi-client local test (2–6 players) from kickoff to a result, including golden-goal overtime and Last Chance, on PC (keyboard/mouse), gamepad, and mobile (touch, verified with Studio device emulation).
2. Every rule in §4–§6 is covered by unit tests; integration tests in §12.2 pass; CI (§12.3) is green on `main`.
3. Every gameplay number lives in `src/shared/Config/*`. Changing a value never requires a code change. Config is validated at startup and by a test.
4. All code is `--!strict` Luau, passes StyLua, selene, and luau-lsp analysis.
5. Every M1 GitHub issue is closed by a merged pull request.

### 1.3 Out of scope for M1 (later milestones)

| Not in M1 | Milestone |
|---|---|
| Bots / AI players | M2 |
| Practice map, dummies | M3 |
| Lobby hub, always-running Mayhem match, team join boxes | M4 |
| Mayhem items | M5 |
| Saving player data, levels, Champions Gold, item rolls, player-facing settings menu | M6 |
| Ranked queues, rating, leaderboards | M7 |
| Cosmetic skins beyond the default, goal effects/emotes, player card, shop, Robux | M8 |
| Final art (Blender meshes, materials), authored animations, music | Art pass (scheduled after M1 feel is tuned) |

M1 does include the **registries** (ball skin, skate skin) holding one default entry each, so later skins are data additions (§9.4).

---

## 2. Decisions log (from brainstorming, 2026-10-21)

| # | Question | Decision |
|---|---|---|
| Q1 | How laps count | **Team streak.** Laps belong to the possessing team; passes keep the count; resets to 0 only when an opponent gains the ball. *Every streak starts at the goal's gate (2026-10-27, the owner's playtest of the Arena part; §4.2).* |
| Q2 | After a point | **Full kickoff reset.** Both streaks → 0, everyone respawns at team spawns, countdown, ball drops at a **random** ball spawn point. |
| Q3 | Tie at 0:00 | **Golden-goal overtime** (no time limit) **plus Last Chance** (user-defined, §5.3). |
| Q4 | Extra moves | **Uppercut, Draft, Tiptoe, Air tackle / air dodge** added to the user's list. |
| Q5 | Who can attach | **Any player** can attach behind a teammate. |
| Q6 | Save definition | **Block or steal** (§6.3). |
| Q7 | Devices | **PC + mobile + gamepad** from M1. |
| Q8 | Character | **Own Roblox avatar + skates**, one fixed collider for everyone. |
| Q9 | Arena art | **Graybox now**, art later. |
| Q10 | Goal placement | **Upright raised ring at a corner gate (Gate 2) on the outer wall**, on the carrier's right shoulder; track runs **counter-clockwise**. *The placement is superseded by the Arena spec's R7 (2026-10-26): the ring hangs over the track at Gate 2 from an arm (§9.1). The gate and the direction stay.* |
| Q11 | Ground shape | Straights: walls both sides, **lower floor by the infield, one smooth wavy step up to a higher floor by the outer wall** (pump down it for speed). Curved ends: **normal floor curving up into the walls (U/J)**. |
| A1 | Movement approach | **Custom skate controller** on physics constraints (not Humanoid, not ControllerManager). |
| A2 | Enclosed arena (2026-10-22) | **The track is a closed tube**: a roof spans the track (half-circle, radius `trackWidth / 2`, top at 50 studs), and both walls rise to **28 studs** (`infieldWallHeight` 20 → 28). The skater's pump on a bank can no longer carry them out of the arena. *Superseded by A7 (2026-10-26).* |
| A3 | Riding the roof (2026-10-22) | **Walls by speed, roof by loop physics.** Walls keep `minWallSpeed`. Past straight up, a skater stays on only while `speed² × curvature ≥ gravity's pull off the surface`. A flat ceiling never holds, at any speed. *The loop rule stays: it is the real-physics rule for the glass's lips (A7; Arena spec 2.3, 7). The walls' rule (`minWallSpeed`) is the Feel part's. **Replaced (#216):** walls hold at any speed and gravity pulls along them at a third of its strength (§7.2 Wall riding); the loop rule is unchanged.* |
| A4 | Future art and maps (2026-10-22) | **Glass walls** in the art pass (ground stays opaque). **More maps, picked at random each game**, later: the arena stays data-driven. |
| A5 | Packages (2026-10-23) | **Roblox's own maintained packages:** React Luau (`roblox/react`, `roblox/react-roblox` 17.3.13) for the HUD and Jest Roblox (`roblox/jest`, `roblox/jest-globals` 3.20.1) for tests. They replace the `jsdotlua` copies, which had not changed since December 2024. |
| A6 | The M1 overhaul (2026-10-25) | **Match Roller Champions 1:1 in play, with Illegal Soccer's polish**, after the owner studied both games (videos in §15): their feel, rules and layout ideas, never their art, logos, names or music. Phase 9's Config tuning pass is replaced. After Phase 9, M1 continues in four parts, in this order, each with its own spec, plan and test-first tasks: **Arena** (RC's size and shape, an open top with glass barriers, gate arches and a beam beside the carrier) → **Feel** (camera, real physics on walls, jumps, landings, double jump, no action spam) → **Ball & rules** (passes through the air, shooting, 1/3/5 points for 1/2/3 laps, kickoff, leavers, team switching, networking) → **Presentation** (a lighter HUD and phone buttons, goal replay and celebration, cutscenes). Sound, music, art, animations, the stadium and crowd, more maps and the tutorial move to a later milestone; fans to M6; the practice park to M3. *The Arena part's shape is A7's and the Arena spec's R18 (rideable glass with lips, gate walls), not its first version's.* |
| A7 | The arena's enclosure (2026-10-26; replaces A2 and A3's roof) | **Rideable glass walls with lips, closed by a per-map top** (Arena spec, `docs/superpowers/specs/2026-10-25-m1-arena-design.md`, §2.2). The opaque floor, the inner bank and the outer wall rise into rideable glass up to `glass.top`, each wall curling inward into a lip. Above them, `Arena.top` closes the arena: a glass roof (Closed, our map) or an invisible ceiling 20 studs higher (Open). The top stops skaters and the ball and is never ridden. |

---

## 3. Architecture

### 3.1 Principles

- **Pure core, thin shell.** `Rules/`, `Skate/`, `Arena/Geometry`, `Actions/` contain plain Luau with no Instance access. They are unit-tested in milliseconds. Services (server) and controllers (client) adapt them to parts, remotes, input, and UI.
- **Config is data.** All tunables are typed, frozen tables in `src/shared/Config/`. A validator (`Config/Validate.luau`) checks types, ranges, and cross-field invariants at server and client start; a test runs it against the shipped config.
- **Game modes are config.** `src/shared/Modes/NormalChampions.luau` is a table of overrides on the default config plus feature flags (`itemsEnabled = false`). Mayhem (M5) is another mode file.
- **Events, not coupling.** The rules engine emits typed events (§4.7). ScoreKeeper, HUD feed, and later systems (progression, ranked) subscribe.
- **Explicit dependencies.** A small, tested loader (`src/shared/Util/Loader.luau`) starts services/controllers in declared order, passing dependencies explicitly so tests inject fakes. No third-party framework.

### 3.2 Repository layout

```
blox-champions/
├─ rokit.toml                  pinned tools
├─ wally.toml                  packages
├─ default.project.json        Rojo: production build (no tests/dev packages)
├─ test.project.json           Rojo: production + tests + dev packages
├─ selene.toml  stylua.toml  .luaurc
├─ src/
│  ├─ shared/                  → ReplicatedStorage.Shared
│  │  ├─ Config/               Match, Scoring, Movement, Actions, Ball, Arena, Input, Camera, UI, Network
│  │  ├─ Modes/                NormalChampions
│  │  ├─ Rules/                Possession, LapTracker, GoalJudge, MatchClock, MatchOutcome,
│  │  │                        LastChance, ScoreKeeper, AssistTracker, SaveDetector, MatchEngine
│  │  ├─ Skate/                SkateMath (pure step function), Draft, Attach
│  │  ├─ Actions/              ActionRunner, action definitions
│  │  ├─ Ball/                 BallState, Trajectory
│  │  ├─ Arena/                Geometry (pure), Tags
│  │  ├─ Skins/                BallSkins, SkateSkins registries
│  │  ├─ Net/                  Remotes (all remote definitions), Schemas
│  │  └─ Util/                 Signal, Loader, Freeze, Types
│  ├─ server/                  → ServerScriptService.Server
│  │  └─ MatchService, TeamService, BallService, ActionService, ArenaService,
│  │     MovementGuard, CharacterService
│  └─ client/                  → StarterPlayerScripts.Client
│     └─ SkateController, InputController, CameraController, PoseController,
│        BallIndicatorController, HudStore, Hud/ (React components)
├─ tests/                      *.spec.luau mirroring src/ (unit) + tests/integration/
├─ docs/superpowers/           specs/, plans/
└─ .github/                    workflows/, ISSUE_TEMPLATE/, pull_request_template.md
```

### 3.3 Authority model

| Concern | Owner | Notes |
|---|---|---|
| Own skater movement | **Client** (Roblox default network ownership of the character) | Instant response. Server sanity-checks (§10.3). |
| Ball state, possession, laps, goals, score, clock | **Server** | Clients only render. |
| Actions (tackle, dodge, uppercut, throw, pass, attach) | Client predicts animation/feel; **server validates and applies** | §8.1 |
| HUD | Client | Driven by server rule events + snapshot on join. |

---

## 4. Rules of play (pure, in `src/shared/Rules/`)

### 4.1 Possession (`Possession`)

- **Possessing team** = the team whose player last **held** the ball.
- It changes **only** when a player of the other team **picks up** the ball (catch or ground pickup).
- Loose ball, missed pass, deflection, or knock-loose do **not** change it.
- After a kickoff reset, possession is **neutral** until the first pickup.
- Emits `PossessionChanged { team, player, previousTeam }`.

### 4.2 Laps (`LapTracker`)

- The arena has **4 lap gates** at the corners where straights meet the curved ends, numbered in track order (§9.1). Each gate is a rectangle spanning the track with a **forward normal** pointing along the track direction.
- Lap progress tracks **the ball**: each server tick, the segment from the ball's previous position to its current position is tested against every gate rectangle (carried, flying, or loose — so a pass thrown through a gate counts).
- A crossing counts **either way**, from the gate's front or its back, while the possessing team is not neutral (the owner, 2026-10-27: "the player can record passing the gate either ways, from the back or the front, but the order of the gates is the same"). The segment must start off the gate's plane and end on it or past it, so a ball that stops exactly on the plane counts once. *(Until 2026-10-27: only forward crossings, segment direction · gate normal > 0, counted.)*
- **Every streak starts at the goal's gate** (`Arena.goalGateIndex`, Gate 2): from the moment the streak starts, it is the next gate, so its marker shows on the pickup. Only the **next gate in order** counts; out-of-order crossings are ignored, whichever way they go. A lap runs Gate 2 → 3 → 4 → 1 and ends just before the goal (the owner, 2026-10-27, after playing the Arena part: "it should start from the marker that is close to the goal ... so that then players just see the goal open and ready to shoot"). A carrier who picks the ball up just past Gate 2 may turn back through it: that is their first marker. *(Until 2026-10-27: the first forward crossing after the streak started set the sequence, whichever gate it was.)*
- 4 accepted crossings in order = **1 lap**. Emits `GateCrossed { team, gateIndex, progress }` and `LapCompleted { team, streak, holder }`.
- The streak resets to 0, and the next gate to the goal's, on `PossessionChanged` to a different team and on kickoff reset.

### 4.3 Goal (`GoalJudge`)

- One **goal ring** (upright, raised) at the configured gate (§9.1). Closed: a **panel** covers it and the ball bounces off.
- The goal **opens for the possessing team** when its streak ≥ `Match.lapsToOpenGoal` (4). Emits `GoalOpened { team }`. It closes on possession change to the other team or on any point (`GoalClosed`).
- A **goal** is scored when the ball's tick segment passes through the ring's disc **either way**, front or back, while the goal is open for the possessing team (the owner, 2026-10-27: "also the goal should be able to get scored by either way, front or back"), by the same crossing rule as a lap gate (§4.2). *(Until 2026-10-27: only front-to-back, with the track direction, scored.)*
- The goal is credited to the possessing team; the **scorer** is the possessing-team player who last held the ball. A defender's deflection that still goes in counts.
- Emits `GoalScored { team, scorer, assister? }`.

### 4.4 Streak point

- When the possessing team's streak reaches `Match.lapsForStreakPoint` (12), it earns `Match.pointValue.streak` (1) point, credited to the teammate who holds or last held the ball. Emits `StreakPointScored { team, holder }`.

### 4.5 Points and kickoff reset

- Goal and streak point are worth `Match.pointValue.goal` = 1 and `Match.pointValue.streak` = 1.
- After any point: celebration (`Match.celebrationSeconds` = 3), then **kickoff reset**: both streaks → 0, goal closed, possession neutral, all players respawn at their team's spawn points, movement frozen for `Match.kickoffCountdownSeconds` = 3, ball spawns at a **uniformly random** point from the arena's `BallSpawn` set (positioned on the line equidistant from both team spawns, §9.1).

### 4.6 `MatchEngine`

A single pure state machine composing the modules above. States: `Waiting → Kickoff → Live → Celebration → Kickoff …`, plus `LastChance`, `Overtime`, `Ended`. Input: timestamped facts (`tick(dt)`, `ballMoved(from, to)`, `pickedUp(player)`, `touched(player)`, `thrown(player)`). Output: an ordered list of events (§4.7). Deterministic for a given input sequence — the basis of the rule tests.

### 4.7 Event catalogue

`MatchStarted`, `KickoffStarted`, `KickoffEnded`, `PossessionChanged`, `GateCrossed`, `LapCompleted`, `GoalOpened`, `GoalClosed`, `GoalScored`, `StreakPointScored`, `AssistAwarded`, `SaveMade`, `Steal`, `TackleKnockdown`, `ClockWarning { secondsLeft }`, `LastChanceStarted`, `OvertimeStarted`, `MatchEnded { winner, mvp, stats }`.

---

## 5. Clock and match end

### 5.1 Clock (`MatchClock`)

- Counts down from `Match.durationSeconds` = 300.
- **Paused** during kickoff countdowns and celebrations (`Match.clockPausesDuringKickoff = true`).
- Emits `ClockWarning` at `UI.clockWarnings = {60, 30}` seconds.

### 5.2 Outcome (`MatchOutcome`), checked after every event

1. A team reaches `Match.pointsToWin` (5) → that team wins immediately.
2. Clock reaches 0:00:
   - Scores tied → **golden-goal overtime**: unlimited time; the next point (goal or streak point) wins. The HUD shows "OVERTIME" with a clock counting up from 0:00.
   - Trailing team behind by exactly `Match.lastChance.maxDeficit` (1) **and** is the possessing team → **Last Chance** (§5.3).
   - Otherwise → leader wins.

### 5.3 Last Chance (`LastChance`)

- Play continues with a "LAST CHANCE" banner.
- If the trailing team scores (goal or streak point) → scores tied → kickoff reset → **golden-goal overtime**.
- If a **leading-team player picks up the ball** → match ends, leader wins.
- A loose ball last held by the trailing team does **not** end Last Chance (possession unchanged, §4.1).
- `Match.lastChance.enabled = true`.

### 5.4 After the match

`MatchEnded` shows the end screen for `Match.postMatchSeconds` = 15, then a new match starts with auto-balanced teams.

---

## 6. Score tab, assists, saves, MVP

### 6.1 Points (`Config/Scoring`)

| Event | Default points |
|---|---|
| Goal (scorer) | 100 |
| Streak point (holder) | 100 |
| Assist | 50 |
| Save | 50 |
| Lap completed (possessing-team player who holds or last held the ball when the 4th gate is crossed) | 10 |
| Steal (gain possession from opponent) | 20 |
| Tackle knockdown | 10 |

### 6.2 Assist (`AssistTracker`)

The last **different** teammate who held the ball before the scorer, if the handoff to the scorer happened within `Scoring.assistWindowSeconds` = 8. At most one assist per point. Streak points have no assist.

### 6.3 Save (`SaveDetector`)

A save is either:

- **(a) Block:** a defender touches (catch, tackle-hit, uppercut, body contact) a **thrown** ball whose predicted ballistic trajectory (`Ball/Trajectory`, gravity only, no bounces) would pass through the **open** goal ring, either way, within `Scoring.saveLookaheadSeconds` = 1.5 (either of an arc's two crossings of the ring's plane; until 2026-10-27, front-to-back only); or
- **(b) Steal-save:** a defender's team gains possession from the team whose goal is currently open.

One action that satisfies both counts as **one** save. Emits `SaveMade { player, kind }`.

### 6.4 Score tab

Per player: score, goals, assists, saves, steals; grouped by team, sorted by score. Opened by Tab (PC), Select/View (gamepad), HUD button (mobile).

### 6.5 MVP

Highest score on the **winning team**. Tie-breakers in order: more goals, more saves, more assists, earliest join order.

---

## 7. Skating movement (custom controller)

### 7.1 Structure

- `Skate/SkateMath.step(state, input, ground, dt) -> state` is pure and deterministic. `state` = velocity, orientation, mode (`Grounded | Airborne | KnockedDown | Attached`). `input` = move vector (camera-relative), pump, brake, jump. `ground` = hit, normal, distance (from raycasts).
- `client/SkateController` each physics step: raycast ground (down along current up), call `SkateMath.step`, apply the result through a `LinearVelocity` constraint (velocity) and an `AlignOrientation` constraint (up = smoothed ground normal, forward = travel direction).
- The controller **hovers**: the root is held at `Movement.hoverHeight` above the raycast hit, so seams between arena strips (§9.2) never snag.
- **One ray's normal is not trusted.** Every arena part is a slab behind the riding surface, so a ray that lands exactly on a seam between two parts can hit the side face of a slab. Phase 3 measured this: a downward ray on a seam of the step returned the normal (0, 0.49, −0.87) instead of the step's slope. The controller therefore filters ground normals (for example, dropping one that turns sharply from the last and smoothing the rest) before using them for orientation or wall riding. The smoothing settles exactly on a surface's normal (#234): angles are measured with `atan2` of the cross and dot products, never the arccosine of a dot product, which read a 1.3e-4 rad gap as 4.88e-4 for float32 vectors a hair under unit length and kept the smoothed normal swinging across the glass's.
- The Humanoid remains for avatar display and joints; its movement is disabled. Avatar limbs are non-colliding; **one fixed-size collider** (`Movement.colliderSize`) is the same for every player regardless of avatar scale.
- Poses in M1 are code-driven on the character's Motor6D joints by `PoseController` (lean into turns, pump crouch, airborne tuck, tackle lunge, knockdowns, the Air Pose). The default Animate script is disabled. Authored animations come in the art pass.
- Knockdowns (#243) read the `KnockedDown` attribute's kind. A strike or a hard landing lays the skater flat on the back (`Pose.knockdownTiltDeg = 85` back, sunk `knockdownSinkStuds = 1.3` toward the ground); a diver lies face-down, kneeling on the belly (`diveDeg = 70` forward, thighs `diveHipDeg = 50` forward under the body, shins folded back `diveKneeDeg = 110`, sunk `diveSinkStuds = 0.7`). Both sinks fit the owner's R15 avatar: it touches the ground with no part below it (forward kinematics on its joints). Every knockdown eases into its pose and back upright once it ends over `knockdownEaseSeconds = 0.3` (smoothstep), kept per character. *The owner (#243): "give him like a real human being weight, just like RC"; RC's diver lands on the knees and belly and slides kneeling (Video 4, 32.3–33.4 s), its tackled skaters lie flat sliding (Video 1). Chosen on Studio screenshots; was a 60° tip back at standing height, snapping in one frame.*

### 7.2 Behaviors (all numbers in `Config/Movement`; initial values are tuning starting points)

| Behavior | Rule | Key config (initial) |
|---|---|---|
| Body | One collider shape for every player; root hovers above the ground hit; ground sensing ray length. | `colliderSize = Vector3.new(2, 2, 2)` (sphere), `hoverHeight = 2.5`, `groundProbeLength = 6` |
| Momentum | Gravity's component along the surface accelerates downhill / decelerates uphill. Rolling friction and air drag always apply. Soft cap: acceleration scales down linearly from `softCap` to `hardCap`, and on the ground speed past `softCap` bleeds off, each step losing 1 − e^(−`overSpeedBleed` × dt) of the excess (the further over, the faster). Hard cap clamps, on the ground and in the air: one ceiling for skating, the whip, dives and drops. *Roller Champions, measured (#214): nothing past 145 km/h; whipped to 144, back near 110 within a second; a dive gains speed in the air, so the bleed is the ground's. Was `hardCap = 140` with no bleed.* | `gravity = workspace.Gravity`, `rollingFriction = 4`, `airDrag = 0.02`, `cruiseSpeed = 60`, `softCap = 90` (108 km/h), `hardCap = 121` (145 km/h), `overSpeedBleed = 5` (/s) |
| Coasting | On the ground, a skater pressing nothing (no stick, pump or brake) loses `coastDecel` more speed per second on top of friction and drag, so swings from wall to wall die out. A knocked-down skater slides by `knockdownDecel` instead, and a diver glides with neither until their touchdown (§8.2 Dive). *The owner (#215): from cruise (72 km/h) to a stop in about 5 s (4.96 s with these numbers; 4.95 s measured in Studio). Without it a skater let go at cruise rolled 15 s on a straight, swinging across the track three times (28 s in an earlier let-go).* | `coastDecel = 7.5` (studs/s²) |
| Steering | Turn rate shrinks with speed (wider turns when fast), and on a wall never passes `wallTurnRate` (Wall riding, #239). | `turnRateLow = 4.0`, `turnRateHigh = 1.5` (rad/s) |
| Wall riding | Real physics (#216): a surface steeper than `wallAngle` is a wall, and it holds a skater at any speed. Gravity pulls along a wall at `wallGravityScale` of its strength (full in the air and on gentler surfaces), so a slow rider slides back down and a fast one climbs high and comes down faster. On a wall the skates only roll (#239): the stick never strides and turns the heading at most `wallTurnRate`, and the brake does nothing, so climbing costs speed, a rider slower than `wallGravityScale` × g / `wallTurnRate` (78 km/h) cannot hold a line along the glass and curves back down, and no one stands still or tiptoes on it. *The owner, at the Feel playtest: "why the player can just ride the wall and be stick to it like skating on the ground floor?". Measured on an upright wall with the stick held level along it: before, every rider stayed above 20 studs for the 20 s tested and ended at cruise; now a 30 km/h rider is back on the floor in 1.6 s at 86 km/h and a 90 km/h one holds a line ~1.9 s (RC, Video 3 21:09: ~2 s at 90). Braking used to hold a skater still on the glass, and brake + stick tiptoed them up it at 14 km/h.* *The owner: about a third, from a ranked player's ride up the glass, which lost speed about three times slower than full gravity would. The owner chose the 30° start from measured climbs (a skater sent straight at the outer glass at 108 km/h, nothing pressed: 30 studs from 60°, 40 from 45°, 46 from 30°): below 60° our wall's 18-stud curved foot cost most of the speed at full gravity. The pump step, 19° at its steepest, keeps full gravity. Was: below `minWallSpeed = 35` on a surface steeper than `maxStickAngle`, the skater fell off.* Past straight up (overhangs: the glass's lips, A7), the skater also needs loop physics: `speed² × curvature ≥ gravity's pull off the surface`, so a flat ceiling never holds (A3). A face leaning past vertical by float noise alone is a wall, not an overhang: the arena's built glass reads up to 6.5e-5 past vertical (measured, #234), and before that margin skaters dropped off it. The curvature is measured over the last `curvatureWindow` studs of the skater's path, so a lip's flat strips read as the arc they make (Phase 5 review). The top is never ridden (A7). | `wallAngle = 30`°, `wallGravityScale = 1 / 3`, `wallTurnRate = 1` (rad/s), `curvatureWindow = 10` (studs) |
| Pump (hold) | Multiplies the downhill gravity component; small push on flat ground; no gain uphill. Crouch pose. | `pumpSlopeMultiplier = 1.6`, `pumpFlatAccel = 8` |
| Brake (hold) | Strong deceleration to a stop. Nothing on a wall (Wall riding, #239). | `brakeDecel = 120` |
| Tiptoe (brake + steer) | Precise low-speed movement capped at `tiptoeSpeed`. Not on a wall, where the brake does nothing. | `tiptoeSpeed = 12` |
| Jump | Impulse along the current surface normal (walls launch you off); a jump keeps 1 − `jumpSpeedCost` of the speed along the surface. *The owner (#218): each jump costs 10%, no free jump spam.* | `jumpImpulse = 60` (a 9.2-stud jump), `jumpSpeedCost = 0.1` |
| Air Pose | The jump input in the air, once until landing: the fall is cancelled and `airPoseImpulse` is added straight up (a 4.5-stud hop, about half a jump), costing `jumpSpeedCost` of the speed across like a jump, and the skater strikes a pose (`Pose.airPoseDeg`, `airPoseArmDeg`: Roller Champions' superman stretch). Landing ends the pose and re-arms it. Every client sees it: the skater's `SkateState` carries it and the server sets `AirPosing` on the character. The jump's hint reads "Air Pose" in the air. *The owner (#218), from RC's Air Pose.* | `airPoseImpulse = 42` |
| Fall line | A diver in the air (§8.2) flies down a line `fallLineDeg` below their facing instead of falling straight: each step keeps the velocity's part along the line and adds gravity's pull along it (g sin `fallLineDeg`), less air drag, never past `hardCap`; the stick does nothing meanwhile. Across the ground that is 196.2 × sin 20° × cos 20° = 63 studs/s² (76 km/h per s). *The owner (#241): RC's readout climbed ~75 km/h per s diving down (Video 6).* | `fallLineDeg = 20` |
| Hard landing | A fall of `hardLanding.drop` or more onto ground flatter than `wallAngle` knocks the skater down for `hardLanding.knockdownSeconds`, sliding (a carrier drops the ball; the Get Up flow); landing on a wall or a bank is safe. The fall is the height from the top of the skater's last rise to where they come to rest (`hoverHeight` over the ground): any rise moves the top, so an Air Pose's hop breaks a fall, and riding the ground moves it too. The server judges it with its own ray along each skater's down every frame (`ActionService`, `Skate/Fall`); a server placement starts a fall over; no one scores the knockdown. *The owner (#222): 40 studs, above an uppercut's leap with an Air Pose at its top (31.5 + 4.5 ≈ 36), not the 20 first planned; and the height decides, because `hardCap` holds in the air: a free fall reaches it after 121² / (2 × 196.2) = 37.3 studs, so every longer fall lands at the same speed.* | `hardLanding = { drop = 40, knockdownSeconds = 1.5 }` |
| Draft | Inside a cone behind any player, extra acceleration scaled by closeness. | `draftRange = 18`, `draftConeDeg = 30`, `draftMaxAccel = 20` |
| Attach (Grapple Whip) | Any player holds Attach while within `attachRange` of a teammate and inside `attachConeDeg` of the direction directly behind them → attached: held at `attachFollowDistance` behind the leader, who keeps full control. Release (or `attachMaxSeconds` elapsed) → a boost of `attachBoostSpeed` toward the stick held as the skater lets go, or along the leader's travel direction with the stick at rest (RC's "Hold & Release + direction: Speed Boost", #214); then cooldown. | `attachRange = 8`, `attachConeDeg = 45`, `attachFollowDistance = 4`, `attachMaxSeconds = 3`, `attachBoostSpeed = 75` (90 km/h), `attachCooldown = 3` |
| Speedometer | Display value = speed (studs/s) × `speedometerScale`, labeled "km/h". The speed is Roller Champions' (#233, `SkateMath.shownSpeed`): along the surface the skater rides on the ground, on walls and behind a teammate (without the hover's pull off it), and across the ground in the air, so a standing jump reads 0 and a fall adds nothing. *Roller Champions: 0 during a standing jump (the owner's Video 5), steady through an Air Pose (Video 4: 21 → 21, 38 → 38), falling as a rider climbs the glass and rising as they come down (Video 3, 21:01). Was the 3D speed: 85 km/h right after a jump at 71.* | `speedometerScale = 1.2` |

Lap-time target for arena tuning: ~10–12 s per lap at `cruiseSpeed` (§9.1).

---

## 8. Actions, controls, camera

### 8.1 Generic action system (`Actions/ActionRunner`)

Each action is a data entry in `Config/Actions`:

```lua
Tackle = {
    phases = { windup = 0.05, active = 0.25, recovery = 0.35 },
    cooldown = 1,
    requires = { ball = "without", grounded = "any", notKnockedDown = true },
    effect = "Knockdown",
    pose = "Lunge",
    hit = { range = 7, coneDeg = 50, aimUpDeg = 0, knockdownSeconds = 1.5 },
    motion = { lungeSpeed = 40 },
    followUp = { action = "Dive", from = 0.1, to = 1 },
}
```

`ActionRunner` (pure) advances phases, enforces cooldowns/requirements and follow-up windows, and reports effect windows. A `followUp` names another action the same key starts from `from` to `to` seconds after this one started; an action named as a follow-up starts only then, and replaces the action it follows if that still runs. A refused (refunded) action or a reset opens no window. A key starts the first of its `Input.actions` that may start now (`ActionRunner.available`: its requirements fit the ball and the ground or air, and a follow-up's window is open): the Tackle key is a Dive 0.1–1.0 s after a Tackle, else a Tackle, or a Dodge with the ball. The client starts the action immediately (pose + motion); the server's `ActionService` re-checks requirements, cooldown and a follow-up's window (after the Tackle the server itself started, with `Network.actionTimingTolerance` = 0.1 s of slack on each edge), and resolves hits against server-side positions with `Network.hitLagToleranceStuds` = 3 extra range. The server's view of a jump lags the client's, so it never judges the air: an action needing the ground or the air may start there either way. An action with a `landing` (the Dive) ends on the skater's belly (§8.2). Adding an action (or an M5 item) = config entry + one effect function.

### 8.2 Action list (initial values in `Config/Actions`)

| Action | Requires | Behavior |
|---|---|---|
| Tackle | no ball, on the ground or in the air | Lunge: `lungeSpeed = 40` more along the facing, never past `lungeCap = 60` (72 km/h), a faster skater slowing to it; from the strike's end the speed eases back evenly over the recovery (0.35 s) to the speed before, and drops to it at once if the tackle stops early (refused, knocked down), so a tackle never makes a skater faster. In the air the lunge is the Tackle's own `airMultiplier = 0.4` as strong (16 studs/s, 19 km/h), under the same ceiling. Speeds are the speedometer's (§7.2). *The owner (#241): Roller Champions' lunge peaked at 65–75 km/h whatever the speed before (31 → 75, 47 → 71, 82 → 73, 96 → 74) and fell back within ~0.3 s (Video 4); its air tackle added 15–19 km/h (Videos 5 and 6); was +40 that stayed, 0.8 in the air.* Hit opponent in cone → knockdown 1.5 s; a hit ball carrier drops the ball, which keeps their momentum. Cooldown 1.0 s; its key dives from 0.1 to 1.0 s after it (`followUp`). *The owner (#240): Roller Champions' "Dive" replaces "Tackle" 0.1–0.2 s after the press for 0.7–0.8 s, and "Tackle" is back 0.9–1.0 s after it (Video 4, five ground tackles); was 0.8 s, on the ground only.* |
| Dive | no ball, only as the Tackle's follow-up: the Tackle key 0.1–1.0 s after a Tackle, on the ground or in the air | `diveSpeed = 60` (72 km/h) along the way, or the speed already shown if faster (never `airMultiplier`'d): along the facing on the ground; in the air down the fall line, `Movement.fallLineDeg = 20` below the facing, where gravity's pull along the line (g sin 20° = 67 studs/s²) speeds the diver up to the `hardCap` ceiling (145 km/h): from an Uppercut's top (31 studs) the diver lands 0.98 s later at 136 km/h on the speedometer. *The owner (#241): RC's dive went 19 → 65 km/h at the press and climbed ~7.5 km/h every 0.1 s to 133 at the touchdown 1.1 s later (Video 6); was +60 at once along the facing.* Range 11, active 0.7 s, recovery 0.9 s. Until the touchdown the diver glides: the stick, pump, brake and jump do nothing, and on the ground only friction and drag slow them (no coasting or knockdown slowing). It ends on the belly: nothing else starts until the diver's first touch of the ground after the active phase, which knocks them down (`KnockedDown = "Dive"`) until their slide is slower than `landing.stopSpeed = 2` studs/s (2.4 km/h) along the ground, or for `landing.knockdownSeconds = 1.5` at most, in case a slope keeps them sliding; moving does not get them up sooner, and no Get Up prompt shows. *The owner (#242): RC's dive built to 67–70 km/h within ~0.4 s, glided there ~0.3 s, then slid to 0–3 km/h in 0.7–0.8 s, and every action came back at the stop, 1.5–1.6 s after the press (Video 6); no prompt showed (Video 4). Was 0.35 s, slowed at once, then the Get Up flow.* The server sees the touchdown with its own ray along the diver's down (`Movement.groundProbeLength`) against the arena's ride surfaces; no one scores that knockdown. *The owner (#221): Roller Champions' dive (Video 5 at 1:13) rose to 139 km/h and ended on the belly, sliding; it is its own anti-spam, so the 3 s wait after a dive planned earlier is dropped. The owner (#240): RC's dive follows a Tackle on the ground and in the air ("Tackle Dive: Square then Square", "Air Tackle Dive: X then Square then Square"), so mashing the key dives the skater onto the floor; #221 had made it the first Tackle press in the air.* |
| Dodge | ball | Side-step at `sideSpeed = 45` in the move direction; tackle-immune for 0.3 s; cooldown 1.5 s. |
| Uppercut | no ball | Knocks down an opponent in front/above (range 6, cone 60°). Leaps the skater straight up anywhere (`leapImpulse = 110`: about 31 studs from the ground, `airMultiplier` as strong in the air), never past `hardCap`. *The owner (#219): Roller Champions' uppercut launches on open floor; was a leap only within 5 studs of a wall.* No recovery (windup 0.05 s, active 0.2 s): a Tackle may start 0.25 s after the press. *The owner (#240): RC's air Tackle was ready 0.13–0.3 s after an Uppercut (Videos 5 and 6); was 0.4 s of recovery.* Cooldown 1.2 s. |
| Air dodge | ball, airborne | Same as Dodge with `airMultiplier = 0.8` on the side speed. |
| Charge Throw | ball | Hold to charge up to `chargeMaxSeconds = 1.0`; release throws along camera aim at `lerp(minThrowSpeed = 60, maxThrowSpeed = 160, charge)` + `inheritCarrierVelocity = 0.5` × carrier velocity. |
| Pass | ball | Magnetic pass at `passSpeed = 90` to a teammate who called within `callPassWindow = 3` s (most recent caller first), else the best-scored teammate inside `passTargeting.coneDeg = 70` and `passTargeting.maxRange = 120`, where score = `angleWeight (0.6)` × (1 − angle/cone) + `distanceWeight (0.4)` × (1 − distance/maxRange). With no valid target, the ball is passed straight along the aim at `passSpeed`. Homing acceleration `passHomingAccel = 60`; interceptable. |
| Call Pass | no ball | Shows a hand icon over you for `callPassWindow`; cooldown 1 s. |
| Ball Focus | — | Camera keeps the ball in view. Mode `Input.ballFocusMode = "Hold"` (`"Toggle"` available). A player-facing setting arrives with saved settings in M6. |
| Get Up | knocked down by a strike or a hard landing | Any movement input (keys, stick or touch stick) asks the server to get the skater up: once per knockdown, through the `GetUp` remote. The server gets them up `getUpAfter = 0.5` s after the knockdown at the soonest (at once if the request comes later); without a request they are up after the hit's `knockdownSeconds` (1.5 s). A "Get Up" prompt shows the movement keys meanwhile (§11.1). A knocked-down character's `KnockedDown` attribute holds why: `"Hit"` (a strike), `"Fall"` (a hard landing) or `"Dive"` (a diver's own touchdown, which Get Up does not end: the Dive row). *The owner (#220): Roller Champions' prompt shows the movement keys, and its skaters were up in under 1.8 s (Video 5 at 0:18).* |

### 8.3 Controls (`Config/Input` — single source for bindings and on-screen hints)

| Action | PC | Gamepad | Mobile |
|---|---|---|---|
| Move / Camera | WASD / Mouse | Left / Right stick | Thumbstick / swipe |
| Jump / Air Pose (in the air) | Space | ButtonA | Button |
| Pump (hold) | LeftShift | ButtonR2 | Hold button |
| Brake / Tiptoe (hold) | LeftControl | ButtonR1 | Hold button |
| Charge Throw (with ball) | MouseButton1 hold | ButtonL2 hold | Hold button |
| Ball Focus (without ball) | MouseButton2 | ButtonL2 | Toggle button |
| Tackle / Dive (0.1–1.0 s after a Tackle) / Dodge (with ball) | E | ButtonX | Context button |
| Uppercut | Q | ButtonB | Button |
| Pass / Call Pass | R | ButtonY | Context button |
| Attach (hold) | F | ButtonL1 | Appears only when behind a teammate |
| Score tab | Tab | ButtonSelect | HUD button |

The gamepad layout mirrors Roller Champions' console layout (Ball Focus / Charge Throw on L2, Pump R2, Brake R1, Jump, Tackle, Uppercut, Call Pass, Grapple on L1).

### 8.4 Camera (`client/CameraController`)

Third-person chase camera with mouse lock. `Camera.distance = 12`, `Camera.height = 4`, FOV from `fovBase = 70` to `fovMax = 90` scaled by speed toward `hardCap`. Ball Focus rotates the camera to keep the ball in frame while staying behind the player. Spectators get a camera that follows the ball.

**Tilt (#223).** The camera's up rolls toward the surface the skater rides at `rollResponse`, but leans at most `Camera.maxTiltDeg = 30`° from world up. On the glass the floor never stands up on screen, and over a lip the view never turns past sideways or loops. Under a surface facing straight down it keeps the lean it has, and it rolls back level when the surface flattens. *The owner picked 30° from Studio screenshots at 0–90°. Roller Champions, judged by eye: about 15–30° in the owner's own games, 60–90° in ranked players' glass rides. Before this, the camera rolled all the way with the surface and looped over overhangs.* The validator keeps the limit under 90°, so two ups the camera may take are never opposite and a roll always has an axis. The stick still follows the screen: `SkateController` lays the camera's right and look on the skater's surface, so on the glass, pushing toward the wall climbs it at full strength under a leaning camera too.

### 8.5 Roblox defaults that conflict with our bindings

- Roblox's Shift Lock option uses Shift, which we bind to Pump → `StarterPlayer.EnableMouseLockOption = false` (our camera handles mouse lock).
- The default player list opens with Tab, which we bind to the score tab → the `PlayerList` core GUI is disabled with `StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)`.
- Both are verified in a Studio playtest as part of the input issue.

---

## 9. Arena (graybox) and the ball

### 9.1 Layout (`Config/Arena`)

The arena follows the M1 overhaul's Arena spec (`docs/superpowers/specs/2026-10-25-m1-arena-design.md`, decisions R1–R18 and A7). Its §3 holds the full cross-section and every size; this section summarises them.

```
                Gate 2 + GOAL RING (hanging, ¾ across)         Gate 1
                   ▼  ◄────────── top straight (stepped) ─────────  │
            ╭──────┼──────────────────────────────────────────────┼──────╮
           ╱       │   [Blue spawn]                                │       ╲
   curved │  ▼     │      ╭────────────────────────────────╮      │     ▲  │ curved
   end    │ (ball  │      │  MIDDLE (closed off, 40 wide)  │      │ (ball│  end
          │ spawn) │      ╰────────────────────────────────╯      │ spawn)
           ╲       │   [Orange spawn]                              │       ╱
            ╰──────┼──────────────────────────────────────────────┼──────╯
                Gate 3  ───────── bottom straight (stepped) ─────►  Gate 4
                         track direction: COUNTER-CLOCKWISE
          at every gate a thin glass wall stands across the track; only the next one shows
```

- `trackDirection = "CounterClockwise"` (outer wall on the skater's right).
- Gates numbered in track order: Gate 1 top-right, Gate 2 top-left, Gate 3 bottom-left, Gate 4 bottom-right.
- **The goal (R7):** `goalGateIndex = 2`. The upright ring hangs over the track in Gate 2's plane:
  - its centre is `goal.across` (0.75) of the way from the inner glass to the outer glass, `goal.heightAboveFloor` (18) up, and its front faces oncoming skaters;
  - it hangs from a decorative arm: a post from the rim's top up to `goal.arm.height` (40), then a beam out to the outer glass;
  - when open, its panel slides away and the ring glows in the possessing team's color.
- **Gate panels (R6, R18, amended after the playtest):** they replace the flat corner markers.
  - At every gate a thin glass wall (`gatePanel.depth` 0.2) fills the track's whole cross-section, from the surface up to the walls' top, and skaters pass through it.
  - Nothing hits, sees or touches a wall. Only the next gate's wall shows, glowing in the possessing team's color; every other wall is invisible. Every streak starts at the goal's gate (§4.2), so its wall shows from the pickup. The ball carrier sees an on-screen arrow to its middle.
- **The carrier's beam (R6):** a glowing strip on the outer glass travels beside the carried ball, in the possessing team's color (`client/CarrierBeam`).
- **Team spawns** on opposite straights, mirrored across the arena's long axis (Blue on the top straight, Orange on the bottom). **Ball spawns** on the long axis, equidistant from both team spawns (one in each curved end). Both teams score in the same goal, so fairness comes from the mirrored spawns and the random ball spawn, not from distance to the goal.
- **Cross-sections** (Arena spec §3.1):
  - **The enclosure (A7):** the floor, the inner bank (8 high) and the outer wall (28 high) are opaque. They rise into **rideable glass** up to `glass.top` (120), clear plastic at 85% see-through (R5's look: Roblox's Glass material hides every see-through part behind it), and each wall ends in a **lip** curling inward (a quarter circle of `glass.lipRadius`, 12). A **per-map top** closes the arena: a glass roof at 120 (`top.kind = "Closed"`, our map) or an invisible ceiling 20 higher (`"Open"`). The top stops skaters and the ball and is not ridden.
  - **Straights:** a **lower floor** next to the inner bank, one **smooth step** up to an **upper floor** next to the outer wall's foot curve (skating down the step is a pump spot).
  - **Curved ends:** the floor curves up into the walls, with no step.
  - Between straight and end, the profile **blends smoothly** over `profileBlendLength`.
  - **The middle** (40 wide) is closed off behind the inner glass: a floor slab that is not a ride surface.
- **Dimensions (studs):**
  - the loop: `straightLength = 200`, `endRadius = 60` (centerline), `trackWidth = 80`, so the arena is 200 across;
  - the solid profile: `outerWallHeight = 28`, `innerBankHeight = 8`, `wallCurveRadius = 18`, `stepHeight = 4`, `stepWidth = 18`, `upperFloorWidth = 8`, `profileBlendLength = 20`, `segmentLength = 4`, `stripsPerSection = 20`;
  - the enclosure: `glass = { top = 120, lipRadius = 12, lipStrips = 4, transparency = 0.85, material = SmoothPlastic }`, `top = { kind = "Closed", ceilingAbove = 20 }`;
  - the features: `gatePanel = { depth = 0.2 }`, `goal = { ringRadius = 7, heightAboveFloor = 18, across = 0.75, arm = { thickness = 1, height = 40 } }`.
- **The lap:** the centerline loop is 2·200 + 2π·60 ≈ 777 studs. A skater holding the stick laps in 12.7–12.8 s (measured 2026-10-26), past the 10–12 s target until the Feel part tunes speeds (Arena spec 2.3, 13).

### 9.2 Arena generation

- `Arena/Geometry` (pure) builds the centerline loop and sweeps each cross-section around it (`Profile`: the solid section, the two glass sections with their lips, the top of each kind). It returns the pieces of every part: `surface`, `glass`, `top`, `infield` (the middle's floor), `gates`, `goal` (rim, panel and arm), `gatePanels`, `teamSpawns` and `ballSpawns`. Unit-tested: closure of the loop, continuity between strips, profile heights at known stations, gate, wall and goal placement.
- `server/ArenaService` turns the geometry into **anchored parts** (strips of thin parts and wedges) at server start, through `server/Arena/Builder`, which groups them in folders (Arena spec §6.2):
  - `Surface` and `Glass`, tagged `RideSurface`: the floors, banks, walls and the rideable glass, which skaters ride and every ray finds;
  - `Top`, tagged `Barrier`: the roof or the open map's ceiling, which only the skaters' collider sweep finds (`RideSurfaces.solid`), so skaters and the ball bounce off it but nobody rides it;
  - `Infield` (no tag), `Gates`, `Goal` (the hoop, its panel and the arm), `GatePanels` and `Spawns`.
- Gameplay code finds arena features **only by CollectionService tag**: `LapGate` (attribute `GateIndex`), `GoalHoop`, `GoalPanel`, `TeamSpawn` (attribute `Team`), `BallSpawn`, `CornerMarker` (attribute `GateIndex`; a gate wall's Model, or any single part), `RideSurface`, `Barrier`. Any future art model with the same tags drops in.
- EditableMesh is **not** used in M1: per Roblox docs it fails in published games unless "Enable Mesh / Image APIs" is turned on, it is capped at 60,000 vertices / 20,000 triangles per mesh, and its docs show only `Hull` collision. Revisit in the art pass.

### 9.3 Ball (`Ball/BallState`, `server/BallService`)

- States: `Dead` (during kickoff) → `Loose` ↔ `Flying` ↔ `Carried(player)`.
- **Carried:** attached to the carrier's hand; only the server assigns the carrier.
- **Loose / Flying:** a server-owned physics part (`SetNetworkOwner(nil)`), physical properties from `Config/Ball` (`radius = 1.5`, `elasticity = 0.5`, `friction = 0.3`). Magnetic passes add homing acceleration toward the receiver.
- **Pickup / catch:** a player who is not knocked down, within `pickupRadius = 5` (+ `Network.pickupLagToleranceStuds = 2`), gets the ball. The thrower cannot re-catch for `rethrowPickupDelay = 0.4` s.
- **Recovery:** if the ball is not inside the arena's box by more than `Ball.outOfBoundsMargin = 2` (`Bounds.inArena`: between the two glass faces, no lower than the floor and no higher than the top; Arena spec §4.4), or stays untouched for `ballIdleResetSeconds = 15`, it respawns at a random `BallSpawn`. Possession is unchanged. The top holds the ball, so only a fault puts it outside.
- Each server tick, the ball's previous→current segment is fed to `LapTracker` and `GoalJudge` (§4.2–4.3), so fast throws cannot tunnel through a gate or the ring.

### 9.4 Ball indicator and skins

- Client renders an always-on-top **ring** around the ball (possessing team's color; white when neutral), a **vertical line to a ground marker**, and an **edge-of-screen arrow** when off-screen.
- `Skins/BallSkins` and `Skins/SkateSkins` registries each hold one `Default` entry in M1. The ball's visual comes from the carrier's selected ball skin (always `Default` in M1). M8 adds entries as data.

---

## 10. Teams, characters, networking

### 10.1 Teams (`server/TeamService`)

- Teams **Blue** and **Orange** (colors in `Config/UI`). Max `Match.teamSize = 3` per team; joining players are auto-balanced (smaller team first; ties → random). Extra players spectate until a slot opens.
- A match starts when `Match.minPlayersToStart = 1` players are present (solo testing allowed; bots arrive in M2).

### 10.2 Remotes (`Net/Remotes` — every remote is defined here only)

| Remote | Direction | Payload | Notes |
|---|---|---|---|
| `ActionRequest` | client → server | `{ action: string, aim: Vector3?, charge: number? }` | Schema-validated; rate-limited per player (`Network.maxActionsPerSecond = 15`). |
| `ActionRejected` | server → client | `{ action: string }` | The server refused the action; the client cancels it (§13). |
| `SkateState` | client → server | `{ pump: boolean, brake: boolean, airPose: boolean }` | Sent when one changes; schema-validated; rate-limited per player (`Network.maxSkateStatesPerSecond = 20`); other clients pose from the attributes the server sets. |
| `GetUp` | client → server | `{}` | A knocked-down player moved (§8.2), once per knockdown; schema-validated; rate-limited per player (`Network.maxGetUpsPerSecond = 2`: one per knockdown, each at least `getUpAfter` long). |
| `MatchSnapshot` | server → client | full match state | Sent on join and on resync. |
| `RuleEvents` | server → client | ordered batch of §4.7 events | Drives HUD and feed. |
| `BallCarrier` | server → client | `{ carrier: Player? }` | Ball physics replicates natively when loose. |

### 10.3 Movement guard (`server/MovementGuard`)

Samples each character every `Network.guardSampleSeconds = 0.25`. If the upward move in a sample exceeds `Movement.hardCap × Network.speedTolerance (1.2)` for `Network.guardStrikes = 3` consecutive samples, or one move exceeds `Network.guardTeleportFactor = 2` times that allowance, falling excluded, the character is returned to its last valid position and the event is logged. A character whose root is not inside the arena's box (`Bounds.inArena`: past either glass face, under the floor or over the top; Arena spec §4.4) by more than `Network.guardOutsideMargin = 2` is placed back on its team spawn, and the event is logged (owner, 2026-10-24, #181). The top holds every skater, so only a fault puts one outside. The speed rule is judged first, so a jump out of the arena is a return, not a placement. A carrier placed on their spawn first drops the ball, still, where they were last inside the arena (owner, 2026-10-25), so leaving the arena never takes the ball home. The guard runs in MatchService's frame before the ball, and no move of a carrier by the server counts as the ball crossing a gate or the ring. Thresholds are config.

---

## 11. HUD and UI (React Luau)

### 11.1 Components (`client/Hud/`)

React Luau (Roblox's `roblox/react` 17.3.13 + `roblox/react-roblox` 17.3.13, A5) components rendered from a client `HudStore` that applies `MatchSnapshot` and `RuleEvents`.

- **Scoreboard (top center):** Blue score | timer | Orange score; `Match.pointsToWin` pips per team; ball-carrier name; **lap bar** for the possessing team — 4 segments per lap, "Lap n/4" until the goal opens, then "Streak n/12"; glows while the goal is open.
- **Banners (center):** kickoff 3-2-1, GOAL!, DENIED! (on a save), 60/30 SECONDS, LAST CHANCE, OVERTIME.
- **Event feed (bottom center):** possession changes, laps, goal open, scores.
- **World UI:** ball indicator (§9.4), next-gate arrow for the carrier, call-pass hand over teammates, team-colored name tags.
- **Control hints (right):** generated from `Config/Input`, filtered by context (with/without ball, airborne, just after a Tackle, near teammate) and by the current input device's glyphs.
- **Speedometer (bottom right):** the speed along the surface, or across the ground in the air (§7.2).
- **Get Up prompt (bottom center, above the feed):** while the local skater is knocked down by a strike or a hard landing (not a diver's own slide), the movement keys as the device shows them (the keyboard's first composite, up, left, down, right, named by the player's own layout, e.g. Z Q S D on AZERTY; the gamepad's stick glyph; "Move" on touch) and "Get Up" (§8.2).
- **Mobile controls:** laid out from `Config/Input`; context buttons appear only when usable.
- **Score tab** (§6.4) and **end screen** (winner banner, MVP card, team totals).

### 11.2 Text and colors

All strings and colors in `Config/UI` (team colors: Blue and Orange).

---

## 12. Tooling, testing, CI, workflow

### 12.1 Toolchain (versions verified on GitHub releases, 2026-10-21; Jest Roblox and React Luau on the Wally index, 2026-10-23)

| Tool | Version | Use |
|---|---|---|
| Rokit | 1.2.0 | Installs/pins the tools below via `rokit.toml` |
| Rojo | 7.7.1 | Sync files ↔ Studio; `rojo build` |
| Wally | 0.3.2 | Packages |
| StyLua | 2.6.0 | Formatting |
| selene | 0.32.0 | Linting |
| luau-lsp | 1.70.1 | Type checking (`--!strict`) |
| Jest Roblox | 3.20.1 (`roblox/jest`, `roblox/jest-globals`) | Tests (dev dependency; runs inside Roblox, in Studio and through Open Cloud Luau Execution) |
| React Luau | 17.3.13 (`roblox/react`, `roblox/react-roblox`) | HUD |

### 12.2 Testing

- **TDD:** every behavior starts as a failing test, then the minimal code to pass it, then refactor.
- **Unit tests** (`tests/**/*.spec.luau`): Rules (every clause in §4–§6), SkateMath (each behavior in §7.2 with exact numbers), ActionRunner and each action's requirements, BallState transitions, Trajectory, Arena Geometry, Config validation, Input mapping, Loader, Signal, HudStore reducers, React components (render + props).
- **Integration tests** (`tests/integration/`), run in a Roblox server context: generate the arena from config; move a ball part through gates and the ring and assert emitted events; simulate pickups/throws/tackles with test characters and assert possession, laps, goal, save, assist, and score.
- **Runner:** `test.project.json` places tests and dev packages in the DataModel; a runner script calls Jest Roblox and prints results. During development the suite is executed in the open Studio session through the Roblox Studio MCP connection.
- **Manual playtest checklists** on movement/feel issues (Studio multi-client local test + device emulation).
- **Performance targets (measured in integration tests / MicroProfiler):** server match logic < 1 ms average per Heartbeat with 6 players; client `SkateController` step < 0.5 ms.

### 12.3 CI (GitHub Actions, on every pull request and push to `main`)

1. `stylua --check src tests scripts`
2. `selene src tests scripts`
3. `luau-lsp analyze` with Roblox type definitions (`bash scripts/analyze.sh`, strict)
4. `rojo build default.project.json` and `rojo build test.project.json`
5. The CI scripts' Python (Phase 9): `ruff format --check scripts`, `ruff check scripts` and their unit tests, which must print no warning
6. **Jest suite via Open Cloud Luau Execution** — Roblox's API that runs Luau in a place headlessly; tasks run up to 5 minutes, at most 10 unfinished per place. The owner set it up once (#170, `scripts/ci/setup-cloud-tests.sh`): a private test game, whose universe and place IDs are GitHub repository variables (`ROBLOX_TEST_UNIVERSE_ID`, `ROBLOX_TEST_PLACE_ID`), and an Open Cloud API key restricted to that game, stored as the GitHub secret `ROBLOX_API_KEY`.

### 12.4 Git and GitHub workflow

- Each plan task → a **GitHub issue** in milestone #1, labeled by type (`feature`, `test`, `chore`, `docs`) and area (`rules`, `skate`, `ball`, `arena`, `actions`, `ui`, `input`, `infra`).
- One branch per issue (`feat/<issue>-<slug>`, `chore/…`, `docs/…`), one PR per issue with `Closes #<issue>`, CI green before merge into `main`.
- Small commits in Conventional Commits style (`test(rules): lap streak resets on opponent pickup`, `feat(rules): …`). Tests and code land together.
- Docs: `README.md` (setup for a newcomer: install Rokit, `rokit install`, `wally install`, Rojo Studio plugin, `rojo serve`), `CONTRIBUTING.md` (conventions above), issue and PR templates.

---

## 13. Error handling

- **Config:** invalid config fails fast at start with a message naming the key and rule violated; the config test catches it in CI first.
- **Remotes:** malformed or rate-exceeding payloads are dropped and counted per player; never trusted.
- **Actions:** a server-rejected action sends the client a correction (cancel pose/motion).
- **Ball:** out-of-bounds or idle → respawn (§9.3). A carrier leaving the game drops the ball as `Loose` at their last position.
- **Players leaving mid-match:** their team plays short; the slot reopens for joiners. Stats of departed players remain on the score tab.
- **Arena generation failure:** server logs and refuses to start the match (no partial arena).

---

## 14. Implementation phases

M1 is large, so the implementation plan is written and executed **per phase**, each phase producing working, tested software and its own set of GitHub issues:

1. **Foundation:** repo scaffolding, Rokit/Wally/Rojo projects, lint/format/typecheck, Config + validator, Signal, Loader, Jest-Lua runner in Studio, CI (steps 1–4), README/CONTRIBUTING/templates.
2. **Rules engine (pure):** Possession, LapTracker, GoalJudge, MatchClock, MatchOutcome, LastChance, ScoreKeeper, AssistTracker, SaveDetector, Trajectory, MatchEngine.
3. **Arena:** Geometry (pure) + ArenaService generation, tags, gates, goal ring/panel, markers, spawns.
4. **Ball + match wiring:** BallState, BallService, TeamService, MatchService, remotes, integration tests for laps/goal/possession on the generated arena.
5. **Skating:** SkateMath, SkateController, MovementGuard, CharacterService (collider, hover, poses).
6. **Actions:** ActionRunner, each action, ActionService validation.
7. **Input + camera:** Config/Input bindings for PC/gamepad/mobile, CameraController, Ball Focus, §8.5 defaults.
8. **HUD:** React Luau HUD, score tab, end screen, MVP.
9. **CI test execution + playtests:** Open Cloud Luau Execution job, real-device and multi-client playtests. Its config tuning pass was replaced by the overhaul (A6).

M1 then continues with the overhaul's four parts (A6), each designed in its own spec and planned on its own: **10. Arena**, **11. Feel**, **12. Ball & rules**, **13. Presentation**. Each part's spec states which sections of this one it replaces.

---

## 15. References (facts used in this design)

**Roller Champions**
- Scoring by laps and lap reset on opponent possession; checkpoints open the goal: Ubisoft game guide (2020), as summarized by web search (the page now returns HTTP 404): https://www.ubisoft.com/en-us/game/roller-champions/news-updates/3PfX2zoJnrnKuvTGsZzday/roller-champions-game-guide
- Controls (Pump, Brake & Tiptoe, Jump, Tackle/Dive, Dodge, Uppercut, Charged Throw, Magnetic Pass/Call for Pass, Grapple → Speed Boost/Super Jump, Draft, Ball Focus, air moves): https://outsidergaming.com/roller-champions-complete-controls-guide-for-ps4-ps5-xbox-one-and-xbox-series-xs-with-gameplay-tips-for-beginners/
- Team Grapple Whip (grab teammate, release, boost): https://ubisoft.com/en-us/game/roller-champions/news-updates/5kBACqgb3LkUoEW0d8auVi/dev-blog-team-moves
- Video observations — "Trying ROLLER CHAMPIONS Almost 2 YEARS LATER" (https://www.youtube.com/watch?v=t2JZw0nMcic): feed "Lap 1/2/3 Completed", "Orange goal is active", "Three points on the line", banners GOAL / DENIED! / 30 SECONDS REMAINING! / LAST CHANCE; HUD with score pips, timer, carrier name, segmented lap bar, km/h speedometer, context-sensitive control hints (L2 Ball Focus ↔ Charge Throw); ball ring + vertical line to ground marker; at 5:07–5:09 the goal is a raised upright ring at the end of a straight on the carrier's right, glowing in the possessing team's color.
- "8 MUST Know Tips For Roller Champions!" (https://www.youtube.com/watch?v=4Ofq9CFUWnQ) narration: pump on downward slopes; draft behind opponents; grabbing a teammate and letting go gives a large speed boost; dive tackles cover more area but recover slower; holding brake = tiptoe; uppercut near a wall gives a big leap.
- "Roller Champions: Wild Ones Launch Trailer" (https://www.youtube.com/watch?v=oTxqS3wVqGw): 55 s trailer; "pick a prize" unlock system.
- The overhaul's study (A6, 2026-10-25): "Roller Champions Gameplay", the E3 2019 pre-alpha with its tutorial (https://www.youtube.com/watch?v=GItLiPXpoZw), and "Let's Play Roller Champions in 2025", the released game (https://www.youtube.com/watch?v=DvufnT_DigM), sampled every 2 s. The observations are committed with the Arena part's spec.

**Illegal Soccer (Roblox)** — user's screen recording (2026-10-21): lobby overlooking the live match with Join Red/Join Blue pads showing open spots; separate "Legal Ranked"/"Illegal Ranked" queues each beside a "Top Elo" board; cosmetic pedestals (Jersey, Goal Effect, Emote); end-of-match awards (Guardian Angel – most saves, Box to Box – studs covered, Safe Hands, Final Boss). Item boxes/loadout/rolls: https://allthings.how/illegal-soccer-on-roblox-how-to-play-controls-and-item-boxes/ (informs M4–M8, not M1). The user's second recording (2026-10-25, 10:40) informs the overhaul's polish (A6): the HUD, the goal replay and celebration, knockdowns.

**Roblox platform**
- Luau Execution (Open Cloud): https://create.roblox.com/docs/en-us/cloud/reference/features/luau-execution.md
- ControllerManager (`UpDirection`; GroundController wall behavior undocumented): https://create.roblox.com/docs/en-us/reference/engine/classes/ControllerManager.md
- EditableMesh (published-game toggle, 60k vertices / 20k triangles): https://create.roblox.com/docs/en-us/reference/engine/classes/EditableMesh.md
- Jest Roblox (Roblox's Jest; Wally `roblox/jest`): https://github.com/Roblox/jest-roblox
- React Luau (Roblox's React; Wally `roblox/react`): https://github.com/Roblox/react-lua
