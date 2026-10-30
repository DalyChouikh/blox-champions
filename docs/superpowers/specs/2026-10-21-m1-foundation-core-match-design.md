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
| Q11 | Ground shape | Straights: walls both sides, **lower floor by the infield, one smooth wavy step up to a higher floor by the outer wall** (pump down it for speed). Curved ends: **normal floor curving up into the walls (U/J)**. *Superseded by the Feel part's #268 (2026-10-29): Roller Champions' structure, the owner's pick after playing six trials (§9.1, Arena spec §3.1).* |
| A1 | Movement approach | **Custom skate controller** on physics constraints (not Humanoid, not ControllerManager). |
| A2 | Enclosed arena (2026-10-22) | **The track is a closed tube**: a roof spans the track (half-circle, radius `trackWidth / 2`, top at 50 studs), and both walls rise to **28 studs** (`infieldWallHeight` 20 → 28). The skater's pump on a bank can no longer carry them out of the arena. *Superseded by A7 (2026-10-26).* |
| A3 | Riding the roof (2026-10-22) | **Walls by speed, roof by loop physics.** Walls keep `minWallSpeed`. Past straight up, a skater stays on only while `speed² × curvature ≥ gravity's pull off the surface`. A flat ceiling never holds, at any speed. *The loop rule stays: it is the real-physics rule for the glass's lips (A7; Arena spec 2.3, 7). The walls' rule (`minWallSpeed`) is the Feel part's. **Replaced (#216):** walls hold at any speed and gravity pulls along them at a third of its strength (§7.2 Wall riding); the loop rule is unchanged. **Then (#256):** full gravity on walls. **Generalised (#257):** the loop rule is the contact rule on every surface, so a wall bending away and a crest at speed let go too (§7.2 Wall riding). **Then (#289):** a wall that holds grips the skates against a bend away (`wallGrip`), and the curve is read the way the surface bends (§7.2 Wall riding).* |
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
- `client/SkateController` each physics step: raycast ground (down along current up, or toward the wall a skater left or touched, rising or falling: `SkateMath.groundRay`, §7.2 Landing on what they touch), call `SkateMath.step`, apply the result through a `LinearVelocity` constraint (velocity) and an `AlignOrientation` constraint (up = the ground normal, eased: `bodyUpSmoothing`; forward = the facing).
- The controller **hovers**: the root is held at `Movement.hoverHeight` above the raycast hit, so seams between arena strips (§9.2) never snag.
- **One ray's normal is not trusted.** Every arena part is a slab behind the riding surface, so a ray that lands exactly on a seam between two parts can hit the side face of a slab. Phase 3 measured this: a downward ray on a seam of the step returned the normal (0, 0.49, −0.87) instead of the step's slope. So the controller trusts a ground normal that turns more than `Movement.cornerDeg` from the last (a corner, or a seam's side face) only once a second ray in a row agrees with it (`Skate/NormalFilter`); a smaller turn is a curve and passes through as it is. **The skating follows the surface's own normal, never a smoothed one** (#255): smoothing small turns made the skating lag the surface on curved walls and added energy on every wall visit, so swings from wall to wall with nothing pressed never died (from 108 km/h, stepped over the real arena: floor crossings 96, 107, 97, 104, 90, 95 … km/h for 32 s; with the surface's normal 61, 38 and a stop at 6.1 s. In Play after the fix, nothing pressed, straight at the outer wall: 108 km/h came back at 76, then 60, and stopped at 7.5 s; 72 km/h at 43, 28, stopped at 7.6 s; 145 km/h at 91, 71, 43, 28, stopped at 13.5 s). The arena's curves are flat strips (§9.2), so through a turn under `cornerDeg` the speed along the ground is kept as it turns with it, as on the curve the strips stand for (the ground does no work); at a corner, or touching down, the speed into the new face is lost (projecting the speed onto every strip lost ~12% of it per wall visit). Only the looks ease: the skater body's up turns toward the skating's, each step closing 1 − e^(−`bodyUpSmoothing` × dt) of the gap, and stands upright at once for a freeze or a new character. Angles are measured with `atan2` of the cross and dot products, never the arccosine of a dot product, which read a 1.3e-4 rad gap as 4.88e-4 for float32 vectors a hair under unit length (#234).
- The Humanoid remains for avatar display and joints; its movement is disabled. Avatar limbs are non-colliding; **one fixed-size collider** (`Movement.colliderDiameter`) is the same for every player regardless of avatar scale.
- Poses in M1 are code-driven on the character's Motor6D joints by `PoseController` (lean into turns, pump crouch, airborne tuck, tackle lunge, knockdowns, the Air Pose). The default Animate script is disabled. Authored animations come in the art pass.
- Knockdowns (#243) read the `KnockedDown` attribute's kind. A strike or a hard landing lays the skater flat on the back (`Pose.knockdownTiltDeg = 85` back, sunk `knockdownSinkStuds = 1.3` toward the ground); a diver lies face-down, kneeling on the belly (`diveDeg = 70` forward, thighs `diveHipDeg = 50` forward under the body, shins folded back `diveKneeDeg = 110`, sunk `diveSinkStuds = 0.7`). Both sinks fit the owner's R15 avatar: it touches the ground with no part below it (forward kinematics on its joints). Every knockdown eases into its pose and back upright once it ends over `knockdownEaseSeconds = 0.3` (smoothstep), kept per character. *The owner (#243): "give him like a real human being weight, just like RC"; RC's diver lands on the knees and belly and slides kneeling (Video 4, 32.3–33.4 s), its tackled skaters lie flat sliding (Video 1). Chosen on Studio screenshots; was a 60° tip back at standing height, snapping in one frame.*

### 7.2 Behaviors (all numbers in `Config/Movement`; initial values are tuning starting points)

| Behavior | Rule | Key config (initial) |
|---|---|---|
| Body | One collider shape for every player; root hovers above the ground hit; ground sensing ray length. | `colliderDiameter = 2` (sphere), `hoverHeight = 2.5`, `groundProbeLength = 6`, `cornerDeg = 30`, `bodyUpSmoothing = 30` (/s) (§7.1) |
| Momentum | Gravity's component along the surface accelerates downhill / decelerates uphill. Rolling friction and air drag always apply. Soft cap: acceleration scales down linearly from `softCap` to `hardCap`, and on the ground speed past `softCap` bleeds off, each step losing 1 − e^(−`overSpeedBleed` × dt) of the excess (the further over, the faster). Hard cap clamps, on the ground and in the air: one ceiling for skating, the whip, dives and drops. *Roller Champions, measured (#214): nothing past 145 km/h; whipped to 144, back near 110 within a second; a dive gains speed in the air, so the bleed is the ground's. Was `hardCap = 140` with no bleed.* *The owner (#265, Q30): the stride tops out at 55 km/h, like Roller Champions' 45–58 on the flat (Videos 13–15); was 60 (72 km/h). Measured in Play, the stick held on a straight: 45.9–46.5 studs/s (55–56 km/h).* *The owner (#279, Q44–Q46): gravity at two thirds of Roblox's default, after "player currently can't even go up into the outer wall from the middle straight" (Video 23) and "don't measure with their speedometer or ours". Timed by frames and read in body heights (our skater stands 5.85 studs: 196.2 is 33.5 body heights/s²), Roller Champions' climb up an upright wall (3.3 body heights up in 0.55 s, down in 0.5 s: Video 20), its standing jumps (0.60–0.73 s in the air: Video 5) and its Uppercut (~1.5 s: Video 14) all fit ~2/3 of ours; the owner played it (trial 7) and kept it. One setting, read by the skating, the poses' lean, the ball's pass lift and the rules' save prediction, and given to Roblox's own physics (`workspace.Gravity`) when each realm boots; walls pull as hard as floors. The jump, the Air Pose and the Uppercut push √(2/3) as hard, so they rise as high as before. Measured in Play on #268's map: a standing jump 8.9 studs, 0.73 s in the air (was 9.2, 0.61 s); an Uppercut 31.5 studs, 1.38 s (was 31.5, 1.12 s); from the spawn room straight at the outer wall with nothing pressed, the root's first top 9.2 / 13.4 / 28.1 / 29.6 studs from 55 / 72 / 108 / 145 km/h (7.2 / 10.7 / 20.1 / 26.2 at 196.2), stopped at 5.0 / 8.9 / 12.4 / 8.9 s (6.3 / 9.0 / 11.6 / 14.1); from 108 km/h a 0.26 s flight off the rise's crest onto the wall's foot, from 145 a 0.8 s flight onto the wall 29.5 up; the Uppercut at a climb's top on the wall's foot: from 108 km/h caught on the glass at 61.2 (61.0 with the Air Pose at its top), from 145 back down at 22.7 (21.2), peaks 58.7–62.3; a lap along the spawn lane 15.0 s.* | `World.gravity = 130.8` (studs/s², two thirds of 196.2), `rollingFriction = 4`, `airDrag = 0.02`, `cruiseSpeed = 46` (55 km/h), `softCap = 90` (108 km/h), `hardCap = 121` (145 km/h), `overSpeedBleed = 5` (/s) |
| Coasting | On the ground, rolling friction and air drag (Momentum) slow a skater the same whether keys are pressed or not, so a skater let go keeps rolling on the flat, and swings from wall to wall fade by friction, drag and gravity only. A knocked-down skater slides instead (Knockdown slide), and a diver glides with friction and drag until their touchdown (§8.2 Dive). From the stride's top speed (46 studs/s) a skater rolls to a stop on flat ground in 50 × ln((4 + 0.92) / 4) = 10.35 s. *The owner (#288, Q67-Q70): "follow RC and real physics ... if we are going in a straight line and not clicking anything we are going to have momentum and coast longer"; RC's skater rolled ~11 s to a stop after ~2 s of W (the owner's Video 27), ours stopped 3-4 s after a short press (Video 28); trial 288 (no extra brake) rolled 11.2 s / 100 studs after 2 s of W and was kept (Q70). Was `coastDecel = 7.5` studs/s² more for pressing nothing (#215: from 72 km/h to a stop in about 5 s, chosen before any RC numbers; 3.85 s from the 55 km/h cruise).* | (Momentum's `rollingFriction`, `airDrag`) |
| Steering | The keys push the way the camera looks; the mouse orbits the camera freely. Turn rate shrinks with speed (wider turns when fast), and on a wall never passes `wallTurnRate` (Wall riding, #239). With weight (#266): the part of the stick pointing back against the motion pushes back like a stride (`strideAccel`; on a wall, nothing) and only the part across turns, at the turn rate scaled by its share, so a stick held straight back stops the skater before they go its way, never a U-turn carved at speed. *The owner (#266, Q33, replacing Q29's skater-relative keys): Roller Champions' keys follow the camera with weight (Video 15, W only: at 55–67 km/h the skater curved round the island toward the camera; at low speed, the camera swung back, 13 → 1 km/h in 0.5 s, then off the camera's way; Video 14: 31 → 0 at ~60 km/h per s, 15 → 0 at ~40). Ours carved a U-turn at full speed. Q34 halved the turn rates; the owner put them back (#272, Q37): Roller Champions' skater circles on with W, A, S, D pressed in turn, at 14–45 km/h and never under 2 after the start (Video 19), where the halved rates stopped ours; ~3 rad/s at the 55 km/h stride. Measured in Play: from the 55 km/h stride, the stick held straight back stopped the skater in 1.33 s with no sideways drift, they set off the other way facing it, 13.7 studs/s half a second later; at the halved rates the stick held 90° off turned them 0.41 rad in the first 0.27 s (1.52 rad/s). W → A → S → D from 30 km/h in the spawn room (keys fixed in the world, the dip's slopes included, 6 s after the first 2): a key every 0.4 s 11–60 km/h, never under 5 (halved rates 1–52, 0.22 s under 5); every 0.8 s 4–63 km/h, 0.07 s under 5 (halved 0–55, 0.78 s). On flat ground (a model of these rules) every 0.4 s: 12–44 km/h.* | `turnRateLow = 4.0`, `turnRateHigh = 1.5` (rad/s) |
| Facing and riding backwards | The skater's facing turns toward the way they move, on the ground and in the air, at most a half-turn in `turnRoundSeconds` (π / 0.3 = 10.5 rad/s, faster than any steering, so it keeps up with turns); it never snaps, after a bounce, a push or a push-off the other way from a stop. A skater carried back against their facing (a slope or a wall pulling them the way they roll, steeper than `pumpFlatSlopeDeg`) rides backwards while the stick points within `backwardsConeDeg` of the way they roll and their facing within it of the way back: the facing turns toward the way back, so their back leads, onto the flat below and into the air too. Letting go of the stick, or steering elsewhere (S with A or D is 45° off), turns them round at the same rate; a turn begun leaves the cone at once, so it never flips back. From a stop on the flat, S turns them round and they skate off forward. Only the facing changes: speed, steering and every speed reading are as before. The body (and so every client's view of it), the camera's swing-back (§8.4) and the lean (which leans the body's other side when riding backwards) follow the facing. *The owner (#246, Q15): RC's skater rode back down a bank still facing up it for ~0.7 s, then turned round over ~0.3 s (Video 7, 16.9–17.9 s); Q23: S from a stop turns round smoothly. Before, the facing was the velocity's way, so it snapped round in a frame. `backwardsConeDeg` is a ruling within #246, not measured in RC.* | `turnRoundSeconds = 0.3`, `backwardsConeDeg = 30` |
| Wall riding | Real physics (#216): a surface steeper than `wallAngle` is a wall, and it holds a skater at any speed. Gravity pulls along a wall at full strength, as on the floor and in the air (#256), so a slow rider slides back down and a fast one climbs and comes back down faster. On a wall the skates only roll (#239): the stick never strides (up one gentler than `crawlLimitDeg` it keeps a crawl: Crawl) and turns the heading at most `wallTurnRate`, and the brake does nothing, so climbing costs speed, no rider holds a level line along upright glass (that needs g / `wallTurnRate` = 131 studs/s at #279's gravity, past `hardCap`): every rider curves back down, and no one stands still or tiptoes on it. *The owner, at the Feel playtest: "why the player can just ride the wall and be stick to it like skating on the ground floor?". Measured on an upright wall with the stick held level along it (walls then pulled at a third): before, every rider stayed above 20 studs for the 20 s tested and ended at cruise; with #239 a 30 km/h rider was back on the floor in 1.6 s at 86 km/h and a 90 km/h one held a line ~1.9 s (RC, Video 3 21:09: ~2 s at 90). Braking used to hold a skater still on the glass, and brake + stick tiptoed them up it at 14 km/h.* *The owner (#256, Q25): one gravity everywhere, real physics (on RC, Video 6: "the gravity is strong and pull him, it is hard to go up"). It reverses #216's third (Q16), which came from RC's readout falling 98 → 21 km/h up the glass in ~1 s (Video 3, 21:01), read as the full speed; RC's readout in the air is speed across the ground (Video 5), so on the glass it may not be the full speed either. Measured in Play at full gravity, nothing pressed, straight at the outer wall from the floor: the root topped out at 3.6 / 8.8 / 19.2 / 24.3 studs from 55 (cruise, #265) / 72 / 108 / 145 km/h (36.1 / 50.6 from 108 / 145 at a third); a line along the glass from 40 studs up, the stick along it (SkateMath over the real arena): above 20 studs for 0.55 / 0.63 / 0.68 s at 72 / 108 / 145 km/h (2.5 / 4.5 s from 72 / 108 at a third). `wallAngle = 30`° was the owner's choice for where the third began (#216); it now marks where the skates only roll. Was: below `minWallSpeed = 35` on a surface steeper than `maxStickAngle`, the skater fell off.* **A surface only pushes** (#257, A3): on every surface the skater stays on while `speed² × curvature ≥ gravity's pull off the surface`, the curvature negative where the surface bends away from them. So a flat ceiling never holds, an overhang (the glass's lips, A7) holds only fast enough round its curve, a curve bending toward them (the outer wall's foot, a bank's) always holds, an upright wall bending away (the middle glass's round ends) holds only a slow drift round it (Walls grip, below), and a crest throws off a skater too fast for gravity to keep on it (speed² / radius past g × the cosine of its slope). *The owner (#257, Q26): real physics, "specially the middle how he can turn the hard curved turns and being able to stick to the wall" (Video 8). Before, only an overhang could throw a skater off: `SkateMath` alone kept one on the outside of an upright pillar of radius 20 at any speed (196° round at 108 km/h). Measured after (SkateMath over the real arena; Play): riding along the middle glass into its round end, a skater lets go as they enter it at 48–145 km/h and lands on the floor 0.5–0.7 s later (before: 106–165° round it on the glass); a skater reaching the top of the old map's pump step (gone since #268) faster than ~90 km/h hopped off it for 0.1–0.2 s; steering round a curved end high on the inner bank at 72–108 km/h lifts off 1–3 times a pass, at most 1.6 studs; the outer wall's climbs are unchanged.* **Walls grip** (#289): a surface that holds presses the skates on at least `wallGrip` against a bend away from them, on it and in the air beside it after leaving or touching it (Landing on what they touch), since gravity presses nothing onto an upright wall. Round the middle glass's round ends (the root 22.5 studs from their axis) it holds a drift slower than √(38 × 22.5) = 29 studs/s, 5 body lengths a second; riding along the middle wall from a straight (about 8 body lengths a second or more) still flies off there, never carried round. Only the part of the speed the way the surface bends follows its curve: rising or falling fast along the round glass while drifting slowly round it holds, and a crest crossed slantwise throws off only a skater too fast across it. *The owner (#289, Q69, Q71, Q72): "players don't stick their feet in the curved end of the middle glass wall like other walls, he drops vertical to it" (Video 29), and "I don't players riding the middle wall from the straight side to be able to continue and stick to the wall and curve the curved edge"; trial 289 played and kept. Traced in Play (session 45): on the upright round glass gravity presses nothing, so #257 let go at the slightest drift round it (about 1.6 studs/s), and in the air #258's catch gave up because drifting round convex glass always moves off the next face; the curve was also read per stud of the whole path, so a fast rise with a slow drift read as a sharp bend (82.5 studs/s² for 80 up and 20 round, where the path bends by 20). Measured in Play: up into a round end at 80 studs/s within 7° of head-on (at 70 within 10°), the feet stay on the glass up and back down (10–14° off at 80 fly off); Jumps and Uppercuts pressed 10–20 studs up a round end rise along its glass to 42–80 up and are caught feet first at the top; on the outer wall and the middle glass every Jump and Uppercut rises along the face (at most 3.7 studs off it, the hover being 2.5) and is caught at the top; riding along the straight's middle bank into the round end goes 11–30° round, then onto the floor (before: 15–30°); the flat glass is unchanged (40–45 steps feet on it, none in the air); 0 warnings.* Float noise is no push: the rule allows `gravity × 1e-3` of slack, so a face leaning past vertical by float noise alone holds like a wall (the arena's built glass reads up to 6.5e-5 past vertical, measured, #234; before that margin skaters dropped off it), and a turn under 1e-3 rad between two steps is no turn (measured on the arena, #257: neighbouring rays on one face differ by up to 1.5e-4 rad, real turns are 8.5e-3 or more). The curvature is measured over the last `curvatureWindow` studs of the skater's path the way the surface bends (#289; a corner is no curve and leaves that way as it was), so a lip's flat strips read as the arc they make (Phase 5 review). The top is never ridden (A7). | `wallAngle = 30`°, `wallGrip = 38` (studs/s²), `wallTurnRate = 1` (rad/s), `curvatureWindow = 10` (studs) |
| Landing on what they touch | A skater in the air lands feet first on any ride surface they touch (#258): the ray along their feet finds it within `hoverHeight`, or the collider meets it (the controller checks that a ray through ride surfaces alone meets that face no further, so a barrier, A7, only blocks). Like any touchdown, the speed into it is lost and the rest kept, the feet turn onto it (`up` = its normal), and a posed or diving touchdown is a belly landing and a fall (Hard landing, Belly landing), walls included; then the Wall riding rules apply. An overhang never takes a touchdown (its push depends on a curve no touchdown knows yet): it only blocks. A skater who leaves a wall that holds (riding off it, an Uppercut up it, a jump) remembers it. While they rise off it nothing lands them: a leap up the glass is a flight with every air action (Air Pose, Tackle, Dive), and what the collider meets on the way only blocks, so they slide up it. From then on their ground ray looks toward that wall instead of along the feet (`SkateMath.groundRay`; rising too since #289), and a wall whose grip holds them (Wall riding: Walls grip) keeps them by it in the air: where it bends away from them the speed along it turns with it and their part off it stays, unless it bends away more than the grip holds (then they fly on free); a wall bending toward them meets them (the collider). Once they fall it catches them anywhere the ray reaches (`groundProbeLength`) unless they move off it faster than float noise (0.1 studs/s: the built glass reads up to 6.5e-5 rad past upright, #234); a jump on it goes up along it (Jump, #267), so the wall catches that too. A skater still rising who meets any wall, by the collider or the feet, does not land on it either (#267): they slide up it, the speed into it lost, and a surface that holds met that way is the one that catches them once they fall; floors and gentle banks met rising land them as before. Jump comes back only with a landing. A wall that cannot catch them (out of reach, moving off it, or bending away past its grip) is let go for the rest of that flight. A launch (the Uppercut's leap, a jump) leaves the ground with the speed along it: the hover's pull off the surface is no momentum. In the air the skating's up still turns upright, so the server's ray along the body's down sees a caught skater land. *The owner (#258, Q27): "make sure that his legs are riding the wall, and not just drop down vertical next to it"; RC Video 7 (0:01.1–3.0, 0:05.9–7.3): up the bank, off its top, back down feet first onto its face. Q28, on an Uppercut or a jump at the glass: "both", every air action, and the glass catches them. RC Video 10 (46.2–48.9 s): an Uppercut at the wall, the Air Pose at its top, back onto the wall's foot posed: a fall. Before, in the air only a surface along the feet within `hoverHeight` landed a skater, so they fell upright beside a wall (our Video 8, 0:02.0–2.8). Measured in Play: flying at the upright glass from 6 studs off it at 30 studs/s, a skater lands on it feet first 0.2 s later; an Uppercut while riding up the glass at 50 studs/s leaves it at 46.7 studs up, flies to 83.7 in 0.6 s and is caught there (moving off it at exactly 0); with the Air Pose struck on the way up it flies to 96.1 and the posed catch is a "Fall" knockdown 0.2 s later; a jump off the glass leaves at 59.9 studs/s, is never caught and lands on the floor 0.8 s later; ridden from the floor straight at the outer wall at 108 / 145 km/h with the Uppercut at the ride's top (19.8 / 20.7 up), the glass catches them at the leap's top, 56.1 / 55.8 up. Riding the outer wall's foot the hover pushed the skater off it at 0.6–1.5 studs/s, which a leap kept (still 1.2 off the wall at its top: let go) until launches dropped it; and a leap up the glass first landed back on it the very next step (the feet ray along it), a ride with no air actions, until rising off a wall stopped landing them. RC (#267, Q32; Video 14, 55.2–57.6 s): a jump from the floor straight at the wall lost the speed into it (59 → 13 km/h) and went up the glass still in the air, back onto it ~1.2 s later. Measured in Play: flying at the upright glass from 5 studs off it at 30 studs/s and rising at 60, the skater met it 0.15 s later still rising at 30, lost the speed into it, slid up it in the air to 38.7 and was caught once falling, 0.33 s after the start (before, a jump off the glass left at 59.9 studs/s and was never caught).* | `hoverHeight = 2.5`, `groundProbeLength = 6` |
| Pump (hold) | Multiplies the downhill gravity component; small push on flat ground; no gain uphill. Crouch pose. | `pumpSlopeMultiplier = 1.6`, `pumpFlatAccel = 8` |
| Brake (hold) | Strong deceleration to a stop. Nothing on a wall (Wall riding, #239). | `brakeDecel = 120` |
| Tiptoe (brake + steer) | Precise low-speed movement capped at `tiptoeSpeed`. Not on a wall, where the brake does nothing. | `tiptoeSpeed = 12` |
| Crawl (stick up a slope) | Holding the stick up a slope gentler than `crawlLimitDeg` and steeper than flat (`pumpFlatSlopeDeg`), walls under the limit included, a skater never slows below `crawlSpeed` along their heading, scaled by how far the stick points along it; steeper, gravity slides them back. Not with the stick pushing back against the motion (Steering), nor with no stick. It is no stride: on walls the stick still never pushes, and `crawlSpeed` stays below `cruiseSpeed`. *The owner (#273, Q38): "currently the player can't get close to the wall at low speed at all, unlike RC, look at this vide, I am just clicking W, I am able to get close and ride the walls a little" (Video 20: from a stop, 0 → 25 km/h on the flat in 1.2 s, up a bank 23 → 4 km/h in 1.2 s, then a crawl at 1–5 km/h for 4+ s, no brake held). Widened to 45° (Q45/Q46, trial 7 kept) for the straights' rise (#268, ~39° at its steepest, past `wallAngle`). Before, the stride beat gravity only on slopes under asin(30 / 130.8) = 13.3°, and no one got over the rise from the spawn room (Video 23). Measured in Play: W from a stop in the spawn room, 14 km/h at the room's end (0.5 s), then 4 km/h up the rise (its top at 4.8 s), the outer wall's foot at 10.8 s, and up the foot curve to 18 studs (near its 45° point) before sliding back.* | `crawlSpeed = 3.33` (4 km/h), `crawlLimitDeg = 45` |
| Jump | Impulse along a floor's normal; on a wall (steeper than `wallAngle`) up along it, never off it, so the wall catches them once they fall (Landing on what they touch). A jump keeps 1 − `jumpSpeedCost` of the speed along the surface, and only that (the hover's pull is no momentum). *The owner (#218): each jump costs 10%, no free jump spam. The owner (#267, Q32): "when a player jumps next or more like into the wall, he bounce back from the wall"; RC (Video 14, 4.0–7.4 s): Jump riding up the glass rose straight up along it, ~1 s in the air, back on the glass. Before, a jump on a wall pushed 60 studs/s straight off it (our Video 12, 2.8 s). Measured in Play: on the upright glass 40 up riding up at 30 studs/s, Jump left with 0 studs/s off the glass, rose to 58.4 and was caught there 0.43 s later.* *#279: √(2/3) of 60, as high at two thirds of the gravity and longer in the air; measured in Play 8.9 studs, 0.73 s (Roller Champions 0.60–0.73 s, Video 5).* | `jumpImpulse = 48.99` (a 9.2-stud jump, 0.75 s in the air), `jumpSpeedCost = 0.1` |
| Air Pose | The jump input in the air, once until landing: the fall is cancelled and `airPoseImpulse` is added straight up (a 4.5-stud hop, about half a jump), costing `jumpSpeedCost` of the speed across like a jump, and the skater strikes a pose (`Pose.airPoseDeg`, `airPoseArmDeg`: Roller Champions' superman stretch). The pose lasts while the jump key is held: letting go ends it (a press and release between two steps poses for one step, and its hop still breaks a fall); falling posed, the skater flies down the fall line; touching down still posing, on any surface, walls included (#258), is a fall (Hard landing) and a belly landing. Landing ends the pose and re-arms it. Every client sees it: the skater's `SkateState` carries it and the server sets `AirPosing` on the character. The jump's hint reads "Air Pose" in the air. *The owner (#218), from RC's Air Pose. The owner (#245, Q13): RC's pose lasts while the key is held, and holding it into the ground knocks the skater down (Video 7).* | `airPoseImpulse = 34.29` (√(2/3) of 42, #279: the same 4.5-stud hop) |
| Fall line | A diver in the air (§8.2), and a skater falling in the Air Pose (not while the hop still rises), flies down a line `fallLineDeg` below their facing instead of falling straight: each step keeps the velocity's part along the line and adds gravity's pull along it (g sin `fallLineDeg`), less air drag, never past `hardCap`; the stick does nothing meanwhile. Across the ground that is 130.8 × sin 20° × cos 20° = 42 studs/s² (50 km/h per s) at #279's gravity (63 studs/s², 76 km/h per s, at 196.2). Measured in Play (#279), from an Uppercut's top: a dive went 73 → 89 km/h across the ground in 0.5 s and touched down 0.8 s after the press; a posed fall 0 → 73 km/h in 1.7 s, touching down 2.0 s after it (a Fall knockdown). *The owner (#241): RC's readout climbed ~75 km/h per s diving down (Video 6). The owner (#245, Q14): a posed fall too, RC's 46 → 104 km/h in 1.0 s (Video 7).* | `fallLineDeg = 20` |
| Hard landing | A fall of `hardLanding.drop` or more onto ground flatter than `wallAngle` knocks the skater down for `hardLanding.knockdownSeconds`, sliding (a carrier drops the ball; the Get Up flow); a landing on a wall or a bank is never hard (the slope carries the skater on). The fall is the height from the top of the skater's last rise to where they come to rest (`hoverHeight` over the ground): any rise moves the top, so an Air Pose's hop breaks a fall, and riding the ground moves it too. Touching down still posing is the same knockdown (`KnockedDown = "Fall"`) from any height, onto any surface, walls included (#258); a pose let go before the touchdown still breaks a fall. The server judges it with its own ray along each skater's down every frame (`ActionService`, `Skate/Fall`): a landing is the first frame that finds ground within `groundProbeLength` after one that found none, on any surface; it is hard past the drop onto ground flatter than `wallAngle`, and any other (a soft one, walls included) knocks down only a skater whose client reports the Air Pose. The client keeps reporting a pose it touched down in (by its ground ray, or onto a surface its collider met: §7.2 Landing on what they touch) for `Network.posedLandingTolerance`, or until the knockdown arrives, because the server sees the touchdown behind the client's screen and the character's physics and the remote events reach it in no fixed order. A server placement starts a fall over; no one scores the knockdown. *The owner (#222): 40 studs, above an uppercut's leap with an Air Pose at its top (31.5 + 4.5 ≈ 36), not the 20 first planned; and the height decides, because `hardCap` holds in the air: a free fall reaches it after 121² / (2 × 130.8) = 56 studs at #279's gravity (37.3 at 196.2), so every longer fall lands at the same speed. Measured in Play (#279): placed 45 studs up at rest, a Fall knockdown; 35 up, none. The owner (#245, Q13): touching down posed is a fall at any height, like RC (Video 7: every action greyed, the Get Up prompt). The owner (#258), with RC Video 10 (46.2–48.9 s: an Uppercut at the wall, the Air Pose at its top, back onto the wall's foot with the Get Up prompt): "if the player airpose next to the wall, he falls like in the video, same for the dive"; before, a landing on a wall was no landing at all.* | `hardLanding = { drop = 40, knockdownSeconds = 1.5 }`, `Network.posedLandingTolerance = 0.3` |
| Belly landing | A touchdown from the air (on any surface, #258) while diving or still posing keeps `bellyLandingKeep` of the speed (the whole velocity is scaled on the touchdown step), then the slide; a ground dive, and a pose let go before the touchdown, lose nothing. *The owner (#245, Q19): RC kept 59–73% (133 → 84 and 139 → 101 km/h at air dives' touchdowns, Videos 6 and 5; 104 → 70 and 97 → 57 at posed falls', Video 7), then slid 0.7–0.8 s; ours kept ~95%.* | `bellyLandingKeep = 0.65` |
| Knockdown slide | A knocked-down skater (any `KnockedDown` kind) slows evenly to a stop in their kind's `knockdownSlideSeconds`, whatever the speed, timed from the slide's first step on the ground: each step loses its share of the time left, so on the flat the speed falls in a straight line to 0; a slope's pull only bends the line, and once the time is up they lie still until up. Friction, drag and coasting add nothing to it. Getting up early (the stick from `getUpAfter`, §8.2 Get Up) keeps the speed left. *The owner (#252, Q24): RC's readout (10 frames a second) fell evenly to 0 in about the same time whatever the speed: a tackle 50 → 0 km/h in 1.5 s (Video 4), posed falls 70 → 0 and 57 → 0 in 1.5 s each (Video 7), a hard landing 31 → 1 in ~1.4 s (Video 5), dives 68 → 0 in 0.7 s and 84 → 10 in 0.8 s (Videos 4 and 6). Was one rate for every knockdown, `knockdownDecel = 75` studs/s² on top of friction and drag (measured: a posed fall 88 → 42 km/h in 0.57 s, a dive 78 → 34).* | `knockdownSlideSeconds = { Hit = 1.5, Fall = 1.5, Dive = 0.8 }` |
| Draft | Inside a cone behind any player, extra acceleration scaled by closeness. | `draftRange = 18`, `draftConeDeg = 30`, `draftMaxAccel = 20` |
| Attach (Grapple Whip) | Any player holds Attach while within `attachRange` of a teammate and inside `attachConeDeg` of the direction directly behind them → attached: held at `attachFollowDistance` behind the leader, who keeps full control. Release (or `attachMaxSeconds` elapsed) → a boost of `attachBoostSpeed` toward the stick held as the skater lets go, or along the leader's travel direction with the stick at rest (RC's "Hold & Release + direction: Speed Boost", #214); then cooldown. | `attachRange = 8`, `attachConeDeg = 45`, `attachFollowDistance = 4`, `attachMaxSeconds = 3`, `attachBoostSpeed = 75` (90 km/h), `attachCooldown = 3` |
| Speedometer | Display value = speed (studs/s) × `speedometerScale`, labeled "km/h". The speed is Roller Champions' (#233, `SkateMath.shownSpeed`): along the surface the skater rides on the ground, on walls and behind a teammate (without the hover's pull off it), and across the ground in the air, so a standing jump reads 0 and a fall adds nothing. *Roller Champions: 0 during a standing jump (the owner's Video 5), steady through an Air Pose (Video 4: 21 → 21, 38 → 38), falling as a rider climbs the glass and rising as they come down (Video 3, 21:01). Was the 3D speed: 85 km/h right after a jump at 71.* | `speedometerScale = 1.2` |

Lap-time target for arena tuning: ~10–12 s per lap at `cruiseSpeed` (§9.1). At the 55 km/h cruise (#265) the centerline's 777 studs take 16.9 s (computed); pumps and slopes make laps faster.

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
    hit = { range = 7, coneDeg = 90, aimUpDeg = 0, knockdownSeconds = 1.5 },
    seek = {
        snap = { range = 12, coneDeg = 90, aimUpDeg = 0 },
        bend = { range = 18, coneDeg = 45, aimUpDeg = 0 },
        turnDegPerSecond = 300,
    },
    motion = { lungeSpeed = 40, lungeCap = 60 },
    airMultiplier = 0.4,
    followUp = { action = "Dive", from = 0.1, to = 1 },
}
```

`ActionRunner` (pure) advances phases, enforces cooldowns/requirements and follow-up windows, and reports effect windows. A `followUp` names another action the same key starts from `from` to `to` seconds after this one started; an action named as a follow-up starts only then, and replaces the action it follows if that still runs. A refused (refunded) action or a reset opens no window. A key starts the first of its `Input.actions` that may start now (`ActionRunner.available`: its requirements fit the ball and the ground or air, and a follow-up's window is open): the Tackle key is a Dive 0.1–1.0 s after a Tackle, else a Tackle, or a Dodge with the ball. The client starts the action immediately (pose + motion); the server's `ActionService` re-checks requirements, cooldown and a follow-up's window (after the Tackle the server itself started, with `Network.actionTimingTolerance` = 0.1 s of slack on each edge), and resolves hits against server-side positions with `Network.hitLagToleranceStuds` = 3 extra range. The server's view of a jump lags the client's, so it never judges the air: an action needing the ground or the air may start there either way. An action with a `landing` (the Dive) ends on the skater's belly (§8.2). Adding an action (or an M5 item) = config entry + one effect function.

**Magnetic strikes** (`seek`, #277). The Tackle, the Dive and the Uppercut home onto an opponent. At the press the client looks along the stick's way (camera-relative), else the facing: the nearest opponent the strike may reach (`Reach.strikable`, the server's own rule: another team, on their feet, not dodging; the client reads `KnockedDown` and `Action` on their character) within `seek.snap` (a range and a cone, as a hit's), else within `seek.bend`, is the target. The skater turns at once to face and move toward them (else the stick's way), keeping their speed across the surface, and the action's own push then goes that way. Until the strike's recovery, while the target stays within `seek.bend`'s cone (around the facing, pitched up by its `aimUpDeg`, at any range) and reachable, the facing and the motion bend toward them at most `turnDegPerSecond`: on the ground across the surface, in the air the whole motion, so an Uppercut's leap tilts toward an opponent above. The cones sit in the skater's own surface frame, like the hit's. The server still judges every hit, and each counts its front half (`coneDeg = 90`), so a skater close beside is reached. *The owner (#277, Q57–Q66; trials A–E played in 2-player tests, E kept): Roller Champions' hits in the owner's Video 24 landed 1–3 body lengths ahead, up to ~20–30° aside, 0.1–0.3 s after the press, and close Uppercuts hit skaters on the ground (119.6 and 153.8 s); its lunge goes where the keys point (Video 26: trails off left at 50.4 s, right at 53.7 s). Whether its lunge bends could not be measured. Was a push along the facing only, with hits within 50° of it (the Uppercut's 60° around the facing pitched up 30°).*

### 8.2 Action list (initial values in `Config/Actions`)

| Action | Requires | Behavior |
|---|---|---|
| Tackle | no ball, on the ground or in the air | Lunge: `lungeSpeed = 40` more along the facing, never past `lungeCap = 60` (72 km/h), a faster skater slowing to it; from the strike's end the speed eases back evenly over the recovery (0.35 s) to the speed before, and drops to it at once if the tackle stops early (refused, knocked down), so a tackle never makes a skater faster. In the air the lunge is the Tackle's own `airMultiplier = 0.4` as strong (16 studs/s, 19 km/h), under the same ceiling. Speeds are the speedometer's (§7.2). *The owner (#241): Roller Champions' lunge peaked at 65–75 km/h whatever the speed before (31 → 75, 47 → 71, 82 → 73, 96 → 74) and fell back within ~0.3 s (Video 4); its air tackle added 15–19 km/h (Videos 5 and 6); was +40 that stayed, 0.8 in the air.* Homes (§8.1 Magnetic strikes): snaps to anyone within 12 studs (2 body lengths) in the front half, else within 18 studs and 45°, bending 300°/s, a quarter-turn over its strike. Hits an opponent in its front half within 7 studs → knockdown 1.5 s; a hit ball carrier drops the ball, which keeps their momentum. Cooldown 1.0 s; its key dives from 0.1 to 1.0 s after it (`followUp`). *The owner (#240): Roller Champions' "Dive" replaces "Tackle" 0.1–0.2 s after the press for 0.7–0.8 s, and "Tackle" is back 0.9–1.0 s after it (Video 4, five ground tackles); was 0.8 s, on the ground only.* |
| Dive | no ball, only as the Tackle's follow-up: the Tackle key 0.1–1.0 s after a Tackle, on the ground or in the air | `diveSpeed = 60` (72 km/h) along the way, or the speed already shown if faster (never `airMultiplier`'d): along the facing on the ground; in the air down the fall line, `Movement.fallLineDeg = 20` below the facing, where gravity's pull along the line (g sin 20° = 67 studs/s²) speeds the diver up to the `hardCap` ceiling (145 km/h): from an Uppercut's top (31 studs) the diver lands 0.98 s later at 136 km/h on the speedometer. *The owner (#241): RC's dive went 19 → 65 km/h at the press and climbed ~7.5 km/h every 0.1 s to 133 at the touchdown 1.1 s later (Video 6); was +60 at once along the facing.* Hits in its front half within 11 studs; active 0.3 s, recovery 0.9 s. *The owner (#277, Q66): a shorter flight, RC's ~0.3 s (#242); was 0.7 s.* Homes (§8.1 Magnetic strikes): snaps to anyone within 18 studs up to 120° from the way it looks (all but the 60° behind), on the ground or in the air, else within 18 studs and 45°, bending 300°/s. *The owner (#277, Q64): their dives missed opponents 10–19 studs away, 62–96° off the facing (our Video 25).* Until the touchdown the diver glides: the stick, pump, brake and jump do nothing, and on the ground only friction and drag slow them (no coasting or knockdown slide). It ends on the belly (a touchdown from the air keeps `Movement.bellyLandingKeep` of the speed, §7.2 Belly landing): nothing else starts until the diver's first touch of the ground after the active phase, which knocks them down (`KnockedDown = "Dive"`) until their slide is slower than `landing.stopSpeed = 2` studs/s (2.4 km/h) along the ground, or for `landing.knockdownSeconds = 1.5` at most (their slide stops within `Movement.knockdownSlideSeconds.Dive = 0.8`, §7.2 Knockdown slide); moving does not get them up sooner, and no Get Up prompt shows. *The owner (#242): RC's dive built to 67–70 km/h within ~0.4 s, glided there ~0.3 s, then slid to 0–3 km/h in 0.7–0.8 s, and every action came back at the stop, 1.5–1.6 s after the press (Video 6); no prompt showed (Video 4). Was 0.35 s, slowed at once, then the Get Up flow.* The server sees the touchdown with its own ray along the diver's down (`Movement.groundProbeLength`) against the arena's ride surfaces; no one scores that knockdown. *The owner (#221): Roller Champions' dive (Video 5 at 1:13) rose to 139 km/h and ended on the belly, sliding; it is its own anti-spam, so the 3 s wait after a dive planned earlier is dropped. The owner (#240): RC's dive follows a Tackle on the ground and in the air ("Tackle Dive: Square then Square", "Air Tackle Dive: X then Square then Square"), so mashing the key dives the skater onto the floor; #221 had made it the first Tackle press in the air.* |
| Dodge | ball | Side-step at `sideSpeed = 45` in the move direction; tackle-immune for 0.3 s; cooldown 1.5 s. |
| Uppercut | no ball, on the ground or a wall (`requires.grounded = "grounded"`) | Knocks down an opponent in its front half within 6 studs as the leap starts, on the ground too. *The owner's note on #277: RC's Uppercuts hit skaters on the ground (Video 24 at 119.6 and 153.8 s); was 60° around the facing pitched up 30°.* Homes (§8.1 Magnetic strikes): snaps to anyone within 12 studs in the front half, else bends its leap toward an opponent above, within 31 studs (its leap) and 45° of straight up, at 360°/s. *The owner (#277, Q56, Q58).* Leaps the skater straight up from any ground or wall (`leapImpulse = 89.81`, √(2/3) of 110 at #279's two-thirds gravity: about 31 studs from the floor, 1.37 s in the air; 31.5 studs and 1.38 s measured in Play from a standstill, #279; Roller Champions' ~1.5 s, Video 14), never past `hardCap`; up the glass it is a flight the glass catches at its top (§7.2 Landing on what they touch). Never in the air: the uppercut key does nothing there and its hint and touch button hide, like any action that cannot start. *The owner (#219): Roller Champions' uppercut launches on open floor; was a leap only within 5 studs of a wall. The owner (#262): "if a player jump, he can't sequence it with an uppercut unless he touches a ground or wall, basically something solid"; RC greys the Uppercut in the air (Video 10 at 82.0 and 107.0 s, Video 11 at 51.0 s) and lights it on the ground; was allowed in the air at `airMultiplier`.* No recovery (windup 0.05 s, active 0.2 s): a Tackle may start 0.25 s after the press. *The owner (#240): RC's air Tackle was ready 0.13–0.3 s after an Uppercut (Videos 5 and 6); was 0.4 s of recovery.* Cooldown 1.2 s. |
| Air dodge | ball, airborne | Same as Dodge with `airMultiplier = 0.8` on the side speed. |
| Charge Throw | ball | Hold to charge up to `chargeMaxSeconds = 1.0`; release throws along camera aim at `lerp(minThrowSpeed = 60, maxThrowSpeed = 160, charge)` + `inheritCarrierVelocity = 0.5` × carrier velocity. |
| Pass | ball | Magnetic pass at `passSpeed = 90` to a teammate who called within `callPassWindow = 3` s (most recent caller first), else the best-scored teammate inside `passTargeting.coneDeg = 70` and `passTargeting.maxRange = 120`, where score = `angleWeight (0.6)` × (1 − angle/cone) + `distanceWeight (0.4)` × (1 − distance/maxRange). With no valid target, the ball is passed straight along the aim at `passSpeed`. Homing acceleration `passHomingAccel = 60`; interceptable. |
| Call Pass | no ball | Shows a hand icon over you for `callPassWindow`; cooldown 1 s. |
| Ball Focus | — | Camera keeps the ball in view. Mode `Input.ballFocusMode = "Hold"` (`"Toggle"` available). A player-facing setting arrives with saved settings in M6. |
| Get Up | knocked down by a strike or a hard landing | Any movement input (keys, stick or touch stick) asks the server to get the skater up: once per knockdown, through the `GetUp` remote. The server gets them up `getUpAfter = 1.5` s after the knockdown at the soonest (at once if the request comes later); without a request they are up after the hit's `knockdownSeconds` (1.5 s), so today every strike and fall keeps them down the whole slide, keys or not. *The owner (#287, Q62): "make the duration of the tackle, dive, uppercut longer to stand up from, currently it is almost instantly"; RC's tackled skater slid 1.5 s and pushed off as the slide stopped (Video 4), its posed falls the same (Video 7); was 0.5 s.* A "Get Up" prompt shows the movement keys meanwhile (§11.1). A knocked-down character's `KnockedDown` attribute holds why: `"Hit"` (a strike), `"Fall"` (a hard landing) or `"Dive"` (a diver's own touchdown, which Get Up does not end: the Dive row). *The owner (#220): Roller Champions' prompt shows the movement keys, and its skaters were up in under 1.8 s (Video 5 at 0:18).* |

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

Third-person chase camera with mouse lock. How far behind and how high it sits follows its pitch (`Camera.framing`, below); FOV from `fovBase = 70` to `fovMax = 90` scaled by speed toward `hardCap`. Ball Focus rotates the camera to keep the ball in frame while staying behind the player. Spectators get a camera that follows the ball (`Camera.spectator`: 30 behind, 6 above it). On a gamepad or touch, once the look input rests, the camera swings back behind the skater's facing (not their velocity, #246), so a skater riding backwards keeps looking the way they face and S keeps pointing the way they roll.

**Framing and fade (#276).** The camera sits `distance` behind its focus (the point it looks past, where the crosshair dot sits) and the focus sits `height` above the root along the camera's up, both set by the pitch: `Camera.framing` lists points rising in pitch, joined by straight lines and held past the first and the last.

| Pitch | 55° down | 35° down | 20° down | 10° down | level | 15° up | 30° up | 45° up and past |
|---|---|---|---|---|---|---|---|---|
| `distance` | 22 | 19 | 16 | 14 | 12 | 10 | 5 | 1 |
| `height` | 5 | 5 | 5 | 5 | 5 | 5 | 1.5 | −1.5 |

Looking down it backs out above the skater; looking up it slides in to their feet. The root hovers 2.5 above the floor and the head's top is about 3.3 above the root, so a focus 5 up sits 1.5 above the head and −1.5 a stud above the floor. A negative height reaches the focus down toward the feet, and a surface under the skater stops it as walls stop the camera. The local skater's parts and decals fade, on that client only (`LocalTransparencyModifier`), as the camera closes in on its focus: whole at `Camera.fade.seen = 4` studs or farther, gone at `fade.gone = 1.5` or nearer, straight between; a wall pulling the camera in fades them too, so the body never fills the view. The parts are gathered once per character and kept as they come and go (an accessory loading late fades with the rest; a part the skater loses shows whole), and the fade is written only when it changes. *The owner (#276, Q39): "see how the camera gets close to the player and the fades him out, when I move the mouse up, and go back to till the top of the player when I move mouse down" (Video 18: Roller Champions' skater fades from 2.6 s and is gone by 3.1 s, the view then looking up at the roof from the feet; the head stays near the screen's middle; RC's field of view cannot be measured). Picked by playing three trials in Studio: A (Q47: Video 18's sizes on screen at our field of view, 8 out slightly down, 6 level, 3 at 15° up) and A2 (Q48: 1.5 times A) sat too close aiming up at the ring ("the camera is almost attached to the player"), and A2's focus on the head put the crosshair dot on it (Q51; the owner wants the dot shown only while carrying the ball, a ticket of its own); A3, about 1.2 times A2 with the focus 1.5 above the head, kept (Q53). Measured in Play (trial A3): level 12 back and 5 up; 24° up 6.6 back, the skater whole; fading from ~33° up, gone by ~44° at the feet; 55° down 12.7 back and 22.9 up. Before: 12 behind a focus 4 up at every pitch, and the skater never faded.*

**Tilt (#223).** The camera's up rolls toward the surface the skater rides at `rollResponse`, but leans at most `Camera.maxTiltDeg = 30`° from world up. On the glass the floor never stands up on screen, and over a lip the view never turns past sideways or loops. Under a surface facing straight down it keeps the lean it has, and it rolls back level when the surface flattens. *The owner picked 30° from Studio screenshots at 0–90°. Roller Champions, judged by eye: about 15–30° in the owner's own games, 60–90° in ranked players' glass rides. Before this, the camera rolled all the way with the surface and looped over overhangs.* The validator keeps the limit under 90°, so two ups the camera may take are never opposite and a roll always has an axis. The stick still follows the screen: `SkateController` lays the camera's right and look on the skater's surface, so on the glass, pushing toward the wall climbs it at full strength under a leaning camera too.

**Mouse look (#275).** The mouse turns the camera at a fifth of Roblox's own scale: `Input.look.mouse.degPerUnit = (0.1, 0.077)` degrees per pixel across and up, so a full turn takes 3,600 px at Roblox's default mouse sensitivity, which players still scale in Roblox's settings; the stick and touch keep Roblox's own scales. *The owner (#275, Q35): "today I can do 360 around the player in a small movement of the mouse to the right or left, but in RC, I can't do it easily, I need to do more drag movement to do a 360" (Video 18). Roller Champions' own value cannot be measured from video. Was 0.5 (720 px a turn); the owner then played a half (1,440 px) and a quarter (2,880 px) during #276's camera trials and asked for slower each time (Q49, Q52: "still decrease the camera sensitivity by a little bit more"). Measured in Play at a half: a scripted drag of 1,440 px at 720 px/s turned the camera 357°, within one frame's 3° of a full turn; at a fifth the live MouseDelta binding reads 0.1° per pixel × the Roblox setting 1 (trial A3).*

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
  - its centre is `goal.across` (0.75) of the way from the inner glass to the outer glass, `goal.heightAboveFloor` (29; 18 until #268) up, and its front faces oncoming skaters;
  - it hangs from a decorative arm: a post from the rim's top up to `goal.arm.height` (51; 40 until #268), then a beam out to the outer glass;
  - when open, its panel slides away and the ring glows in the possessing team's color.
- **Gate panels (R6, R18, amended after the playtest):** they replace the flat corner markers.
  - At every gate a thin glass wall (`gatePanel.depth` 0.2) fills the track's whole cross-section, from the surface up to the walls' top, and skaters pass through it.
  - Nothing hits, sees or touches a wall. Only the next gate's wall shows, glowing in the possessing team's color; every other wall is invisible. Every streak starts at the goal's gate (§4.2), so its wall shows from the pickup. The ball carrier sees an on-screen arrow to its middle.
- **The carrier's beam (R6):** a glowing strip on the outer glass travels beside the carried ball, in the possessing team's color (`client/CarrierBeam`).
- **Team spawns** on opposite straights, mirrored across the arena's long axis (Blue on the top straight, Orange on the bottom). **Ball spawns** on the long axis, equidistant from both team spawns (one in each curved end). Both teams score in the same goal, so fairness comes from the mirrored spawns and the random ball spawn, not from distance to the goal.
- **Cross-sections** (Arena spec §3.1):
  - **The enclosure (A7):** the floor, the inner bank (16 high) and the outer wall (40 high) are opaque. They rise into **rideable glass** up to `glass.top` (120), clear plastic at 85% see-through (R5's look: Roblox's Glass material hides every see-through part behind it), and each wall ends in a **lip** curling inward (a quarter circle of `glass.lipRadius`, 12). A **per-map top** closes the arena: a glass roof at 120 (`top.kind = "Closed"`, our map) or an invisible ceiling 20 higher (`"Open"`). The top stops skaters and the ball and is not ridden.
  - **Straights** (#268): from the inner glass, a wide bank (a quarter ellipse 24 wide, 16 high), a flat **spawn room** (u 24–30), a steep **rise** (steepest ~39°) to 8 high at u 44, a 14° **incline** and a wide foot curve (r 22) up into the outer wall.
  - **Curved ends** (#268): the bank (a quarter circle r 16), then a **bowl** rising 14 · s² from the bank's foot to the outer wall's foot curve (r 18), steeper toward the wall: no flat lane.
  - Between straight and end, the profile **blends point by point** over `profileBlendLength` (both have the same six pieces).
  - **The middle** (40 wide) is closed off behind the inner glass: a floor slab that is not a ride surface.
- **Dimensions (studs):**
  - the loop: `straightLength = 200`, `endRadius = 60` (centerline), `trackWidth = 80`, so the arena is 200 across;
  - the solid profile: `outerWallHeight = 40`, `innerBankHeight = 16`, `straight = { bankWidth = 24, roomEnd = 30, riseEnd = 44, riseHeight = 8, inclineDeg = 14, footRadius = 22 }`, `curvedEnd = { bowlHeight = 14, bowlPower = 2, footRadius = 18 }`, `profileBlendLength = 20`, `segmentLength = 4`, `stripsPerSection = 20`;
  - the enclosure: `glass = { top = 120, lipRadius = 12, lipStrips = 4, transparency = 0.85, material = SmoothPlastic }`, `top = { kind = "Closed", ceilingAbove = 20 }`;
  - the features: `gatePanel = { depth = 0.2 }`, `goal = { ringRadius = 7, heightAboveFloor = 29, across = 0.75, arm = { thickness = 1, height = 51 } }`.
- **The lap:** the centerline loop is 2·200 + 2π·60 ≈ 777 studs. A skater holding the stick laps in 12.7–12.8 s (measured 2026-10-26), past the 10–12 s target until the Feel part tunes speeds (Arena spec 2.3, 13). On #268's map, along the spawn lane (u 27, 695 studs round) at the 55 km/h stride: 15.0 s (measured in Play, 2026-10-29).

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
| `SkateState` | client → server | `{ pump: boolean, brake: boolean, airPose: boolean }` | Sent when one changes; schema-validated; rate-limited per player (`Network.maxSkateStatesPerSecond = 20`); other clients pose from the attributes the server sets. `airPose` stays true for `Network.posedLandingTolerance` after a touchdown in the Air Pose, or until the knockdown (§7.2 Hard landing). |
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
