--!strict
-- The HUD on screen (spec §11.1), drawn with React Luau through a legacy root, which renders at once. Its panels sit in
-- the ScreenGui "Hud", below Roblox's own top bar; the reticle and the kickoff count sit in "HudCentre", which spans
-- the whole screen, so the reticle's place there is the screen point throws and passes aim through (#312); the
-- scoreboard sits in "HudTop", the device's safe area, the frame Roblox measures its top bar's free band in
-- (GuiService.TopbarInset), so it can sit in that band beside Roblox's buttons on a phone with a notch too (#352; App
-- draws both through portals). Before each frame is drawn (FrameController), after HudStore has counted the clocks, the
-- Hud renders App again only when something App shows has changed: the HUD state's version, the device, the screen's
-- form (a phone's or not, where the scoreboard sits under Roblox's top bar, and the crosshair's aim: HudScreen), the
-- carrier, whether the local player has a skater, whether it shows the Get Up prompt, or whether the score tab is open.
-- What changes every frame (the clock, the speed, what each control does now and whether it works, how far a throw has
-- charged) goes through bindings instead, each set only when it changes, and so does what moves (Animator's tracks,
-- stepped each frame; the scoreboard's from BoardMotion, which watches each new state): the texts come from caches and
-- the config, so a quiet frame allocates nothing. Each hint row (#354, look C) fades in and out over motion.easeSeconds
-- as its control greys and lights, pops its key for motion.press when the keys working it now are pressed
-- (InputController's counts, against the count the row saw last, so the game's own reads keep their presses), and shows
-- a cooling action's seconds and sweep. The speedometer's reading eases toward the skater's speed
-- (UI.hud.motion.speedRate), from the speed itself whenever a skater appears. Hints name each key as the device shows
-- it: on a gamepad Roblox's glyph, otherwise the name the player's own keyboard layout gives it, else
-- Config.UI.keyNames, else the KeyCode's name, and the mouse's buttons as a mouse with that button inked (Q207).
-- There are none on touch, where the buttons carry the labels; each render
-- names the pass key for the mark over a pass's target (passKey, #315). The Get Up prompt (a skater knocked down by a
-- strike or a fall: SkateController.promptsGetUp, #242) names the movement keys the same way: the first composite's
-- four keys, the gamepad's stick, or on touch Config.UI.text's name for the stick. The score tab shows while its key is
-- held; on touch a button toggles it, and the toggle clears once the device is not touch and whenever the end screen
-- appears or goes, so the tab never pops open unasked. While the tab shows its Switch team button
-- (HudState.switchOffer, #310), the button's key, or a tap on touch, asks the server for a switch when one works. The
-- banner, the feed, the score tab and the end screen centre and fit in the HUD's stage, a binding: on touch the part of
-- the HUD's area left of the touch buttons (TouchArea, from the two guis' areas that GuiService gives), elsewhere the
-- whole of it. It is measured again, with the screen's form, when the screen's size or Roblox's top bar changes (from
-- start on) and when the device does.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ActionController = require(script.Parent.ActionController)
local Animator = require(script.Animator)
local App = require(script.App)
local BallCarrier = require(script.Parent.BallCarrier)
local BannerMotion = require(script.BannerMotion)
local BoardMotion = require(script.BoardMotion)
local Config = require(ReplicatedStorage.Shared.Config)
local ControlHints = require(script.ControlHints)
local ControlLabels = require(script.Parent.ControlLabels)
local HudScreen = require(ReplicatedStorage.Shared.Hud.HudScreen)
local HudStore = require(script.Parent.HudStore)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local InputController = require(script.Parent.InputController)
local Motion = require(ReplicatedStorage.Shared.Hud.Motion)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local ScoreTab = require(script.ScoreTab)
local SkateController = require(script.Parent.SkateController)
local Style = require(script.Style)
local TouchArea = require(ReplicatedStorage.Shared.Input.TouchArea)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

type PlayerId = Types.PlayerId

-- The pass's control, whose key marks a pass's target (#315).
local PASS: Config.TouchControl = "pass"

-- A value shown through a binding: its setter, and the value last set.
type Shown<T> = { binding: React.Binding<T>, set: (value: T) -> (), value: T }

-- One hint row's moving parts (#354): what it reads, its fade and its key's pop (Animator tracks), whether the pop
-- shows, the share of its cooldown still to run and its seconds left, and the control whose presses it counted last
-- (nil before the first step) with how many it saw.
type Row = {
	label: Shown<string>,
	fade: Animator.Track,
	press: Animator.Track,
	pressed: Shown<boolean>,
	cooldown: Shown<number>,
	seconds: Shown<string>,
	worked: Config.Control?,
	presses: number,
}

-- Spelled out so the module is a Loader.LoadableModule and callers see its members.
export type Hud = {
	name: string,
	dependencies: { string },
	init: (self: Hud, deps: { [string]: any }) -> (),
	start: (self: Hud) -> (),
	step: (self: Hud, dt: number) -> (),
	-- What the touch score button does: opens the score tab, or closes it.
	toggleScoreTab: (self: Hud) -> (),
	-- What the Switch team button does (a tap on touch, its key elsewhere): asks for a switch while one works.
	switchTeam: (self: Hud) -> (),
	-- The screen's size changed (the gui's AbsoluteSize): the stage is measured again.
	resize: (self: Hud) -> (),
	-- Unmounts the React root, the reticle with it (tests).
	destroy: (self: Hud) -> (),
	gui: ScreenGui,
	-- Spans the whole screen: the reticle's.
	centre: ScreenGui,
	-- Spans the device's safe area, Roblox's top bar included: the scoreboard's.
	top: ScreenGui,
	-- How many times App has rendered.
	renders: number,
	-- The pass key as the hints show it on this device, or on touch, where no key shows, UI.text.touchPassTarget: what
	-- NameTags floats over the teammate a pass would go to (#315; RC Video 34 at 41.6 s). Nil without a skater.
	passKey: Style.KeyView?,
	_config: Config.GameConfig,
	_text: HudText.HudText,
	_store: HudStore.HudStore,
	_skate: SkateController.SkateController,
	_input: InputController.InputController,
	_actions: ActionController.ActionController,
	_carrier: BallCarrier.BallCarrier,
	_localId: PlayerId,
	_preferredInput: () -> Enum.PreferredInput,
	-- UserInputService's key names and glyphs, or fakes.
	_keyString: (key: Enum.KeyCode) -> string,
	_keyImage: (key: Enum.KeyCode) -> string,
	-- GuiService:GetInsetArea, or a fake: a gui's area on the screen for its ScreenInsets.
	_insetArea: (insets: Enum.ScreenInsets) -> Rect,
	-- GuiService.TopbarInset, or a fake: the part of Roblox's top bar its buttons leave free, in pixels from the safe
	-- area's top-left (probed on a notched phone).
	_topbar: () -> Rect,
	-- The HUD's moving values, the scoreboard's motion and the banners'.
	_animator: Animator.Animator,
	_board: BoardMotion.BoardMotion,
	_banners: BannerMotion.BannerMotion,
	-- The screen's form, as last measured: a phone's, and the scoreboard's top and the crosshair's aim from the top of
	-- the safe area.
	_compact: boolean,
	_boardTop: number,
	_aim: number,
	-- The banner line at its highest (HudScreen.bannerAt), and the stage's top, both from the safe area's top.
	_bannerAt: number,
	_stageTop: number,
	-- The speed the speedometer reads, eased (studs per second); nil without a skater.
	_shownSpeed: number?,
	_root: ReactRoblox.RootType,
	_bindings: App.HudBindings,
	_clock: Shown<string>,
	_speed: Shown<string>,
	_rows: { [string]: Row },
	_charge: Shown<number>,
	-- The stage last set on its binding, and the setter.
	_stage: Vector2,
	_setStage: (stage: Vector2) -> (),
	-- The score button's handler, made once.
	_onScoreButton: () -> (),
	-- The Switch team button's handler, made once, and the request it sends (or a fake).
	_onSwitchTeam: () -> (),
	_sendSwitchTeam: () -> (),
	-- The score tab toggled on by its touch button.
	_touchToggled: boolean,
	-- Whether the match was over at the last step.
	_over: boolean,
	-- What App last rendered from; the version is nil before the first render.
	_version: number?,
	_device: Enum.PreferredInput?,
	_shownCompact: boolean,
	_shownBoardTop: number,
	_shownAim: number,
	_shownBannerAt: number,
	_shownStageTop: number,
	_shownCarrier: PlayerId?,
	_hasSkater: boolean,
	_promptsGetUp: boolean,
	_scoreTabOpen: boolean,
}

local function newShown<T>(value: T): Shown<T>
	local binding, set = React.createBinding(value)
	return { binding = binding, set = set, value = value }
end

local function show<T>(shown: Shown<T>, value: T)
	if value ~= shown.value then
		shown.value = value
		shown.set(value)
	end
end

-- Sets the stage for `device`: on touch the HUD's area left of the touch buttons, elsewhere the whole of it; and the
-- screen's form (HudScreen), from the device's safe area and Roblox's top bar. The safe area, not the whole screen:
-- a notched phone's screen reaches past it, where neither Roblox's top bar nor the touch controls go (probed); only the
-- crosshair's aim is a share of the whole screen, where the 3D view is centred.
local function measure(self: Hud, device: Enum.PreferredInput)
	local hud = self._insetArea(Enum.ScreenInsets.CoreUISafeInsets)
	local safe = self._insetArea(Enum.ScreenInsets.DeviceSafeInsets)
	local stage = if device == Enum.PreferredInput.Touch
		then TouchArea.stage(self._config.Input.touch, hud, safe)
		else hud.Max - hud.Min
	if stage ~= self._stage then
		self._stage = stage
		self._setStage(stage)
	end
	local screen = safe.Max - safe.Min
	self._compact = HudScreen.compact(self._config, screen)
	self._boardTop = HudScreen.boardTop(self._config, self._compact, screen.X, self._topbar())
	local whole = self._insetArea(Enum.ScreenInsets.None)
	self._aim = HudScreen.aim(self._config, whole, safe)
	self._bannerAt = HudScreen.bannerAt(self._config, whole, safe)
	self._stageTop = hud.Min.Y - safe.Min.Y
end

-- The mouse's buttons, whose keys the hints draw as a mouse with that button inked (#354, the owner's Q207).
local MOUSE_BUTTONS: { [Enum.KeyCode]: Style.MouseButton } = {
	[Enum.KeyCode.MouseLeftButton] = "Left",
	[Enum.KeyCode.MouseRightButton] = "Right",
}

-- The first of `codes` the device has: on a gamepad the first with a glyph; otherwise the first without one, named
-- (a mouse's button saying which).
local function keyView(self: Hud, codes: { Enum.KeyCode }, gamepad: boolean): Style.KeyView
	for _, code in codes do
		local image = self._keyImage(code)
		if gamepad and image ~= "" then
			return { image = image }
		elseif not gamepad and image == "" then
			local name = string.match(self._keyString(code), "^%s*(.-)%s*$") :: string
			return {
				text = if name ~= "" then name else self._config.UI.keyNames[code.Name] or code.Name,
				mouse = MOUSE_BUTTONS[code],
			}
		end
	end
	return {}
end

-- The movement keys the Get Up prompt shows on `device`: a keyboard's first composite (up, left, down, right, as
-- Roller Champions lists them), a gamepad's stick, or the touch stick's name.
local function moveKeys(self: Hud, device: Enum.PreferredInput): { Style.KeyView }
	local move = self._config.Input.move
	if device == Enum.PreferredInput.Touch then
		return { { text = self._config.UI.text.touchMove } }
	elseif device == Enum.PreferredInput.Gamepad then
		return { keyView(self, move.sticks, true) }
	end
	local composite = move.composites[1]
	if composite == nil then
		return {}
	end
	local views: { Style.KeyView } = {}
	for _, code in { composite.up, composite.left, composite.down, composite.right } do
		table.insert(views, keyView(self, { code }, false))
	end
	return views
end

-- Each hint's key on `device`; nil where no hints show: on touch, or without a skater.
local function hintKeys(self: Hud, device: Enum.PreferredInput, hasSkater: boolean): ControlHints.HintKeys?
	if not hasSkater or device == Enum.PreferredInput.Touch then
		return nil
	end
	local gamepad = device == Enum.PreferredInput.Gamepad
	local keys: ControlHints.HintKeys = {}
	for _, control: Config.TouchControl in ControlLabels.CONTROLS do
		keys[control] = keyView(self, ControlLabels.keys(control, self._config, self._actions), gamepad)
	end
	return keys
end

-- The pass key on `device` for the mark over a pass's target (#315): the pass hint's own key (`keys`), or on touch,
-- where no hints show, the touch mark; nil without a skater.
local function passKeyView(
	self: Hud,
	device: Enum.PreferredInput,
	hasSkater: boolean,
	keys: ControlHints.HintKeys?
): Style.KeyView?
	if not hasSkater then
		return nil
	elseif device == Enum.PreferredInput.Touch then
		return { text = self._config.UI.text.touchPassTarget }
	end
	return if keys ~= nil then keys[PASS] else nil
end

-- The score tab's Switch team button on `device`: nil while it has none, else whether it works now (`carrier` holding
-- the ball), its key (none on touch, where it is tapped) and what a tap does.
local function switchTeamView(self: Hud, device: Enum.PreferredInput, carrier: PlayerId?): ScoreTab.SwitchTeam?
	local open = self._store.state:switchOffer(carrier)
	if open == nil then
		return nil
	end
	local key: Style.KeyView? = if device == Enum.PreferredInput.Touch
		then nil
		else keyView(self, self._config.Input.switchTeam, device == Enum.PreferredInput.Gamepad)
	return { open = open, key = key, onActivated = self._onSwitchTeam }
end

-- One of the HUD's ScreenGuis, covering the screen as `insets` says: kept across respawns, its parts drawn in their
-- ZIndex order among siblings.
local function screenGui(name: string, insets: Enum.ScreenInsets, parent: Instance): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.ScreenInsets = insets
	gui.Parent = parent
	return gui
end

local Hud: Hud = {
	name = "Hud",
	dependencies = { "Config", "HudStore", "InputController", "SkateController", "ActionController", "BallCarrier" },
	gui = nil :: any,
	centre = nil :: any,
	top = nil :: any,
	renders = 0,
	passKey = nil,
	_config = nil :: any,
	_text = nil :: any,
	_store = nil :: any,
	_skate = nil :: any,
	_input = nil :: any,
	_actions = nil :: any,
	_carrier = nil :: any,
	_localId = "",
	_preferredInput = function(): Enum.PreferredInput
		return Enum.PreferredInput.KeyboardAndMouse
	end,
	_keyString = function(_key: Enum.KeyCode): string
		return ""
	end,
	_keyImage = function(_key: Enum.KeyCode): string
		return ""
	end,
	_insetArea = function(_insets: Enum.ScreenInsets): Rect
		return Rect.new(Vector2.zero, Vector2.zero)
	end,
	_topbar = function(): Rect
		return Rect.new(Vector2.zero, Vector2.zero)
	end,
	_animator = nil :: any,
	_board = nil :: any,
	_banners = nil :: any,
	_compact = false,
	_boardTop = 0,
	_aim = 0,
	_bannerAt = 0,
	_stageTop = 0,
	_shownSpeed = nil,
	_root = nil :: any,
	_bindings = nil :: any,
	_clock = nil :: any,
	_speed = nil :: any,
	_rows = {},
	_charge = nil :: any,
	_stage = Vector2.zero,
	_setStage = function(_stage: Vector2) end,
	_onScoreButton = function() end,
	_onSwitchTeam = function() end,
	_sendSwitchTeam = function() end,
	_touchToggled = false,
	_over = false,
	_version = nil,
	_device = nil,
	_shownCompact = false,
	_shownBoardTop = 0,
	_shownAim = 0,
	_shownBannerAt = 0,
	_shownStageTop = 0,
	_shownCarrier = nil,
	_hasSkater = false,
	_promptsGetUp = false,
	_scoreTabOpen = false,

	-- deps.Parent keeps the guis out of the local player's PlayerGui in tests; deps.PreferredInput, deps.LocalId,
	-- deps.KeyString, deps.KeyImage, deps.InsetArea, deps.TopbarInset and deps.SendSwitchTeam replace the live game
	-- there.
	init = function(self: Hud, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		self._config = config
		self._text = HudText.new(config)
		self._store = deps.HudStore
		self._skate = deps.SkateController
		self._input = deps.InputController
		self._actions = deps.ActionController
		self._carrier = deps.BallCarrier
		self._localId = deps.LocalId or PlayerIds.of(Players.LocalPlayer :: Player)
		self._preferredInput = deps.PreferredInput
			or function(): Enum.PreferredInput
				return UserInputService.PreferredInput
			end
		self._keyString = deps.KeyString
			or function(key: Enum.KeyCode): string
				return UserInputService:GetStringForKeyCode(key)
			end
		self._keyImage = deps.KeyImage
			or function(key: Enum.KeyCode): string
				return UserInputService:GetImageForKeyCode(key)
			end
		self._insetArea = deps.InsetArea
			or function(insets: Enum.ScreenInsets): Rect
				return GuiService:GetInsetArea(insets)
			end
		self._topbar = deps.TopbarInset or function(): Rect
			return GuiService.TopbarInset
		end
		self._animator = Animator.new(config.UI.hud.motion)
		self._board = BoardMotion.new(self._text, self._animator)
		self._banners = BannerMotion.new(config.UI.hud.motion, self._animator)
		self._compact = false
		self._boardTop = 0
		self._aim = 0
		self._bannerAt = 0
		self._stageTop = 0
		self._shownSpeed = nil
		self.renders = 0
		self.passKey = nil
		self._version = nil
		self._device = nil
		self._shownCompact = false
		self._shownBoardTop = 0
		self._shownAim = 0
		self._shownBannerAt = 0
		self._shownStageTop = 0
		self._shownCarrier = nil
		self._hasSkater = false
		self._promptsGetUp = false
		self._scoreTabOpen = false
		self._touchToggled = false
		self._over = false
		self._onScoreButton = function()
			self:toggleScoreTab()
		end
		self._onSwitchTeam = function()
			self:switchTeam()
		end
		self._sendSwitchTeam = deps.SendSwitchTeam
			or function()
				Remotes.get(ReplicatedStorage, Remotes.names.SwitchTeam):FireServer({})
			end

		self._clock = newShown(self._text:clock(self._store.state:clockSeconds()))
		self._speed = newShown("")
		local animator = self._animator
		local rows: { [string]: Row } = {}
		local hints: ControlHints.HintRows = {}
		for _, control: Config.TouchControl in ControlLabels.CONTROLS do
			local row: Row = {
				label = newShown(""),
				fade = animator:track(0),
				press = animator:track(1),
				pressed = newShown(false),
				cooldown = newShown(0),
				seconds = newShown(""),
				worked = nil,
				presses = 0,
			}
			rows[control] = row
			hints[control] = {
				label = row.label.binding,
				fade = row.fade.binding,
				cap = {
					press = row.press.binding,
					pressed = row.pressed.binding,
					cooldown = row.cooldown.binding,
					seconds = row.seconds.binding,
				},
			}
		end
		self._rows = rows
		self._charge = newShown(0)
		local stage, setStage = React.createBinding(Vector2.zero)
		self._stage = Vector2.zero
		self._setStage = setStage
		self._bindings = {
			clock = self._clock.binding,
			speed = self._speed.binding,
			hints = hints,
			stage = stage,
			charge = self._charge.binding,
		}

		local parent = deps.Parent or (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
		self.gui = screenGui("Hud", Enum.ScreenInsets.CoreUISafeInsets, parent)
		self._root = ReactRoblox.createLegacyRoot(self.gui)
		self.centre = screenGui("HudCentre", Enum.ScreenInsets.None, parent)
		self.top = screenGui("HudTop", Enum.ScreenInsets.DeviceSafeInsets, parent)
	end,

	-- The screen's size changes when the window is resized or the device turned; Roblox's top bar when its buttons do.
	start = function(self: Hud)
		self.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:resize()
		end)
		GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(function()
			self:resize()
		end)
		self:resize()
	end,

	toggleScoreTab = function(self: Hud)
		self._touchToggled = not self._touchToggled
	end,

	switchTeam = function(self: Hud)
		if self._store.state:switchOffer(self._carrier.carrier) == true then
			self._sendSwitchTeam()
		end
	end,

	destroy = function(self: Hud)
		self._root:unmount()
	end,

	resize = function(self: Hud)
		measure(self, self._preferredInput())
	end,

	step = function(self: Hud, dt: number)
		local state = self._store.state
		local device = self._preferredInput()
		local carrier = self._carrier.carrier
		local skate = self._skate
		local hasSkater = skate:hasSkater()
		-- SkateController keeps its last reading once the skater is gone.
		local promptsGetUp = hasSkater and skate.promptsGetUp
		if device ~= self._device then
			measure(self, device)
		end
		local over = state.ended ~= nil
		if device ~= Enum.PreferredInput.Touch or over ~= self._over then
			self._touchToggled = false
			self._over = over
		end
		local scoreTabOpen = self._input:scoreTabHeld() or self._touchToggled
		-- Switch team's key counts only while the tab shows the button (the owner, Q117).
		if self._input:switchTeamPressed() and scoreTabOpen then
			self:switchTeam()
		end
		local compact, boardTop, aim = self._compact, self._boardTop, self._aim
		local bannerAt, stageTop = self._bannerAt, self._stageTop
		if state.version ~= self._version then
			self._board:watch(state.match)
			self._banners:watch(state)
		end
		if
			state.version ~= self._version
			or device ~= self._device
			or compact ~= self._shownCompact
			or boardTop ~= self._shownBoardTop
			or aim ~= self._shownAim
			or bannerAt ~= self._shownBannerAt
			or stageTop ~= self._shownStageTop
			or carrier ~= self._shownCarrier
			or hasSkater ~= self._hasSkater
			or promptsGetUp ~= self._promptsGetUp
			or scoreTabOpen ~= self._scoreTabOpen
		then
			self._version = state.version
			self._device = device
			self._shownCompact = compact
			self._shownBoardTop = boardTop
			self._shownAim = aim
			self._shownBannerAt = bannerAt
			self._shownStageTop = stageTop
			self._shownCarrier = carrier
			self._hasSkater = hasSkater
			self._promptsGetUp = promptsGetUp
			self._scoreTabOpen = scoreTabOpen
			self.renders += 1
			local keys = hintKeys(self, device, hasSkater)
			self.passKey = passKeyView(self, device, hasSkater, keys)
			self._root:render(React.createElement(App, {
				config = self._config,
				text = self._text,
				state = state,
				device = device,
				localId = self._localId,
				compact = compact,
				boardTop = boardTop,
				aim = aim,
				bannerAt = bannerAt,
				stageTop = stageTop,
				board = self._board,
				banners = self._banners,
				hasSkater = hasSkater,
				carrying = carrier == self._localId,
				keys = keys,
				getUpKeys = if promptsGetUp then moveKeys(self, device) else nil,
				scoreTabOpen = scoreTabOpen,
				onScoreButton = self._onScoreButton,
				switchTeam = switchTeamView(self, device, carrier),
				bindings = self._bindings,
				centre = self.centre,
				top = self.top,
			}))
		end

		show(self._clock, self._text:clock(state:clockSeconds()))
		local skater = skate.skater
		if hasSkater and skater ~= nil then
			local speed = skater:shownSpeed()
			local shownSpeed = self._shownSpeed
			if shownSpeed ~= nil then
				speed = Motion.approach(shownSpeed, speed, self._config.UI.hud.motion.speedRate, dt)
			end
			self._shownSpeed = speed
			show(self._speed, self._text:speed(speed))
		else
			self._shownSpeed = nil
		end
		self._banners:step(state)
		self._animator:step(dt)
		local config, actions, input, text, animator =
			self._config, self._actions, self._input, self._text, self._animator
		for _, control: Config.TouchControl in ControlLabels.CONTROLS do
			local row = self._rows[control]
			local label, greyed = ControlLabels.label(control, config, actions, skate)
			show(row.label, label or "")
			local fade = Style.dim(config, greyed)
			if fade ~= row.fade.target then
				animator:play(row.fade, "Ease", fade)
			end
			-- A row whose keys changed (the throw's, catching the ball) only counts on from here.
			local worked: Config.Control = ControlLabels.worked(control, actions)
			local presses = input:pressCount(worked)
			if worked == row.worked and presses ~= row.presses then
				animator:play(row.press, "Press", 1)
			end
			row.worked, row.presses = worked, presses
			show(row.pressed, row.press.moving)
			local left, share = ControlLabels.cooldown(control, config, actions)
			show(row.cooldown, share)
			show(row.seconds, if left > 0 then text:cooldown(left) else "")
		end
		show(self._charge, actions:chargeSeconds() or 0)
	end,
}

return Hud
