# M1 Phase 9 — Cloud Tests, Playtests and Tuning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** M1 is done (spec §1.2, §14 #9).
- **Phones:** the big panels, the banner and the feed sit left of the touch buttons. The score tab and the end screen are solid, and the end screen is compact on a phone.
- **CI:** CI runs the whole Jest suite in Roblox's cloud on every pull request and every push to `main`.
- **Playtests:** the game is played on a real phone, a gamepad and with a second player.
- **Tuning:** the owner's tuning pass changes Config values only. *(Replaced on 2026-10-25 by the M1 overhaul: see Task 4.)*

**Architecture:**
- **The stage.** On touch, the HUD's centred parts centre in the space left of the touch buttons:
  - a pure `Input/TouchArea` measures that space (the one rule for how big the touch controls are, moved out of `TouchControls`);
  - the Hud keeps it in a binding;
  - App draws the banner, the feed, the score tab and the end screen inside a Frame "Stage" sized by that binding.
- **The cloud test job** is a small Python script using only the standard library. It:
  - uploads the built test place as a Saved version;
  - runs `RunTests` in it through Open Cloud Luau Execution, against that exact version;
  - fails unless the returned summary says every test passed.
- **Playtests and tuning** are owner sessions. Every finding and every tuning change goes through an issue and a test-first PR.

**Tech Stack:**
- Luau (`--!strict`), Rojo 7.7.1, StyLua 2.6.0, selene 0.32.0, luau-lsp 1.70.1, Jest Roblox 3.20.1, React Luau 17.3.13.
- New: Python 3 (standard library only) with Ruff 0.17.2 pinned in `rokit.toml`; Roblox Open Cloud.

**Spec:** `docs/superpowers/specs/2026-10-21-m1-foundation-core-match-design.md`:
- §1.2 (definition of done), §8.3 (controls), §11 (HUD), §12.2–12.4 (testing, CI, workflow), §13 (errors), §14 (phase 9).

## Verified facts this plan relies on (2026-10-24)

1. **Open Cloud Luau Execution** (create.roblox.com/docs/en-us/cloud/reference/features/luau-execution.md):
   - **Endpoints:**
     - create: `POST https://apis.roblox.com/cloud/v2/universes/{u}/places/{p}/versions/{v}/luau-execution-session-tasks`, body `{ "script", "timeout" }` (default and maximum 5 minutes);
     - poll: `GET https://apis.roblox.com/cloud/v2/{task.path}`;
     - logs: `GET {path}/logs`, which returns `luauExecutionSessionTaskLogs[].messages` and a `nextPageToken`; Roblox keeps at most 450 KB of logs.
   - **States:** QUEUED, PROCESSING, COMPLETE, FAILED (the `error` field says why), CANCELLED.
   - **Limits:**
     - the return values come back serialized to JSON, at most 4 MB;
     - 5 task creations a minute per key owner, 200 polls a minute, 45 log reads a minute;
     - at most 10 incomplete tasks per place, after which creating one returns HTTP 429.
   - **Scopes:** creating needs `universe.place.luau-execution-session:write`; reading accepts read or write.
   - **The environment:** "physics simulation does not run", "server and local scripts within the place also do not automatically run", and changes "cannot be persisted". Nothing is said about `loadstring`.
2. **Place upload** (create.roblox.com/docs/en-us/cloud/reference/features/places.md and the publishing guide):
   - `POST https://apis.roblox.com/universes/v1/{u}/places/{p}/versions?versionType=Saved`;
   - "Saved: the place file should be saved, but not published";
   - `Content-Type: application/octet-stream` for `.rbxl`; scope `universe-places:write`; 30 a minute per key owner;
   - it returns the `versionNumber`.
3. **Roblox's `rocale-cli` (v0.1.3, its last release, 2026-04-13; last commit 2026-05-14), read from its source:**
   - it stops polling at any state other than PROCESSING, so a QUEUED task ends the wait;
   - it exits 0 unless the state is FAILED or CANCELLED;
   - it runs the task against the place's default version, not the version it uploaded.

   It can therefore pass without running a test. Roblox's archived `place-ci-cd-demo` has the same polling rule.
4. **Jest Roblox's README:** it "can run within Roblox itself, including via Roblox's OCALE … for testing on CI systems". Its changelog lists a `loadstring` fallback for "lower privileged contexts". **Not yet verified:** whether our `RunTests` runs there unchanged. Task 2's first cloud run proves it.
5. **GitHub Actions concurrency** (docs.github.com, "Control workflow concurrency"):
   - one run runs per group at a time;
   - "by default, any existing pending job … in the same concurrency group will be canceled", whatever `cancel-in-progress` says.
6. **Tools, read on GitHub today** (the owner's rule: tools updated and maintained regularly):

   | Tool | Version | Released | Status |
   |---|---|---|---|
   | Rojo | 7.7.1 | 2026-10-02 | current |
   | StyLua | 2.6.0 | 2026-10-10 | current |
   | selene | 0.32.0 | 2026-10-01 | current |
   | luau-lsp | 1.70.1 | 2026-09-27 | current |
   | wally-package-types | 1.7.0 | 2026-09-24 | current |
   | Rokit | 1.2.0 | 2025-09-30 | last commit 2026-09-27 |
   | Wally | 0.3.2 | 2023 | newest stable; 0.4.0 alphas 2026-09-26 and 10-12 |
   | Ruff | 0.17.2 | 2026-10-22 | installs through Rokit (tried in a scratch folder) |
   | `CompeyDev/setup-rokit` | v0.2.1 | 2026-05-06 | wraps a modified copy of Rokit's installer, then `rokit install --no-trust-check` |

   Roblox's React 17.3.13 and Jest 3.20.1 are still the newest on the Wally index.
7. **The phone emulator** (iPhone 17 Pro, landscape, probed 2026-10-24):
   - `GetInsetArea` gives CoreUISafeInsets (0,0)–(750,323) and DeviceSafeInsets (0,−58)–(750,323).
   - The HUD gui spans the first and the touch gui the second.
   - The leftmost touch button's left edge is at x 504 = 750 − (210 + 72/2).
   - The score tab now fits at 307/360 and the end screen at 307/520 of their sizes.
8. **Draw order, probed in Edit** (`StarterGui:GetGuiObjectsAtPosition`, topmost first; ZIndexBehavior Sibling):
   - a sibling with ZIndex 2 and its children draw above a ZIndex 1 sibling, whichever was parented first;
   - with equal ZIndex, the one parented later draws on top;
   - children draw above their parent.
9. **The code today:**
   - `TouchControls.layout` holds the big-screen rule;
   - `Hud:resize(area)` feeds one `area` binding to the banner, the feed, the score tab and the end screen;
   - `Hud.step` clears the touch toggle once the device is not touch or the match is over;
   - App hides the score button and the score tab while the match is over;
   - `Style.panel` gives every panel `panelTransparency` 0.35;
   - CI runs StyLua, selene, luau-lsp and both Rojo builds, but no tests.

## Owner decisions (2026-10-24)

1. **Real-device tests:** a phone, a gamepad on the PC, and a second player (a friend or a second computer). No tablet.
2. **Where the games live:** in the owner's community (group).
   - The cloud tests run in a separate private experience, "Blox Champions Tests".
   - The game itself is "Blox Champions".
3. **The API key** belongs to the owner's own account.
   - It has only the two permissions CI needs, on the test experience only, with no IP restriction.
   - The owner creates it and stores it in GitHub themselves, walked through by a wizard script. **The key never appears in chat.**
4. **Phones:** the end screen, the score tab, the banner and the feed centre in the space left of the touch buttons.
   - The end screen keeps its scale (its height limits it).
   - The score tab goes from 0.85 to about 0.76.
   - The feed keeps its 5 lines; a thumb may cover some.
5. **Solid panels:** the score tab and the end screen become solid; the scoreboard stays see-through.
6. **A compact end screen on touch:** the winner, the totals and the MVP's card, without the full table.
   - The SCORES button stays during the end screen and opens the full score tab over it.
   - Its toggle clears when the end screen appears and when the next match starts.
   - On PC a held Tab still opens nothing during the end screen, which holds the full table itself.
7. **Tuning:** the owner plays and says in plain words what feels off; Config values change test-first, each one recorded. No live tuning panel.
8. **Tools:**
   - CI installs Rokit with Rokit's own installer (pinned) instead of `setup-rokit`;
   - Wally stays on 0.3.2, its newest stable release, until 0.4.0 leaves alpha;
   - only tools updated and maintained regularly are used.

## Global Constraints

- **Everything from Phases 1–8 holds:**
  - `--!strict`;
  - StyLua, selene and `bash scripts/analyze.sh` clean;
  - lines at most 120 columns, comments included;
  - relative requires in `src/`, service-path requires in tests, `JestGlobals` only;
  - annotate what strict mode can't infer;
  - selene rejects `assert(x)` without a message.
- **The pure core touches no Instance:** `src/shared/{Rules,Ball,Skate,Actions,Arena/Geometry,Config,Net/RateLimiter,Net/Schemas,Util,Camera,Input,Hud}`. `Rect` and `Vector2` are datatypes, not Instances.
- **No gameplay or style literals** outside `src/shared/Config/*`.
- **Names are spelled once:** the big-screen rule and the buttons' reach in `Input/TouchArea`, solid panels in `Style.overlay`.
- **Client modules are `Loader` modules with an explicit exported type**, and `init(deps)` takes fakes. React components are plain functions of their props.
- **No per-frame allocation:** the stage is measured only when the screen or the device changes.
- **Python:**
  - standard library only;
  - `ruff format` and `ruff check` clean, at 120 columns;
  - every network call goes through one injectable opener, so the unit tests make no network call;
  - the API key is never printed.
- **Tests:**
  - instances live under a uniquely named `…Test` folder and are removed in `afterEach`;
  - compare names or booleans, never an Instance that might fail;
  - **prove each guard with a mutation** and record it.
- **Process:**
  - one issue and one stacked branch per task, `CONTRIBUTING.md` naming, one type label plus one area label;
  - commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, PR bodies with `🤖 Generated with [Claude Code](https://claude.com/claude-code)`;
  - **merges are squash-only**, replaying each next branch onto the new main.

## How tests run

As in Phase 8:
- `rojo serve test.project.json` runs and stays connected.
- Tests run through `execute_luau` (Edit) in a spawned thread that stores its summary in `shared.BloxFocus` / `shared.BloxSuite`.
- Check a changed module's `.Source` before debugging a test that disagrees with the code.

The suite has **652 tests** before this phase. Each task states its new tests and the new total; a different total is a finding to rule on.

Python: `python -m unittest discover -s scripts/ci -p "test_*.py"`, plus `ruff format --check scripts` and `ruff check scripts`. CI runs the same three commands.

The playtest console must still read exactly `[BloxChampions] Server ready: mode=NormalChampions, modules=8` and `[BloxChampions] Client ready: mode=NormalChampions, modules=17`.

## Review Focus

1. **The device changes mid-match** (touch ↔ keyboard): the stage is measured again, the parts move back to the screen's centre, and the touch toggle clears.
   - Task 1, Hud: `measures the stage again when the device changes or the screen turns`.
2. **A big screen** (shorter side over 500 px): the buttons grow 1.5×, and the stage shrinks to match. **A screen whose touch area ends before the HUD's right edge** (a notch on that side): the stage ends at the buttons, not at the HUD's edge.
   - Task 1, TouchArea: `gives the stage: the HUD's area left of the touch buttons`.
3. **The end screen appears while the score tab is toggled open on touch:** the tab closes, and the next tap opens it over the end screen.
   - Task 1, Hud: the rewritten touch test.
4. **A cloud run that never finishes, fails, is cancelled, stays queued, or runs no test** (Jest failed to start): CI fails, saying why.
   - Task 2: `test_waits_while_the_task_is_queued_or_processing`, `test_fails_when_the_task_outlives_its_deadline`, `test_fails_when_the_task_failed_or_was_cancelled`, `test_fails_when_no_test_ran`.
5. **A pull request opened while the key or an ID is missing** (a fork, whose runs get no secrets, or before the setup wizard): CI fails loudly, naming each missing value.
   - Task 2: `test_fails_loudly_naming_each_missing_setting`.

## Decisions not spelled out in the spec (for owner review)

1. **Our own small client instead of Roblox's `rocale-cli`** (fact 3: it can pass without running a test). Cost if wrong: about 200 lines of Python to maintain.
2. **Each task runs against the version its own job uploaded.** So runs from different pull requests run side by side, each in its own concurrency group:
   - a pull request's newer push cancels its older run;
   - every push to `main` gets its own group, so none is cancelled.

   One shared group would cancel pending runs (fact 5) and break the stacked-PR merges. The client waits out an HTTP 429 (rate or task limit). Cost if wrong: a 429 wait of up to a few minutes when many branches are pushed at once.
3. **`cloud-tests` runs after `quality`**, so the cloud's limits are spent only on commits that build and pass the static checks. Cost if wrong: one to two minutes more per CI run.
4. **A fork's pull request fails `cloud-tests` loudly.** GitHub gives fork runs no secrets, and running a stranger's code with the key would be unsafe. Cost if wrong: such a PR is reviewed and tested locally before merging.
5. **The setup wizard is committed** (`scripts/ci/setup-cloud-tests.sh`, linked from the README). A key unused for 60 days expires, so re-running it is the documented fix. Cost if wrong: one script in the repo.
6. **The stage is a Frame that holds the centred parts.** Their configured positions (scale 0.5) keep meaning "centred", with no new layout values. Cost if wrong: none.
7. **The score tab draws over the end screen with ZIndex 2.** Fact 8: with equal ZIndex the later-parented sibling wins, and React's order of keyed children is not fixed. Cost if wrong: none.
8. **The score tab over the compact end screen shows the ended match's stats**, the end screen's own numbers. Cost if wrong: none (the last snapshot carries the same stats).
9. **A config rule: every touch button sits at the bottom-right corner (scales 1, 1).** `Config.Input` already documents this, and the stage's reach depends on it. Cost if wrong: a button can no longer be placed from another corner.
10. **`hud.overlayTransparency`** (0) is the solid big panels' transparency. Cost if wrong: a name.
11. **Ruff lints and formats the Python**, at 120 columns like StyLua, because the zero-warnings rule covers every language in the repo. Cost if wrong: one more pinned tool.

**Not in this phase:**
- **Art pass:** the HUD's and touch controls' look, our own arrow image, the gate arrow above its marker, and glass walls.
- **M2–M8:** bots, the practice map, the lobby, items, progression and saved settings, ranked, cosmetics.

## File Structure

```
src/shared/Input/TouchArea.luau            pure: the touch controls' scale, the buttons' reach, the HUD's stage
src/shared/Config/{Input,UI}.luau          corner rule; hud.overlayTransparency
src/client/TouchControls.luau              scales from TouchArea
src/client/Hud/{init,App,Style,EndScreen,ScoreTab,Banner,Feed}.luau   the stage, solid panels, compact end screen
scripts/install-toolchain.sh               CI: Rokit's own installer (pinned), then rokit.toml's tools
scripts/ci/cloud_tests.py                  upload, run the suite in the cloud, judge the summary
scripts/ci/test_cloud_tests.py             its unit tests (unittest, no network)
scripts/ci/run-tests-task.luau             the task's script: the suite's summary
scripts/ci/setup-cloud-tests.sh            the owner's one-time setup wizard
ruff.toml, rokit.toml                      Ruff 0.17.2 at 120 columns
.github/workflows/ci.yml                   install script, Python checks, the cloud-tests job
README.md, CONTRIBUTING.md                 cloud tests, Ruff, the new check
docs/playtests/2026-10-24-m1-phase9.md     the playtest record (Task 3)
```

---

### Task 1: The phone layout (labels `feature`, `ui`)

**Issue:** to be created · **Branch:** `feat/<issue>-phone-layout` · **Base:** `main`

**Files:**
- Create: `src/shared/Input/TouchArea.luau`
- Modify:
  - `src/shared/Config/Input.luau`: the corner rule, before the overlap rule. `buttonsOverlap` drops its scale comparison, because the corner rule makes every scale equal.
  - `src/shared/Config/UI.luau`: `hud.overlayTransparency = 0`.
  - `src/client/TouchControls.luau`: `layout` takes its scales from TouchArea.
  - `src/client/Hud/init.luau`, `App.luau`, `Style.luau` (`overlay`), `EndScreen.luau` (`compact`, solid), `ScoreTab.luau` (solid, ZIndex 2). Banner and Feed change only their comments, because their props stay.
- Test: `tests/shared/Input/TouchArea.spec.luau`, `tests/shared/Config/Config.spec.luau`, `tests/client/Hud/{EndScreen,ScoreTab}.spec.luau`, `tests/client/Hud.spec.luau`

**Interfaces:**
- Produces:
  ```lua
  -- Input/TouchArea (pure). `screen`: the touch gui's size in pixels (its DeviceSafeInsets area).
  TouchArea.stickScale(touch: Config.TouchLayout, screen: Vector2): number   -- bigScreenStickScale or 1
  TouchArea.buttonScale(touch: Config.TouchLayout, screen: Vector2): number  -- bigScreenButtonScale or 1
  -- Pixels from the screen's right edge to the leftmost button's left edge: the largest
  -- (−button.X.Offset + buttonSize.X.Offset / 2) × scale.
  TouchArea.reach(touch: Config.TouchLayout, scale: number): number
  -- The stage on touch: the HUD's area (`hud`, CoreUISafeInsets) left of the buttons, drawn in `controls`
  -- (DeviceSafeInsets). Width = controls.Max.X − reach − hud.Min.X, clamped to 0..the HUD's width; height = the HUD's.
  TouchArea.stage(touch: Config.TouchLayout, hud: Rect, controls: Rect): Vector2
  Style.overlay(config, props?): Props   -- Style.panel with hud.overlayTransparency
  EndScreenProps += { compact: boolean }  -- true: no full table, and contentHeight without it
  HudBindings: `area` becomes `stage: React.Binding<Vector2>` -- the stage in pixels; zero until known
  -- Hud: deps.InsetArea: (Enum.ScreenInsets) -> Rect (default GuiService:GetInsetArea).
  -- Hud:resize() takes no argument: it measures the stage again.
  ```
- **The stage:**
  - on touch it is `TouchArea.stage(Input.touch, InsetArea(CoreUISafeInsets), InsetArea(DeviceSafeInsets))`; on any other device it is the size of the CoreUISafeInsets area;
  - it is measured on `resize()` (from `start`, and on the HUD gui's AbsoluteSize change) and in `step` when the device changes;
  - it is set on the binding only when it differs.
- **App:**
  - Root holds the scoreboard, hints, speedometer and score button, as now, plus a Frame "Stage" (`Style.holder`, position 0,0).
  - Its Size is the stage in pixels, or the whole of Root while the stage is zero.
  - Banner, Feed, ScoreTab and EndScreen move into Stage and fit to `bindings.stage`.
  - **On touch:**
    - EndScreen gets `compact = true`;
    - the ScoreButton shows whether or not the match is over;
    - the ScoreTab shows while open, over the end screen too, with `ended.stats` while the match is over.
  - **Elsewhere:** the ScoreTab hides while the match is over, as now.
- **Hud's toggle** clears when the device is not touch, and whenever `state.ended` appears or disappears (a `_over` flag, written on change).

- [ ] **Step 1: Write the failing tests:**
  - `TouchArea.spec`:
    - `grows the stick and the buttons only on a screen whose shorter side exceeds bigScreenSide`: (750, 381) → 1 and 1; (1280, 800) → 2 and 1.5; (1000, 500) → 1 and 1.
    - `measures how far the buttons reach in from the screen's right edge`: scale 1 → 246; scale 1.5 → 369.
    - `gives the stage: the HUD's area left of the touch buttons`:
      - phone: hud `Rect.new(0, 0, 750, 323)`, controls `Rect.new(0, -58, 750, 323)` → (504, 323);
      - controls ending 50 px short, `Rect.new(0, -58, 700, 323)` → (454, 323);
      - big screen: hud `Rect.new(0, 0, 1280, 742)`, controls `Rect.new(0, -58, 1280, 742)` → (911, 742);
      - zero rects → (0, 0).
  - `Config.spec`:
    - the UI defaults gain `overlayTransparency = 0`;
    - the touch-layout rejection test gains `buttons.jump = UDim2.new(0.5, -50, 1, -70)` → `Input.touch: buttons must sit at the bottom-right corner (scales 1, 1)`;
    - the HUD rejection test gains `hud.overlayTransparency = 2` → `UI.hud.overlayTransparency: must be <= 1 (got 2)`.
  - `ScoreTab.spec`: the first test also expects `BackgroundTransparency == hud.overlayTransparency` and `ZIndex == 2`.
  - `EndScreen.spec`:
    - the first test also expects `BackgroundTransparency == hud.overlayTransparency`;
    - new `on touch, leaves out the full table and fits by what is left`: `compact = true`, `Fixtures.roster(12)`, area (750, 323) → no `Table` child, `Mvp` shown, Fit `307 / 520` (not compact: `307 / 630`, as measured in Phase 8).
  - `Hud.spec` (beforeEach injects `InsetArea` from a table `rects` keyed by `Enum.ScreenInsets`, starting with the phone's two rects):
    - **rewritten** `fits the score tab, the end screen, the banner and the feed to the stage, left of the touch buttons on touch`:
      - keyboard, held ScoreTab: `Stage.Size == UDim2.fromOffset(750, 323)` and ScoreTab Fit `307 / 360`;
      - touch: `Stage.Size == UDim2.fromOffset(504, 323)`, ScoreTab Fit `488 / 640`, Banner Fit `488 / 640`, Feed Fit 1;
      - `endMatch()` → EndScreen Fit `307 / 520`.
    - new `measures the stage again when the device changes or the screen turns`:
      - touch → 504 wide;
      - `rects` set to the big screen and `Hud:resize()` → 911;
      - keyboard → 1280;
      - touch again → 911.
    - **rewritten** (session 14's Minor 1) `on touch, keeps the score button through the end screen and opens the full score tab over a compact one`:
      - touch, toggle → ScoreTab;
      - `endMatch()` → no ScoreTab (cleared), ScoreButton shown, EndScreen without `Table`;
      - toggle → ScoreTab shown with `ZIndex > EndScreen.ZIndex` (booleans), EndScreen still shown;
      - a Kickoff snapshot → no ScoreTab, no EndScreen, ScoreButton shown.
    - Unchanged and still green: the held-Tab test (PC: nothing during the end screen) and the toggle test (cleared off touch).
- [ ] **Step 2:** Run `testPathPattern = "(TouchArea|shared/Config|Hud)"`. Expected: FAIL (TouchArea missing; the new expectations).
- [ ] **Step 3:** Implement. `TouchControls.layout` calls `TouchArea.stickScale` / `buttonScale`; its tests stay unchanged and green.
- [ ] **Step 4:** Run, then the full suite. Expected: **657 tests** (+5), all passing.
- [ ] **Step 5:** Mutations, each restored. Each must break exactly its guard; where a shared rule breaks several tests, say so in the ledger.
  - `buttonScale` ignoring the big screen → the TouchArea scale test and TouchControls' big-screen test fail;
  - `reach` without the half width → the reach and stage tests fail;
  - `stage` ignoring `controls.Max.X` (using the HUD's right edge) → the 454 case fails;
  - the toggle not cleared when `ended` appears → the touch Hud test fails;
  - the ScoreTab hidden whenever the match is over → the touch Hud test fails;
  - ScoreTab `ZIndex` 1 → the ScoreTab and Hud tests fail;
  - `Style.overlay` using `panelTransparency` → the ScoreTab and EndScreen tests fail;
  - `compact` keeping the table → the compact test fails;
  - the corner rule removed → the Config test fails.
- [ ] **Step 6: Play check on the phone emulator** (the owner's Studio is on the iPhone 17 Pro). Console: the two ready lines only.
  - **Measured in a Client probe:**
    - the Stage frame is 504 wide;
    - the banner's and the feed's centres are at x 252;
    - the score tab is solid.
  - **Drive the match to its end** from a Server probe that moves the loose ball through the gates and the ring (session 13's method; `workspace.DistributedGameTime` checked).
  - **Then the owner taps SCORES** (MCP clicks don't reach the emulator): the compact end screen holds the winner, the totals and the MVP's card, and the score tab opens over it.
  - Screenshots with `shot.ps1` (PrintWindow) of the banner, the score tab and the end screen with the tab over it.
- [ ] **Step 7:** Static checks (`checks.sh`). Commit `feat(ui): the phone layout: the HUD's stage left of the touch buttons, solid panels, a compact end screen`.

---

### Task 2: The cloud test job (labels `feature`, `infra`)

**Issue:** to be created · **Branch:** `feat/<issue>-cloud-tests` · **Stacked on:** Task 1

**Files:**
- Create:
  - `scripts/install-toolchain.sh`: Rokit's own `scripts/install.sh` at the v1.2.0 tag's commit (read in full before use), with version argument `1.2.0` and `GITHUB_PAT`; then `~/.rokit/bin` on `$GITHUB_PATH` when set, `rokit authenticate github`, `rokit install --no-trust-check`.
  - `scripts/ci/cloud_tests.py`, `scripts/ci/test_cloud_tests.py`.
  - `scripts/ci/run-tests-task.luau`: `--!strict`, a header, and `return require(game:GetService("ServerStorage").RunTests)()`.
  - `scripts/ci/setup-cloud-tests.sh`: the wizard.
  - `ruff.toml`: `line-length = 120`, `target-version = "py312"`, lint rules `E`, `F`, `W`, `I`, `B`, `UP`, `SIM`.
- Modify:
  - `rokit.toml`: `ruff = "astral-sh/ruff@0.17.2"`;
  - `.github/workflows/ci.yml`;
  - `scripts/RunTests.luau`: its header names the cloud task as a caller;
  - `README.md`: Ruff in the tools and the `rokit trust` line, and a "Cloud tests" section;
  - `CONTRIBUTING.md`: the `cloud-tests` check, and Ruff with the other tools.

**Interfaces:**
- Produces:
  ```python
  # scripts/ci/cloud_tests.py — usage: python scripts/ci/cloud_tests.py <place.rbxl> <task.luau>
  # Environment: ROBLOX_API_KEY (secret), ROBLOX_TEST_UNIVERSE_ID, ROBLOX_TEST_PLACE_ID.
  class SetupError(Exception): ...          # a missing setting; its message names every one
  @dataclass(frozen=True)
  class Settings: api_key: str; universe_id: str; place_id: str
  def settings_from(env: Mapping[str, str]) -> Settings
  class CloudError(Exception): ...          # a rejected request or a dead task; never holds the key
  class Client:
      def __init__(self, api_key: str, opener=urllib.request.urlopen, sleep=time.sleep, clock=time.monotonic): ...
      def upload_place(self, universe_id: str, place_id: str, place: bytes) -> int        # the Saved version
      def create_task(self, universe_id: str, place_id: str, version: int, script: str) -> dict
      def wait(self, task: dict) -> dict      # polls every POLL_SECONDS while QUEUED or PROCESSING, until DEADLINE
      def logs(self, task: dict) -> list[str]  # every page
  def verdict(task: dict) -> tuple[bool, str]  # pure: COMPLETE and a summary with success, 0 failed tests and
                                               # suites, and > 0 tests; else False and why (failures without ANSI)
  def main(argv: list[str], env: Mapping[str, str], out: TextIO, client_factory=Client) -> int   # 0 or 1
  ```
  - **Constants:** `POLL_SECONDS = 3`, `TASK_TIMEOUT = "300s"`, a deadline of 600 s from creation (5 minutes of running plus time queued), and 3 retries.
  - **Retries:** HTTP 429 and 5xx, and connection errors, are retried after `Retry-After` seconds, else 5 s, then 10 s.
  - **Failures:** any other HTTP error raises `CloudError(method, path, status, body)`. `main` prints it as `::error::…` and returns 1.
  - The logs are printed before the verdict.
- **CI (`.github/workflows/ci.yml`):**
  - `quality`:
    - `bash scripts/install-toolchain.sh` (env `GITHUB_TOKEN: ${{ github.token }}`) replaces `CompeyDev/setup-rokit`;
    - after the type check, a step runs `ruff format --check scripts`, `ruff check scripts` and the unit tests.
  - New `cloud-tests`:
    - `needs: quality`, `timeout-minutes: 15`;
    - `concurrency: { group: cloud-tests-${{ github.event_name == 'push' && github.sha || github.ref }}, cancel-in-progress: ${{ github.event_name == 'pull_request' }} }`;
    - steps: checkout, the toolchain, packages, `rojo build test.project.json --output build/test.rbxl`, then `python3 scripts/ci/cloud_tests.py build/test.rbxl scripts/ci/run-tests-task.luau`;
    - env `ROBLOX_API_KEY: ${{ secrets.ROBLOX_API_KEY }}`, `ROBLOX_TEST_UNIVERSE_ID: ${{ vars.ROBLOX_TEST_UNIVERSE_ID }}`, `ROBLOX_TEST_PLACE_ID: ${{ vars.ROBLOX_TEST_PLACE_ID }}`.
- **The wizard** (`mattpocock-skills:wizard`'s template; stages checked against Roblox's docs as they are written, never guessed):
  1. what this sets up, and `gh auth status`;
  2. create the private experience "Blox Champions Tests" in the owner's community;
  3. copy its Universe ID and start Place ID (`set_var ROBLOX_TEST_UNIVERSE_ID`, `set_var ROBLOX_TEST_PLACE_ID`);
  4. create the key on the owner's account: `universe-places` Write and `luau-execution-sessions` Write, on that experience only, no IP restriction;
  5. paste it hidden (`ask_secret`, `set_secret ROBLOX_API_KEY`);
  6. a summary: how to re-run CI, and that an unused key expires after 60 days (re-run the wizard).

  It writes no `.env`: nothing runs the cloud tests locally.

- [ ] **Step 1: Write the failing tests** (`test_cloud_tests.py`):
  - **Fakes:** a fake opener that replays scripted `(method, URL prefix) → (status, JSON, headers)` and records each request; a fake clock and sleep.
  - **Tests:**
    - `test_passes_when_every_test_passed`: upload → 7, task COMPLETE with `{ success = true, numTotalTests = 657, numPassedTests = 657, numFailedTests = 0, numFailedTestSuites = 0 }` → `main` returns 0 and prints `657/657`.
    - `test_runs_the_task_on_the_version_it_uploaded`: the upload's URL ends `versions?versionType=Saved` with `Content-Type: application/octet-stream` and the file's bytes; the create URL contains `/versions/7/luau-execution-session-tasks`, and its body has the script and `"timeout": "300s"`.
    - `test_waits_while_the_task_is_queued_or_processing`: QUEUED, PROCESSING, then COMPLETE → three polls, `POLL_SECONDS` apart.
    - `test_fails_when_a_test_failed`: `numFailedTests = 1` and a coloured failure message → 1; the message is printed without ANSI codes.
    - `test_fails_when_no_test_ran`: `numTotalTests = 0` → 1, also with `success = true`. A result that is not a summary (`[]`) → 1.
    - `test_fails_when_the_task_failed_or_was_cancelled`: FAILED with `error.message` → 1 and the message printed; CANCELLED → 1.
    - `test_fails_when_the_task_outlives_its_deadline`: PROCESSING past 600 s on the fake clock → 1.
    - `test_waits_out_a_rate_limit`: create → 429 with `Retry-After: 12`, then 200 → sleeps 12 and passes; four 429s → 1.
    - `test_fails_with_the_status_of_a_rejected_request_and_never_prints_the_key`: upload → 403 `{ "message": "Forbidden" }` → 1; the output names 403 and the upload path, and does not contain the key.
    - `test_fails_loudly_naming_each_missing_setting`: an empty environment → 1, and the output names `ROBLOX_API_KEY`, `ROBLOX_TEST_UNIVERSE_ID` and `ROBLOX_TEST_PLACE_ID` and points to `scripts/ci/setup-cloud-tests.sh`.
    - `test_prints_every_page_of_the_logs`: two pages (`nextPageToken`) → both pages' messages printed in order.
- [ ] **Step 2:** Run the unit tests. Expected: FAIL (`cloud_tests` missing).
- [ ] **Step 3:** Implement `cloud_tests.py`, `run-tests-task.luau`, `install-toolchain.sh`, `ruff.toml`, `rokit.toml` (`rokit add astral-sh/ruff@0.17.2`), the workflow and the docs.
- [ ] **Step 4:** Run the unit tests, `ruff format --check scripts`, `ruff check scripts`, `bash -n` and (if installed) `shellcheck` on both shell scripts, then the Luau checks and the full suite. Expected: 11 Python tests passing; **657** Jest tests (+0).
- [ ] **Step 5:** Mutations, each restored, each failing its guard:
  - `wait` stopping at any state but PROCESSING (rocale-cli's rule) → the queued test fails;
  - `verdict` trusting `success` alone → the no-test test fails;
  - the create URL without `/versions/{v}` → the version test fails;
  - the error text including the request headers → the key test fails.
- [ ] **Step 6: The owner's setup.** Generate the wizard (`bash -n`, shellcheck, `chmod +x`), trace it against the workflow's `secrets.*` and `vars.*` names, and ask the owner to run `bash scripts/ci/setup-cloud-tests.sh` in their own terminal.
- [ ] **Step 7: Prove it.** Push the branch; `cloud-tests` must pass with **657/657** in its log.
  - If Jest cannot load modules there (`loadstring`), set `ServerScriptService.LoadStringEnabled = true` in `test.project.json`'s `$properties` only (the test place), then record the finding. That needs a Rojo restart and the owner's Connect.
  - Also prove a red run: a scratch commit with one failing assertion makes `cloud-tests` fail with that test's name; then drop the commit.
  - Record both run URLs in the ledger and the PR.
- [ ] **Step 8:** Commit `feat(infra): run the test suite in Roblox's cloud on every pull request and push to main`.

---

### Task 3: Real-device and multi-client playtests (labels `test`, `input`)

**Issue:** to be created (the checklist below) · **Branch:** `test/<issue>-playtests` · **Stacked on:** Task 2

These are owner sessions. **Each finding becomes its own issue** (`bug` plus its area) with a stacked branch, fixed test-first like any task (RED watched, a mutation, the full suite). Then the owner retests it. Zero deferrals.

- [ ] **Step 1: Publishing.**
  - Build `build/game.rbxl` from `default.project.json` at the stack's head (the arena is generated at runtime).
  - The owner opens it in Studio and publishes it to their community as "Blox Champions" (private).
  - Check Roblox's docs then for the friend's access (a community role, or early testers) and walk the owner through the exact steps.
- [ ] **Step 2: PC with a gamepad:**
  - Select opens the score tab;
  - the hints show the pad's button pictures;
  - the sticks feel right (look, a resting right stick reads exactly 0);
  - a held Tab with Roblox's menu open;
  - a switch to keyboard and back leaves Roblox's own controls off.
- [ ] **Step 3: The phone:**
  - two fingers at once (the stick and a camera swipe);
  - the new layout (stage, solid panels, compact end screen with SCORES);
  - the arrow image shows;
  - wall riding with screen steering;
  - a button hiding under a finger;
  - the Uppercut button below the top bar;
  - the edge arrows' 48 px margin against Roblox's top-bar buttons;
  - camera jitter;
  - controls staying off after a device switch.
- [ ] **Step 4: Two players on the live server:**
  - a pass caught at 40 studs and one around a bend;
  - a head-on duel;
  - dodge → throw and tackle → uppercut chains under real latency;
  - the lunge length the other player sees;
  - a real knockdown;
  - drafting and attach;
  - name tags and the ✋ between real clients.
- [ ] **Step 5:** Commit `docs/playtests/2026-10-24-m1-phase9.md`: each check with its device, result and the issue of any finding. Its PR closes this task's issue.

---

### Task 4: The tuning pass (labels `chore`, `skate`)

> **Not executed: replaced by the M1 overhaul (the owner, 2026-10-25; spec decision A6).** After Task 3's playtests and a study of Roller Champions and Illegal Soccer, the owner asked for the game to match Roller Champions in play, which takes more than Config values. M1 continues in four parts, each with its own spec and plan: Arena → Feel → Ball & rules → Presentation. The tuning below happens inside them, test-first.

**Issue:** to be created · **Branch:** `chore/<issue>-tuning` · **Stacked on:** Task 3's last branch

**The starting notes** (session-10 measurements; the owner's feel decides):
- the pump reaches about 102 studs/s on the flat;
- the roof can't be looped (it needs about 151 against the hardCap of 140);
- lunge 40/60, dodge 45, wall leap 110, knockdown slide 75, the 60° tilt;
- pass 90 with homing 60;
- the uppercut measured 30 → 131 studs/s vertical;
- the guard pulls back a skater stalled about 0.6 s at 100 studs/s;
- the goal ring's rim bumps wall riders;
- plus every camera, touch and HUD number.

- [ ] **Step 1:** For each thing the owner says feels off, propose the value (or values) to change, with the measured fact behind it, and ask (AskUserQuestion, one at a time, the recommended option first).
- [ ] **Step 2:** For each agreed change:
  - the defaults test (`Config.spec`) expects the new value: RED watched;
  - change the Config value;
  - the full suite;
  - commit `chore(<area>): <what> <old> → <new>` with why in the body.

  A change that breaks a `Validate.checkAll` rule changes the rule's other value in the same commit, or the owner picks another value.
- [ ] **Step 3:** Rebuild `build/game.rbxl`; the owner republishes and replays. Repeat until the owner is happy.
- [ ] **Step 4:** The PR body lists every change: key, old value, new value, and why.

---

## After the tasks

- **The fresh end-of-phase reviewer:** exactly one, a general-purpose agent on `opus`, given the plan, the spec, this Review Focus and the ledger's rulings.
- **The review-fixes issue and PR:** every finding of every severity is fixed test-first in one PR, and every "declined to judge" line gets a `Final: Ruling:`.
- **Merges:** CI green (both checks) and the owner's OK; squash, in order, replaying each next branch onto the new main.
- **The phase summary to the owner:**
  - what changed;
  - every ruling with its cost if wrong;
  - the cloud run, the playtest record, and that the tuning task was replaced by the overhaul (Task 4).

  Then ask before deleting the ledger folder.
- **M1 continues** with the overhaul's parts (spec A6), each starting with its own brainstorm. **M1 closes** when every M1 issue is closed by a merged PR (spec §1.2 #5); then M2 (bots) starts with brainstorming.
