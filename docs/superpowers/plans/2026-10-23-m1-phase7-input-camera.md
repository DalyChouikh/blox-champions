# M1 Phase 7 — Input and Camera Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The game gets its own camera and controls on every device (spec §8.3–8.5).
- A third-person chase camera, mouse-locked on PC, follows the skater. It rolls with them up the walls and over the roof, never passes through the arena, and widens its view with speed.
- Ball Focus keeps the ball in view. Spectators watch the ball.
- Phones and tablets get our own stick and buttons.
- Roblox's conflicting defaults are switched off: shift lock, the player list on Tab, its character and camera keys, and its touch controls.

**Architecture:**
- **Pure modules**, unit-tested with exact numbers:
  - `Camera/ChaseCamera` holds the camera's up, heading, pitch and field of view, and steps them from the look input, the skater, Ball Focus and the recenter rule;
  - `Input/TouchStick` turns a touch's offset into a stick.
- **`CameraController`** (client) owns `workspace.CurrentCamera` as `Scriptable`. It also owns the mouse lock, the wall check, Ball Focus and the spectator view.
- **`InputController`** gains:
  - the look and Ball Focus actions;
  - the touch hooks (a stick pad and a button per control);
  - a pause while Roblox's menu is open.
- **`TouchControls`** (client) builds the touch stick and buttons from `Config.Input.touch`. It names and shows each button for what it does now, through `ActionController:keyAction`.
- **`RobloxDefaults`** (client) switches off what conflicts.
- **`RideSurfaces`** (client) is the one ray filter that skating, poses and the camera share.
- **`FrameController` keeps one order per frame:** physics steps (skate → actions → poses) and render steps (camera → touch controls).

**Tech Stack:** Luau (`--!strict`), Jest-Lua 3.10.0 in Studio through the Roblox Studio MCP, Rojo 7.7.1, StyLua 2.6.0, selene 0.32.0, luau-lsp 1.70.1 (`bash scripts/analyze.sh`).

**Spec:** `docs/superpowers/specs/2026-10-21-m1-foundation-core-match-design.md`:
- §1.2 (PC, gamepad and mobile; mobile verified with Studio device emulation);
- §8.2 (Ball Focus, `Input.ballFocusMode`);
- §8.3 (controls), §8.4 (camera: `distance 12`, `height 4`, FOV `70 → 90` toward `hardCap`, mouse lock, Ball Focus, spectators follow the ball), §8.5 (Roblox defaults);
- §12.2 (budgets), §14 (phase 7).

## Verified facts this plan relies on (probed in Studio Play, 2026-10-23)

1. **Roblox's default contexts:**
   - `StarterPlayer.PlayerModule.InputContexts.CharacterContext` (priority 150, no sink) binds `MoveAction`, `JumpAction` and eleven `AbilityAction`s. Our `SkateControls` (1000, sink) hides those on our keys. **C, V, G, X, DPadDown, DPadRight and DPadLeft still reach Roblox's AbilityActions** (a C press fired `AbilityAction8`).
   - Roblox's `AvatarAbilitiesInterface:isEnabled()` is `humanoid and not humanoid.EvaluateStateMachine`, which is true on our clients (Phase 5 turns the state machine off).
   - `CharacterContext.Enabled = false` stays false across a respawn.
2. **`CameraContext`** (100, no sink) binds `CameraRotationAction` to `MouseDelta` (`Vector2Scale` 0.008727, 0.00672), `Thumbstick2` (4.189, −3.225), `TouchDelta` (0.01745, 0.01152) and `TrackpadPan`. That's 0.5°, 0.385° per pixel; 240°, −185° per second; and 1°, 0.66° per pixel.
   - Roblox's own `CameraInput.getRotation(dt)` returns `cameraRotationAction:GetState() * dt`, so **a rotation action's state is a rate** and a frame's turn is the state times `dt`.
   - It scales the mouse and trackpad bindings by `UserGameSettings.MouseSensitivity` and the gamepad binding by `GamepadCameraSensitivity`. It flips every binding's `Vector2Scale.Y` for `GetCameraYInvertValue()`.
   - Simulated mouse moves from the MCP tool arrive with a zero delta, so `MouseDelta` can only be tested with a real mouse.
3. **`CameraType = Scriptable` turns Roblox's camera off.** `CameraModule:ActivateCameraController` disables the active controller for `Scriptable`, and only an active controller writes the camera and calls `UpdateMouseBehavior`. So with a Scriptable camera, the CFrame, FOV and `MouseBehavior` are ours to set.
   - `RunService.PreRender` exists.
   - The Studio assistant resets the camera to `Custom` after each `execute_luau` call. That's a tool notice, and the controller re-asserts `Scriptable` every frame anyway.
4. **Roblox's touch controls:**
   - `GuiService.TouchControlsEnabled = false` hides Roblox's whole touch UI (thumbstick, jump, ability buttons) and disables its touch controller (`ControlModule:UpdateTouchGuiVisibility`, `UpdateActiveControlModuleEnabled`).
   - Roblox's `DynamicThumbstick` uses a `ViewportPosition` action with a `TouchPosition` binding. The binding's `UIModifier` is an invisible `ImageButton` covering the stick area (landscape: 40% wide, the bottom two-thirds tall). `StateChanged` gives the touch position, or `(-1, -1)` when it ends.
   - From the touch's offset Roblox makes `unit × min(1, length / 20 px)`, with a 2 px dead zone and Y flipped. It fires a `Scriptable` binding on the move action.
5. **Two actions in one context bound to the same key both fire** (K: First and Second pressed, then both released). So Charge Throw and Ball Focus can share ButtonL2.
6. **Our keys keep firing while Roblox's Escape menu is open.** E fired `Tackle.Pressed` with `GuiService.MenuIsOpen == true`.
7. **Other settings:**
   - `StarterGui:SetCoreGuiEnabled(PlayerList, false)` from the client takes effect (`GetCoreGuiEnabled` read true, then false).
   - `UserInputService.PreferredInput` exists (`KeyboardAndMouse` in Studio).
   - `StarterPlayer.EnableMouseLockOption` is true in the place. Rojo writes `"$properties": { "EnableMouseLockOption": false }` on `StarterPlayer` into a built place (checked in a `.rbxlx`).
8. **Two client modules build the same ride-surface ray filter today:** `SkateController.refreshSurfaces` and `PoseController.refreshSurfaces`. The camera's wall check would be a third.

## Owner decisions (2026-10-23)

1. **The camera rolls with you.** Its up follows the surface you ride, smoothly. On a wall the view tilts; on the roof it turns upside down, like a loop. It always stays inside the tube.
2. **Free look, plus a gentle swing back on gamepad and touch.** With a mouse, only the mouse turns the camera. On gamepad and touch, once the look input has rested about 0.5 s, the camera eases behind the way you skate.
3. **Touch:**
   - the stick appears where your thumb lands on the left side;
   - the buttons sit on the right, each shown only when it can be used;
   - the Tackle button reads Tackle / Dive / Dodge, and the Pass button reads Pass / Call;
   - one button is Throw (hold to charge) with the ball, and Focus (tap to toggle) without it;
   - Attach shows only when you are right behind a teammate;
   - swiping on the right side turns the camera.

## Global Constraints

- **Everything from Phases 1–6 holds:**
  - `--!strict`;
  - StyLua, selene and `bash scripts/analyze.sh` clean;
  - lines at most 120 columns, comments included (StyLua never wraps comments);
  - relative requires in `src/`, service-path requires in tests;
  - `JestGlobals` only;
  - annotate what strict mode can't infer (singleton unions in locals and loop variables, `x or {}`; tables are invariant: a `{ Union }` is not a `{ string }`);
  - selene rejects `assert(x)` without a message.
- **The pure core touches no Instance:** `src/shared/{Rules,Ball,Skate,Actions,Arena/Geometry,Config,Net/RateLimiter,Net/Schemas,Util}` plus the new `src/shared/Camera` and `src/shared/Input`.
- **No gameplay literals** outside `src/shared/Config/*`: every number, key, label and layout position comes from `Config.Camera`, `Config.Input` or `Config.UI`.
- **Names are spelled once:** tags in `Arena/Tags` (the new `Ball`); action names in `Config/Actions`; input action names in `InputController`; ride-surface rays in `RideSurfaces`.
- **Client modules are `Loader` modules with an explicit exported type** (declare `start: (...)?` when there is none).
  - `init(deps)` takes fakes in tests (`deps.Camera`, `deps.Mouse`, `deps.PreferredInput`, `deps.MenuOpen`, `deps.GuiService`, `deps.Parent`, …) and touches no global state.
  - `start()` holds every global effect.
- **One frame order on the client:** `FrameController` alone connects `RunService` (PreSimulation: skate → actions → poses; PreRender: camera → touch controls). Never connect a per-frame event in another module. **Roblox runs `PreSimulation` handlers in reverse connection order** (measured in Phase 6).
- **Budgets** (spec §12.2): `CameraController.step` and `TouchControls.step` each under **0.1 ms**, measured in their tests.
  - No per-frame allocations beyond the camera's one `CFrame` and its one ray. Records are reused; touch-button properties are written only when they change.
- **Tests:**
  - Instances live under a uniquely named `…Test` folder or `ScreenGui` and are removed in `afterEach`.
  - Compare names or booleans, never an Instance that might fail.
  - Yield once before asserting on a Roblox event (`Pressed`, `StateChanged`).
  - Shared helpers live only in `tests/Fixtures.luau` (`Fixtures.root`, `Fixtures.scriptedBinding(context, name)`).
  - **Prove each guard with a mutation** and record it.
  - Keep timings off exact boundaries.
- **Process:**
  - one issue and one stacked branch per task, `CONTRIBUTING.md` naming, one type label plus one area label;
  - commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, PR bodies with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## How tests run

As in Phase 6:
- `rojo serve test.project.json` stays running and connected.
- Tests run through `execute_luau` (Edit) in a spawned thread that stores the summary in `shared.BloxFocus` / `shared.BloxSuite`, read by a second call.
- Check a changed module's `.Source` in Studio before debugging a test that disagrees with the code.

The suite has **496 tests** before this phase. Each task states its new tests and the new total; a different total is a finding to rule on.

After this phase the playtest console must read exactly `[BloxChampions] Server ready: mode=NormalChampions, modules=8` and `[BloxChampions] Client ready: mode=NormalChampions, modules=10`.

## Review Focus

1. **Roblox's Escape menu is open** (measured: our keys still act). Every key stops, and every hold lets go, until it closes.
   - Task 4: `stops every key while Roblox's menu is open, and lets go of every hold`.
2. **The camera behind a wall or under the roof.** It pulls in in front of the arena, never closer than `minDistance`, and never sees through it.
   - Task 3: `pulls in in front of a hit, never closer than minDistance`.
   - Task 5: `pulls in in front of a wall behind the skater`.
3. **A kickoff or a respawn with the camera turned away or rolled.** Every player starts looking down their facing, level, upright on their surface.
   - Task 5: `faces down the skater's facing during the kickoff freeze`, `starts behind a new character`.
4. **No character and no ball** (a spectator during the kickoff countdown, when the ball is hidden). The camera holds still, with no error.
   - Task 6: `holds still with neither a character nor a ball`.
5. **The device changes mid-play** (a touch player plugs in a gamepad). Touch controls hide, the mouse lock follows the device, and the swing-back follows the device.
   - Task 5: `locks the mouse to the center with a mouse, and frees it on other devices or while Roblox's menu is open`.
   - Task 8: `shows only on touch`.

## Decisions not spelled out in the spec (for owner review)

1. **The look input is a rate, as in Roblox's own camera** (fact 2): a frame's turn is the state × `dt`. The defaults are Roblox's own scales. The player's Roblox mouse and gamepad sensitivity and Y-invert settings apply, as they do for Roblox's camera. Cost if wrong: tuning.
2. **The camera updates in PreRender**, after physics, so it shows where the skater is drawn. Skating and aiming read the camera of the frame before. Cost if wrong: none found.
3. **During the kickoff freeze, the camera holds behind the skater's spawn facing**, so everyone starts looking down the track. Cost if wrong: no looking around during the 3 s countdown.
4. **The swing-back turns the heading only**, never the pitch. It turns only while the skater moves faster than `recenterMinSpeed` (10 studs/s). Cost if wrong: tuning.
5. **Ball Focus:**
   - It turns heading and pitch toward the ball, and takes over from the swing-back. Hold mode (PC, gamepad) ends on release; toggle mode (touch) ends on a second tap. Catching the ball ends either.
   - The camera then stays where it turned; it doesn't snap back.
   - Cost if wrong: tuning.
6. **The spectator camera** (no character) follows the ball, with world up, 30 studs back and 6 up, under the same look controls and swing-back. With no ball either, it holds still. Cost if wrong: tuning.
7. **We switch off Roblox's character and camera input contexts** (not only their keys), its touch controls and the player list. Our game drives the character, the camera and the touch UI. Cost if wrong: a future Roblox feature riding those contexts would need them back.
8. **Our controls pause while Roblox's menu is open:** `SkateControls.Enabled = false`, so holds let go. Cost if wrong: none.
9. **The mouse cursor stays visible at the screen center while locked**, as an aim mark, until the HUD draws a reticle. Cost if wrong: visual only.
10. **Which key starts which action becomes data:** `Config.Input.actions`, chosen by each action's `requires.ball`. That's one rule for the keys, the touch labels and Phase 8's hints. Cost if wrong: none.
11. **Touch buttons are plain Roblox UI** (`TextButton`s), not React. Phase 8's React HUD sits beside them, and the art pass restyles them. The PC and gamepad control hints come with the Phase 8 HUD, built on `ActionController:keyAction`. Cost if wrong: Phase 8 reworks two UI styles into one.
12. **Multi-touch** (the stick and a swipe at once) can't be emulated with a mouse in Studio. It goes on Phase 9's real-device checklist. Cost if wrong: a multi-touch fault surfaces in Phase 9.

**Not in this phase:**
- **Phase 8:** the score tab (Tab / ButtonSelect / a HUD button), the PC and gamepad control hints (built on `ActionController:keyAction`), the reticle, the call-pass hand icon and `DENIED!`.
- **Phase 9:** tuning every camera and touch number; multi-touch and the look feel on a real phone; the multi-client checklist.

## File Structure

```
src/shared/Config/Camera.luau          new area: distance, height, FOV, pitch limits, roll, swing-back, Ball Focus,
                                       wall check, spectator
src/shared/Config/{init,Input,UI}.luau  look bindings, Ball Focus keys and modes, key → actions, touch layout, labels
src/shared/Camera/ChaseCamera.luau     pure: up, heading, pitch, FOV stepped from the look input and the skater
src/shared/Input/TouchStick.luau       pure: a touch's offset as a stick
src/shared/Util/Vectors.luau           rotateAbout
src/shared/Arena/Tags.luau             Ball
src/server/BallService.luau            tags its ball part
src/client/RideSurfaces.luau           the one ride-surface ray filter
src/client/CameraController.luau       the camera, mouse lock, wall check, Ball Focus, spectator
src/client/RobloxDefaults.luau         Roblox's conflicting defaults off
src/client/TouchControls.luau          touch stick and buttons
src/client/{InputController,SkateController,PoseController,ActionController,FrameController,Modules}.luau
default.project.json, test.project.json    StarterPlayer.EnableMouseLockOption = false
```

---

### Task 1: Camera, look, Ball Focus and touch config (labels `feature`, `input`)

**Issue:** to be created · **Branch:** `feat/<issue>-camera-input-config` · **Base:** `main`

**Files:**
- Create: `src/shared/Config/Camera.luau`
- Modify: `src/shared/Config/init.luau` (area `Camera`; re-export `CameraConfig`, `Control`, `ActionKey`, `LookBinding`, `FocusMode`, `TouchLayout`), `src/shared/Config/Input.luau`, `src/shared/Config/UI.luau`
- Test: `tests/shared/Config/Config.spec.luau`

**Interfaces:**
- Produces:
  ```lua
  export type CameraConfig = {
  	distance: number, height: number, minDistance: number, collisionMargin: number,
  	fovBase: number, fovMax: number, fovResponse: number,
  	minPitchDeg: number, maxPitchDeg: number,
  	rollResponse: number,
  	recenterDelay: number, recenterResponse: number, recenterMinSpeed: number,
  	ballFocusResponse: number,
  	spectator: { distance: number, height: number },
  }
  -- Input additions
  export type Control = "jump" | "pump" | "brake" | "attach" | "tackle" | "uppercut" | "pass" | "throw" | "ballFocus"
  export type ActionKey = "tackle" | "uppercut" | "pass" | "throw"
  export type LookBinding = { key: Enum.KeyCode, degPerUnit: Vector2 }
  export type FocusMode = "Hold" | "Toggle"
  export type TouchLayout = {
  	stickArea: UDim2, stickDeadZone: number, stickRadius: number, buttonSize: UDim2,
  	buttons: { jump: UDim2, pump: UDim2, brake: UDim2, attach: UDim2, tackle: UDim2, uppercut: UDim2,
  		pass: UDim2, throw: UDim2 },
  }
  InputConfig += {
  	look: { mouse: LookBinding, stick: LookBinding, touch: LookBinding },
  	ballFocus: { Enum.KeyCode }, ballFocusMode: FocusMode, touchBallFocusMode: FocusMode,
  	-- the actions a key may start, in order; the first whose requires.ball fits is the one
  	actions: { tackle: { ActionName }, uppercut: { ActionName }, pass: { ActionName }, throw: { ActionName } },
  	touch: TouchLayout,
  }
  UIConfig += { controlLabels: { Jump: string, Pump: string, Brake: string, Attach: string, Tackle: string,
  	Dive: string, Dodge: string, Uppercut: string, ChargeThrow: string, Pass: string, CallPass: string,
  	BallFocus: string } }
  ```

**Default values:**
- **Camera** (spec §8.4 gives distance, height and the FOVs; the rest are tuning starts):
  - `distance 12`, `height 4`, `minDistance 2`, `collisionMargin 0.5`;
  - `fovBase 70`, `fovMax 90`, `fovResponse 6` (per s);
  - `minPitchDeg −70`, `maxPitchDeg 60`;
  - `rollResponse 8`;
  - `recenterDelay 0.5`, `recenterResponse 2.5`, `recenterMinSpeed 10`;
  - `ballFocusResponse 10`;
  - `spectator { distance 30, height 6 }`.
- **Input:**
  - `look`, Roblox's own scales (fact 2):
    - `mouse { MouseDelta, (0.5, 0.385) }` (degrees per pixel);
    - `stick { Thumbstick2, (240, −185) }` (degrees per second at full tilt);
    - `touch { TouchDelta, (1, 0.66) }`.
  - `ballFocus { MouseRightButton, ButtonL2 }`, `ballFocusMode "Hold"`, `touchBallFocusMode "Toggle"`.
  - `actions`: `tackle { "Tackle", "Dodge" }`, `uppercut { "Uppercut" }`, `pass { "Pass", "CallPass" }`, `throw { "ChargeThrow" }`.
  - `touch` (button centers as screen fractions, landscape):
    - `stickArea UDim2.fromScale(0.4, 2/3)` (anchored bottom-left), `stickDeadZone 2`, `stickRadius 20` (px, Roblox's), `buttonSize UDim2.fromOffset(72, 72)`;
    - buttons: `uppercut (0.92, 0.42)`, `pass (0.81, 0.52)`, `tackle (0.92, 0.62)`, `attach (0.70, 0.70)`, `throw (0.81, 0.70)`, `brake (0.70, 0.88)`, `pump (0.81, 0.88)`, `jump (0.92, 0.82)`, each `UDim2.fromScale`.
- **UI.controlLabels:** Jump "Jump", Pump "Pump", Brake "Brake", Attach "Attach", Tackle "Tackle", Dive "Dive", Dodge "Dodge", Uppercut "Uppercut", ChargeThrow "Throw", Pass "Pass", CallPass "Call", BallFocus "Focus".

**Schema rules:**
- **Camera:**
  - distances and `height` > 0, except `collisionMargin ≥ 0`;
  - `minDistance ≤ distance` (message `minDistance must be at most distance`);
  - `0 < fovBase ≤ fovMax ≤ 120` (`fovMax must be at least fovBase`);
  - `minPitchDeg` −89..0, `maxPitchDeg` 0..89;
  - responses and `recenterDelay ≥ 0`;
  - `spectator.distance > 0`, `spectator.height ≥ 0`.
- **Input:**
  - `look.*.key` is an `Enum.KeyCode` and `degPerUnit` a `Vector2`;
  - modes are one of Hold / Toggle;
  - each `actions` list is non-empty and names known actions (`Actions.names` strings);
  - touch positions and sizes are `UDim2`, `stickDeadZone ≥ 0` and `stickRadius > stickDeadZone` (message `Input.touch: stickRadius must be above stickDeadZone`).
- **The duplicate-key rule now covers the look keys.** It allows exactly one sharing: `ballFocus` keys that are also `throw` keys (one needs the ball, the other works without it).
- **UI labels are non-empty strings.**

- [ ] **Step 1: Write the failing tests** in `Config.spec`:
  - `has the camera defaults` (`toEqual` on the whole `Camera` table above);
  - the Input defaults test gains `look`, `ballFocus`, both modes, `actions` and `touch`;
  - the UI defaults test gains `controlLabels`;
  - `rejects a camera or touch layout that contradicts itself`:
    - `Camera { fovMax = 60 }` → `Camera: fovMax must be at least fovBase`;
    - `Camera { minDistance = 20 }` → `Camera: minDistance must be at most distance`;
    - `Input { touch = { stickRadius = 1 } }` → `Input.touch: stickRadius must be above stickDeadZone`;
    - `Input { actions = { tackle = { "Fly" } } }` → a message containing `Input.actions.tackle[1]`.
  - The duplicate-key test gains three cases:
    - `ballFocus = { Enum.KeyCode.E }` → `Input: E is bound to more than one action`;
    - `move = { …, sticks = { Enum.KeyCode.Thumbstick2 } }` → `Input: Thumbstick2 is bound to more than one action`;
    - the defaults (ButtonL2 on both throw and ballFocus) → `never.toThrow()`.

  Match Validate's message format (read `Validate.check` and `Validate.list`).
- [ ] **Step 2:** Run `testPathPattern = "shared/Config"`. Expected: FAIL (no `Camera` area, missing Input and UI fields).
- [ ] **Step 3:** Implement. `boundKeys` adds the three look keys and the ballFocus keys that are not also throw keys.
- [ ] **Step 4:** Run, then the full suite. Expected: **498 tests** (+2).
- [ ] **Step 5:** Mutation: let ballFocus share any key (count it never) → the `E` case must fail. Restore. Static checks. Commit `feat(input): camera, look, ball focus and touch settings`.

---

### Task 2: One ride-surface ray filter for the client (labels `chore`, `skate`)

**Issue:** to be created · **Branch:** `chore/<issue>-ride-surfaces` · **Stacked on:** Task 1

**Files:**
- Create: `src/client/RideSurfaces.luau`
- Modify:
  - `src/client/SkateController.luau` and `src/client/PoseController.luau`: drop `refreshSurfaces`, their `RaycastParams` and tag connections, and use `deps.RideSurfaces.params`;
  - `src/client/Modules.luau` (RideSurfaces right after InputController: 7 modules).
- Test: `tests/client/RideSurfaces.spec.luau`; the setups of `SkateController.spec`, `PoseController.spec` and `ActionController.spec` init RideSurfaces and pass it in `deps`.

**Interfaces:**
- Produces:
  ```lua
  export type RideSurfaces = { name: string, dependencies: { string }, init: (...), start: (...),
  	params: RaycastParams,   -- Include, every Tags.RideSurface instance
  	refresh: (self) -> () }   -- start() runs it on every tag added or removed
  ```

- [ ] **Step 1:** Write the failing test `includes every tagged ride surface, and follows tags added and removed`. A part tagged in a test folder is in `params.FilterDescendantsInstances` after `init`, checked with a `table.find(…) ~= nil` boolean. A second part tagged afterward is included after `refresh()`; once its tag is removed and `refresh()` runs, it is gone.
- [ ] **Step 2:** Run `testPathPattern = "(RideSurfaces|SkateController|PoseController|ActionController)"`. Expected: FAIL (module missing).
- [ ] **Step 3:** Implement. The two controllers read `self._surfaces.params` (one `RaycastParams`, shared).
- [ ] **Step 4:** Run, then the full suite. Expected: **499 tests** (+1).
- [ ] **Step 5:** Mutation: `refresh` doing nothing → the new test fails. Restore. Static checks. Commit `chore(skate): one ride-surface ray filter for the client`.

---

### Task 3: ChaseCamera (labels `feature`, `input`)

**Issue:** to be created · **Branch:** `feat/<issue>-chase-camera` · **Stacked on:** Task 2

**Files:**
- Create: `src/shared/Camera/ChaseCamera.luau`
- Modify: `src/shared/Util/Vectors.luau`
- Test: `tests/shared/Camera/ChaseCamera.spec.luau`, `tests/shared/Util/Vectors.spec.luau`

**Interfaces:**
- Produces:
  ```lua
  Vectors.rotateAbout(vector: Vector3, axis: Vector3, angle: number): Vector3   -- right-handed, unit axis
  export type Target = {
  	up: Vector3,       -- the up to roll toward (the skater's surface up; world up for a spectator)
  	travel: Vector3,   -- the velocity the swing-back turns behind
  	look: Vector2,     -- this frame's turn in radians: x > 0 turns right, y > 0 tips down
  	recenter: boolean, -- the device swings back (gamepad, touch)
  	aimAt: Vector3?,   -- a direction to turn toward (Ball Focus)
  	speed: number,     -- for the field of view
  }
  ChaseCamera.new(camera: Config.CameraConfig, hardCap: number, up: Vector3, forward: Vector3): ChaseCamera
  -- fields: up (unit), forward (unit, ⟂ up), pitch (radians), fov (degrees), idle (seconds since a look input)
  ChaseCamera:reset(up: Vector3, forward: Vector3)   -- behind `forward` on `up`, pitch 0, idle 0
  ChaseCamera:step(target: Target, dt: number)
  ChaseCamera:lookVector(): Vector3                  -- forward·cos(pitch) + up·sin(pitch)
  ChaseCamera.targetFov(camera: Config.CameraConfig, speed: number, hardCap: number): number
  ChaseCamera.pullIn(camera: Config.CameraConfig, desired: number, hit: number?): number
  ```
- **`step`, in order** (`k(r) = 1 − e^(−r·dt)`):
  1. **Roll.** Turn `up` toward `target.up` by `angle × k(rollResponse)`, where `angle = atan2(|up × t|, up · t)`. Rotate `forward` by the same rotation. Its axis is `up × t`, or `forward × up` (the camera's right, a loop) when the two are opposite. Then lay `forward` back onto the plane ⟂ `up`.
  2. **Look.**
     - A non-zero `look`: `idle = 0`; `forward = rotateAbout(forward, up, −look.X)`; `pitch = clamp(pitch − look.Y, rad(minPitchDeg), rad(maxPitchDeg))`.
     - A zero `look`: `idle += dt`.
  3. **Ball Focus** (`aimAt` given):
     - turn `forward` toward `aimAt` laid on the surface, by `k(ballFocusResponse)` of the angle (unchanged when that lies on no surface);
     - move `pitch` toward `asin(aimAt.Unit · up)`, clamped, by the same fraction;
     - skip the swing-back.
  4. **Swing-back** (no `aimAt`, `recenter`, `idle ≥ recenterDelay`, `|travel on the surface| ≥ recenterMinSpeed`): turn `forward` toward the travel's direction by `k(recenterResponse)` of the angle.
  5. **Field of view:** `fov += (targetFov − fov) × k(fovResponse)`.
- **`targetFov`** = `fovBase + (fovMax − fovBase) × clamp(speed / hardCap, 0, 1)`.
- **`pullIn`** = `desired`, or `hit − collisionMargin` when `hit` is closer, never below `minDistance`.

- [ ] **Step 1: Write the failing tests** (config `Config.defaults().Camera`, hardCap 140, up Y, forward −Z unless stated; vectors within 1e-3):
  - `Vectors.spec`: `rotates a vector about an axis, right-handed`: `rotateAbout((1,0,0), Y, π/2) ≈ (0,0,−1)`; `rotateAbout((0,0,−1), Y, −π/2) ≈ (1,0,0)`.
  - `ChaseCamera.spec`:
    - `looks along its heading, level, at fovBase`: `lookVector ≈ (0,0,−1)`, `fov == 70`, `pitch == 0`.
    - `turns right and tips down with the look input, within the pitch limits`:
      - `look (π/2, 0)` → `forward ≈ (1,0,0)`;
      - then `look (0, rad 30)` → `lookVector ≈ (0.866, −0.5, 0)`;
      - then `look (0, rad 100)` → `pitch ≈ rad(−70)`;
      - then `look (0, −rad 500)` → `pitch ≈ rad(60)`.
    - `rolls toward the surface it rides, keeping its heading on that surface`:
      - target up +X, `dt 0.1` → `up · Y ≈ cos(rad(90 × (1 − e^−0.8)))` (49.56°, within 1e-3);
      - `dt 10` → `up ≈ (1,0,0)`, `forward ≈ (0,0,−1)`.
    - `rolls over the top like a loop when its up turns upside down`: target up −Y, `dt 10` → `up ≈ (0,−1,0)`, `forward ≈ (0,0,1)`.
    - `swings behind the travel once the look input rests, only when the device allows it`: travel `(50,0,0)`, `recenter = true`:
      - `step 0.4` → forward unchanged (idle 0.4);
      - `step 0.2` → turned toward +X by `90° × (1 − e^−0.5)` = 35.41° (check `forward · X ≈ sin(35.41°)`);
      - `recenter = false`, 2 s → unchanged;
      - travel `(5,0,0)` (below `recenterMinSpeed`) → unchanged;
      - a look input in the same step resets `idle` → unchanged.
    - `turns toward the ball with Ball Focus, within the pitch limits`:
      - `aimAt (1,1,0)`, `dt 10` → `forward ≈ (1,0,0)`, `pitch ≈ rad(45)`;
      - `aimAt (0,1,0)` → forward unchanged, `pitch ≈ rad(60)`, no NaN.
    - `widens the field of view with speed toward hardCap`:
      - `targetFov` at speeds 0, 70, 140 and 300 → 70, 80, 90 and 90;
      - from 70, `speed 140`, `dt 0.1` → `fov ≈ 70 + 20 × (1 − e^−0.6)` (79.02).
    - `pulls in in front of a hit, never closer than minDistance`: `pullIn(desired 12)` with no hit → 12; with hit 8 → 7.5; with hit 1 → 2.
    - `resets behind a facing, level`: after turns and a pitch, `reset(Y, (1,0,0))` → `forward ≈ (1,0,0)`, `pitch == 0`, `idle == 0`.
- [ ] **Step 2:** Run `testPathPattern = "(ChaseCamera|Vectors)"`. Expected: FAIL.
- [ ] **Step 3:** Implement. Vector3 math only: no table or CFrame per step.
- [ ] **Step 4:** Run, then the full suite. Expected: **509 tests** (+10: nine ChaseCamera tests, one Vectors test).
- [ ] **Step 5:** Mutations, each restored:
  - the swing-back ignoring `recenter` → the swing test fails;
  - the loop fallback axis replaced by up × forward → the loop test fails.

  Static checks. Commit `feat(input): a chase camera that rolls with the skater`.

---

### Task 4: InputController: look, Ball Focus, touch hooks, menu pause (labels `feature`, `input`)

**Issue:** to be created · **Branch:** `feat/<issue>-look-input` · **Stacked on:** Task 3

**Files:**
- Modify: `src/client/InputController.luau`
- Test: `tests/client/InputController.spec.luau`

**Interfaces:**
- Produces:
  ```lua
  export type CameraKeys = { look: Vector2, ballFocus: boolean, ballFocusPressed: boolean }
  InputController.newCameraKeys(): CameraKeys
  InputController:readCamera(into: CameraKeys)   -- look: the Look action's state (radians per second);
                                                 -- ballFocus: held now; ballFocusPressed: pressed since the last read
  InputController:setLookSettings(mouse: number, stick: number, invertY: boolean)
  InputController:bindButton(control: Config.Control, button: GuiButton)   -- a UIButton binding on that control
  InputController:bindTouchStick(pad: GuiButton): InputAction   -- "TouchMove" (ViewportPosition), TouchPosition
                                                                -- while a touch that began on `pad` lasts
  InputController:setStick(stick: Vector2)                      -- fires Move's "TouchStick" Scriptable binding
  InputController:setPaused(paused: boolean)                    -- SkateControls.Enabled = not paused
  ```
- **The actions:**
  - `Look` (Direction2D) gets one binding per `Config.Input.look` entry, with `Vector2Scale` = `degPerUnit` in radians.
  - `BallFocus` (Bool) is bound to `Config.Input.ballFocus` and counted under a new `ballFocus` press.
  - `Move` gains a `TouchStick` Scriptable binding.
- **`setLookSettings`** works as Roblox's camera does (fact 2): the mouse binding's `Scale = mouse`, the stick binding's `Scale = stick`, and every look binding's `Vector2Scale.Y` negated when `invertY`. Calling it again with the same `invertY` changes nothing.
- **Wiring:**
  - `init` connects `deps.GuiService or GuiService` `MenuOpened`/`MenuClosed` to `setPaused`, so a menu opened during `init` is caught too;
  - `start` reads `UserSettings():GetService("UserGameSettings")` into `setLookSettings` and on its `MouseSensitivity` / `GamepadCameraSensitivity` changes.

- [ ] **Step 1: Write the failing tests:**
  - `binds the look to the mouse, the right stick and touch, in radians`: three bindings with keys `MouseDelta`, `Thumbstick2` and `TouchDelta`, and `Vector2Scale` within 1e-6 of `rad(0.5), rad(0.385)`, `rad(240), rad(−185)`, `rad(1), rad(0.66)`.
  - `scales the look by the player's Roblox settings`: `setLookSettings(2, 0.5, true)` → mouse `Scale 2`, stick `Scale 0.5`, every `Vector2Scale.Y` negated. Calling `setLookSettings(2, 0.5, true)` again leaves them; `(1, 1, false)` restores the defaults.
  - `reads the look and Ball Focus once per step`:
    - scripted `Look` `Fire(Vector2.new(2, −1))` → `readCamera` gives `look (2, −1)`;
    - a `BallFocus` press (yield) → `ballFocusPressed` true once, then false;
    - held → `ballFocus` true until released.
  - `moves with the touch stick, and makes a stick pad the touch's modifier`:
    - `bindTouchStick(pad)` → a `TouchMove` action whose `TouchPosition` binding has `UIModifier == pad` (boolean);
    - `setStick(Vector2.new(0, 1))` → `read` gives `move (0, 1)`;
    - `setStick(Vector2.zero)` → `(0, 0)`.
  - `binds a touch button to its control`: `bindButton("jump", button)` → a binding under `Jump` with `UIButton == button` (boolean); `"ballFocus"` → under `BallFocus`.
  - `stops every key while Roblox's menu is open, and lets go of every hold`:
    - a fake `GuiService` (two `Signal`s);
    - Pump held through a scripted binding; `MenuOpened:Fire()` → `read` gives `pump == false` and a Tackle press gives no `tackle`;
    - `MenuClosed:Fire()` and Pump fired again → `pump == true`.
- [ ] **Step 2:** Run `testPathPattern = "InputController"`. Expected: FAIL.
- [ ] **Step 3:** Implement. A control name maps to its action name in one record in InputController. The `Presses` record gains `ballFocus`.
- [ ] **Step 4:** Run, then the full suite. Expected: **515 tests** (+6).
- [ ] **Step 5:** Mutation: `setPaused` ignored → the menu test fails. Restore. Static checks. Commit `feat(input): look and ball focus keys, touch hooks, and a pause while Roblox's menu is open`.

---

### Task 5: CameraController (labels `feature`, `input`)

**Issue:** to be created · **Branch:** `feat/<issue>-camera-controller` · **Stacked on:** Task 4

**Files:**
- Create: `src/client/CameraController.luau`
- Modify:
  - `src/client/SkateController.luau`: the bound root becomes public, `root: BasePart?` (rename `_root`);
  - `src/client/FrameController.luau`: a `render(dt)` step on `PreRender` that steps the camera;
  - `src/client/Modules.luau`: CameraController after PoseController, 8 modules.
- Test: `tests/client/CameraController.spec.luau`, `tests/client/FrameController.spec.luau`

**Interfaces:**
- Consumes: `ChaseCamera`, `InputController:readCamera`, `RideSurfaces.params`, `SkateController.skater/root/frozen`, `BallCarrier`.
- Produces:
  ```lua
  export type CameraController = { name: string, dependencies: { string }, init: (...), start: (...),
  	step: (self, dt: number) -> (), chase: ChaseCamera.ChaseCamera }
  -- dependencies { "Config", "InputController", "RideSurfaces", "SkateController", "BallCarrier" }
  -- deps.Camera { CFrame, FieldOfView, CameraType } (workspace.CurrentCamera); deps.Mouse { MouseBehavior }
  -- (UserInputService); deps.PreferredInput: () -> Enum.PreferredInput; deps.MenuOpen: () -> boolean;
  -- deps.Raycast (workspace:Raycast)
  FrameController:render(dt: number)   -- PreRender: CameraController:step (TouchControls joins in Task 8)
  ```
- **What a step does:**
  - **Takes over the camera:** sets `CameraType = Scriptable` when it isn't.
  - **Mouse lock:** `MouseBehavior = LockCenter` when `PreferredInput() == KeyboardAndMouse` and not `MenuOpen()`, else `Default`.
  - **Reads the input:** `readCamera`.
  - **With a skater and a root:**
    - `chase:reset(skater.up, skater.forward)` on a new root or while `frozen`;
    - otherwise step the chase with `up = skater.up`, `travel = skater.velocity`, `look = keys.look × dt`, `recenter = PreferredInput() ~= KeyboardAndMouse`, `speed = |velocity|`.
  - **Places the camera:**
    - `focus = root.Position + chase.up × height`;
    - one ray from `focus` along `−look × distance` through `RideSurfaces.params`;
    - `CFrame = CFrame.lookAlong(focus − look × pullIn(distance, hit), look, chase.up)`;
    - `FieldOfView = chase.fov`.
  - **With no skater:** Task 6.

- [ ] **Step 1: Write the failing tests** (a real SkateController on a rig over a 400-stud test floor, as `ActionController.spec` does; fake camera, mouse, `PreferredInput` and `MenuOpen`; DT = 1/60):
  - `takes over the camera: behind and above the skater, level`:
    - `CameraType == Scriptable`;
    - `CFrame.Position ≈ root + (0, 4, 12)` for a skater facing −Z;
    - `LookVector ≈ (0,0,−1)`;
    - `FieldOfView ≈ 70`.
  - `turns with the look input`: scripted `Look` `Fire(Vector2.new((π/2) / DT, 0))`, one step → `LookVector ≈ (1,0,0)`.
  - `locks the mouse to the center with a mouse, and frees it on other devices or while Roblox's menu is open`: `LockCenter` → (`MenuOpen` true) `Default` → (menu closed, `Touch`) `Default` → (`KeyboardAndMouse`) `LockCenter`.
  - `pulls in in front of a wall behind the skater`: a 1-stud-thick wall tagged `RideSurface`, 6 studs behind the focus and tall enough → `(camera − focus).Magnitude ≈ 5.0` (face at 5.5, margin 0.5).
  - `rolls with the skater riding a wall`: `skater.up = +X`, `step(10)` → `CFrame.UpVector ≈ (1,0,0)`.
  - `swings behind the travel on a gamepad but not with a mouse`:
    - `Gamepad`, `skater.velocity = (50,0,0)`, steps for 1 s → `LookVector · X > 0.5`;
    - `KeyboardAndMouse` from a fresh setup → `LookVector ≈ (0,0,−1)`.
  - `faces down the skater's facing during the kickoff freeze`: turn the camera to +X, anchor the root and `SkateController:step(DT)` (sets `frozen`), then a camera step → `LookVector ≈ skater.forward`.
  - `starts behind a new character`: bind SkateController to a second rig facing +X → after a step `LookVector ≈ (1,0,0)`.
  - `widens the view with speed`: `skater.velocity = (0,0,−140)`, `step(10)` → `FieldOfView ≈ 90`.
  - `steps in under 0.1 ms`: 600 steps (look held half the time), mean < 0.0001 s; record the mean.
  - `FrameController.spec`: `renders the camera before each frame is drawn`: fakes record `render(dt)` calling the camera's `step` with that `dt`.
- [ ] **Step 2:** Run `testPathPattern = "(CameraController|FrameController|SkateController)"`. Expected: FAIL.
- [ ] **Step 3:** Implement. `start` sets the real camera's `CameraType` once; FrameController connects `PreRender` in its `start`.
- [ ] **Step 4:** Run, then the full suite. Expected: **526 tests** (+11).
- [ ] **Step 5:** Mutations, each restored:
  - no pull-in → the wall test fails;
  - no reset while frozen → the freeze test fails.

  Static checks. Commit `feat(input): the chase camera follows, rolls, and stays inside the arena`.

---

### Task 6: Ball Focus and the spectator camera (labels `feature`, `input`)

**Issue:** to be created · **Branch:** `feat/<issue>-ball-focus` · **Stacked on:** Task 5

**Files:**
- Modify: `src/shared/Arena/Tags.luau` (`Ball = "Ball"`), `src/server/BallService.luau` (tags each ball part it builds), `src/client/CameraController.luau`
- Test: `tests/server/BallService.spec.luau`, `tests/client/CameraController.spec.luau`

**Interfaces:**
- Produces:
  - `Tags.Ball` on the ball part.
  - `CameraController` finds the ball through `deps.Ball: () -> BasePart?`. The default reads a cache kept by `CollectionService` added/removed signals for `Tags.Ball`, connected in `start`; the cache drops a part that leaves the workspace.
- **Rules:**
  - **Ball Focus** applies only while the local player doesn't carry the ball (`BallCarrier.carrier ~= LocalId`) and a ball exists: `aimAt = ball.Position − focus`.
  - **The mode** is `touchBallFocusMode` when `PreferredInput() == Touch`, else `ballFocusMode`:
    - `Hold` follows `keys.ballFocus`;
    - `Toggle` flips on `keys.ballFocusPressed`;
    - carrying the ball switches it off.
  - **The spectator** (no skater): with a ball, step the chase with world up, `travel = ball velocity`, `focus = ball + Y × spectator.height`, `distance = spectator.distance`. With no ball, leave the camera as it is.

- [ ] **Step 1: Write the failing tests:**
  - `BallService.spec`: `tags its ball part so clients can find it` (`CollectionService:HasTag(BallService.part, Tags.Ball)`).
  - `CameraController.spec`:
    - `turns toward the ball while Ball Focus is held`: a ball part 30 studs to the skater's right; BallFocus held, `step(10)` → `LookVector` within 1e-2 of `(ball − focus).Unit`; released, `step(1)` → unchanged.
    - `ignores Ball Focus while carrying the ball`: `BallCarrier:set(LocalId)`, held → `LookVector ≈ (0,0,−1)`.
    - `toggles Ball Focus with a tap on touch`: `Touch`; one press → after `step(10)` facing the ball; turn away with the look; a second press → no turn back.
    - `follows the ball when the player has no character`: no bound character; ball at `(0, 10, 0)` → `CFrame.Position ≈ (0, 16, 30)`, `LookVector ≈ (0,0,−1)`.
    - `holds still with neither a character nor a ball`: the CFrame set before a step is unchanged after it, no error.
- [ ] **Step 2:** Run `testPathPattern = "(CameraController|BallService)"`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run, then the full suite. Expected: **532 tests** (+6).
- [ ] **Step 5:** Mutation: Ball Focus applied while carrying → `ignores Ball Focus while carrying the ball` fails. Restore. Static checks. Commit `feat(input): ball focus, and a spectator camera that follows the ball`.

---

### Task 7: Roblox's conflicting defaults off (labels `feature`, `input`)

**Issue:** to be created · **Branch:** `feat/<issue>-roblox-defaults` · **Stacked on:** Task 6

**Files:**
- Create: `src/client/RobloxDefaults.luau`
- Modify: `src/client/Modules.luau` (first, 9 modules), `default.project.json` and `test.project.json` (`StarterPlayer` `"$properties": { "EnableMouseLockOption": false }`)
- Test: `tests/client/RobloxDefaults.spec.luau`

**Interfaces:**
- Produces:
  ```lua
  RobloxDefaults:apply(services: { StarterGui: any, GuiService: any, InputContexts: Instance })
  -- SetCoreGuiEnabled(PlayerList, false); GuiService.TouchControlsEnabled = false;
  -- InputContexts.CharacterContext.Enabled = false; InputContexts.CameraContext.Enabled = false
  -- start(): apply with the real services, waiting (in its own thread, with a timeout) for
  -- StarterPlayer.PlayerModule.InputContexts
  ```

- [ ] **Step 1: Write the failing tests:**
  - `turns off the player list, Roblox's touch controls, and its character and camera input`: a fake StarterGui records its calls (`{ PlayerList, false }`); a fake GuiService ends with `TouchControlsEnabled == false`; a Folder holds two InputContexts named `CharacterContext` and `CameraContext`, which end disabled.
  - `keeps Roblox's shift lock off in the place`: `game:GetService("StarterPlayer").EnableMouseLockOption == false`. It fails until both project files set the property and Rojo serve restarts (the owner reconnects).
- [ ] **Step 2:** Run `testPathPattern = "RobloxDefaults"`. Expected: FAIL.
- [ ] **Step 3:** Implement. Edit both project files. Restart `rojo serve test.project.json` and ask the owner to click Connect. Verify `.Source` sync and the property in Edit.
- [ ] **Step 4:** Run, then the full suite. Expected: **534 tests** (+2).
- [ ] **Step 5:** Static checks. Commit `feat(input): switch off Roblox's defaults that clash with our controls`.

---

### Task 8: Touch controls, and what each key does now (labels `feature`, `input`)

**Issue:** to be created · **Branch:** `feat/<issue>-touch-controls` · **Stacked on:** Task 7

**Files:**
- Create: `src/shared/Input/TouchStick.luau`, `src/client/TouchControls.luau`
- Modify:
  - `src/client/ActionController.luau`: `keyAction`, with `chosen` built on it;
  - `src/client/SkateController.luau`: `attachable`;
  - `src/client/FrameController.luau`: `render` steps TouchControls after the camera;
  - `src/client/Modules.luau`: TouchControls after CameraController, 10 modules.
- Test: `tests/shared/Input/TouchStick.spec.luau`, `tests/client/TouchControls.spec.luau`, `tests/client/ActionController.spec.luau`, `tests/client/SkateController.spec.luau`, `tests/client/FrameController.spec.luau`

**Interfaces:**
- Produces:
  ```lua
  TouchStick.vector(origin: Vector2, position: Vector2, deadZone: number, radius: number): Vector2
  -- offset inside deadZone → zero; else offset.Unit × min(1, |offset| / radius), Y flipped (screen down = back)
  ActionController:keyAction(key: Config.ActionKey): Config.ActionName?
  -- the first of Input.actions[key] whose requires.ball fits holding the ball (or not), then its follow-up when
  -- that action runs in the follow-up's window; nil when none fits (an uppercut with the ball, a throw without)
  SkateController.attachable: boolean   -- each step: attached, or a leader found and no cooldown
  export type TouchControls = { name: string, dependencies: { string }, init: (...), start: (...),
  	step: (self, dt: number) -> (), gui: ScreenGui, buttons: { [Config.Control]: TextButton }, pad: ImageButton }
  -- deps.Parent (PlayerGui), deps.PreferredInput
  ```
- **What TouchControls builds:**
  - **The gui:** a `ScreenGui` "TouchControls" (`ResetOnSpawn = false`).
  - **The stick pad:** an invisible `ImageButton` (anchor (0, 1), `Position UDim2.fromScale(0, 1)`, `Size = stickArea`), plus a ring and knob drawn at the touch.
  - **The buttons:** one `TextButton` per `touch.buttons` entry (anchor (0.5, 0.5), its position, `buttonSize`).
  - **Bindings:**
    - `bindButton(control, button)` for every button, and `"ballFocus"` on the throw button too;
    - `bindTouchStick(pad)`, whose `StateChanged` (the touch position, `(-1,-1)` at its end) drives `setStick(TouchStick.vector(…))`.
  - **Each step** (property writes only on change):
    - `gui.Enabled = PreferredInput() == Touch`;
    - the tackle and pass buttons read `controlLabels[keyAction(…)]`;
    - the throw button reads `ChargeThrow` with the ball, `BallFocus` without;
    - uppercut is visible only when `keyAction("uppercut") ~= nil`;
    - attach is visible only when `attachable`.
- **ActionController's `chosen`** asks `keyAction` for each pressed key, in the existing order.

- [ ] **Step 1: Write the failing tests:**
  - `TouchStick.spec`: `turns a touch's offset into a stick, with a dead zone and full speed at the radius` (origin (100,100), dead zone 2, radius 20):
    - (100, 90) → (0, 0.5);
    - (100, 60) → (0, 1);
    - (101, 101) → zero;
    - (115, 100) → (0.75, 0).
  - `ActionController.spec`: `names the action each key would start now`:
    - without the ball: tackle Tackle, uppercut Uppercut, pass CallPass, throw nil;
    - with it: Dodge, nil, Pass, ChargeThrow;
    - during a tackle's active phase (no ball): tackle → Dive.
  - `SkateController.spec`: `knows when a teammate is close enough to attach behind`: a teammate leader 5 studs ahead, facing the same way → `attachable == true` after a step; 40 studs ahead → false.
  - `TouchControls.spec` (a `ScreenGui` parent in the test folder; a real InputController, ActionController, SkateController and BallCarrier as in `ActionController.spec`):
    - `lays out a button for every control from Config.Input.touch`: names, positions and size equal the config; the pad's size is `stickArea`.
    - `binds each button to its control, and the throw button to Ball Focus too`: `UIButton == button` checked as booleans on Jump, Pump, Brake, Attach, Tackle, Uppercut, Pass and Throw, and on BallFocus for the throw button.
    - `moves the skater with a touch that starts on the stick pad`: a scripted `TouchMove` binding fires (100, 300), then (100, 280); yield → `Move` reads (0, 1). Then (−1, −1) → (0, 0).
    - `names and shows each button for what it does now`:
      - without the ball: "Tackle", "Call", "Focus", uppercut visible;
      - with it: "Dodge", "Pass", "Throw", uppercut hidden;
      - during the tackle's active phase: "Dive";
      - attach visible only when `attachable`.
    - `shows only on touch`: `PreferredInput` Touch → `gui.Enabled`; KeyboardAndMouse → not.
    - `steps in under 0.1 ms`: 600 steps, the ball changing hands every 100; record the mean.
  - `FrameController.spec`: `renders the camera, then the touch controls`: fakes record the order.
- [ ] **Step 2:** Run `testPathPattern = "(TouchStick|TouchControls|ActionController|SkateController|FrameController)"`. Expected: FAIL.
- [ ] **Step 3:** Implement.
- [ ] **Step 4:** Run, then the full suite. Expected: **544 tests** (+10).
- [ ] **Step 5:** Mutations, each restored:
  - `keyAction` ignoring `requires.ball` → `names the action each key would start now` fails;
  - the stick's Y not flipped → the touch-stick test fails.
- [ ] **Step 6: Phase playtest.**
  - The console reads exactly `Server ready: … modules=8` / `Client ready: … modules=10`, with no warnings.
  - **Keyboard and mouse, through the MCP keyboard and mouse tools:**
    - the camera sits behind and level at the kickoff;
    - `MouseBehavior == LockCenter` while playing;
    - the FOV rises with a pump to speed;
    - Tab opens no player list, and `PlayerList` reads disabled;
    - C, V, G and X fire no Roblox ability, because `CharacterContext` is disabled;
    - Escape opens the menu, during which E gives no tackle;
    - Mouse2 held turns the camera to the ball.
  - **The owner turns the mouse** to confirm the turn direction and speed feel right (simulated moves carry no delta, fact 2).
  - **Screenshots:** the camera rolled on the bank's wall, and the camera pulled in under the roof.
  - **Mobile:** the owner switches Studio's device emulator to a phone and plays.
    - Our stick and buttons show; Roblox's thumbstick and jump button don't.
    - A drag on the left moves the skater; a swipe on the right turns the camera; Jump, Tackle and Throw work.
    - The buttons relabel with and without the ball.
    - Probes read `PreferredInput` and the actions' states.
    - Multi-touch goes on the Phase 9 real-device checklist.
- [ ] **Step 7:** Static checks. Commit `feat(input): touch controls, and the action each key starts now`.

---

## After the tasks

- **The fresh end-of-phase reviewer:** exactly one, a general-purpose agent on `opus`, given the plan, the spec, this Review Focus and the ledger's rulings.
- **The review-fixes issue and PR:** every finding of every severity is fixed test-first in one PR.
- **Merges:** with the owner's OK, in order, with `--merge`. **Retarget each next PR to `main` before deleting the merged branch.** Then the Rojo-safe `main` sync.
- **The phase summary to the owner:**
  - what changed;
  - the camera and touch budgets;
  - every ruling with its cost if wrong;
  - the mobile emulation results;
  - what's next (Phase 8, the HUD).
