# M1 Phase 6 — Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Players act (spec §8.1–8.2). They tackle and dive, dodge with the ball, uppercut (leaping off a wall), charge a throw along the camera, pass to a teammate with a homing ball, and call for a pass. Knocked-down players slide, slow and cannot catch, and a knocked-down carrier drops the ball with their momentum. Every action is bound to keyboard and gamepad keys.

**Architecture:**
- **Pure modules in `src/shared/Actions/`**, unit-tested with the spec's numbers:
  - `ActionRunner`: phases, cooldowns, requirements and follow-ups, one runner per player, the same on client and server;
  - `Reach`: who a strike reaches;
  - `PassTarget`: who a pass goes to;
  - `Throw`: throw and pass velocities.
- **`Ball/Homing`** (pure) steers a passed ball.
- **One data entry per action in a new `Config.Actions` area.** An action is a config entry plus one effect function on the server (spec §8.1).
- **The client predicts.** `ActionController` reads the action keys, starts the action at once in its own runner, pushes the skater (`SkateController:push`) and sends `ActionRequest`.
- **The server decides.** `ActionService` validates the request (schema and rate limit through `NetService:listen`), re-checks it in the player's server runner, and applies the effects: throws and passes through `BallService`, strikes against server positions, knockdowns as a replicated character attribute. It refuses with `ActionRejected`.
- **`MatchService` keeps one frame order** and reports knockdowns and body touches to the rules engine.

**Tech Stack:** Luau (`--!strict`), Jest-Lua 3.10.0 in Studio through the Roblox Studio MCP, Rojo 7.7.1, StyLua 2.6.0, selene 0.32.0, luau-lsp 1.70.1 (`bash scripts/analyze.sh`).

**Spec:** `docs/superpowers/specs/2026-10-21-m1-foundation-core-match-design.md`:
- §3.3 (authority), §6.3 (saves: touches), §7.1 (`KnockedDown`, the tackle-lunge and knockdown-tilt poses);
- §8.1–8.3 (the action system, the action list, the keys), §9.3 (knocked-down players can't catch);
- §10.2 (`ActionRequest`), §12.2 (budgets), §13 (remotes never trusted; a rejected action is corrected), §14 (phase 6).

Constraints from Phase 5 are in the PR bodies of #83–#99:
- `SkateController` drives the skater body in `PreSimulation`;
- `CharacterService:holders()` lists seated, living characters;
- pump and brake are shared through `SkateState`, with `Net/Schemas` and `Net/RateLimiter`;
- the kickoff freeze anchors roots.

## Verified facts this plan relies on (probed in Studio, 2026-10-22)

- **The server sees each skater's facing.** A client-driven root's `CFrame.LookVector` read the same on the server as on the owning client: (1, 0, 0) on both. Server-side strikes can use the attacker's root facing.
- **A thrown ball bounces off a skater's collider** (a server-owned 3-stud ball launched at a skater at 40 studs/s came within 2.34 studs of the root and bounced back).
  - The collider has `CanTouch = false` (Phase 5), so the server gets no `Touched` for it. Body contact is measured by distance instead.
  - The ball is caught first by anyone allowed to catch: the pickup reach (5 + 2 studs) is larger than contact (1.5 + 1 studs). So a body touch only comes from someone who cannot catch: a knocked-down player, or the thrower inside the rethrow delay.
- **Mouse buttons bind like keys.** Roblox's own `CharacterContext` binds `AbilityAction5` with `InputBinding.KeyCode = Enum.KeyCode.MouseLeftButton`. Roblox's camera already uses `MouseRightButton` to turn (`CameraContext`), which matters to Phase 7's Ball Focus, not here.
- **An `InputAction` has `Pressed`, `Released` and `StateChanged`.** In the Edit DataModel a scripted `Fire(true)` shows in `GetState()` at once, while the three events arrive only after a yield. **Holds are therefore timed by reading `GetState()` each step**, as pump is, not from events.
- **Roblox's default `Animate` no longer exists in our characters** (PR #99): `StarterCharacterScripts.Animate` is ours and plays nothing. Only the dynamic head's mood (face) track plays, so poses written through `Transform` are the only body animation.
- **Attributes the server sets on a character replicate to every client** (Phase 5: `Pumping`, `Braking`).

## Owner decisions (2026-10-22)

1. **The action keys come in this phase, for keyboard and gamepad** (changing Phase 5's decision 4). Spec §8.3:
   - E / ButtonX: Tackle, or Dive during a tackle, or Dodge with the ball;
   - Q / ButtonB: Uppercut;
   - R / ButtonY: Pass with the ball, Call Pass without;
   - hold MouseLeftButton / ButtonL2: Charge Throw.

   Phase 7 still adds the mobile buttons, the on-screen hints, the camera and Ball Focus.
2. **A knocked-down skater slides and slows fast** for the 1.5 s, with no steering, pump, brake, jump or attach. It ends up behind the play. A new `Movement.knockdownDecel = 75` studs/s² sets how fast: with friction, 80 studs/s falls to about 40 at 0.5 s and to 0 at about 1 s.

## Global Constraints

- **Earlier constraints still apply.** Everything in the Phase 1–5 Global Constraints holds:
  - `--!strict` first line;
  - StyLua, selene and `bash scripts/analyze.sh` clean;
  - relative requires in `src/`, service-path requires in tests;
  - `JestGlobals` only, no `jest.fn()`;
  - annotate locals strict mode can't infer;
  - lines at most 120 columns, comments included (StyLua never wraps comments; measure).
- **Pure modules** never touch an Instance, a service or `workspace`: `src/shared/{Actions,Ball,Skate,Net/RateLimiter,Net/Schemas,Config}`.
- **No gameplay literals.** Every number comes from `Config.Actions`, `Config.Movement`, `Config.Pose`, `Config.Input` or `Config.Network`.
- **Names are spelled once:**
  - remote names in `Net/Remotes`;
  - character attributes in `Net/Attributes`;
  - action names in `Config/Actions` (`Actions.names`);
  - tags in `Arena/Tags`.
- **Services and controllers are `Loader` modules with an explicit exported type.**
  - `init(deps)` touches no global Roblox state, though it may build instances under a `deps.Parent`.
  - `start()` holds every global effect.
  - Tests inject fakes through `deps` and call `step(dt)` by hand.
- **Budgets** (spec §12.2):
  - the server match frame stays under 1 ms with 6 players; `ActionService.step` must take under **0.2 ms** with six players striking, measured in its test;
  - the client `SkateController` step stays under 0.5 ms; `ActionController.step` must take under **0.1 ms**, measured in its test.
  - No per-frame allocations on hot paths: runners, records and lists are reused.
- **Tests:**
  - Instances live under a uniquely named `…Test` folder and are removed in `afterEach`/`afterAll`.
  - Compare names or booleans, never an Instance that might fail.
  - Yield once before asserting on a Roblox event.
  - A shared helper goes in `tests/Fixtures.luau`, never into two specs.
  - **Prove each guard test with a mutation** (remove the guard, watch the test fail, restore it) and record it in the ledger.
- **Process:** branches, commits and PRs follow `CONTRIBUTING.md`. Every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, and every PR body with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## How tests run

As in Phase 5: `rojo serve test.project.json` stays running and connected, and tests run through the Roblox Studio MCP `execute_luau` (`datamodel_type = "Edit"`):

```lua
task.wait(1)
local s = require(game:GetService("ServerStorage").RunTests:Clone())({ testPathPattern = "(A|B)" })
return { passed = s.numPassedTests, failed = s.numFailedTests, total = s.numTotalTests }
```

- Check a changed module's `.Source` in Studio before debugging a test that disagrees with the code: Rojo serve has died three times.
- A long run can return "Target is not reachable"; its results are then in `get_console_output`.
- The suite has **403 tests** before this phase. Each task states its new tests and the new total. A different total is a finding: work out which number is right, rule on it and record the ruling.
- After this phase the playtest console must read exactly `[BloxChampions] Server ready: mode=NormalChampions, modules=8` and `[BloxChampions] Client ready: mode=NormalChampions, modules=5`.

## Review Focus

1. **Lag and jitter rejecting fair actions.** A client starting an action the moment its cooldown ends can reach the server a little early. The server allows `Network.actionCooldownTolerance` (0.1 s).
   - Task 6: `accepts an action that arrives up to actionCooldownTolerance early, and rejects one earlier`.
2. **Actions across a kickoff.** A tackle mid-swing, a knockdown or a call must not outlive the kickoff reset, on either side.
   - Task 6: `clears every action, knockdown and call at a kickoff`.
   - Task 8: `spends the keys and resets the runner while frozen`.
3. **The knocked-down carrier.** The ball drops with the carrier's velocity; the victim cannot catch it back; the tackler can.
   - Task 5: `lets a knocked-down player not catch, but reports their touch`.
   - Task 9: `knocks the carrier down; the ball keeps their momentum and the tackler takes it`.
4. **A client that lies or floods.** An unknown action, an extra field, a NaN aim, a charge of 5, a throw without the ball, a tackle while knocked down or frozen: each is dropped or rejected, never applied.
   - Task 1: `accepts each action's exact shape and rejects anything else`.
   - Task 6: `rejects what the player cannot do now, and tells them`.
5. **Players who leave, die or respawn mid-action.** Records are forgotten. A new character carries no stale attribute. A pass homing on a player who left flies straight.
   - Task 5: `stops homing when the target can no longer catch`.
   - Task 6: `forgets a player who leaves, and starts a respawned character clean`.

## Decisions not spelled out in the spec (for owner review)

1. **Knocked down is a lock on the skater's input, not a `SkateMath` mode.**
   - Spec §7.1 lists `KnockedDown` among the modes. Here the body keeps `Grounded`/`Airborne`, so it still falls, slides and rides walls by the same rules.
   - While locked, `SkateMath` ignores the stick, pump, brake, jump and draft and removes `knockdownDecel × dt` of speed on the ground.
   - The server shows it as a replicated character attribute `KnockedDown`. The owning client reads it into the lock, every client poses it, and `CharacterService:holders()` marks the player unable to catch.
   - *Cost if wrong:* none found; the pose and the catch filter read the attribute.
2. **A strike knocks down the nearest opponent it reaches, once per use.** Tackle, Dive and Uppercut each stop striking after their first knockdown. Teammates, knocked-down players and dodging players are never reached. *Cost if wrong:* two opponents side by side, and only one goes down.
3. **Motions are one-shot pushes when the action starts**, added to the skater's velocity and capped at `hardCap`, scaled by `Actions.airMultiplier` (0.8) in the air (spec's air tackle and air dodge):
   - Tackle +40 and Dive +60 along the facing;
   - Dodge +45 along the stick's world direction, or to the skater's right with no stick;
   - Uppercut: if a steep ride surface lies within 5 studs ahead, +110 straight up and airborne (spec's wall leap).

   *Cost if wrong:* the feel of each action, tuned in Phase 9.
4. **Values the spec doesn't give:**
   - Dive: `lungeSpeed = 60`, `cooldown = 0.8`;
   - Dodge: phases 0 / 0.3 / 0.2, immune exactly during its active phase (the spec's 0.3 s);
   - Uppercut: phases 0.05 / 0.2 / 0.4, `aimUpDeg = 30`, so its 60° cone covers "in front and above";
   - Tackle and Dive: `aimUpDeg = 0`;
   - Charge Throw, Pass and Call Pass: phases 0 / 0 / 0; Charge Throw and Pass: no cooldown;
   - `Pose.lungeDeg = 35`, `Pose.knockdownTiltDeg = 60`.

   *Cost if wrong:* tuning.
5. **A cooldown starts when the action starts.** Cones are half-angles, as `draftConeDeg` and `attachConeDeg` are. *Cost if wrong:* none.
6. **The server never judges `grounded`.** It cannot see the client's ground ray, and every M1 action allows `"any"`. It refuses an action from a frozen (anchored) player, and allows `Network.actionCooldownTolerance = 0.1` s of early arrival. *Cost if wrong:* a future grounded-only action needs a server check.
7. **A new remote `ActionRejected`** (server → client, `{ action }`) carries spec §13's correction. The client cancels the action's pose and refunds its cooldown. It cannot undo a push already applied, which the movement guard tolerates. *Cost if wrong:* a refused lunge still moved the skater a little.
8. **`ActionRequest` has exactly one shape per action**, checked by a new `Validate.tagged("action", variants)`:
   - `{ action }` for Tackle, Dive, Dodge, Uppercut and Call Pass;
   - `{ action, aim }` for Pass;
   - `{ action, aim, charge }` for Charge Throw.

   `aim` is a finite non-zero `Vector3`, which the server makes unit; `charge` is a number in 0..1. Spec §10.2's optional fields become required per action. *Cost if wrong:* none.
9. **New attributes, set by the server on a character:**
   - `KnockedDown`;
   - `Action`: the running action's name, cleared when it ends;
   - `CallingPass`: true for `Actions.callPassWindow`, for Phase 8's hand icon.

   Clients pose others from them, and pose their own skater from the local runner, for immediacy.
10. **Catching and touching:**
    - `CharacterService:holders()` gains `canCatch` (false while `KnockedDown`).
    - `BallService` lets only `canCatch` holders catch, and homes passes only on them.
    - It reports a body touch (`frame.toucher`) for the nearest non-catcher within contact distance (`Ball.radius + Movement.colliderDiameter / 2 + Network.pickupLagToleranceStuds`). `MatchService` passes it to `engine:touched`, completing spec §6.3's "body contact".
11. **The server frame order** (`MatchService.step`):
    1. `ActionService:step(dt)`: strikes, knockdowns and drops, before the ball moves;
    2. `BallService:step`;
    3. the engine facts: `ballMoved`, `thrown`, `pickedUp`, `touched`, then each `knockedDown`;
    4. `tick`, then the events.

    `ActionService` has no Heartbeat of its own. *Cost if wrong:* none.
12. **Passes:**
    - A pass flies at `passSpeed` toward the target's current position (no lead). Homing (`passHomingAccel`) steers it while it flies and the target can catch.
    - With no target it flies straight along the aim.
    - A pass is a throw for the rules: saves and the rethrow delay apply.

    *Cost if wrong:* a fast receiver may outrun a pass; tuned in Phase 9.
13. **Charge Throw aims along the camera** (`workspace.CurrentCamera.CFrame.LookVector`), as does Pass. Phase 7's camera replaces Roblox's, and stays the aim.
14. **A dive pressed in the last moments of a tackle may reach the server after its tackle's active phase** and be refused. *Cost if wrong:* a rare refused dive.
15. **`BallCarrier` becomes one client module**, read by `PoseController` and `ActionController`, instead of each listening to the remote (DRY).

**Not in this phase:**
- **Phase 7:** mobile buttons, on-screen hints, the custom camera, Ball Focus (it shares ButtonL2 with Charge Throw, so Phase 7 makes that binding depend on holding the ball), and spec §8.5's defaults.
- **Phase 8:** the call-pass hand icon and the `DENIED!` banner, from `CallingPass` and `SaveMade`.
- **Phase 9:** tuning every action's numbers.

## File Structure

```
src/shared/Config/Actions.luau        new area: one entry per action, airMultiplier, callPassWindow, names
src/shared/Config/{init,Movement,Network,Input,Pose,Validate}.luau   new values; Validate.tagged
src/shared/Actions/ActionRunner.luau  pure: phases, cooldowns, requirements, follow-ups
src/shared/Actions/Reach.luau         pure: who a strike reaches
src/shared/Actions/PassTarget.luau    pure: who a pass goes to
src/shared/Actions/Throw.luau         pure: throw and pass velocities
src/shared/Ball/Homing.luau           pure: a pass steering toward its target
src/shared/Skate/{SkateMath,Types,Pose}.luau   push, the knockdown lock, lunge and knockdown poses
src/shared/Net/{Remotes,Schemas,Attributes}.luau   ActionRequest, ActionRejected; KnockedDown, Action, CallingPass
src/server/ActionService.luau         validates and applies actions; knockdowns
src/server/{BallService,CharacterService,MatchService,Modules}.luau   pass, drop velocity, canCatch, touches, order
src/client/BallCarrier.luau           who carries the ball, for every client module
src/client/ActionController.luau      keys → local runner → push + request; rejections
src/client/{InputController,SkateController,PoseController,Modules}.luau   action keys, push, lock, poses
```

---

### Task 1: Action config and the action request (labels `feature`, `actions`)

**Issue:** to be created · **Branch:** `feat/<issue>-action-config` · **Base:** `main`

**Files:**
- Create: `src/shared/Config/Actions.luau`
- Modify: `src/shared/Config/init.luau` (area `Actions`), `Config/Network.luau`, `Config/Validate.luau` (`tagged`), `src/shared/Net/{Remotes,Schemas,Attributes}.luau`
- Test: `tests/shared/Config/Config.spec.luau`, `tests/shared/Config/Validate.spec.luau`, `tests/shared/Net/{Schemas,Remotes}.spec.luau`

**Interfaces:**
- Produces:
  ```lua
  -- Config/Actions
  export type ActionName = "Tackle" | "Dive" | "Dodge" | "Uppercut" | "ChargeThrow" | "Pass" | "CallPass"
  export type Effect = "Knockdown" | "Dodge" | "Throw" | "Pass" | "CallPass"
  export type PoseName = "Lunge" | "None"
  export type Phases = { windup: number, active: number, recovery: number }
  export type Requires = { ball: "with" | "without" | "any", grounded: "grounded" | "airborne" | "any",
  	notKnockedDown: boolean }
  export type Hit = { range: number, coneDeg: number, aimUpDeg: number, knockdownSeconds: number }
  export type Motion = { lungeSpeed: number?, sideSpeed: number?, wallLeapDistance: number?,
  	wallLeapImpulse: number? }
  export type ThrowSettings = { chargeMaxSeconds: number, minSpeed: number, maxSpeed: number,
  	inheritCarrierVelocity: number }
  export type PassSettings = { speed: number, homingAccel: number, coneDeg: number, maxRange: number,
  	angleWeight: number, distanceWeight: number }
  export type ActionConfig = { phases: Phases, cooldown: number, requires: Requires, effect: Effect,
  	pose: PoseName, hit: Hit?, motion: Motion?, followUp: { action: ActionName, window: "Active" }?,
  	throw: ThrowSettings?, pass: PassSettings? }
  export type ActionsConfig = { airMultiplier: number, callPassWindow: number, Tackle: ActionConfig,
  	Dive: ActionConfig, Dodge: ActionConfig, Uppercut: ActionConfig, ChargeThrow: ActionConfig,
  	Pass: ActionConfig, CallPass: ActionConfig }
  -- module: { defaults, schema, names: { ActionName } } (names frozen, in the order above)
  Config.GameConfig.Actions: ActionsConfig
  -- Config re-exports ActionsConfig, ActionConfig, ActionName, Effect, PoseName, Hit, ThrowSettings, PassSettings
  NetworkConfig += { maxActionsPerSecond: number, hitLagToleranceStuds: number, actionCooldownTolerance: number }
  Validate.tagged(field: string, variants: { [string]: Validator }): Validator
  Remotes.names += { ActionRequest = "ActionRequest", ActionRejected = "ActionRejected" }
  Schemas.ActionRequest: Validator
  Attributes += { KnockedDown = "KnockedDown", Action = "Action", CallingPass = "CallingPass" }
  ```

**Default values** (spec §8.1–8.2 and decisions 3–4):

| Action | phases (w / a / r) | cooldown | requires.ball | effect | pose | other |
|---|---|---|---|---|---|---|
| Tackle | 0.05 / 0.25 / 0.35 | 0.8 | without | Knockdown | Lunge | hit {7, 50°, up 0°, 1.5 s}; motion {lungeSpeed 40}; followUp {Dive, Active} |
| Dive | 0 / 0.35 / 0.9 | 0.8 | without | Knockdown | Lunge | hit {11, 50°, up 0°, 1.5 s}; motion {lungeSpeed 60} |
| Dodge | 0 / 0.3 / 0.2 | 1.5 | with | Dodge | None | motion {sideSpeed 45} |
| Uppercut | 0.05 / 0.2 / 0.4 | 1.2 | without | Knockdown | None | hit {6, 60°, up 30°, 1.5 s}; motion {wallLeapDistance 5, wallLeapImpulse 110} |
| ChargeThrow | 0 / 0 / 0 | 0 | with | Throw | None | throw {1.0, 60, 160, 0.5} |
| Pass | 0 / 0 / 0 | 0 | with | Pass | None | pass {90, 60, 70°, 120, 0.6, 0.4} |
| CallPass | 0 / 0 / 0 | 1 | without | CallPass | None | — |

Every action: `requires.grounded = "any"`, `requires.notKnockedDown = true`. Top level: `airMultiplier = 0.8`, `callPassWindow = 3`. Network: `maxActionsPerSecond = 15`, `hitLagToleranceStuds = 3`, `actionCooldownTolerance = 0.1`.

**Schema:** each action's record holds exactly the fields in its row: no `hit` on Dodge, no `throw` on Pass, and so on. Rules, in order:
- phases and cooldowns ≥ 0;
- ranges, speeds, `knockdownSeconds`, `chargeMaxSeconds` and `callPassWindow` > 0;
- cones 0..180, `aimUpDeg` 0..90, `airMultiplier` 0..1;
- `throw.maxSpeed >= throw.minSpeed`;
- `pass.angleWeight + pass.distanceWeight > 0`;
- a `followUp.action` names a known action other than its own.

- [ ] **Step 1: Write the failing tests**
  - `Config.spec`:
    - `has the action defaults` (`toEqual` on the whole `Actions` table above);
    - the Network defaults test gains the three values;
    - three rejection cases in the existing table: `Actions.ChargeThrow.throw.maxSpeed: must be at least minSpeed` (for `maxSpeed = 50`), `Actions.Tackle.followUp.action: must name another action` (for `"Tackle"`), and `Actions.Dodge: unknown key hit` (a `hit` added to Dodge).
  - `Validate.spec`: `tagged picks the variant named by the tag` (one valid record per variant, no errors) and `tagged rejects a missing or unknown tag by name` (`{}` gives a message containing `action`; `{ action = "Fly" }` names `Fly`).
  - `Schemas.spec`: `accepts each action's exact shape and rejects anything else`:
    - **accepted:** `{ action = "Tackle" }`, `{ action = "Pass", aim = Vector3.new(0, 0, -1) }`, `{ action = "ChargeThrow", aim = Vector3.new(1, 0, 0), charge = 0.5 }`;
    - **rejected:** `{ action = "Tackle", aim = Vector3.zero }`, `{ action = "Pass" }`, `{ action = "ChargeThrow", aim = Vector3.new(0 / 0, 0, 0), charge = 0.5 }`, `{ action = "ChargeThrow", aim = Vector3.xAxis, charge = 5 }`, `{ action = "Pass", aim = Vector3.zero }`, `{ action = "Fly" }`, `"Tackle"`.
  - `Remotes.spec`: its existing tests loop over every name, so they cover the two new remotes; `finds a remote by name…` also asserts `Remotes.get(parent, Remotes.names.ActionRequest).Name == "ActionRequest"`.
- [ ] **Step 2:** Run `testPathPattern = "(Config|Validate|Schemas|Remotes)"`. Expected: FAIL (missing `Actions` area, `tagged`, schema and names).
- [ ] **Step 3:** Implement the area (defaults, schema with the rules above, `names`), the Network values, `Validate.tagged`, the two remote names, the attributes, and `Schemas.ActionRequest` (variants built from `Actions.names` and each action's effect: Throw → aim and charge; Pass → aim; others → action only).
- [ ] **Step 4:** Run the same pattern, then the full suite. Expected: **407 tests** (+4: the action defaults, two `tagged`, the schema; the Network, rejection and Remotes changes extend existing tests).
- [ ] **Step 5:** Mutation: drop the `maxSpeed >= minSpeed` rule; its rejection case must fail. Restore. Static checks; commit `feat(actions): action config and the action request`.

---

### Task 2: ActionRunner (labels `feature`, `actions`)

**Issue:** to be created · **Branch:** `feat/<issue>-action-runner` · **Stacked on:** Task 1

**Files:**
- Create: `src/shared/Actions/ActionRunner.luau`
- Test: `tests/shared/Actions/ActionRunner.spec.luau`

**Interfaces:**
- Consumes: `Config.ActionsConfig`, `ActionName`, `Requires`.
- Produces:
  ```lua
  export type Phase = "Windup" | "Active" | "Recovery"
  export type Context = { hasBall: boolean, airborne: boolean, knockedDown: boolean }
  export type Verdict = "Started" | "Busy" | "CoolingDown" | "NotAllowed"
  ActionRunner.new(actions: Config.ActionsConfig): Runner
  -- fields: action: ActionName?, phase: Phase?
  runner:start(name: ActionName, context: Context, tolerance: number?): Verdict  -- starts only on "Started"
  runner:step(dt: number)                       -- advances the phase and every cooldown
  runner:cooldownLeft(name: ActionName): number
  runner:cancel(refund: boolean)                -- stops the running action; refund clears its cooldown
  runner:reset()                                -- no action, every cooldown 0
  ```
- Rules:
  - Check in this order: requirements (`NotAllowed`), then busy (`Busy`), then the cooldown (`CoolingDown`; allowed when `cooldownLeft ≤ tolerance or 0`).
  - Busy means an action is running, unless the new action is the running one's `followUp` and the running action is in `followUp.window`. A follow-up replaces the running action.
  - A phase of length 0 is skipped. An action whose three phases are 0 starts and ends inside `start` (`action` stays nil).
  - `step` carries leftover time into the next phase, so a 0.3 s step through a 0.05 windup lands 0.25 s into the active phase.
  - The cooldown starts at `start`.
  - `grounded = "grounded"` requires `not context.airborne`; `"airborne"` requires it; `"any"` passes.

- [ ] **Step 1: Write the failing tests** (config from `Config.defaults().Actions`; tests may override one action through `Fixtures.config`):
  - `runs a tackle through windup, active and recovery`: after `start`, `phase == "Windup"`; `step(0.05)` → `"Active"`; `step(0.25)` → `"Recovery"`; `step(0.35)` → `action == nil`.
  - `carries leftover time into the next phase`: `step(0.2)` right after `start` gives `"Active"` (0.15 s into it); `step(0.09)` keeps it; `step(0.02)` gives `"Recovery"`.
  - `keeps an action waiting for its cooldown, and allows it within the tolerance`: after a tackle runs out (0.65 s), `start` again gives `"CoolingDown"`; `step(0.1)` (cooldown 0.05 left) gives `"CoolingDown"` without tolerance and `"Started"` with tolerance 0.1.
  - `refuses what the context does not allow`: Tackle with `hasBall = true`; Dodge or ChargeThrow without; anything while `knockedDown` → `"NotAllowed"`.
  - `refuses a second action while one runs`: Uppercut during a tackle's windup → `"Busy"`.
  - `starts a dive only during a tackle's active phase, replacing it`: Dive in the windup → `"Busy"`; after `step(0.06)` → `"Started"`, with `action == "Dive"` and `phase == "Active"` (Dive has no windup); during the dive's recovery a second Dive → `"Busy"`.
  - `ends an instant action at once and starts its cooldown`: CallPass → `"Started"`, `action == nil`, `cooldownLeft("CallPass") == 1`; again → `"CoolingDown"`.
  - `cancels with or without a refund, and resets everything`: `cancel(true)` after a tackle starts → `action == nil` and `cooldownLeft("Tackle") == 0`; `cancel(false)` keeps 0.8; `reset()` clears all.
- [ ] **Step 2:** Run `testPathPattern = "ActionRunner"`. Expected: FAIL (module missing).
- [ ] **Step 3:** Implement. `cooldownLeft` reads a record keyed by action name, created in `new` from `Actions.names`, so `step` allocates nothing.
- [ ] **Step 4:** Run, then the full suite. Expected: **415 tests** (+8).
- [ ] **Step 5:** Mutation: let `start` ignore `followUp.window` (accept the dive any time the tackle runs); `starts a dive only during a tackle's active phase` must fail. Restore. Static checks; commit `feat(actions): run each action's phases, cooldowns and requirements`.

---

### Task 3: Reach, pass targets, throws and homing (labels `feature`, `actions`)

**Issue:** to be created · **Branch:** `feat/<issue>-action-math` · **Stacked on:** Task 2

**Files:**
- Create: `src/shared/Actions/{Reach,PassTarget,Throw}.luau`, `src/shared/Ball/Homing.luau`
- Test: `tests/shared/Actions/{Reach,PassTarget,Throw}.spec.luau`, `tests/shared/Ball/Homing.spec.luau`

**Interfaces:**
- Produces:
  ```lua
  export type Candidate = { player: PlayerId, position: Vector3 }   -- Reach and PassTarget share it (Reach exports it)
  -- the nearest candidate within hit.range + extra, within hit.coneDeg of the facing pitched up by hit.aimUpDeg
  Reach.nearest(origin: Vector3, facing: Vector3, up: Vector3, hit: Config.Hit, extra: number,
  	candidates: { Reach.Candidate }): PlayerId?
  -- a caller within callWindow (latest call wins), else the best-scored teammate in the cone and range, else nil
  PassTarget.choose(pass: Config.PassSettings, callWindow: number, passer: Vector3, aim: Vector3,
  	teammates: { Reach.Candidate }, calls: { [PlayerId]: number }, now: number): PlayerId?
  Throw.charged(throw: Config.ThrowSettings, aim: Vector3, charge: number, carrierVelocity: Vector3): Vector3
  Throw.pass(pass: Config.PassSettings, from: Vector3, aim: Vector3, target: Vector3?): Vector3
  Homing.step(position: Vector3, velocity: Vector3, target: Vector3, accel: number, dt: number): Vector3
  ```
- Formulas:
  - **Pass score:** `angleWeight × (1 − angle / coneDeg) + distanceWeight × (1 − distance / maxRange)`. Higher wins; a tie goes to the earlier teammate.
  - **Charged throw:** `aim.Unit × lerp(minSpeed, maxSpeed, clamp(charge, 0, 1)) + carrierVelocity × inheritCarrierVelocity`.
  - **Pass:** `(target − from).Unit × speed`, or `aim.Unit × speed` with no target.
  - **Homing:** `velocity + (target − position).Unit × accel × dt`; the velocity is returned unchanged when the target is closer than 1e-3.

- [ ] **Step 1: Write the failing tests**
  - `Reach.spec`:
    - `reaches the nearest opponent within range and cone`: tackle hit {7, 50°, up 0}, origin 0, facing −Z, up +Y; candidates at (0, 0, −6), (0, 0, −3) and (5, 0, −1) (79° off). Expected: the one at −3.
    - `adds the lag tolerance to the range, and reaches nobody beyond it`: a candidate at (0, 0, −9.9) with extra 3 → reached; at (0, 0, −10.1) → nil.
    - `aims an uppercut up`: hit {6, 60°, up 30°}; above and slightly ahead at (0, 5, −0.5) (54° from the aim) is reached; behind at (0, 0, 4) (150°) is not.
  - `PassTarget.spec`:
    - `passes to the latest caller within the window, wherever they are`: two teammates called at 1 and 2 (now 3, window 3), the second one behind the passer → the second.
    - `ignores calls older than the window`: a call at −0.5 with now 3 is ignored, so the best-scored teammate wins.
    - `scores teammates by angle and distance inside the cone and range`: aim −Z; A at (0, 0, −100) (angle 0, distance 100 → 0.6 + 0.0667 = 0.667); B at (30, 0, −30) (45°, 42.4 → 0.214 + 0.259 = 0.473) → A. B alone → B. C at (0, 0, −130) (beyond 120) alone → nil.
    - `finds no target outside the cone`: a teammate at (100, 0, −10) (84° > 70°) → nil.
  - `Throw.spec`:
    - `throws faster the longer the charge, plus half the carrier's velocity`: aim (0, 0, −1), carrier (10, 0, 0): charge 0 → (5, 0, −60); 1 → (5, 0, −160); 0.5 → (5, 0, −110); 2 → (5, 0, −160).
    - `passes at passSpeed toward the target, or along the aim without one`: from 0 to (0, 0, −30) → (0, 0, −90); no target, aim (2, 0, 0) → (90, 0, 0).
  - `Homing.spec`: `turns a pass toward its target at homingAccel`: position 0, velocity (0, 0, −90), target (10, 0, 0), accel 60, dt 0.5 → (30, 0, −90).
- [ ] **Step 2:** Run `testPathPattern = "(Reach|PassTarget|Throw|Homing)"`. Expected: FAIL (modules missing).
- [ ] **Step 3:** Implement. None of these allocates a table.
- [ ] **Step 4:** Run, then the full suite. Expected: **425 tests** (+10).
- [ ] **Step 5:** Mutation: drop the cone check in `Reach.nearest`; `aims an uppercut up` must fail on the point behind (4 studs, inside the range). Restore. Static checks; commit `feat(actions): reach, pass targets, throws and homing`.

---

### Task 4: Pushes, the knockdown lock and the action poses (labels `feature`, `skate`)

**Issue:** to be created · **Branch:** `feat/<issue>-push-and-knockdown` · **Stacked on:** Task 3

**Files:**
- Modify: `src/shared/Skate/{SkateMath,Types,Pose}.luau`, `src/shared/Config/{Movement,Pose}.luau`; `src/client/SkateController.luau` and `src/client/PoseController.luau` only to fill the new input fields with `false`
- Test: `tests/shared/Skate/{SkateMath,Pose}.spec.luau`, `tests/shared/Config/Config.spec.luau`

**Interfaces:**
- Produces:
  ```lua
  Types.SkateInput += { knockedDown: boolean }
  SkateMath.push(self: Skater, change: Vector3, launch: boolean)   -- velocity += change, capped; launch → "Airborne"
  MovementConfig += { knockdownDecel: number }                      -- 75
  Pose.PoseInput += { lunging: boolean, knockedDown: boolean }
  PoseConfig += { lungeDeg: number, knockdownTiltDeg: number }      -- 35, 60
  ```
- Rules:
  - While `knockedDown`, the grounded step ignores the stick, pump, brake and draft. It removes `knockdownDecel × dt` of speed after friction, never below 0. A locked skater never jumps, and the air step does not steer.
  - **Pose priority:** knocked down > lunging > the Phase 5 poses.
    - Knocked down tips the root back by `knockdownTiltDeg`: a positive pitch, the sign that tips the torso back.
    - Lunging tips it forward by `lungeDeg`.
    - Neither changes the body offset.

- [ ] **Step 1: Write the failing tests**
  - `SkateMath.spec`:
    - `pushes the skater and caps the result at hardCap`: grounded at (0, 0, −100), push (0, 0, −60) → speed 140 after the push (no step).
    - `launches with a push that leaves the ground`: push (0, 110, 0) with `launch = true` → mode `"Airborne"`, velocity.Y = 110.
    - `slides a knocked-down skater, slowing by knockdownDecel and ignoring the stick, pump and jump`: on flat ground at 80 studs/s along −Z, input with the stick +X, pump and jump all on and `knockedDown = true`; `step(0.5)` → mode `"Grounded"`, heading still −Z, speed `80 − (4 + 0.02·80)·0.5 − 75·0.5` within 0.5 of 39.7.
    - `stops a knocked-down skater at zero, never backwards`: from 10 studs/s, `step(1)` → speed 0.
  - `Pose.spec`:
    - `tips a lunging root forward and a knocked-down root back, knocked down first`: lunging → the root's look vector has a negative Y component equal to `-sin(35°)` within 1e-6; knocked down (with lunging also set) → `+sin(60°)`.
  - `Config.spec`: the Movement and Pose defaults tests gain the three values.
- [ ] **Step 2:** Run `testPathPattern = "(SkateMath|Pose|Config)"`. Expected: FAIL.
- [ ] **Step 3:** Implement. `SkateController` and `PoseController` pass `knockedDown = false`, `lunging = false` until Task 8, so the suite stays green.
- [ ] **Step 4:** Run, then the full suite. Expected: **430 tests** (+5).
- [ ] **Step 5:** Mutation: let a knocked-down skater keep the stick; the slide test must fail. Restore. Static checks; commit `feat(skate): pushes, the knockdown slide and the action poses`.

---

### Task 5: The ball for actions: drops, passes, catching and touches (labels `feature`, `ball`)

**Issue:** to be created · **Branch:** `feat/<issue>-ball-actions` · **Stacked on:** Task 4

**Files:**
- Modify: `src/server/BallService.luau`, `src/server/CharacterService.luau`, `src/server/MatchService.luau`
- Test: `tests/server/BallService.spec.luau` (its `holder` helper gains `canCatch`), `tests/server/CharacterService.spec.luau`, `tests/integration/Match.spec.luau`

**Interfaces:**
- Consumes: `Homing.step`, `Attributes.KnockedDown`.
- Produces:
  ```lua
  BallService.Holder = { player: PlayerId, root: BasePart, canCatch: boolean }
  BallService.BallFrame += { toucher: PlayerId?, touchPosition: Vector3, touchVelocity: Vector3 }
  BallService:drop(velocity: Vector3?)                          -- a given velocity replaces the ball's
  BallService:pass(player: PlayerId, velocity: Vector3, target: PlayerId?)  -- a throw that homes on target
  -- CharacterService:holders(): canCatch = character:GetAttribute(Attributes.KnockedDown) ~= true
  ```
- Rules:
  - Only `canCatch` holders catch.
  - **Homing:** while the ball is `Flying` and the pass target is a `canCatch` holder, each step sets the ball's velocity to `Homing.step(…, Actions.Pass.pass.homingAccel, dt)`. Homing ends for good when the ball stops flying, or when that target is missing or cannot catch.
  - **Touch:** a free ball within contact distance (decision 10) of a holder who did not catch it this frame. The nearest such holder is the `toucher`; `touchPosition` and `touchVelocity` are the ball's.
  - `MatchService` reports `engine:touched(toucher, touchPosition, touchVelocity)` after `pickedUp`.

- [ ] **Step 1: Write the failing tests**
  - `BallService.spec`:
    - `drops the ball with the carrier's momentum`: catch, then `drop(Vector3.new(30, 0, 0))` → status `"Loose"`, velocity (30, 0, 0).
    - `homes a pass on its target`: A passes to B with velocity (0, 0, −90); `step(0.1, holders)` → the velocity changed by exactly `(B's root − ball).Unit × 60 × 0.1` (within 1e-3).
    - `stops homing when the target can no longer catch`: the same, with B `canCatch = false` on the step → velocity unchanged by homing.
    - `lets a knocked-down player not catch, but reports their touch`: B `canCatch = false` 2 studs from a loose ball, A 6 studs away → `picker == "A"`; with A 20 studs away → no picker, `toucher == "B"`.
  - `CharacterService.spec`: `marks knocked-down players unable to catch`: set the attribute on A's rig → A's holder has `canCatch == false`, B's `true`.
  - `Match.spec`: `reports a body touch to the rules after the pickups`: open the goal with the existing `openGoal` helper, set `KnockedDown` on an Orange rig standing on the ring's approach, throw the carrier's ball along the ring's path (`throughRing`'s points) so it passes within contact distance of that rig → `SaveMade { kind = "Block" }` once the danger passes.
- [ ] **Step 2:** Run `testPathPattern = "(BallService|CharacterService|Match)"`. Expected: FAIL.
- [ ] **Step 3:** Implement. `candidatesFrom` keeps reusing one list and adds only `canCatch` holders. The touch search walks the holders without allocating.
- [ ] **Step 4:** Run, then the full suite. Expected: **436 tests** (+6).
- [ ] **Step 5:** Mutation: let knocked-down holders catch; the knocked-down test must fail. Restore. Static checks; commit `feat(ball): drops with momentum, homing passes, and catches only by players on their feet`.

---

### Task 6: ActionService (labels `feature`, `actions`)

**Issue:** to be created · **Branch:** `feat/<issue>-action-service` · **Stacked on:** Task 5

**Files:**
- Create: `src/server/ActionService.luau`
- Modify: `src/server/MatchService.luau` (dependency, step order, reset at kickoff), `src/server/Modules.luau` (after `CharacterService`, before `MovementGuard`: 8 modules)
- Test: `tests/server/ActionService.spec.luau`, `tests/integration/Match.spec.luau` (its `setup` adds `ActionService`)

**Interfaces:**
- Consumes: `ActionRunner`, `Reach`, `PassTarget`, `Throw`, `BallService:throw/pass/drop`, `CharacterService:holders()`, `TeamService:teamOf`, `NetService:listen/fireTo`, the remotes and attributes.
- Produces:
  ```lua
  export type Knockdown = { attacker: PlayerId, victim: PlayerId }
  export type ActionService = {
  	name: "ActionService", dependencies: { "Config", "NetService", "BallService", "TeamService", "CharacterService" },
  	init: (self, deps) -> (),  -- deps.Clock (default os.clock); listens to ActionRequest in init, as CharacterService does
  	request: (self, player: PlayerId, payload: any) -> (),  -- what a validated message runs (tests call it)
  	step: (self, dt: number) -> { Knockdown },              -- one reused list per frame
  	reset: (self) -> (),                                   -- the kickoff: no actions, knockdowns, calls or attributes
  	forget: (self, player: PlayerId) -> (),
  	isImmune: (self, player: PlayerId) -> boolean,         -- a dodge in its active phase
  }
  ```
- **The effects table:** one function per `Effect`.
  - `Throw`: `BallService:throw(player, Throw.charged(…, aim, charge, root.AssemblyLinearVelocity))`.
  - `Pass`: `PassTarget.choose` over seated teammates who can catch; `BallService:pass(player, Throw.pass(…), target)`.
  - `CallPass`: records the call time and sets `CallingPass` for `callPassWindow`.
  - `Knockdown`: during `"Active"`, until the first knockdown of this use, `Reach.nearest` over opponents' roots who are not knocked down and not immune. Origin, facing and up come from the attacker's root, with `extra = Network.hitLagToleranceStuds`.
    - A knockdown sets `KnockedDown` for `hit.knockdownSeconds` and cancels the victim's action without a refund.
    - If the victim carries the ball, `BallService:drop(victimRoot.AssemblyLinearVelocity)`.
    - The pair is appended to the frame's list.
  - `Dodge`: nothing on the server beyond `isImmune`.
- **A request is refused** (`ActionRejected { action }` to that player) when:
  - the player has no living seated character, or its root is anchored;
  - the runner's verdict is not `"Started"`. The context is: `hasBall` = `BallService.state.carrier == player`, `knockedDown` from the record, `airborne = false` (decision 6); the tolerance is `actionCooldownTolerance`.
- **Attributes:** `Action` is set to the name when an action keeps running after `start`, and cleared when it ends.
- **`MatchService.step`** calls `actions:step(dt)` first, then the ball, then the engine facts in decision 11's order, reporting `engine:knockedDown(attacker, victim)` for each knockdown. `react("KickoffStarted")` also calls `actions:reset()`.
- **`ActionService.init`** connects `forget` to `CharacterService.characterRemoved` and `TeamService.unseated`, as `MovementGuard` does.

- [ ] **Step 1: Write the failing tests** (`ActionService.spec`; a fake `NetService` records `listen` and `fireTo`; real `BallService`, `TeamService` and `CharacterService` on rigs; a fake clock):
  - `throws the carrier's ball at the charged speed along the aim`: A carries; `request("A", { action = "ChargeThrow", aim = Vector3.new(0, 0, -1), charge = 1 })` with A's root still → ball `Flying`, velocity (0, 0, −160).
  - `passes to the teammate who called`: B calls (`CallPass`), and B's character has `CallingPass == true`; A passes with aim +X while B stands 40 studs along −Z → the ball flies at 90 studs/s straight at B (its velocity's unit vector equals `(B − ball).Unit` within 1e-3), not along the aim.
  - `knocks down the nearest opponent a tackle reaches, once`:
    - A tackles facing −Z;
    - opponents B (−5) and C (−6), teammate D (−2);
    - `step` through windup and active.
    - Result: one knockdown `{ A, B }`; B's `KnockedDown == true` until `step` passes 1.5 s, then false; C untouched.
  - `drops the ball of a knocked-down carrier with their momentum`: B carries, moving at (0, 0, 30) (set on B's root) → after the knockdown the ball is `Loose` with velocity (0, 0, 30).
  - `never reaches a teammate, a knocked-down or a dodging player`: each alone in front of A's tackle → no knockdown. A carrier who dodges as the tackle starts stays up through it (immune 0 – 0.3 s, the tackle active 0.05 – 0.3 s); a second tackle after the cooldown knocks them down.
  - `rejects what the player cannot do now, and tells them`: a throw without the ball, a tackle with it, a tackle while knocked down, any action while the root is anchored, and a second tackle inside its cooldown. Each fires `ActionRejected` with the action's name to that player and changes nothing.
  - `accepts an action that arrives up to actionCooldownTolerance early, and rejects one earlier`: tackle, advance 0.75 s (0.05 left) → accepted; another player 0.65 s (0.15 left) → rejected.
  - `clears every action, knockdown and call at a kickoff`: mid-tackle, a knockdown and a call, then `reset()` → no `Action`, `KnockedDown` or `CallingPass` attributes, and an immediate new tackle is accepted.
  - `forgets a player who leaves, and starts a respawned character clean`: `forget` during a knockdown; a new rig adopted for the same player has no `KnockedDown`, and a tackle by them is accepted.
  - `steps six striking players in under 0.2 ms`: six players tackling in turn, 600 steps, mean < 0.2 ms; record the number in the ledger and the PR.
  - `Match.spec` (integration):
    - `reports a tackle's knockdown to the rules` → `TackleKnockdown { attacker, victim }` appears in the fired `RuleEvents`;
    - `clears actions and knockdowns at the next kickoff`: a knockdown, then a goal (`scoreOnce`) → after `KickoffStarted` no character has `KnockedDown` or `Action`.
- [ ] **Step 2:** Run `testPathPattern = "(ActionService|Match)"`. Expected: FAIL.
- [ ] **Step 3:** Implement. One record per player (runner, `struck`, `knockdownLeft`, `callAt`), created on first use and reused. `step` reuses one `Knockdown` list and its records.
- [ ] **Step 4:** Run, then the full suite. Expected: **448 tests** (+12).
- [ ] **Step 5:** Mutations:
  - remove the teammate filter → `never reaches a teammate…` fails;
  - remove `reset` from the kickoff reaction → `clears actions and knockdowns at the next kickoff` fails.

  Restore both.
- [ ] **Step 6: Playtest.** Console exactly `Server ready … modules=8` and `Client ready … modules=3`. From the server probe, request a tackle for the local player with a test rig in front; the rig's `KnockedDown` turns on and off; no warnings.
- [ ] **Step 7:** Static checks; commit `feat(actions): the server validates and applies every action`.

---

### Task 7: The action keys (labels `feature`, `input`)

**Issue:** to be created · **Branch:** `feat/<issue>-action-keys` · **Stacked on:** Task 6

**Files:**
- Modify: `src/shared/Config/Input.luau`, `src/client/InputController.luau`
- Test: `tests/shared/Config/Config.spec.luau`, `tests/client/InputController.spec.luau`

**Interfaces:**
- Produces:
  ```lua
  InputConfig += { tackle: { Enum.KeyCode }, uppercut: { Enum.KeyCode }, pass: { Enum.KeyCode },
  	throw: { Enum.KeyCode } }
  -- defaults: tackle { E, ButtonX }, uppercut { Q, ButtonB }, pass { R, ButtonY },
  -- throw { MouseLeftButton, ButtonL2 }; boundKeys covers them, so a key bound twice is still rejected
  export type ActionKeys = { tackle: boolean, uppercut: boolean, pass: boolean, throw: boolean }
  InputController.newActionKeys(): ActionKeys
  InputController:readActions(into: ActionKeys)   -- tackle/uppercut/pass: pressed since the last readActions;
                                                  -- throw: held now (GetState)
  ```
- Actions `Tackle`, `Uppercut`, `Pass` and `Throw` (Bool) join the `SkateControls` context. Each pressed button has its own counter, independent of `read`'s jump.

- [ ] **Step 1: Write the failing tests**
  - `Config.spec`: the Input defaults test gains the four lists.
  - `InputController.spec`:
    - `reads action presses once and the throw while held`: fire Tackle and Pass, yield → `readActions` gives `tackle` and `pass` true, `uppercut` false; a second `readActions` gives all false. Holding Throw (fired true, no yield needed) → `throw` true until fired false.
    - `keeps the skating keys and the action keys apart`: a Jump press is not consumed by `readActions`, and a Tackle press is not consumed by `read`.
- [ ] **Step 2:** Run `testPathPattern = "(Config|InputController)"`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run, then the full suite. Expected: **450 tests** (+2).
- [ ] **Step 5:** Static checks; commit `feat(input): bind the action keys for keyboard and gamepad`.

---

### Task 8: ActionController, pushes, the lock and the poses on the client (labels `feature`, `actions`)

**Issue:** to be created · **Branch:** `feat/<issue>-action-controller` · **Stacked on:** Task 7

**Files:**
- Create: `src/client/BallCarrier.luau`, `src/client/ActionController.luau`
- Modify: `src/client/SkateController.luau`, `src/client/PoseController.luau`, `src/client/Modules.luau` (order: InputController, BallCarrier, SkateController, ActionController, PoseController)
- Test: `tests/client/{BallCarrier,ActionController}.spec.luau`, `tests/client/{SkateController,PoseController}.spec.luau`

**Interfaces:**
- Consumes: `ActionRunner`, `InputController:readActions`, `Config.Actions`, the remotes and attributes.
- Produces:
  ```lua
  -- BallCarrier: who carries the ball (BallCarrier remote, listened to in start)
  BallCarrier.carrier: PlayerId?
  BallCarrier:set(player: PlayerId?)
  -- SkateController additions
  SkateController:push(change: Vector3, launch: boolean)
  SkateController.move: Vector3            -- the last step's stick as a world direction
  SkateController:wallAhead(distance: number): boolean  -- a ride surface steeper than maxStickAngle within distance
  SkateController.knockedDown: boolean     -- each step: the character's KnockedDown attribute; locks the input and
                                           -- releases the attach
  SkateController.frozen: boolean          -- each step: the root is anchored (the kickoff freeze)
  -- ActionController
  ActionController.runner: ActionRunner.Runner
  ActionController:pose(): Config.PoseName  -- the running action's pose in its windup or active phase, else "None"
  ActionController:step(dt: number)
  -- deps.Camera, deps.SendRequest and deps.LocalId replace the live game in tests; the skater, its frozen and
  -- knocked-down state come from SkateController
  -- PoseController: input.lunging = local: ActionController:pose() == "Lunge";
  --   others: Config.Actions[attribute Action].pose == "Lunge"; input.knockedDown from the KnockedDown attribute
  ```
- **What a step does:**
  - With no skater, or a frozen root: spend the action keys and `runner:reset()`.
  - Otherwise: `runner:step(dt)`, then read the keys and pick at most one action, in order:
    - **Tackle key:** with the ball → `Dodge`; during the tackle's `Active` → `Dive`; otherwise → `Tackle`.
    - **Uppercut key:** `Uppercut`.
    - **Pass key:** with the ball → `Pass`; otherwise → `CallPass`.
    - **Throw key:** while held with the ball, the charge time grows; on release, if the ball is still held → `ChargeThrow` with `charge = held / chargeMaxSeconds`. Losing the ball clears the charge.
- **On `"Started"`,** first the push (decision 3), then the request.
  - **The push:**
    - lunge: `skater.forward × lungeSpeed`;
    - dodge: the stick's direction × `sideSpeed`, or the skater's right with no stick;
    - uppercut: `+Y × wallLeapImpulse` with launch, only when `wallAhead(wallLeapDistance)`;
    - × `airMultiplier` in the air.
  - **The request:** `aim` = the camera's look for Pass and ChargeThrow; `charge` for ChargeThrow.
- **`ActionRejected`** for the running or last action → `runner:cancel(true)`.

- [ ] **Step 1: Write the failing tests**
  - `BallCarrier.spec`: `remembers who carries the ball` (`set("A")` → `carrier == "A"`; `set(nil)` → nil).
  - `ActionController.spec` (scripted bindings, a recording `SendRequest`, a fake camera, and a real `SkateController` on a rig over the test floor, as its spec does):
    - `tackles: lunges forward and asks the server`: Tackle press → one request `{ action = "Tackle" }`; the skater's speed rose by 40 along its facing.
    - `dodges with the ball, sideways along the stick`: carrier, stick right → request `Dodge`, push along the camera's right × 45.
    - `dives when tackle is pressed again during the tackle`: press, step 0.06 s, press → second request `Dive`; press during recovery → no request.
    - `charges a throw for as long as it is held`: carrier; hold Throw for 0.5 s of steps, release → request `{ action = "ChargeThrow", aim = camera look, charge = 0.5 }` (within 1e-6).
    - `passes with the ball and calls for one without`: → `Pass` with the aim; then `CallPass` without the ball.
    - `leaps off a wall with an uppercut, and only near one`: a wall part tagged `RideSurface` 4 studs ahead → velocity.Y = 110 and mode `Airborne`; without it → no leap, request still sent.
    - `does nothing while knocked down`: `KnockedDown` set on the character → the tackle key sends nothing.
    - `spends the keys and resets the runner while frozen`: root anchored, press Tackle, step, unanchor, step → no request.
    - `cancels a rejected action and refunds its cooldown`: tackle, then `ActionRejected { action = "Tackle" }` → `runner.action == nil` and a new tackle is sent at once.
    - `steps in under 0.1 ms`: 600 steps with keys idle and held, mean < 0.1 ms.
  - `SkateController.spec`: `locks a knocked-down skater's input` (attribute set, stick held → no steer, speed falls by `knockdownDecel`).
  - `PoseController.spec`: `poses another skater's lunge and knockdown from their attributes` (`Action = "Tackle"` → root pitched forward; `KnockedDown = true` → tipped back).
- [ ] **Step 2:** Run `testPathPattern = "(BallCarrier|ActionController|SkateController|PoseController)"`. Expected: FAIL.
- [ ] **Step 3:** Implement. `PoseController` drops its own `BallCarrier` listener and `setCarrier` and reads `BallCarrier.carrier`. Its tests call `BallCarrier:set`.
- [ ] **Step 4:** Run, then the full suite. Expected: **463 tests** (+13).
- [ ] **Step 5:** Mutation: skip the freeze reset → `spends the keys and resets the runner while frozen` fails. Restore.
- [ ] **Step 6: Playtest** (keys driven by scripted bindings on `SkateControls`, as in Phase 5):
  - the console reads exactly `modules=8` and `modules=5`, with no warnings;
  - a tackle lunges, a held throw then released throws the ball along the camera, and a pass without a teammate flies straight;
  - **screenshots** of the lunge and of a knocked-down rig (a server probe sets `KnockedDown` on the local character), described in the ledger.
- [ ] **Step 7:** Static checks; commit `feat(actions): every client starts actions at once and the server confirms them`.

---

### Task 9: Actions across the match (labels `test`, `actions`)

**Issue:** to be created · **Branch:** `test/<issue>-actions-integration` · **Stacked on:** Task 8

**Files:**
- Modify: `tests/integration/Match.spec.luau` (its setup already builds every server service on the generated arena)

Physics does not run in the Edit DataModel, so these tests place rigs and the ball by hand, as the existing match tests do.

- [ ] **Step 1: Write the tests** (each drives `ActionService:request` and `MatchService:step` over seated rigs):
  - `knocks the carrier down; the ball keeps their momentum and the tackler takes it`:
    - Blue 1 carries, its root moving at 30 studs/s along the straight;
    - Orange 1, facing Blue 1 from 4 studs behind, tackles.
    - Result: `TackleKnockdown`; the ball `Loose` with Blue 1's velocity; with the ball beside Blue 1, Blue 1 does not catch it; moved beside Orange 1, Orange 1 catches it, and `PossessionChanged` and `Steal` fire.
  - `passes to a teammate who called; the passer cannot take it back at once`:
    - Blue 2 calls; Blue 1 passes.
    - With the ball beside Blue 1 inside `rethrowPickupDelay`, nobody catches it.
    - Moved beside Blue 2, Blue 2 carries it; possession is unchanged, so no `Steal`.
- [ ] **Step 2:** Run `testPathPattern = "integration/Match"`. If a test passes at once, it pins wiring already built in Tasks 5–8, as intended for an integration task. Mutate the wiring it exercises (e.g. skip `drop`'s velocity) to prove it, and restore.
- [ ] **Step 3:** Full suite. Expected: **465 tests** (+2).
- [ ] **Step 4: Phase playtest:**
  - console exactly `modules=8` / `modules=5`;
  - scripted keys: tackle, dodge, uppercut off the outer wall, charged throw, pass and call;
  - two-client checks (a real second client) wait for Phase 9's multi-client playtests: note it in the ledger.
- [ ] **Step 5:** Static checks; commit `test(actions): tackles, throws and passes across the match`.

---

## After the tasks

- **The fresh end-of-phase reviewer:** exactly one, a general-purpose agent on `opus`, given the plan, the spec, this Review Focus and the ledger's rulings.
- **The review-fixes issue and PR:** every finding of every severity is fixed test-first in one PR.
- **Merges:** with the owner's OK, in order, with `--merge`. **Retarget each next PR to `main` before deleting the merged branch** (deleting a base branch closes the PR stacked on it). Then the Rojo-safe `main` sync.
- **The phase summary to the owner:**
  - what changed;
  - the numbers: `ActionService.step` and `ActionController.step` against their budgets, and the knockdown slide;
  - every ruling with its cost if wrong;
  - what's next (Phase 7, input and camera).
