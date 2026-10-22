# M1 Phase 5 — Skating Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Players skate. Each player's own computer moves their skater with momentum (spec §7): it pushes off, coasts, pumps downhill, brakes, tiptoes, jumps, rides the walls, drafts and attaches behind teammates. The skater hovers over the arena's surface on one fixed collider. Every computer poses every character, and the server returns anyone who moves faster than skating allows.

**Architecture:**
- **Pure modules** in `src/shared/Skate/` hold every rule, and are unit-tested with the exact numbers of spec §7.2:
  - `SkateMath`: momentum, steering, modes;
  - `NormalFilter`: ground normals;
  - `Draft` and `Attach`;
  - `Pose`: joint angles;
  - `MovementCheck`: the guard's verdicts.
- **The server builds the skater body** (`SkaterBody`, used by `CharacterService`). It gets a collider, collision groups, and the velocity and orientation constraints, and the default animations are removed. The server also shares each skater's pump and brake (`SkateState` remote) and runs `MovementGuard`.
- **Three client controllers:**
  - `InputController` builds an Input Action System context from `Config.Input`.
  - `SkateController` raycasts, filters, steps `SkateMath` and writes the constraints in `PreSimulation`.
  - `PoseController` writes every character's joint `Transform`s.

**Tech Stack:** Luau (`--!strict`), Jest-Lua 3.10.0 in Studio through the Roblox Studio MCP, Rojo 7.7.1, StyLua 2.6.0, selene 0.32.0, luau-lsp 1.70.1 (`bash scripts/analyze.sh`).

**Spec:** `docs/superpowers/specs/2026-10-21-m1-foundation-core-match-design.md`:
- §3.3 (authority), §7 (skating), §8.3 (the skating keys), §9.3 (who catches);
- §10.2–10.3 (remotes, movement guard), §12.2 (budgets), §13 (remotes never trusted), §14 (phase 5).

Constraints from Phase 4 are in the PR bodies of #67–#71:
- the carried ball welded at `Config.Ball.carryOffset`;
- `CharacterService:holders()`;
- the kickoff freeze by root anchoring.

## Verified facts this plan relies on (probed in Studio and read in the Roblox docs, 2026-10-22)

**The avatar rig**
- **Joints:** avatars use the **Avatar Joint Upgrade**. Joints are `AnimationConstraint`s (`IsKinematic = true`) plus `BallSocketConstraint`s, not `Motor6D`s.
  - The R15 names are kept: `Root` (in `LowerTorso`, `Attachment0` in `HumanoidRootPart`), `Waist`, `RightShoulder`, `LeftHip`, `RightHip`, `LeftKnee`, `RightKnee`.
  - Both `AnimationConstraint` and `Motor6D` have a `Transform` (CFrame) that scripts set in `RunService.PreSimulation`.
  - `StarterPlayer.AvatarJointUpgrade` cannot be read by scripts.
- **Poses stay local.** A `Transform` set on a client stays on that client (the server read 2.3° while the client held 90°). So every client poses every character. A script destroyed on a client is not destroyed on the server.
- **Default animations:** if the server destroys the character's `Animate` LocalScript right after `LoadCharacterAsync` returns, the client never plays the default animations (0 playing tracks).

**Turning off Roblox's own movement**
- **On the server, it breaks deaths.** `Humanoid.EvaluateStateMachine = false` on the server stops `Health = 0` from reaching `Dead`: `Died` never fires and the character never respawns.
- **On the owning client, it works.** There it stops the humanoid's forces, and the change does not replicate. The server's humanoid still dies, fires `Died` and respawns. That held for `Health = 0` and for a fall below `FallenPartsDestroyHeight`: the server saw the root destroyed and `Died` 0.01 s later.

**Constraints and physics**
- **Driving a client-owned root works.** A `LinearVelocity` (Vector mode, World, `ForceLimitsEnabled = false`) and an `AlignOrientation` (OneAttachment, `RigidityEnabled = true`) on one root attachment moved the root 9.94 studs in 1 s at 10 studs/s. It faced the goal exactly.
- **Defaults to override:** `LinearVelocity` defaults to `ForceLimitsEnabled = true` with `MaxForce = 1000`; `AlignOrientation` to `Responsiveness = 10` and `MaxTorque = 10000`.
- **Orientation without allocating:** in OneAttachment mode, `PrimaryAxis` (the goal's X, right) and `SecondaryAxis` (its Y, up) orient a real body; probed facing +X with +Y up.
- **What replicates:**
  - A client-driven root's linear velocity reaches the server exactly: 12 studs/s.
  - Under a rigid `AlignOrientation`, `AssemblyAngularVelocity` reads about 0, so lean cannot come from it.
  - A server `PivotTo` on a client-owned character reaches the owning client.
- **Collision groups:** groups registered by the server at runtime (`PhysicsService:RegisterCollisionGroup`, `CollisionGroupSetCollidable`) reach clients and govern the physics of client-owned parts. The limit is 32 groups.
  - Registering at runtime in the Edit DataModel would persist in the place file, so tests use a fake `PhysicsService`.
- **Ownership after the freeze:** after anchoring and then unanchoring a root, automatic ownership returns to the player in the same frame. `GetNetworkOwner` errors while a part is anchored (Phase 4 playtest).

**Input (the Input Action System)**
- **Roblox's own controls:** the `PlayerModule` now lives at `StarterPlayer.PlayerModule`, not in `PlayerScripts`. Its controls run on the Input Action System: `InputContext` → `InputAction` → `InputBinding`.
  - The default `CharacterContext` (priority 150) binds `MoveAction` (`Direction2D`: WASD composite, `Thumbstick1`) and `JumpAction` (Space, ButtonA).
  - It also binds 11 `AbilityAction`s, including LeftShift/ButtonL1, LeftControl/ButtonB, F, R, Q and the mouse buttons.
- **Our own context:**
  - A client can create one at runtime. One with a higher `Priority` and `Sink = true` blocks the defaults on its keys: with ours holding LeftShift, the default `AbilityAction2` read false.
  - `Direction2D` `GetState()` is a `Vector2`, x right and y forward; W+D gave (0.707, 0.707).
  - `Pressed` fires only for Bool actions.
  - `Scriptable` bindings take `InputBinding:Fire(state)`, and that works **in the Edit DataModel**, so input is unit-testable. `Pressed` fires after a yield.

**The arena and the earlier phases**
- Every arena part is a slab behind the riding surface. A downward ray exactly on a seam of the step returned the side-face normal (0, 0.49, −0.87), 60.6° from up (Phase 3, spec §7.1).
- The arena model is `ModelStreamingMode.Persistent`, with folders `Surface`, `Infield`, `Gates`, `Goal`, `Markers` and `Spawns`.
- Roblox events are deferred in this place. In Edit, physics does not simulate, but `Heartbeat` fires and `AssemblyLinearVelocity` can be set.

## Owner decisions (2026-10-22)

1. **A carried ball scores through the ring as well as a thrown one.** Spec §4.3 stands, with no rule change.
2. **Skaters pass through each other.** Colliders touch the arena, not other skaters. Hitting players is what tackles are for (Phase 6).
3. **A little air steering:** `Movement.airTurnRate = 1` rad/s.
4. **The skating keys come now; the rest in Phase 7.** Phase 5 adds `Config.Input` with move, Jump, Pump, Brake/Tiptoe and Attach, for keyboard and gamepad. Phase 7 adds the action keys, mobile buttons, on-screen hints and the camera.
5. **Players see each other's actions.** Each client tells the server when its pump or brake changes. The server shows it on the character, and every client poses it.

## Global Constraints

- **Earlier constraints still apply.** Everything in the Phase 1–4 Global Constraints holds:
  - `--!strict` first line;
  - StyLua, selene and `bash scripts/analyze.sh` clean;
  - relative requires in `src/`, service-path requires in tests;
  - `JestGlobals` only, no `jest.fn()`;
  - annotate locals strict mode can't infer;
  - lines at most 120 columns, comments included.
- **Pure modules** never touch an Instance, a service or `workspace`: `src/shared/{Skate,Net/RateLimiter,Net/Schemas,Config}`. The one exception is `Skate/SkaterRig`, which only names things.
- **No gameplay literals.** Every number comes from `Config.Movement`, `Config.Pose`, `Config.Input` or `Config.Network`.
- **Names are spelled once:**
  - remote names in `Net/Remotes`;
  - character attributes in `Net/Attributes`;
  - body part, constraint, collision group and joint names in `Skate/SkaterRig`;
  - tags in `Arena/Tags`.
- **Services and controllers are `Loader` modules with an explicit exported type.**
  - `init(deps)` touches no global Roblox state, though it may build instances under a `deps.Parent`.
  - `start()` holds every global effect: `RunService` events, `Players` events, `PhysicsService`.
  - Tests inject fakes through `deps` and call `step(dt)` by hand.
- **The server never turns off the humanoid's state machine** (verified: deaths need it). Only `SkateController`, on the owning client, does.
- **Budgets** (spec §12.2):
  - the client `SkateController` step must stay under 0.5 ms, measured in its test;
  - the server match frame must stay under 1 ms with 6 players.
  - No per-frame allocations on hot paths. `SkateMath` mutates one record. Orientation goes through `PrimaryAxis`/`SecondaryAxis`. The input, ground and source records are reused.
  - The only per-frame allocations are the pose `Transform`s: one CFrame per posed joint per frame, which the engine requires. Task 10 times them: posing six skaters must take under 0.3 ms a frame (decision 16).
- **Tests:**
  - Instances live under a uniquely named `…Test` folder and are removed in `afterEach`/`afterAll`.
  - Compare names or booleans, never an Instance that might fail.
  - Yield once before asserting on a Roblox event (`Pressed`, `Destroying`).
  - A shared helper goes in `tests/Fixtures.luau`, never into two specs.
- **Process:** branches, commits and PRs follow `CONTRIBUTING.md`. Every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, and every PR body with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## How tests run

The same as Phase 4: `rojo serve test.project.json` stays running and connected, and tests run through the Roblox Studio MCP `execute_luau` (`datamodel_type = "Edit"`):

```lua
task.wait(1)
local s = require(game:GetService("ServerStorage").RunTests:Clone())({ testPathPattern = "<pattern>" })
return { success = s.success, passed = s.numPassedTests, total = s.numTotalTests, firstFailure = s.failureMessages[1] }
```

- The suite has **299 tests** before this phase.
- Each task states its new tests and the new total. A different total is a finding: work out which number is right, rule on it and record the ruling.
- After this phase the playtest console must read exactly `[BloxChampions] Server ready: mode=NormalChampions, modules=7` and `[BloxChampions] Client ready: mode=NormalChampions, modules=3`.

## Review Focus

1. **A seam's side face turning the skater.** One ray on a seam can return a slab's side face, 60.6° off. Used as the up vector, it would flip the skater's orientation and wall-riding check for a frame.
   - Task 3: `ignores a lone normal that turns sharply, such as a seam's side face`.
   - Task 9: `keeps the skater's up steady across a seam of the generated arena`.
2. **The kickoff freeze.**
   - A root anchored for the countdown must not build up speed and launch when released. Task 9: `holds still while the root is anchored, then starts from rest`.
   - The guard must not punish the server's own jumps: a frozen root, a kickoff placement or a respawn. Task 11: `leaves frozen skaters alone and trusts the server's placements`.
3. **A respawn.**
   - The new character (a new Model) must be driven, not the old one. Task 9: `drives a new character after a respawn`.
   - Deaths must still register. Task 6: `gives every loaded character a skater body and no default animations` asserts the server leaves `EvaluateStateMachine` on.
4. **A client that lies or floods.** A malformed or too-frequent `SkateState` message must be dropped and counted, never applied. Task 7: `drops malformed and too-frequent messages and counts them per player`.
5. **Leaving the surface.** Running off the top of a wall or out of the arena must make the skater fall, never hover in mid-air. The guard must not mistake a fall for cheating.
   - Task 2: `leaves the ground when the ray finds nothing, and falls`.
   - Task 9: `falls when no riding surface is below`.
   - Task 11: `never counts falling`.

## Decisions not spelled out in the spec (for owner review)

1. **Roblox's own movement is turned off only on the owning client** (`EvaluateStateMachine = false`). The server keeps it on, so deaths, `Died` and respawns work (verified).
2. **The kickoff freeze stays root anchoring.** Phase 4's decision 3 planned to replace it, but anchoring is server-authoritative, and ownership comes back in the same frame (verified). `SkateController` idles while its root is anchored and starts from rest afterwards.
3. **The server builds the skater body** (`SkaterBody.build`, run by `CharacterService` when a character loads):
   - it destroys `Animate`;
   - it puts every avatar part in the `SkaterBody` group, which collides with nothing;
   - it adds `SkateCollider`, a Ball part of `Movement.colliderDiameter`, welded to the root's centre: invisible, not queryable, no touch events, in the `SkaterCollider` group, which collides with the arena (`Default`) but not with other skaters (owner decision 2);
   - it adds one root `SkateAttachment` carrying `SkateVelocity` (a `LinearVelocity`) and `SkateAlign` (a rigid `AlignOrientation`).

   The ball (`Default`) still bounces off colliders.
4. **Hover replaces standing height.**
   - Spawns place the root at `Movement.hoverHeight` above the pad, the same for every avatar.
   - Each avatar's feet meet the floor through a pose offset: the root joint is lifted by `standingHeight − hoverHeight`. `standingHeight` moves from `CharacterService` to `PoseController`.
5. **New `Config.Movement` values the spec doesn't give:**
   - `hoverSpring = 15` /s
   - `strideAccel = 30` studs/s², the push toward `cruiseSpeed` with the stick held
   - `airTurnRate = 1` rad/s (owner decision 3)
   - `airUprightRate = 6` rad/s
   - `pumpFlatSlopeDeg = 3`
   - `normalFilter = { maxTurnDeg = 30, smoothing = 30 }`
   - `attachSpring = 10` /s
   - `colliderDiameter = 2`: the spec's `colliderSize = (2, 2, 2)` sphere becomes one number, because a Ball part must have a uniform size.
6. **The skating formulas** (each pinned by a Task 1 or 2 test):
   - **Momentum:** gravity counts only along the surface (`g − (g·n)n`). Drag is linear: speed loses `(rollingFriction + airDrag × speed) × dt`.
   - **Stride:** `strideAccel × stick × max(0, cos(stick, heading))`, only below `cruiseSpeed` and not while braking.
   - **Soft cap:** above `softCap`, the forward part of the acceleration is scaled by `(hardCap − speed)/(hardCap − softCap)`. The hard cap clamps last.
   - **Steering:** the turn rate goes from `turnRateLow` at 0 to `turnRateHigh` at `hardCap`. From rest the skater faces the stick at once.
   - **Pump:** `max(pumpFlatAccel, 0.6 × downhill pull)` downhill, `pumpFlatAccel` within ±`pumpFlatSlopeDeg` of flat, 0 uphill.
   - **Brake and tiptoe:** brake removes `brakeDecel × dt` down to 0. With the stick held, it brakes down to `tiptoeSpeed × stick`, then moves exactly at that speed in the stick's direction.
   - **Jump:** adds `jumpImpulse` along the surface normal, and the same step runs as airborne.
   - **Landing:** happens only within `hoverHeight` of the surface while moving toward it.
   - **Wall detach:** on a surface steeper than `maxStickAngle` with tangential speed below `minWallSpeed`.
   - **Hover:** the normal velocity is `(hoverHeight − distance) × hoverSpring`.
   - **In the air:** only horizontal steering, and `up` turns toward world up at `airUprightRate`.
7. **Arrives with its user:** `speedometerScale` with the HUD (Phase 8); the `KnockedDown` mode with tackles (Phase 6).
8. **`Config.Input`** runs on the Input Action System. One context (`SkateControls`, `Priority = 1000`, `Sink = true`) sits above Roblox's `CharacterContext` (150). The bindings are spec §8.3's:
   - move: WASD and the left stick;
   - Jump: Space / ButtonA;
   - Pump: LeftShift / ButtonR2;
   - Brake: LeftControl / ButtonR1;
   - Attach: F / ButtonL1.

   Roblox's remaining default actions and §8.5's defaults are Phase 7's, and so is the camera, which stays Roblox's default until then.
9. **Pump and brake are shared** (owner decision 5) through a `SkateState` remote (client → server, `{ pump, brake }`).
   - It is sent only when one changes.
   - It is validated by `Net/Schemas` and rate-limited by `Net/RateLimiter` (`Network.maxSkateStatesPerSecond = 20`). Phase 6's `ActionRequest` reuses the same machinery.
   - The server sets the character attributes `Pumping` and `Braking` for seated players only.
10. **Poses:** each client poses every character from what it sees.
    - Lean comes from the turn of the replicated velocity, smoothed by `Pose.leanSmoothing`.
    - The air tuck comes from a ray along the character's own up. Its length is `hoverHeight + Pose.airborneProbe`, on ride surfaces only.
    - The crouch and brake lean come from the local `SkateController` for your own character and from the attributes for others.
    - The raised arm comes from `BallCarrier`.
    - Joints are found by name for the rig type (R15 or R6) and written through `Transform`.
    - All pose numbers live in a new `Config.Pose` area.
11. **`MovementGuard`:**
    - Downward movement never counts, because falling is legal.
    - One sample beyond `guardTeleportFactor` × the allowed distance returns the skater at once.
    - A return keeps the character's orientation and is logged with `warn` (`deps.Log` in tests).
    - Anchored roots are re-based, never judged.
    - Every server placement re-bases (a new `CharacterService.placed` signal).
12. **Attach:**
    - Candidates are seated teammates (the replicated `Team` attribute).
    - The cone and the follow point use the leader's facing (`root.CFrame.LookVector`, set by their own `SkateAlign`).
    - The follow velocity is `leader velocity + attachSpring × (target − position)`.
    - A release adds `attachBoostSpeed` along the leader's facing (hard-capped) and starts `attachCooldown`.
    - Still holding Attach re-attaches once the cooldown ends.
13. **Draft:**
    - It comes from any other skater, teammate or opponent, through the cone around the direction opposite their velocity.
    - The strongest source wins, and it applies only on the ground.
14. **`SkateMath` mutates one record in place** (`skater:step(...)`) rather than returning a new state, so a step allocates nothing.
15. **Skate rays hit only tagged ride surfaces** (`Tags.RideSurface` on the arena's `Surface` and `Infield` folders), never gates, markers, the goal, characters or the ball.
16. **A pose budget the spec doesn't set:** posing six skaters must take under 0.3 ms a frame. With `SkateController`'s 0.5 ms, the client's skating work stays under 1 ms.

**Not in this phase:**
- **Phase 6:** knockdowns, tackles and every action, including the tackle-lunge and knockdown-tilt poses of spec §7.1; knocked-down players can't catch.
- **Phase 7:** the custom camera and Ball Focus, mobile buttons, on-screen hints, and Roblox's remaining default actions and §8.5's defaults.
- **Phase 8:** the speedometer.
- **Phase 9:** tuning the feel and the lap time.

---

### Task 1: Movement config and skating on the ground

**Issue:** #72 · **Branch:** `feat/72-skate-ground` · **Labels:** `feature`, `skate`

**Files:**
- Create: `src/shared/Config/Movement.luau`, `src/shared/Skate/Types.luau`, `src/shared/Skate/SkateMath.luau`
- Modify: `src/shared/Config/init.luau` (area `Movement`), `tests/Fixtures.luau` (`expectNear`), `tests/server/CharacterService.spec.luau` (its local `near` becomes `Fixtures.expectNear`)
- Test: `tests/shared/Config/Config.spec.luau`, `tests/shared/Skate/SkateMath.spec.luau`

**Interfaces:**
- Consumes: `Validate`, `PartSize`, `Config` area pattern, `Fixtures.GRAVITY`.
- Produces:
  ```lua
  export type MovementConfig = {
  	colliderDiameter: number, hoverHeight: number, hoverSpring: number, groundProbeLength: number,
  	strideAccel: number, rollingFriction: number, airDrag: number,
  	cruiseSpeed: number, softCap: number, hardCap: number,
  	turnRateLow: number, turnRateHigh: number, airTurnRate: number, airUprightRate: number,
  	minWallSpeed: number, maxStickAngle: number,
  	pumpSlopeMultiplier: number, pumpFlatAccel: number, pumpFlatSlopeDeg: number,
  	brakeDecel: number, tiptoeSpeed: number, jumpImpulse: number,
  	normalFilter: { maxTurnDeg: number, smoothing: number },
  	draftRange: number, draftConeDeg: number, draftMaxAccel: number,
  	attachRange: number, attachConeDeg: number, attachFollowDistance: number, attachSpring: number,
  	attachMaxSeconds: number, attachBoostSpeed: number, attachCooldown: number,
  }
  -- Skate/Types
  export type Mode = "Grounded" | "Airborne" | "Attached"
  export type SkateInput = { move: Vector3, pump: boolean, brake: boolean, jump: boolean, draftAccel: number }
  export type Ground = { hit: boolean, normal: Vector3, distance: number }
  -- Skate/SkateMath (class idiom)
  SkateMath.new(movement: Config.MovementConfig, gravity: Vector3): Skater
  -- Skater fields: velocity: Vector3, mode: Types.Mode, up: Vector3, forward: Vector3
  SkateMath.step(self: Skater, input: Types.SkateInput, ground: Types.Ground, dt: number)
  -- Fixtures
  Fixtures.expectNear(actual: Vector3, expected: Vector3, tolerance: number?)  -- default 1e-3
  ```
- **Defaults:**
  - `colliderDiameter = 2`, `hoverHeight = 2.5`, `hoverSpring = 15`, `groundProbeLength = 6`
  - `strideAccel = 30`, `rollingFriction = 4`, `airDrag = 0.02`
  - `cruiseSpeed = 60`, `softCap = 90`, `hardCap = 140`
  - `turnRateLow = 4.0`, `turnRateHigh = 1.5`, `airTurnRate = 1`, `airUprightRate = 6`
  - `minWallSpeed = 35`, `maxStickAngle = 60`
  - `pumpSlopeMultiplier = 1.6`, `pumpFlatAccel = 8`, `pumpFlatSlopeDeg = 3`
  - `brakeDecel = 120`, `tiptoeSpeed = 12`, `jumpImpulse = 60`
  - `normalFilter = { maxTurnDeg = 30, smoothing = 30 }`
  - `draftRange = 18`, `draftConeDeg = 30`, `draftMaxAccel = 20`
  - `attachRange = 8`, `attachConeDeg = 45`, `attachFollowDistance = 4`, `attachSpring = 10`, `attachMaxSeconds = 3`, `attachBoostSpeed = 40`, `attachCooldown = 3`
- **Field rules:**
  - Above 0: `colliderDiameter` (at most `PartSize.MAX`), `hoverHeight`, `hoverSpring`, `groundProbeLength`, `cruiseSpeed`, `softCap`, `hardCap`, `airUprightRate`, `brakeDecel`, `normalFilter.smoothing`, `draftRange`, `attachRange`, `attachMaxSeconds`.
  - At least 0: everything else.
  - Angles: `maxStickAngle` and the cone angles in (0, 180], `normalFilter.maxTurnDeg` in (0, 180], `pumpFlatSlopeDeg` in [0, 90).
  - `pumpSlopeMultiplier` is at least 1.
- **Cross-field rules** (`Validate.checkAll`, in this order, path `Movement`):
  1. `"speeds must rise: cruiseSpeed <= softCap < hardCap"`
  2. `"turnRateHigh must not exceed turnRateLow"`
  3. `"groundProbeLength must reach past hoverHeight"`
  4. `"tiptoeSpeed must not exceed cruiseSpeed"`
  5. `"the collider must clear the ground: colliderDiameter / 2 < hoverHeight"`

- [ ] **Step 1: Write the failing tests**

Append to `describe("Config defaults", …)` and `describe("Config.forMode", …)`:

```lua
	it("match the spec's skating values, plus this phase's", function()
		expect(Config.defaults().Movement).toEqual({
			colliderDiameter = 2, hoverHeight = 2.5, hoverSpring = 15, groundProbeLength = 6,
			strideAccel = 30, rollingFriction = 4, airDrag = 0.02,
			cruiseSpeed = 60, softCap = 90, hardCap = 140,
			turnRateLow = 4.0, turnRateHigh = 1.5, airTurnRate = 1, airUprightRate = 6,
			minWallSpeed = 35, maxStickAngle = 60,
			pumpSlopeMultiplier = 1.6, pumpFlatAccel = 8, pumpFlatSlopeDeg = 3,
			brakeDecel = 120, tiptoeSpeed = 12, jumpImpulse = 60,
			normalFilter = { maxTurnDeg = 30, smoothing = 30 },
			draftRange = 18, draftConeDeg = 30, draftMaxAccel = 20,
			attachRange = 8, attachConeDeg = 45, attachFollowDistance = 4, attachSpring = 10,
			attachMaxSeconds = 3, attachBoostSpeed = 40, attachCooldown = 3,
		})
	end)
```

```lua
	it("rejects skating speeds, turn rates and sizes that contradict each other", function()
		local cases: { { overrides: { [string]: any }, message: string } } = {
			{ overrides = { Movement = { softCap = 150 } }, message = "Movement: speeds must rise: cruiseSpeed <= softCap < hardCap" },
			{ overrides = { Movement = { turnRateHigh = 5 } }, message = "Movement: turnRateHigh must not exceed turnRateLow" },
			{ overrides = { Movement = { groundProbeLength = 2 } }, message = "Movement: groundProbeLength must reach past hoverHeight" },
			{ overrides = { Movement = { tiptoeSpeed = 70 } }, message = "Movement: tiptoeSpeed must not exceed cruiseSpeed" },
			{
				overrides = { Movement = { colliderDiameter = 6 } },
				message = "Movement: the collider must clear the ground: colliderDiameter / 2 < hoverHeight",
			},
			{ overrides = { Movement = { pumpSlopeMultiplier = 0.5 } }, message = "Movement.pumpSlopeMultiplier: must be >= 1 (got 0.5)" },
		}
		for _, case in cases do
			expect(function()
				Fixtures.config(case.overrides)
			end).toThrow(case.message)
		end
	end)
```

`tests/shared/Skate/SkateMath.spec.luau`. Expected values were derived from a reference model of the formulas in decision 6, and each can be checked by hand from the comment beside it:

```lua
local movement = Config.defaults().Movement
local FLAT = Vector3.yAxis
-- A 30° surface falling toward -Z, and the way down it.
local SLOPE = Vector3.new(0, math.cos(math.rad(30)), -math.sin(math.rad(30)))
local DOWNHILL = Vector3.new(0, -0.5, -math.cos(math.rad(30)))

local function input(overrides: { [string]: any }?): Types.SkateInput
	local record: Types.SkateInput = { move = Vector3.zero, pump = false, brake = false, jump = false, draftAccel = 0 }
	for key, value in overrides or {} do
		(record :: any)[key] = value
	end
	return record
end

local function ground(normal: Vector3?, distance: number?, hit: boolean?): Types.Ground
	return { hit = if hit == nil then true else hit, normal = normal or FLAT, distance = distance or movement.hoverHeight }
end

local function skater(velocity: Vector3): SkateMath.Skater
	local s = SkateMath.new(movement, Fixtures.GRAVITY)
	s.velocity = velocity
	return s
end

describe("SkateMath on the ground", function()
	it("pushes off toward the stick and rolls against friction and drag", function()
		local s = skater(Vector3.zero)
		s:step(input({ move = -Vector3.zAxis }), ground(), 0.1)
		-- 30 × 0.1 = 3, then 3 − (4 + 0.02 × 3) × 0.1
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -2.594))
		expect(s.mode).toBe("Grounded")
	end)

	it("coasts without input, slowed by rolling friction and air drag", function()
		local s = skater(Vector3.new(0, 0, -60))
		s:step(input(), ground(), 0.1)
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -59.48)) -- 60 − (4 + 1.2) × 0.1
	end)

	it("strides only up to cruiseSpeed and settles there", function()
		local forward = input({ move = -Vector3.zAxis })
		local atCruise = skater(Vector3.new(0, 0, -60))
		atCruise:step(forward, ground(), 0.1)
		Fixtures.expectNear(atCruise.velocity, Vector3.new(0, 0, -59.48)) -- no push at cruiseSpeed: it coasts
		local s = skater(Vector3.zero)
		for _ = 1, 600 do
			s:step(forward, ground(), 1 / 60)
		end
		for _ = 1, 120 do
			s:step(forward, ground(), 1 / 60)
			expect(s.velocity.Magnitude > 59.5 and s.velocity.Magnitude < 60.5).toBe(true) -- model: 59.91..60.41
		end
	end)

	it("speeds up downhill by gravity's pull along the surface", function()
		local s = skater(DOWNHILL * 10)
		s:step(input(), ground(SLOPE), 0.1)
		Fixtures.expectNear(s.velocity, DOWNHILL * 19.3704) -- + 196.2 × sin 30° × 0.1, then friction and drag
	end)

	it("scales speeding up down between softCap and hardCap, and never exceeds hardCap", function()
		local s = skater(DOWNHILL * 115)
		s:step(input(), ground(SLOPE), 0.01)
		expect(s.velocity.Magnitude).toBeCloseTo(115.4274, 3) -- 98.1 × (140 − 115)/(140 − 90) = 49.05 studs/s²
		local fast = skater(Vector3.new(0, 0, -150))
		fast:step(input(), ground(), 0.1)
		Fixtures.expectNear(fast.velocity, Vector3.new(0, 0, -140))
	end)

	it("turns toward the stick at a rate that shrinks with speed", function()
		local function turned(speed: number): number
			local s = skater(Vector3.new(0, 0, -speed))
			s:step(input({ move = Vector3.xAxis }), ground(), 0.1)
			return math.atan2(s.velocity.X, -s.velocity.Z)
		end
		expect(turned(70)).toBeCloseTo(0.275, 4) -- lerp(4.0, 1.5, 70/140) × 0.1
		expect(turned(140)).toBeCloseTo(0.15, 4)
		local still = skater(Vector3.zero)
		still:step(input({ move = Vector3.xAxis }), ground(), 0.1)
		Fixtures.expectNear(still.velocity, Vector3.new(2.594, 0, 0)) -- from rest it faces the stick at once
	end)

	it("brakes to a stop without reversing", function()
		local s = skater(Vector3.new(0, 0, -60))
		s:step(input({ brake = true }), ground(), 0.1)
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -47.48)) -- 59.48 − 120 × 0.1
		local slow = skater(Vector3.new(0, 0, -5))
		slow:step(input({ brake = true }), ground(), 0.1)
		Fixtures.expectNear(slow.velocity, Vector3.zero)
	end)

	it("tiptoes: braking with the stick held moves exactly at up to tiptoeSpeed", function()
		local s = skater(Vector3.new(0, 0, -60))
		for _ = 1, 60 do
			s:step(input({ brake = true, move = Vector3.xAxis }), ground(), 1 / 60)
		end
		Fixtures.expectNear(s.velocity, Vector3.new(12, 0, 0))
		local still = skater(Vector3.zero)
		still:step(input({ brake = true, move = Vector3.new(0, 0, -0.5) }), ground(), 0.1)
		Fixtures.expectNear(still.velocity, Vector3.new(0, 0, -6)) -- tiptoeSpeed × half the stick
	end)

	it("pumps: more pull downhill, a small push on the flat, nothing uphill", function()
		local downhill = skater(DOWNHILL * 10)
		downhill:step(input({ pump = true }), ground(SLOPE), 0.1)
		expect(downhill.velocity.Magnitude).toBeCloseTo(25.2446, 3) -- pull × 1.6 (19.3704 without)
		local flat = skater(Vector3.new(0, 0, -30))
		flat:step(input({ pump = true }), ground(), 0.1)
		Fixtures.expectNear(flat.velocity, Vector3.new(0, 0, -30.3384)) -- + pumpFlatAccel 8
		local pumping, coasting = skater(DOWNHILL * -30), skater(DOWNHILL * -30)
		pumping:step(input({ pump = true }), ground(SLOPE), 0.1)
		coasting:step(input(), ground(SLOPE), 0.1)
		Fixtures.expectNear(pumping.velocity, coasting.velocity) -- both (0, 9.8748, 17.1037)
	end)

	it("adds the draft's pull along the way it travels", function()
		local s = skater(Vector3.new(0, 0, -30))
		s:step(input({ draftAccel = 10 }), ground(), 0.1)
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -30.538))
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail**

Run `testPathPattern = "(Config|SkateMath)"`. Expected: the Movement defaults test fails (`Movement` is nil), the cases test throws nothing, and `SkateMath.spec` fails to require `Shared.Skate.SkateMath`.

- [ ] **Step 3: Implement `Config/Movement.luau`, register it in `Config/init.luau`, add `Fixtures.expectNear`**

`Fixtures.expectNear` asserts `(actual − expected).Magnitude < (tolerance or 1e-3)` through `JestGlobals.expect`. `CharacterService.spec`'s local `near` is deleted in favour of it.

- [ ] **Step 4: Implement `Skate/Types.luau` and `Skate/SkateMath.luau`, the grounded step only**

- `SkateMath.new` sets `velocity = Vector3.zero`, `mode = "Grounded"`, `up = −gravity.Unit`, `forward = −Vector3.zAxis`.
- `step` resolves the mode first, then runs that mode's physics. Grounded leaves `Grounded` only through Task 2's rules; until then, an airborne skater is unreachable.
- The grounded physics follows decision 6, in this order:
  1. project the velocity onto the surface;
  2. steer;
  3. sum the accelerations (gravity's tangential part, pump, stride, `draftAccel`, all along the heading) and apply the soft cap;
  4. integrate;
  5. apply friction and drag;
  6. brake or tiptoe;
  7. clamp to the hard cap;
  8. add the hover's normal velocity;
  9. set `up = n`, and `forward` to the travel direction (kept while stopped).

Vectors are Luau value types, so the step allocates nothing.

- [ ] **Step 5: Run the tests to verify they pass, then the full suite**

Run `testPathPattern = "(Config|SkateMath)"`, then the full suite. Expected: all green, **311 tests** (299 + 12).

- [ ] **Step 6: Static checks and commit**

```bash
stylua src tests scripts && stylua --check src tests scripts && selene src tests scripts && bash scripts/analyze.sh \
  && mkdir -p build && rojo build default.project.json --output build/game.rbxl && rojo build test.project.json --output build/test.rbxl && echo CHECKS OK
git add src/shared/Config src/shared/Skate tests && git commit -m "feat(skate): movement config and skating on the ground"
```

---

### Task 2: Hovering, the air, landing, jumping and wall riding

**Issue:** #73 · **Branch:** `feat/73-skate-air` · **Labels:** `feature`, `skate`

**Files:**
- Modify: `src/shared/Skate/SkateMath.luau`
- Test: `tests/shared/Skate/SkateMath.spec.luau`

**Interfaces:**
- Consumes: Task 1.
- Produces: `SkateMath.stop(self: Skater)`. It sets the velocity to zero and the mode to `Grounded` (freezes and respawns).
- **Mode rules** (resolved before the physics):
  - **Grounded → Airborne** when one of these holds:
    - the ray found nothing;
    - `jump` (after adding `normal × jumpImpulse`);
    - the surface is steeper than `maxStickAngle` from world up with tangential speed below `minWallSpeed`.
  - **Airborne → Grounded** when `ground.hit and ground.distance <= hoverHeight and velocity:Dot(normal) <= 0`.
- **Air physics:**
  1. steer the horizontal heading toward the stick's horizontal part by at most `airTurnRate × dt`;
  2. add `gravity × dt`;
  3. drag: speed loses `airDrag × speed × dt`;
  4. clamp to the hard cap;
  5. `up` turns toward world up by at most `airUprightRate × dt`, and `forward` becomes the horizontal travel direction.

- [ ] **Step 1: Write the failing tests** (a second `describe` in the same spec, reusing its helpers)

```lua
describe("SkateMath off the ground and on walls", function()
	it("holds the root at hoverHeight above the ground", function()
		local high = skater(Vector3.zero)
		high:step(input(), ground(FLAT, 3), 0.1)
		Fixtures.expectNear(high.velocity, Vector3.new(0, -7.5, 0)) -- (2.5 − 3) × hoverSpring 15
		local low = skater(Vector3.zero)
		low:step(input(), ground(FLAT, 2), 0.1)
		Fixtures.expectNear(low.velocity, Vector3.new(0, 7.5, 0))
	end)

	it("leaves the ground when the ray finds nothing, and falls", function()
		local s = skater(Vector3.new(0, 0, -30))
		s:step(input(), ground(FLAT, 0, false), 0.1)
		expect(s.mode).toBe("Airborne")
		Fixtures.expectNear(s.velocity, Vector3.new(0, -19.5808, -29.94))
	end)

	it("lands only when near the ground and moving toward it", function()
		local falling = skater(Vector3.new(0, -20, -30))
		falling.mode = "Airborne"
		falling:step(input(), ground(FLAT, 2.4), 0.1)
		expect(falling.mode).toBe("Grounded")
		Fixtures.expectNear(falling.velocity, Vector3.new(0, 1.5, -29.54))
		local rising = skater(Vector3.new(0, 20, -30))
		rising.mode = "Airborne"
		rising:step(input(), ground(FLAT, 2.4), 0.1)
		expect(rising.mode).toBe("Airborne")
		Fixtures.expectNear(rising.velocity, Vector3.new(0, 0.3792, -29.94))
	end)

	it("jumps along the surface's normal, off walls too", function()
		local flat = skater(Vector3.new(0, 0, -30))
		flat:step(input({ jump = true }), ground(), 1 / 60)
		expect(flat.mode).toBe("Airborne")
		Fixtures.expectNear(flat.velocity, Vector3.new(0, 56.7111, -29.99))
		local wall = skater(Vector3.new(0, 0, -50))
		wall:step(input({ jump = true }), ground(Vector3.xAxis), 1 / 60)
		Fixtures.expectNear(wall.velocity, Vector3.new(59.98, -3.2689, -49.9833))
	end)

	it("rides a steep surface only while fast enough", function()
		local function modeOn(degrees: number, speed: number): string
			local s = skater(Vector3.new(0, 0, -speed))
			s:step(input(), ground(Vector3.new(math.sin(math.rad(degrees)), math.cos(math.rad(degrees)), 0)), 0.1)
			return s.mode
		end
		expect(modeOn(70, 30)).toBe("Airborne")
		expect(modeOn(70, 40)).toBe("Grounded")
		expect(modeOn(50, 10)).toBe("Grounded")
	end)

	it("steers a little in the air", function()
		local s = skater(Vector3.new(0, 0, -30))
		s.mode = "Airborne"
		s:step(input({ move = Vector3.xAxis }), ground(FLAT, 0, false), 0.1)
		expect(math.atan2(s.velocity.X, -s.velocity.Z)).toBeCloseTo(0.1, 4) -- airTurnRate × 0.1
		Fixtures.expectNear(s.velocity, Vector3.new(2.989, -19.5808, -29.7904))
	end)

	it("turns upright in the air at airUprightRate", function()
		local s = skater(Vector3.new(0, 0, -30))
		s.mode = "Airborne"
		s.up = Vector3.xAxis
		s:step(input(), ground(FLAT, 0, false), 0.1)
		expect(math.deg(math.acos(s.up:Dot(Vector3.yAxis)))).toBeCloseTo(55.6225, 3) -- 90° − 6 × 0.1 rad
	end)

	it("stops dead for a freeze and starts again from rest", function()
		local s = skater(Vector3.new(0, 0, -60))
		s.mode = "Airborne"
		s:stop()
		expect(s.mode).toBe("Grounded")
		Fixtures.expectNear(s.velocity, Vector3.zero)
		s:step(input({ move = -Vector3.zAxis }), ground(), 0.1)
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -2.594))
	end)
end)
```

- [ ] **Step 2: Run the tests to verify they fail.**
  - Run `testPathPattern = "SkateMath"`.
  - Expected:
    - the hover test fails: the Task 1 step already hovers, but these values must still be checked against the hover code;
    - the leave/land/jump/wall/air tests fail on `mode` or velocity;
    - `stop` fails as a missing method.
  - If the hover test passes before its code, that's a finding: Task 1 already implemented the hover. Prove it guards the code with a mutation (drop the hover term and see it go red).
- [ ] **Step 3: Implement the mode rules, the air physics and `stop` in `SkateMath.luau`**
- [ ] **Step 4: Run the tests to verify they pass, then the full suite**

  Expected: **319 tests** (311 + 8).
- [ ] **Step 5: Static checks and commit:** `feat(skate): hover, air, landing, jumps and wall riding`.

---

### Task 3: Filtering ground normals

**Issue:** #74 · **Branch:** `feat/74-normal-filter` · **Labels:** `feature`, `skate`

**Files:**
- Create: `src/shared/Skate/NormalFilter.luau`
- Test: `tests/shared/Skate/NormalFilter.spec.luau`

**Interfaces:**
- Produces:
  ```lua
  NormalFilter.new(settings: { maxTurnDeg: number, smoothing: number }, initial: Vector3): NormalFilter
  NormalFilter.update(self: NormalFilter, raw: Vector3, dt: number): Vector3  -- the filtered unit normal (also .normal)
  NormalFilter.reset(self: NormalFilter, normal: Vector3)
  ```
- **Rule:**
  - Let `raw = raw.Unit`.
  - **A sharp turn** (more than `maxTurnDeg` from the filtered normal):
    - accepted (the filtered normal becomes `raw`) when the previous raw normal was a sharp turn too and lies within `maxTurnDeg` of this one;
    - otherwise remembered as pending and **dropped**, so the filtered normal is unchanged.
  - **A small turn:** clears the pending normal and turns the filtered normal toward `raw` by `1 − exp(−smoothing × dt)` of the angle between them.

- [ ] **Step 1: Write the failing tests**

```lua
local settings = Config.defaults().Movement.normalFilter
-- Measured in Phase 3: a downward ray exactly on a seam of the step hit a slab's side face.
local SEAM = Vector3.new(0, 0.49, -0.87)

describe("NormalFilter", function()
	it("ignores a lone normal that turns sharply, such as a seam's side face", function()
		local filter = NormalFilter.new(settings, Vector3.yAxis)
		Fixtures.expectNear(filter:update(SEAM, 1 / 60), Vector3.yAxis)
		Fixtures.expectNear(filter:update(Vector3.yAxis, 1 / 60), Vector3.yAxis)
	end)

	it("accepts a sharp turn that lasts for two rays", function()
		local filter = NormalFilter.new(settings, Vector3.yAxis)
		filter:update(SEAM, 1 / 60)
		Fixtures.expectNear(filter:update(SEAM, 1 / 60), SEAM.Unit)
	end)

	it("smooths small turns, and starts over from a reset", function()
		local filter = NormalFilter.new(settings, Vector3.yAxis)
		local tilted = Vector3.new(math.sin(math.rad(10)), math.cos(math.rad(10)), 0)
		local out = filter:update(tilted, 1 / 60)
		expect(math.deg(math.acos(out:Dot(Vector3.yAxis)))).toBeCloseTo(3.9347, 3) -- 10° × (1 − e^(−30/60))
		filter:reset(Vector3.xAxis)
		Fixtures.expectNear(filter.normal, Vector3.xAxis)
	end)
end)
```

- [ ] **Step 2:** Run `testPathPattern = "NormalFilter"`; expected FAIL (the module is missing).
- [ ] **Step 3:** Implement `NormalFilter.luau` with the class idiom. It rotates by building the turn about the cross product, which allocates no table.
- [ ] **Step 4:** Run, then the full suite. Expected **322 tests** (319 + 3).
- [ ] **Step 5:** Static checks and commit: `feat(skate): filter ground normals so one seam ray can't turn the skater`.

---

### Task 4: Drafting

**Issue:** #75 · **Branch:** `feat/75-draft` · **Labels:** `feature`, `skate`

**Files:**
- Create: `src/shared/Skate/Draft.luau`
- Test: `tests/shared/Skate/Draft.spec.luau`

**Interfaces:**
- Produces:
  ```lua
  export type Source = { position: Vector3, velocity: Vector3 }
  Draft.accel(movement: Config.MovementConfig, position: Vector3, sources: { Source }): number
  ```
- **Rule:** for each source moving faster than 0, let `d = position − source.position`.
  - It counts when `0 < |d| <= draftRange` and the angle between `d` and `−source.velocity` is at most `draftConeDeg`.
  - It pulls `draftMaxAccel × (1 − |d| / draftRange)`.
  - The strongest pull wins, and the result is 0 when nothing counts.

- [ ] **Step 1: Write the failing tests**

```lua
local movement = Config.defaults().Movement
local LEADER: Draft.Source = { position = Vector3.zero, velocity = Vector3.new(0, 0, -60) }

describe("Draft.accel", function()
	it("pulls a skater in the cone behind another, more the closer they are", function()
		expect(Draft.accel(movement, Vector3.new(0, 0, 9), { LEADER })).toBeCloseTo(10, 4) -- 20 × (1 − 9/18)
		expect(Draft.accel(movement, Vector3.new(0, 0, 13.5), { LEADER })).toBeCloseTo(5, 4)
		local offAxis = 9 * Vector3.new(math.sin(math.rad(20)), 0, math.cos(math.rad(20)))
		expect(Draft.accel(movement, offAxis, { LEADER })).toBeCloseTo(10, 4)
	end)

	it("gives nothing outside the cone, out of range, in front, or behind someone standing still", function()
		local wide = 9 * Vector3.new(math.sin(math.rad(40)), 0, math.cos(math.rad(40)))
		expect(Draft.accel(movement, wide, { LEADER })).toBe(0)
		expect(Draft.accel(movement, Vector3.new(0, 0, 19), { LEADER })).toBe(0)
		expect(Draft.accel(movement, Vector3.new(0, 0, -9), { LEADER })).toBe(0)
		expect(Draft.accel(movement, Vector3.new(0, 0, 9), { { position = Vector3.zero, velocity = Vector3.zero } })).toBe(0)
		expect(Draft.accel(movement, Vector3.zero, { LEADER })).toBe(0)
	end)

	it("uses the strongest pull when several skaters are ahead", function()
		local closer: Draft.Source = { position = Vector3.new(0, 0, 4.5), velocity = Vector3.new(0, 0, -60) }
		expect(Draft.accel(movement, Vector3.new(0, 0, 9), { LEADER, closer })).toBeCloseTo(15, 4) -- 4.5 studs: 20 × 0.75
	end)
end)
```

- [ ] **Step 2:** Run `testPathPattern = "Draft"`; expected FAIL (missing module).
- [ ] **Step 3:** Implement `Draft.luau`. It compares `cos` values (no `acos`) and allocates nothing.
- [ ] **Step 4:** Run, then the full suite. Expected **325 tests** (322 + 3).
- [ ] **Step 5:** Static checks and commit: `feat(skate): draft behind other skaters`.

---

### Task 5: Attaching behind a teammate

**Issue:** #76 · **Branch:** `feat/76-attach` · **Labels:** `feature`, `skate`

**Files:**
- Create: `src/shared/Skate/Attach.luau`
- Modify: `src/shared/Skate/SkateMath.luau` (`follow`, `release`)
- Test: `tests/shared/Skate/Attach.spec.luau`

**Interfaces:**
- Consumes: `SkateMath` (Tasks 1–2), `Types.PlayerId` (`Rules/Types`).
- Produces:
  ```lua
  export type Candidate = { player: PlayerId, position: Vector3, velocity: Vector3, forward: Vector3 }
  export type Change = "None" | "Attached" | "Released"
  Attach.findLeader(movement: Config.MovementConfig, position: Vector3, teammates: { Candidate }): Candidate?
  Attach.target(movement: Config.MovementConfig, leader: Candidate): Vector3  -- leader.position − leader.forward × attachFollowDistance
  Attach.new(movement: Config.MovementConfig): Attach
  -- Attach fields: leader: PlayerId?, attachedFor: number, cooldownLeft: number, releaseDirection: Vector3
  Attach.update(self: Attach, dt: number, holding: boolean, leader: Candidate?): Change
  SkateMath.follow(self: Skater, target: Vector3, position: Vector3, leaderVelocity: Vector3, leaderForward: Vector3)
  SkateMath.release(self: Skater, direction: Vector3)
  ```
- **Rules:**
  - **`findLeader`:** the nearest candidate with `|position − c.position| <= attachRange`, within `attachConeDeg` of `−c.forward`.
  - **`update`:** `cooldownLeft` first falls by `dt`, not below 0. `leader` is the best candidate when not attached, and the current leader's record (or nil) when attached.
    - **Not attached:** it returns `"Attached"` when `holding`, `cooldownLeft == 0` and `leader ~= nil`; otherwise `"None"`.
    - **Attached:** `attachedFor` grows by `dt` and `releaseDirection` becomes `leader.forward`. It returns `"Released"` when any of these holds:
      - not `holding`;
      - `leader == nil`, keeping the last direction;
      - `attachedFor >= attachMaxSeconds`.

      A release clears `leader` and sets `cooldownLeft = attachCooldown`.
  - **`follow`:** velocity is `leaderVelocity + attachSpring × (target − position)`, capped at `hardCap`; `mode = "Attached"`; `forward = leaderForward`.
  - **`release`:** velocity grows by `direction × attachBoostSpeed`, capped at `hardCap`; `mode = "Airborne"`. The next step lands it if it is near the ground.

- [ ] **Step 1: Write the failing tests**

```lua
local movement = Config.defaults().Movement

local function candidate(player: string, position: Vector3, velocity: Vector3): Attach.Candidate
	return { player = player, position = position, velocity = velocity, forward = velocity.Unit }
end

local LEADER = candidate("A", Vector3.zero, Vector3.new(0, 0, -30))

describe("Attach", function()
	it("finds the nearest teammate the skater is right behind", function()
		local farther = candidate("B", Vector3.new(0, 0, -2), Vector3.new(0, 0, -30))
		expect((Attach.findLeader(movement, Vector3.new(0, 0, 6), { farther, LEADER }) :: Attach.Candidate).player).toBe("A")
		expect(Attach.findLeader(movement, Vector3.new(0, 0, 9), { LEADER })).toBeNil() -- beyond attachRange 8
		expect(Attach.findLeader(movement, Vector3.new(6, 0, 4), { LEADER })).toBeNil() -- 56.3° off the line behind
		expect(Attach.findLeader(movement, Vector3.new(0, 0, -6), { LEADER })).toBeNil() -- in front
	end)

	it("attaches while held and follows behind the leader", function()
		local attach = Attach.new(movement)
		expect(attach:update(1 / 60, true, LEADER)).toBe("Attached")
		expect(attach.leader).toBe("A")
		Fixtures.expectNear(Attach.target(movement, LEADER), Vector3.new(0, 0, 4))
		local s = SkateMath.new(movement, Fixtures.GRAVITY)
		s:follow(Attach.target(movement, LEADER), Vector3.new(0, 0, 6), LEADER.velocity, LEADER.forward)
		expect(s.mode).toBe("Attached")
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -50)) -- −30 plus attachSpring 10 × 2 studs short
		expect(attach:update(1 / 60, true, LEADER)).toBe("None")
	end)

	it("lets go with a boost along the leader's way when released, then cools down", function()
		local attach = Attach.new(movement)
		attach:update(1 / 60, true, LEADER)
		expect(attach:update(1 / 60, false, LEADER)).toBe("Released")
		expect(attach.leader).toBeNil()
		Fixtures.expectNear(attach.releaseDirection, Vector3.new(0, 0, -1))
		local s = SkateMath.new(movement, Fixtures.GRAVITY)
		s.velocity = Vector3.new(0, 0, -30)
		s:release(attach.releaseDirection)
		expect(s.mode).toBe("Airborne")
		Fixtures.expectNear(s.velocity, Vector3.new(0, 0, -70))
		expect(attach:update(2.9, true, LEADER)).toBe("None") -- attachCooldown 3
		expect(attach:update(0.2, true, LEADER)).toBe("Attached")
	end)

	it("lets go after attachMaxSeconds even while held", function()
		local attach = Attach.new(movement)
		attach:update(1 / 60, true, LEADER)
		expect(attach:update(2.9, true, LEADER)).toBe("None")
		expect(attach:update(0.2, true, LEADER)).toBe("Released")
	end)

	it("lets go when the leader is gone", function()
		local attach = Attach.new(movement)
		attach:update(1 / 60, true, LEADER)
		expect(attach:update(1 / 60, true, nil)).toBe("Released")
		Fixtures.expectNear(attach.releaseDirection, Vector3.new(0, 0, -1))
	end)
end)
```

- [ ] **Step 2:** Run `testPathPattern = "Attach"`; expected FAIL (missing module).
- [ ] **Step 3:** Implement `Attach.luau` and `SkateMath.follow`/`release`.
- [ ] **Step 4:** Run, then the full suite. Expected **330 tests** (325 + 5).
- [ ] **Step 5:** Static checks and commit: `feat(skate): attach behind a teammate and boost on release`.

---

### Task 6: The skater body on the server

**Issue:** #77 · **Branch:** `feat/77-skater-body` · **Labels:** `feature`, `skate`

**Files:**
- Create:
  - `src/shared/Skate/SkaterRig.luau` (names only);
  - `src/server/SkaterBody.luau` (a helper, not a service).
- Modify:
  - `src/shared/Arena/Tags.luau` (`RideSurface`);
  - `src/server/Arena/Builder.luau` (tag the `Surface` and `Infield` folders);
  - `src/server/CharacterService.luau`:
    - build the body on load;
    - hover placement;
    - a `placed` signal;
    - collision groups in `start`;
    - `standingHeight` removed.
- Test: `tests/server/CharacterService.spec.luau`, `tests/server/SkaterBody.spec.luau`, `tests/server/Arena/Builder.spec.luau`

**Interfaces:**
- Consumes: `Config.MovementConfig.colliderDiameter`, `hoverHeight`.
- Produces:
  ```lua
  SkaterRig.collider: string      -- "SkateCollider"
  SkaterRig.attachment: string    -- "SkateAttachment"
  SkaterRig.velocity: string      -- "SkateVelocity"
  SkaterRig.align: string         -- "SkateAlign"
  SkaterRig.groups: { body: string, collider: string }  -- "SkaterBody", "SkaterCollider"
  Tags.RideSurface: string        -- "RideSurface", on the arena's Surface and Infield folders
  SkaterBody.build(character: Model, movement: Config.MovementConfig)
  -- A plain table type with the three PhysicsService methods used, so tests pass a fake.
  SkaterBody.registerGroups(physics: SkaterBody.Physics)
  CharacterService.placed: Signal.Signal<PlayerId>   -- after every server placement
  ```
- **`build`:**
  - destroys `Animate` if present;
  - sets every `BasePart`'s `CollisionGroup` to `groups.body`;
  - adds the collider: Ball shape, `Size = Vector3.one × colliderDiameter`, centred on the root, `Transparency = 1`, `CanQuery = false`, `CanTouch = false`, group `groups.collider`, with a `WeldConstraint` to the root;
  - adds `SkateAttachment` on the root;
  - adds `SkateVelocity`: Vector mode, World, `ForceLimitsEnabled = false`, `VectorVelocity = 0`;
  - adds `SkateAlign`: OneAttachment, `RigidityEnabled = true`, `PrimaryAxis`/`SecondaryAxis` from the root's current right and up.
- **`registerGroups`:**
  - registers each group that is missing;
  - body: false against `Default`, itself and the collider group;
  - collider: true against `Default`, false against itself.
- **`CharacterService`:**
  - `requestLoad` runs `SkaterBody.build` in the same resumption that `LoadCharacterAsync` returns in (verified necessary for `Animate`), then `adopt` and `place`.
  - `place` pivots to `spawn * CFrame.new(0, Movement.hoverHeight, 0)` and fires `placed`.
  - `start` calls `SkaterBody.registerGroups(PhysicsService)`.

- [ ] **Step 1: Write the failing tests**

In `CharacterService.spec`:
- change the first test to `stands a character on its slot's team spawn with its root at hoverHeight, whatever its rig`. It expects `(0, 2.5, -53)` and `(-10, 2.5, 53)` and drops the `standingHeight` line.
- add:

```lua
	it("gives every loaded character a skater body and no default animations", function()
		CharacterService:init({
			Config = Fixtures.config(),
			ArenaService = fakeArena,
			TeamService = fakeTeams,
			LoadCharacter = function(id: string): Model
				local rig = Fixtures.rig(folder, id, CFrame.new(0, 50, 0))
				local animate = Instance.new("LocalScript")
				animate.Name = "Animate"
				animate.Parent = rig
				return rig
			end,
		})
		CharacterService:requestLoad("A")
		task.wait()
		local rig = folder:FindFirstChild("A") :: Model
		local root = rig.PrimaryPart :: BasePart
		expect(rig:FindFirstChild("Animate") == nil).toBe(true)
		local collider = rig:FindFirstChild(SkaterRig.collider) :: Part
		expect(collider.Shape).toBe(Enum.PartType.Ball)
		expect(collider.Size).toEqual(Vector3.one * 2)
		expect(collider.CanQuery).toBe(false)
		expect((collider:FindFirstChildOfClass("WeldConstraint") :: WeldConstraint).Part0 == root).toBe(true)
		expect((root:FindFirstChild(SkaterRig.velocity) :: LinearVelocity).ForceLimitsEnabled).toBe(false)
		expect((root:FindFirstChild(SkaterRig.align) :: AlignOrientation).RigidityEnabled).toBe(true)
		-- The server keeps the humanoid's state machine: without it a death never fires Died.
		expect((rig:FindFirstChildOfClass("Humanoid") :: Humanoid).EvaluateStateMachine).toBe(true)
	end)

	it("announces each placement, so the movement guard trusts the server's own jumps", function()
		local placed: { string } = {}
		CharacterService.placed:Connect(function(id: string)
			table.insert(placed, id)
		end)
		CharacterService:adopt("A", Fixtures.rig(folder, "A", CFrame.new(0, 50, 0)))
		CharacterService:place("A", false)
		expect(placed).toEqual({ "A" })
	end)
```

`tests/server/SkaterBody.spec.luau`:

```lua
	it("puts avatar parts in a group that touches nothing and the collider in one that touches only the arena", function()
		local rig = Fixtures.rig(folder, "Skater", CFrame.new(0, 5, 0))
		SkaterBody.build(rig, Config.defaults().Movement)
		for _, part in rig:GetDescendants() do
			if part:IsA("BasePart") then
				local expected = if part.Name == SkaterRig.collider then SkaterRig.groups.collider else SkaterRig.groups.body
				expect(part.CollisionGroup).toBe(expected)
			end
		end
	end)

	it("registers the skater groups once: bodies touch nothing, colliders the arena but not each other", function()
		local registered: { [string]: boolean } = { Default = true }
		local collides: { [string]: boolean } = {}
		local registrations = 0
		local physics = {
			IsCollisionGroupRegistered = function(_self: any, name: string): boolean
				return registered[name] == true
			end,
			RegisterCollisionGroup = function(_self: any, name: string)
				registered[name] = true
				registrations += 1
			end,
			CollisionGroupSetCollidable = function(_self: any, a: string, b: string, value: boolean)
				collides[`{a}/{b}`] = value
			end,
		}
		SkaterBody.registerGroups(physics)
		SkaterBody.registerGroups(physics)
		expect(registrations).toBe(2)
		expect(collides).toEqual({
			["SkaterBody/Default"] = false,
			["SkaterBody/SkaterBody"] = false,
			["SkaterBody/SkaterCollider"] = false,
			["SkaterCollider/Default"] = true,
			["SkaterCollider/SkaterCollider"] = false,
		})
	end)
```

In `Builder.spec`, a test `tags the riding surfaces so skaters' rays find only them`. It builds into the spec's workspace folder, collects the `RideSurface`-tagged instances under the built model and expects their names sorted to be `{ "Infield", "Surface" }`.

- [ ] **Step 2: Run the tests to verify they fail.**
  - Run `testPathPattern = "(CharacterService|SkaterBody|Builder)"`.
  - Expected: the hover placement fails (2.5 against the old standing height), and the body, `placed`, groups and tag tests fail on their missing pieces.
- [ ] **Step 3: Implement** `SkaterRig`, `Tags.RideSurface`, the `Builder` tags, `SkaterBody` and the `CharacterService` changes. `Match.spec`'s `seat` helper still adopts plain rigs, which is unchanged.
- [ ] **Step 4: Run, then the full suite.** Expected **335 tests** (330 + 5 new; the placement test is changed, not added).
- [ ] **Step 5: Static checks and commit:** `feat(skate): build each skater's body on the server and hover them on their spawns`.

---

### Task 7: Sharing pump and brake (the first client → server remote)

**Issue:** #78 · **Branch:** `feat/78-skate-state` · **Labels:** `feature`, `infra`

**Files:**
- Create: `src/shared/Net/RateLimiter.luau`, `src/shared/Net/Schemas.luau`
- Modify:
  - `src/shared/Net/Remotes.luau` (`SkateState`, and the header's table);
  - `src/shared/Net/Attributes.luau` (`Pumping` and `Braking` on characters; the header now says "Player and character");
  - `src/shared/Config/Network.luau` (`maxSkateStatesPerSecond = 20`, above 0);
  - `src/server/NetService.luau` (`listen`, `receive`, `dropped`, `forget`; `deps.Clock`);
  - `src/server/CharacterService.luau` (depends on `NetService`; `setSkateState`);
  - `tests/integration/Match.spec.luau` (its `fakeNet` gains a `listen` that records);
  - `tests/server/CharacterService.spec.luau`: every `CharacterService:init` passes a `NetService` fake. One local helper builds the deps, so the fake is written once.
- Test:
  - `tests/shared/Net/RateLimiter.spec.luau`, `tests/shared/Net/Schemas.spec.luau`;
  - `tests/server/NetService.spec.luau`, `tests/server/CharacterService.spec.luau`;
  - `tests/shared/Config/Config.spec.luau` (the network defaults now include `maxSkateStatesPerSecond = 20`).

**Interfaces:**
- Produces:
  ```lua
  RateLimiter.new(perSecond: number): RateLimiter          -- a token bucket per key, capacity perSecond
  RateLimiter.allow(self: RateLimiter, key: string, now: number): boolean
  RateLimiter.forget(self: RateLimiter, key: string)
  Schemas.SkateState: Validate.Validator                   -- { pump: boolean, brake: boolean }, nothing else
  NetService.listen(self, name: string, schema: Validate.Validator, perSecond: number,
  	handler: (player: PlayerId, payload: any) -> ())
  NetService.receive(self, name: string, player: PlayerId, payload: any)  -- what OnServerEvent runs
  NetService.dropped(self, player: PlayerId): number
  NetService.forget(self, player: PlayerId)                 -- start() runs it on PlayerRemoving
  CharacterService.setSkateState(self, player: PlayerId, pump: boolean, brake: boolean)
  ```
- **Rules:**
  - **`receive`:** a payload is dropped and counted when it fails its schema or its sender's limiter, and the handler never runs for it.
  - **`forget`:** clears both the player's limiter state and their drop count.
  - **`listen`:** connects `OnServerEvent` to `receive` (`PlayerIds.of(player)`).
  - **`setSkateState`:** sets `Attributes.Pumping` and `Attributes.Braking` on the character of a **seated** player who has one; it does nothing otherwise.
  - **`CharacterService.init`:** listens on `SkateState` with `Network.maxSkateStatesPerSecond`.

- [ ] **Step 1: Write the failing tests**

```lua
-- RateLimiter.spec
	it("allows a burst of perSecond messages, then refills over time", function()
		local limiter = RateLimiter.new(4)
		for _ = 1, 4 do
			expect(limiter:allow("A", 0)).toBe(true)
		end
		expect(limiter:allow("A", 0)).toBe(false)
		expect(limiter:allow("A", 0.25)).toBe(true) -- one token back after a quarter second
		expect(limiter:allow("A", 0.25)).toBe(false)
	end)

	it("counts each player separately and forgets one who left", function()
		local limiter = RateLimiter.new(1)
		expect(limiter:allow("A", 0)).toBe(true)
		expect(limiter:allow("B", 0)).toBe(true)
		expect(limiter:allow("A", 0)).toBe(false)
		limiter:forget("A")
		expect(limiter:allow("A", 0)).toBe(true)
	end)

-- Schemas.spec
	it("accepts a skate state and rejects malformed ones", function()
		expect(#Schemas.SkateState({ pump = true, brake = false }, "SkateState")).toBe(0)
		for _, bad in { { pump = "yes", brake = false }, { pump = true }, { pump = true, brake = false, speed = 999 }, "x" } do
			expect(#Schemas.SkateState(bad, "SkateState") > 0).toBe(true)
		end
	end)
```

```lua
-- NetService.spec (init with deps.Parent = the spec's folder and deps.Clock = a fake clock)
	it("hands a valid message to its listener with the sender's id", function()
		local got: { any } = {}
		NetService:listen(Remotes.names.SkateState, Schemas.SkateState, 20, function(player: string, payload: any)
			table.insert(got, { player, payload.pump, payload.brake })
		end)
		NetService:receive(Remotes.names.SkateState, "7", { pump = true, brake = false })
		expect(got).toEqual({ { "7", true, false } })
	end)

	it("drops malformed and too-frequent messages and counts them per player", function()
		local handled = 0
		NetService:listen(Remotes.names.SkateState, Schemas.SkateState, 2, function()
			handled += 1
		end)
		for _ = 1, 3 do
			NetService:receive(Remotes.names.SkateState, "7", { pump = true, brake = false })
		end
		NetService:receive(Remotes.names.SkateState, "8", { pump = 1, brake = false })
		expect(handled).toBe(2)
		expect(NetService:dropped("7")).toBe(1)
		expect(NetService:dropped("8")).toBe(1)
		NetService:forget("7")
		expect(NetService:dropped("7")).toBe(0)
	end)
```

```lua
-- CharacterService.spec (beforeEach's init now passes NetService = fakeNet, whose listen keeps the handler)
	it("shows a seated player's pump and brake on their character for everyone", function()
		local seated = Fixtures.rig(folder, "A", CFrame.new(0, 3, 0))
		local spectator = Fixtures.rig(folder, "Z", CFrame.new(5, 3, 0))
		CharacterService:adopt("A", seated)
		CharacterService:adopt("Z", spectator)
		fakeNet.handlers[Remotes.names.SkateState]("A", { pump = true, brake = false })
		fakeNet.handlers[Remotes.names.SkateState]("Z", { pump = true, brake = true })
		expect(seated:GetAttribute(Attributes.Pumping)).toBe(true)
		expect(seated:GetAttribute(Attributes.Braking)).toBe(false)
		expect(spectator:GetAttribute(Attributes.Pumping)).toBeNil()
	end)
```

- [ ] **Step 2:** Run `testPathPattern = "(RateLimiter|Schemas|NetService|CharacterService|Config)"`; expected FAIL on the missing modules and methods, and the network default.
- [ ] **Step 3:** Implement as specified.
- [ ] **Step 4:** Run, then the full suite. Expected **341 tests** (335 + 6).
- [ ] **Step 5:** Static checks and commit: `feat(net): share each skater's pump and brake through a validated, rate-limited remote`.

---

### Task 8: Skating keys (`Config.Input` and `InputController`)

**Issue:** #79 · **Branch:** `feat/79-skate-input` · **Labels:** `feature`, `input`

**Files:**
- Create: `src/shared/Config/Input.luau`, `src/client/InputController.luau`
- Modify:
  - `src/shared/Config/Validate.luau` (`Validate.enumItem`), `src/shared/Config/init.luau` (area `Input`);
  - `src/client/Modules.luau` (first module);
  - `tests/Fixtures.luau` (`scriptedBinding`).
- Test: `tests/shared/Config/Validate.spec.luau`, `tests/shared/Config/Config.spec.luau`, `tests/client/InputController.spec.luau`

**Interfaces:**
- Produces:
  ```lua
  Validate.enumItem(enumType: Enum): Validator   -- "<path>: must be a <Enum> (got <tostring(value)>)", strings quoted
  export type InputConfig = {
  	contextPriority: number,
  	move: { composites: { { up: Enum.KeyCode, down: Enum.KeyCode, left: Enum.KeyCode, right: Enum.KeyCode } },
  		sticks: { Enum.KeyCode } },
  	jump: { Enum.KeyCode }, pump: { Enum.KeyCode }, brake: { Enum.KeyCode }, attach: { Enum.KeyCode },
  }
  export type SkateKeys = { move: Vector2, pump: boolean, brake: boolean, attach: boolean, jump: boolean }
  InputController.context: InputContext       -- "SkateControls"; actions "Move", "Jump", "Pump", "Brake", "Attach"
  InputController.newKeys(): SkateKeys
  InputController.read(self, into: SkateKeys)  -- jump: pressed since the last read
  InputController.destroy(self)
  Fixtures.scriptedBinding(action: InputAction): InputBinding   -- a Scriptable binding to Fire in tests
  ```
- **Defaults:**
  - `contextPriority = 1000`
  - `move`: `composites = { { up = W, down = S, left = A, right = D } }`, `sticks = { Thumbstick1 }`
  - `jump = { Space, ButtonA }`, `pump = { LeftShift, ButtonR2 }`, `brake = { LeftControl, ButtonR1 }`, `attach = { F, ButtonL1 }`
- **Cross-field rule:** `"Input: <KeyCode name> is bound to more than one action"`, for the first key that repeats across the lists.
- **`init(deps)`:** builds the context under `deps.Parent`, or `Players.LocalPlayer.PlayerScripts`, with `Priority = contextPriority` and `Sink = true`. `Jump` counts its `Pressed` events.

- [ ] **Step 1: Write the failing tests**

```lua
-- Validate.spec
	it("checks Enum items by their enum", function()
		local key = Validate.enumItem(Enum.KeyCode)
		expect(#key(Enum.KeyCode.F, "k")).toBe(0)
		expect(key(Enum.UserInputType.Touch, "k")[1]).toBe("k: must be a KeyCode (got Enum.UserInputType.Touch)")
		expect(key("F", "k")[1]).toBe('k: must be a KeyCode (got "F")')
	end)
```

```lua
-- Config.spec
	it("bind the skating keys of spec §8.3", function()
		local input = Config.defaults().Input
		expect(input.contextPriority).toBe(1000)
		expect(input.move).toEqual({
			composites = { { up = Enum.KeyCode.W, down = Enum.KeyCode.S, left = Enum.KeyCode.A, right = Enum.KeyCode.D } },
			sticks = { Enum.KeyCode.Thumbstick1 },
		})
		expect(input.jump).toEqual({ Enum.KeyCode.Space, Enum.KeyCode.ButtonA })
		expect(input.pump).toEqual({ Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonR2 })
		expect(input.brake).toEqual({ Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonR1 })
		expect(input.attach).toEqual({ Enum.KeyCode.F, Enum.KeyCode.ButtonL1 })
	end)

	it("rejects a key bound to two actions", function()
		expect(function()
			Fixtures.config({ Input = { pump = { Enum.KeyCode.Space } } })
		end).toThrow("Input: Space is bound to more than one action")
	end)
```

```lua
-- InputController.spec (init with { Config = Fixtures.config(), Parent = folder } in beforeEach; destroy in afterEach)
	it("builds one sinking context above Roblox's own controls, bound as Config.Input says", function()
		local context = InputController.context
		expect(context.Priority).toBe(1000)
		expect(context.Sink).toBe(true)
		local pump = context:FindFirstChild("Pump") :: InputAction
		expect(pump.Type).toBe(Enum.InputActionType.Bool)
		local keys: { string } = {}
		for _, binding in pump:GetChildren() do
			table.insert(keys, (binding :: InputBinding).KeyCode.Name)
		end
		table.sort(keys)
		expect(keys).toEqual({ "ButtonR2", "LeftShift" })
		local move = context:FindFirstChild("Move") :: InputAction
		expect(move.Type).toBe(Enum.InputActionType.Direction2D)
		expect(#move:GetChildren()).toBe(2) -- the WASD composite and the left stick
	end)

	it("reads the move stick and the held buttons", function()
		local context = InputController.context
		Fixtures.scriptedBinding(context:FindFirstChild("Move") :: InputAction):Fire(Vector2.new(0.6, 0.8))
		Fixtures.scriptedBinding(context:FindFirstChild("Brake") :: InputAction):Fire(true)
		local keys = InputController.newKeys()
		InputController:read(keys)
		expect(keys.move.X).toBeCloseTo(0.6, 5)
		expect(keys.move.Y).toBeCloseTo(0.8, 5)
		expect(keys.brake).toBe(true)
		expect(keys.pump).toBe(false)
		expect(keys.attach).toBe(false)
	end)

	it("counts a jump press once, however long it is held", function()
		local jump = Fixtures.scriptedBinding(InputController.context:FindFirstChild("Jump") :: InputAction)
		local keys = InputController.newKeys()
		jump:Fire(true)
		task.wait() -- Pressed is deferred
		InputController:read(keys)
		expect(keys.jump).toBe(true)
		InputController:read(keys)
		expect(keys.jump).toBe(false)
		jump:Fire(false)
		jump:Fire(true)
		task.wait()
		InputController:read(keys)
		expect(keys.jump).toBe(true)
	end)
```

- [ ] **Step 2:** Run `testPathPattern = "(Validate|Config|InputController)"`; expected FAIL on the missing validator, area and controller.
- [ ] **Step 3:** Implement as specified. `Modules.luau` lists `InputController` first.
- [ ] **Step 4:** Run, then the full suite. Expected **347 tests** (341 + 6).
- [ ] **Step 5:** Static checks and commit: `feat(input): skating keys on the Input Action System`.

---

### Task 9: `SkateController` (the client moves its own skater)

**Issue:** #80 · **Branch:** `feat/80-skate-controller` · **Labels:** `feature`, `skate`

**Files:**
- Create: `src/client/SkateController.luau`
- Modify: `src/client/Modules.luau` (after `InputController`)
- Test: `tests/client/SkateController.spec.luau`

**Interfaces:**
- Consumes: Tasks 1–8. `SkaterRig`, `Tags.RideSurface`, `Remotes.names.SkateState`, `Attributes.Team`, `PlayerIds`.
- Produces:
  ```lua
  export type SkaterView = { player: PlayerId, team: string?, root: BasePart }
  export type SkateController = {
  	name: string, dependencies: { string },          -- { "Config", "InputController" }
  	init: (self, deps: { [string]: any }) -> (), start: (self) -> (),
  	bind: (self, character: Model) -> (),            -- waits for the skater body, turns the state machine off
  	step: (self, dt: number) -> (),
  	skater: SkateMath.Skater?, pumping: boolean, braking: boolean,
  	...
  }
  ```
- **Optional `deps` (all defaulted in production):**
  - `Camera`: anything with a `CFrame`; defaults to `workspace.CurrentCamera`.
  - `Skaters`: `() -> { SkaterView }`, every other player's character root; defaults to scanning `Players`.
  - `SendSkateState`: `(pump: boolean, brake: boolean) -> ()`; defaults to `FireServer({ pump, brake })` on the `SkateState` remote.
  - `Gravity`: defaults to `Vector3.new(0, -workspace.Gravity, 0)`.
  - `Team`: `() -> string?`; defaults to the local player's `Team` attribute.
- **`step(dt)`, in order:**
  1. **Nothing to drive:** do nothing without a bound character with a root.
  2. **Frozen:** if the root is anchored, `skater:stop()`, reset the filter to world up and stop.
  3. **Input:** read the keys. The world move is `camera.RightVector × move.X + flatForward × move.Y`, where `flatForward` is the camera's look vector without its vertical part, unit length.
  4. **Ground:** cast a ray from the root along `−skater.up × groundProbeLength`, including only `Tags.RideSurface` instances. The include list is refreshed when tags are added or removed.
     - On a hit, `ground.normal` is the `NormalFilter`'s output and `distance` is the hit distance.
     - On no hit, `hit = false`.
  5. **Draft:** `input.draftAccel = Draft.accel(...)` over the other skaters, using reused records.
  6. **Attach:** among teammates, run `Attach.update` with the `attach` key.
     - While attached, `skater:follow(...)`.
     - On `"Released"`, `skater:release(...)`.
     - Otherwise, `skater:step(input, ground, dt)`.
  7. **Apply:** `SkateVelocity.VectorVelocity = skater.velocity`; `SkateAlign.PrimaryAxis = forward:Cross(up)`, `SecondaryAxis = up`.
  8. **Share:** when pump or brake changes, update `pumping`/`braking` and call `SendSkateState` once.
- **`start`:** binds the local character (now and on `CharacterAdded`) and connects `RunService.PreSimulation` to `step`.

- [ ] **Step 1: Write the failing tests**

Fixture for every test:
- a `SkateControllerTest` folder in `workspace` holding a floor `Part`: size (400, 1, 400), top at y = 0, the folder tagged `RideSurface`;
- `InputController:init({ Config = config, Parent = folder })`;
- a rig whose root sits exactly at `hoverHeight` above the floor (`Fixtures.rig(folder, "Skater", CFrame.new(0, 2.5, 0))`), with its body built (`SkaterBody.build`);
- `SkateController:init` with a camera looking toward −Z (`{ CFrame = CFrame.lookAt(Vector3.new(0, 5, 10), Vector3.new(0, 5, 0)) }`), `Skaters` returning `{}`, a recording `SendSkateState`, `Gravity = Fixtures.GRAVITY` and `Team = function() return "Blue" end`;
- `SkateController:bind(rig)`.

`Fixtures.scriptedBinding` drives the keys. Tests:

1. `takes over a character and drives its skater body from the stick`:
   - After binding, `EvaluateStateMachine` is false.
   - Move (0, 1), then `step(0.1)`. `SkateVelocity.VectorVelocity` ≈ (0, 0, −2.594), the same as SkateMath's first test, since the root is exactly at hover height.
   - `SkateAlign.SecondaryAxis` ≈ (0, 1, 0) and `PrimaryAxis` ≈ (1, 0, 0).
2. `holds still while the root is anchored, then starts from rest`:
   - Hold the stick for 10 steps of 0.1, then anchor the root and `step(0.1)`. `skater.velocity` is zero.
   - Unanchor and `step(0.1)`. The velocity is ≈ (0, 0, −2.594).
3. `falls when no riding surface is below`:
   - Pivot the rig to (1000, 50, 1000) and `step(0.1)`.
   - `skater.mode == "Airborne"`, and the velocity is ≈ (0, −19.5808, 0).
4. `drives a new character after a respawn`:
   - Build a second rig `B` with its body and `bind` it, then step with the stick held.
   - `B`'s `SkateVelocity` changes; the first rig's stays at its last value.
5. `tells the server about pump and brake only when they change`:
   - Hold pump, then step 3 times: the sender's calls are `{ { true, false } }`.
   - Release, then step: the calls are `{ { true, false }, { false, false } }`.
6. `keeps the skater's up steady across a seam of the generated arena`:
   - Build the arena with `Builder` into the folder, as `Arena.spec` does, and untag the test floor.
   - Scan x = 30, z from −58 to −68 in steps of 0.005. Find the first z where the ray's normal is more than `normalFilter.maxTurnDeg` from the normal 0.05 studs before it, and assert one was found.
   - Pivot the root across that z, from 0.2 studs before to 0.2 after, in steps of 0.02 at `hoverHeight` above the hit, calling `step(1 / 60)` at each.
   - Every frame's `skater.up` must be within `maxTurnDeg` of the normal measured 0.05 studs before that frame.
7. `steps in under half a millisecond`:
   - Give `Skaters` five rigs around the skater (two of them teammates within attach range) and hold pump and the stick.
   - The mean of 600 `step(1 / 60)` calls, timed with `os.clock()`, is under 0.0005 s.

- [ ] **Step 2:** Run `testPathPattern = "SkateController"`; expected FAIL (missing module).
- [ ] **Step 3:** Implement `SkateController.luau`. Reuse one input record, one ground record, the `RaycastParams`, the draft source list and the candidate list across steps. `Modules.luau` lists `InputController`, then `SkateController`.
- [ ] **Step 4:** Run, then the full suite. Expected **354 tests** (347 + 7). Record the measured mean step time in the ledger.
- [ ] **Step 5: Playtest.**
  - Start play, wait about 5 s, then `get_console_output`. Expect `Server ready … modules=6` and `Client ready … modules=2`.
  - Hold W and LeftShift with `user_keyboard_input` for 2 s. On the server, the root's `AssemblyLinearVelocity` magnitude is > 20, and the root's height above the floor ray is ≈ 2.5.
  - Release, stop play, and check the console has nothing else.
  - Write the observations to the ledger.
- [ ] **Step 6:** Static checks and commit: `feat(skate): the client skates its own character`.

---

### Task 10: Poses (`Config.Pose`, `Skate/Pose`, `PoseController`)

**Issue:** #81 · **Branch:** `feat/81-poses` · **Labels:** `feature`, `skate`

**Files:**
- Create: `src/shared/Config/Pose.luau`, `src/shared/Skate/Pose.luau`, `src/client/PoseController.luau`
- Modify:
  - `src/shared/Config/init.luau` (area `Pose`);
  - `src/shared/Skate/SkaterRig.luau` (joint names by rig type);
  - `src/client/Modules.luau` (after `SkateController`);
  - `tests/Fixtures.luau` (`jointedRig`).
- Test: `tests/shared/Config/Config.spec.luau`, `tests/shared/Skate/Pose.spec.luau`, `tests/client/PoseController.spec.luau`

**Interfaces:**
- Produces:
  ```lua
  export type PoseConfig = { maxLeanDeg: number, leanSmoothing: number, crouchDeg: number, brakeLeanDeg: number,
  	tuckDeg: number, carryArmDeg: number, airborneProbe: number }
  -- defaults: maxLeanDeg 30, leanSmoothing 10, crouchDeg 30, brakeLeanDeg 15, tuckDeg 60, carryArmDeg 75, airborneProbe 1.5
  export type Role = "root" | "waist" | "leftHip" | "rightHip" | "leftKnee" | "rightKnee" | "rightShoulder"
  export type PoseInput = { lean: number, airborne: boolean, pumping: boolean, braking: boolean, carrying: boolean,
  	bodyOffset: number }
  Pose.leanDeg(pose: Config.PoseConfig, speed: number, turnRate: number, gravity: number): number
  Pose.compute(pose: Config.PoseConfig, input: PoseInput, out: { [Role]: CFrame })
  SkaterRig.joints: { R15: { [Role]: string }, R6: { [Role]: string } }
  -- R15: Root, Waist, LeftHip, RightHip, LeftKnee, RightKnee, RightShoulder
  -- R6: RootJoint, Left Hip, Right Hip, Right Shoulder (no waist or knees)
  -- PoseController: dependencies { "Config", "SkateController" } (the local character's mode, pump and brake)
  PoseController.track(self, character: Model, isLocal: boolean)
  PoseController.setCarrier(self, player: PlayerId?)
  PoseController.step(self, dt: number)
  Fixtures.jointedRig(parent: Instance, name: string, cframe: CFrame): Model   -- an R15 rig whose joints are Motor6Ds
  ```
- **`Pose.compute` rules.** Signs are checked visually in this task's playtest; the tests pin magnitudes.
  - **root:** `CFrame.new(0, bodyOffset, 0)`, rolled by `−lean` about Z, pitched forward by `crouchDeg / 2` while pumping or back by `brakeLeanDeg` while braking.
  - **waist:** pitched forward by `crouchDeg / 2` while pumping.
  - **hips:** pitched `crouchDeg` while pumping, or `tuckDeg` while airborne.
  - **knees:** bent `2 × crouchDeg` while pumping, or `tuckDeg` while airborne.
  - **rightShoulder:** rolled `carryArmDeg` while carrying.
  - Otherwise each joint gets `CFrame.identity`.
- **`Pose.leanDeg`:** `clamp(deg(atan(speed × turnRate / gravity)), ±maxLeanDeg)`.
- **`PoseController.step`**, for each tracked character:
  - **Lean:** the turn rate is the signed change of the horizontal velocity's heading divided by `dt` (positive when turning right). The lean moves toward `leanDeg(...)` by `1 − exp(−leanSmoothing × dt)` of the gap.
  - **Airborne:** for the local character, `SkateController.skater.mode == "Airborne"`. For others, no ride-surface hit within `hoverHeight + airborneProbe` along `−root.CFrame.UpVector`.
  - **Pumping and braking:** for the local character, `SkateController.pumping` and `braking`. For others, the `Pumping` and `Braking` attributes.
  - **Carrying:** the player is the current carrier.
  - **bodyOffset:** `standingHeight(character) − hoverHeight`. `standingHeight` moves here from `CharacterService`, with its R15/R6 rule.
  - **Writing:** each found joint's `Transform` is set; a missing joint is skipped.
- **`start`:**
  - tracks every player's character, now and on `CharacterAdded`, and untracks it on removal;
  - follows `BallCarrier` through `setCarrier`;
  - connects `PreSimulation` to `step`.

- [ ] **Step 1: Write the failing tests**

`Config.spec`, in the Config defaults describe:

```lua
	it("pose skaters with the starting angles", function()
		expect(Config.defaults().Pose).toEqual({ maxLeanDeg = 30, leanSmoothing = 10, crouchDeg = 30,
			brakeLeanDeg = 15, tuckDeg = 60, carryArmDeg = 75, airborneProbe = 1.5 })
	end)
```

`Pose.spec` (one describe):
- `leans into turns, up to maxLeanDeg`:
  - `leanDeg(pose, 30, 1, 196.2) ≈ 8.6935`;
  - `(30, −1) ≈ −8.6935`;
  - `(60, 2) == 30`.
- `lifts the body so the avatar's feet meet the ground`: with `bodyOffset = 0.5`, `out.root.Position.Y == 0.5`.
- `crouches while pumping and leans back while braking`:
  - pumping gives |knee angle| = 60°, |hip| = 30° and |waist| = 15°;
  - braking gives a root pitch of |15°|.
- `tucks the legs in the air`: hips and knees at |60°|.
- `raises the right arm while carrying`: the right shoulder's roll is |75°|. Angles are read with `ToEulerAnglesXYZ`.

`PoseController.spec`. A floor tagged `RideSurface` sits under the rigs. `SkateController` is a fake table `{ skater = nil, pumping = false, braking = false }`.
- `lifts each avatar by its own standing height above hoverHeight, R15 and R6 alike`:
  - Track an R15 `Fixtures.jointedRig` (standing height 3) and step: the `Root` joint's `Transform` Y ≈ 0.5.
  - An R6 rig from `Fixtures.rig(…, R6)`, given a `RootJoint` Motor6D in its root, gets Y ≈ 0.5 too.
- `raises the carrier's arm and shows another player's pump from their character's attribute`:
  - `setCarrier` the rig's player and set its `Pumping` attribute to true, then step.
  - `RightShoulder`'s roll is |75°|; `RightKnee`'s bend is |60°|.
- `leans a character into the turn its velocity makes`:
  - Set the root's `AssemblyLinearVelocity` to (0, 0, −30) and step once.
  - Rotate it by 1/60 rad toward +X and step once more, so the turn rate is 1 rad/s.
  - The root roll is ≈ 1.3346°: the target 8.6935° × (1 − e^(−10/60)).
- `poses six skaters in under 0.3 ms a frame`:
  - Track six jointed rigs, one carrying and two with `Pumping`, all moving.
  - The mean of 600 `step(1 / 60)` calls, timed with `os.clock()`, is under 0.0003 s.

- [ ] **Step 2:** Run `testPathPattern = "(Config|Pose)"`; expected FAIL (missing area and modules).
- [ ] **Step 3:** Implement as specified, reusing one `out` table and one `PoseInput` per tracked character.
- [ ] **Step 4:** Run, then the full suite. Expected **364 tests** (354 + 10: one config test, five `Pose` tests, four `PoseController` tests). Record the measured pose time in the ledger.
- [ ] **Step 5: Playtest.** Expect `Client ready … modules=3`. Hold W with A or D to turn, LeftShift and LeftControl in turn, and Space.
  - Read the joints' `Transform`s on the client: roll while turning, crouch while pumping, lean back while braking, tuck while airborne.
  - Read them on the server too: the server shows none of them, as expected.
  - Check the signs visually with `screen_capture` if it renders. Otherwise record the joint angles and fix any sign that bends a joint the wrong way, with a test.
  - Write the observations to the ledger.
- [ ] **Step 6:** Static checks and commit: `feat(skate): every client poses every skater`.

---

### Task 11: `MovementGuard`

**Issue:** #82 · **Branch:** `feat/82-movement-guard` · **Labels:** `feature`, `skate`

**Files:**
- Create: `src/shared/Skate/MovementCheck.luau`, `src/server/MovementGuard.luau`
- Modify:
  - `src/shared/Config/Network.luau`: `guardSampleSeconds = 0.25`, `speedTolerance = 1.2`, `guardStrikes = 3`, `guardTeleportFactor = 2`.
    - All are above 0; `guardStrikes` is an integer of at least 1.
    - The header comment loses "Later phases add…".
  - `src/server/Modules.luau`: `MovementGuard` after `CharacterService`.
- Test: `tests/shared/Config/Config.spec.luau` (network defaults), `tests/shared/Skate/MovementCheck.spec.luau`, `tests/server/MovementGuard.spec.luau`

**Interfaces:**
- Produces:
  ```lua
  export type Verdict = "Ok" | "Strike" | "Return"
  MovementCheck.new(movement: Config.MovementConfig, network: Config.NetworkConfig): MovementCheck
  MovementCheck.reset(self, player: PlayerId, position: Vector3, now: number)
  MovementCheck.sample(self, player: PlayerId, position: Vector3, now: number): Verdict
  MovementCheck.lastValid(self, player: PlayerId): Vector3?
  MovementCheck.forget(self, player: PlayerId)
  -- MovementGuard: dependencies { "Config", "CharacterService" }; deps.Log (default warn), deps.Clock (default os.clock)
  MovementGuard.step(self, dt: number)
  ```
- **`sample` rules:**
  - The first sample for a player is a reset (`Ok`).
  - `allowed = hardCap × speedTolerance × (now − last time)`, and `delta` is the move since the last sample with its downward part removed.
  - **One huge move:** `|delta| > guardTeleportFactor × allowed` → `Return`.
  - **Too fast:** `|delta| > allowed` → a strike; the `guardStrikes`-th strike in a row → `Return`; otherwise `Strike`.
  - **Within the limit:** `Ok`. It clears the strikes and makes this position the last valid one.
  - A `Return` re-bases the record at the last valid position, with strikes cleared.
- **`MovementGuard`:**
  - Every `guardSampleSeconds` of `step`, it samples `CharacterService:holders()` roots.
  - An anchored root is reset, not judged.
  - On `Return`, it pivots the character to the last valid position with its current rotation and logs `[BloxChampions] MovementGuard: returned <player>`.
  - `placed` resets the player; `characterRemoved` forgets them. `start` connects `Heartbeat` to `step`.

- [ ] **Step 1: Write the failing tests**

```lua
-- MovementCheck.spec. Allowed per 0.25 s sample: 140 × 1.2 × 0.25 = 42 studs.
	it("returns a skater who is too fast for guardStrikes samples in a row to the last valid place", function()
		local check = MovementCheck.new(movement, network)
		check:reset("A", Vector3.zero, 0)
		expect(check:sample("A", Vector3.new(0, 0, -30), 0.25)).toBe("Ok")
		expect(check:sample("A", Vector3.new(0, 0, -80), 0.5)).toBe("Strike")
		expect(check:sample("A", Vector3.new(0, 0, -130), 0.75)).toBe("Strike")
		expect(check:sample("A", Vector3.new(0, 0, -180), 1)).toBe("Return")
		Fixtures.expectNear(check:lastValid("A") :: Vector3, Vector3.new(0, 0, -30))
	end)

	it("forgives the strikes once the skater is back under the limit", function()
		local check = MovementCheck.new(movement, network)
		check:reset("A", Vector3.zero, 0)
		check:sample("A", Vector3.new(0, 0, -50), 0.25)
		check:sample("A", Vector3.new(0, 0, -100), 0.5)
		expect(check:sample("A", Vector3.new(0, 0, -130), 0.75)).toBe("Ok")
		expect(check:sample("A", Vector3.new(0, 0, -180), 1)).toBe("Strike")
	end)

	it("returns at once a skater who moves farther than guardTeleportFactor allows in one sample", function()
		local check = MovementCheck.new(movement, network)
		check:reset("A", Vector3.zero, 0)
		expect(check:sample("A", Vector3.new(0, 0, -85), 0.25)).toBe("Return") -- more than 2 × 42
	end)

	it("never counts falling", function()
		local check = MovementCheck.new(movement, network)
		check:reset("A", Vector3.new(0, 100, 0), 0)
		expect(check:sample("A", Vector3.zero, 0.25)).toBe("Ok")
	end)

	it("starts over from a reset, so the server's own jumps never count", function()
		local check = MovementCheck.new(movement, network)
		check:reset("A", Vector3.zero, 0)
		check:reset("A", Vector3.new(500, 0, 0), 0.2)
		expect(check:sample("A", Vector3.new(510, 0, 0), 0.45)).toBe("Ok")
	end)
```

`MovementGuard.spec` uses a fake `CharacterService`: `holders()` returns one rig's holder, plus real `Signal`s for `placed` and `characterRemoved`. It also passes a fake clock that `step` advances and a recording `Log`.
- `returns a cheater to their last valid place and logs it`:
  - Pivot the rig 50 studs further along −Z before each of four `step(0.25)` calls.
  - After the fourth, the root is back at the second sample's position: the first is the baseline and the second the last valid.
  - `Log` got one line containing the player's id.
- `leaves frozen skaters alone and trusts the server's placements`:
  - Anchor the root, pivot it 500 studs and `step(0.25)`: no log.
  - Unanchor, fire `placed` after another 500-stud pivot and `step(0.25)`: no log.
- `forgets a character that is gone`: fire `characterRemoved`; the check's `lastValid` for the player is nil.

The `Config.spec` network test gains `guardSampleSeconds = 0.25`, `speedTolerance = 1.2`, `guardStrikes = 3` and `guardTeleportFactor = 2`.

- [ ] **Step 2:** Run `testPathPattern = "(Config|MovementCheck|MovementGuard)"`; expected FAIL.
- [ ] **Step 3:** Implement as specified.
- [ ] **Step 4:** Run, then the full suite. Expected **372 tests** (364 + 8; the network defaults test is changed, not added).
- [ ] **Step 5: Phase playtest.** Expect exactly `Server ready … modules=7` and `Client ready … modules=3`.
  - Skate with W, LeftShift and Space for 5 s: no `MovementGuard` line.
  - From the server, pivot the character 200 studs and wait 0.3 s: the character is back.
  - Kill the character: it respawns at hover height on its pad, skates, and nothing is logged.
  - Stop play and check the console is clean.
  - Write the observations to the ledger.
- [ ] **Step 6:** Static checks and commit: `feat(skate): return skaters who move faster than skating allows`.

---

## After the tasks

- **The fresh end-of-phase reviewer:** exactly one, a general-purpose agent on `opus`, given the plan, the spec, this Review Focus and the ledger.
- **The review-fixes issue and PR:** every finding is fixed test-first.
- **Merges:** in order, with `--merge`, then the Rojo-safe `main` sync.
- **The phase summary to the owner:** what changed, the numbers (the `SkateController` step time, the lap time at cruise against the 10–12 s target), every ruling with its cost if wrong, and what's next (Phase 6, Actions).
