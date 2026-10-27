--!strict
-- The HUD on screen (spec §11.1), drawn with React Luau through a legacy root, which renders at once. Its panels sit in
-- the ScreenGui "Hud", below Roblox's own top bar; the reticle sits in "HudCentre", which spans the whole screen, so
-- its centre is where the camera aims (App draws it there through a portal). Before each frame is drawn
-- (FrameController), after HudStore has counted the clocks, the Hud renders App again only when something App shows has
-- changed: the HUD state's version, the device, the carrier, whether the local player has a skater, whether it is
-- knocked down, or whether the score tab is open. What changes every frame (the clock, the speed, what each control
-- does now) goes through bindings instead, each set only when its text changes; the texts come from caches and the
-- config, so a quiet frame allocates nothing. Hints name each key as the device shows it: on a gamepad Roblox's glyph,
-- otherwise the name the player's own keyboard layout gives it, else Config.UI.keyNames, else the KeyCode's name.
-- There are none on touch, where the buttons carry the labels. A knocked-down skater's Get Up prompt names the
-- movement keys the same way: the first composite's four keys, the gamepad's stick, or on touch Config.UI.text's name
-- for the stick. The score tab shows while its key is held; on touch a button toggles it, and the toggle clears once
-- the device is not touch and whenever the end screen appears or goes, so the tab never pops open unasked.
-- The banner, the feed, the score tab and the end screen centre and fit in the HUD's stage, a binding: on touch the
-- part of the HUD's area left of the touch buttons (TouchArea, from the two guis' areas that GuiService gives),
-- elsewhere the whole of it. It is measured again when the screen's size changes (from start on) and when the device
-- does.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ActionController = require(script.Parent.ActionController)
local App = require(script.App)
local BallCarrier = require(script.Parent.BallCarrier)
local Config = require(ReplicatedStorage.Shared.Config)
local ControlHints = require(script.ControlHints)
local ControlLabels = require(script.Parent.ControlLabels)
local HudStore = require(script.Parent.HudStore)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local InputController = require(script.Parent.InputController)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local SkateController = require(script.Parent.SkateController)
local Style = require(script.Style)
local TouchArea = require(ReplicatedStorage.Shared.Input.TouchArea)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

type PlayerId = Types.PlayerId

-- A text shown through a binding: its setter, and the value last set.
type Shown = { binding: React.Binding<string>, set: (text: string) -> (), value: string }

-- Spelled out so the module is a Loader.LoadableModule and callers see its members.
export type Hud = {
	name: string,
	dependencies: { string },
	init: (self: Hud, deps: { [string]: any }) -> (),
	start: (self: Hud) -> (),
	step: (self: Hud, dt: number) -> (),
	-- What the touch score button does: opens the score tab, or closes it.
	toggleScoreTab: (self: Hud) -> (),
	-- The screen's size changed (the gui's AbsoluteSize): the stage is measured again.
	resize: (self: Hud) -> (),
	-- Unmounts the React root, the reticle with it (tests).
	destroy: (self: Hud) -> (),
	gui: ScreenGui,
	-- Spans the whole screen: the reticle's.
	centre: ScreenGui,
	-- How many times App has rendered.
	renders: number,
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
	_root: ReactRoblox.RootType,
	_bindings: App.HudBindings,
	_clock: Shown,
	_speed: Shown,
	_labels: { [string]: Shown },
	-- The stage last set on its binding, and the setter.
	_stage: Vector2,
	_setStage: (stage: Vector2) -> (),
	-- The score button's handler, made once.
	_onScoreButton: () -> (),
	-- The score tab toggled on by its touch button.
	_touchToggled: boolean,
	-- Whether the match was over at the last step.
	_over: boolean,
	-- What App last rendered from; the version is nil before the first render.
	_version: number?,
	_device: Enum.PreferredInput?,
	_shownCarrier: PlayerId?,
	_hasSkater: boolean,
	_knockedDown: boolean,
	_scoreTabOpen: boolean,
}

local function newShown(text: string): Shown
	local binding, set = React.createBinding(text)
	return { binding = binding, set = set, value = text }
end

local function show(shown: Shown, text: string)
	if text ~= shown.value then
		shown.value = text
		shown.set(text)
	end
end

-- Sets the stage for `device`: on touch the HUD's area left of the touch buttons, elsewhere the whole of it.
local function measure(self: Hud, device: Enum.PreferredInput)
	local hud = self._insetArea(Enum.ScreenInsets.CoreUISafeInsets)
	local stage = if device == Enum.PreferredInput.Touch
		then TouchArea.stage(self._config.Input.touch, hud, self._insetArea(Enum.ScreenInsets.DeviceSafeInsets))
		else hud.Max - hud.Min
	if stage ~= self._stage then
		self._stage = stage
		self._setStage(stage)
	end
end

-- The first of `codes` the device has: on a gamepad the first with a glyph; otherwise the first without one, named.
local function keyView(self: Hud, codes: { Enum.KeyCode }, gamepad: boolean): Style.KeyView
	for _, code in codes do
		local image = self._keyImage(code)
		if gamepad and image ~= "" then
			return { image = image }
		elseif not gamepad and image == "" then
			local name = string.match(self._keyString(code), "^%s*(.-)%s*$") :: string
			return { text = if name ~= "" then name else self._config.UI.keyNames[code.Name] or code.Name }
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

local Hud: Hud = {
	name = "Hud",
	dependencies = { "Config", "HudStore", "InputController", "SkateController", "ActionController", "BallCarrier" },
	gui = nil :: any,
	centre = nil :: any,
	renders = 0,
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
	_root = nil :: any,
	_bindings = nil :: any,
	_clock = nil :: any,
	_speed = nil :: any,
	_labels = {},
	_stage = Vector2.zero,
	_setStage = function(_stage: Vector2) end,
	_onScoreButton = function() end,
	_touchToggled = false,
	_over = false,
	_version = nil,
	_device = nil,
	_shownCarrier = nil,
	_hasSkater = false,
	_knockedDown = false,
	_scoreTabOpen = false,

	-- deps.Parent keeps the guis out of the local player's PlayerGui in tests; deps.PreferredInput, deps.LocalId,
	-- deps.KeyString, deps.KeyImage and deps.InsetArea replace the live game there.
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
		self.renders = 0
		self._version = nil
		self._device = nil
		self._shownCarrier = nil
		self._hasSkater = false
		self._knockedDown = false
		self._scoreTabOpen = false
		self._touchToggled = false
		self._over = false
		self._onScoreButton = function()
			self:toggleScoreTab()
		end

		self._clock = newShown(self._text:clock(self._store.state:clockSeconds()))
		self._speed = newShown("")
		local labels: { [string]: Shown } = {}
		local labelBindings: ControlHints.HintLabels = {}
		for _, control: Config.TouchControl in ControlLabels.CONTROLS do
			local shown = newShown("")
			labels[control] = shown
			labelBindings[control] = shown.binding
		end
		self._labels = labels
		local stage, setStage = React.createBinding(Vector2.zero)
		self._stage = Vector2.zero
		self._setStage = setStage
		self._bindings =
			{ clock = self._clock.binding, speed = self._speed.binding, labels = labelBindings, stage = stage }

		local parent = deps.Parent or (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
		-- Both are kept across respawns.
		local gui = Instance.new("ScreenGui")
		gui.Name = "Hud"
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		gui.Parent = parent
		self.gui = gui
		self._root = ReactRoblox.createLegacyRoot(gui)
		local centre = Instance.new("ScreenGui")
		centre.Name = "HudCentre"
		centre.ResetOnSpawn = false
		centre.ScreenInsets = Enum.ScreenInsets.None
		centre.Parent = parent
		self.centre = centre
	end,

	-- The screen's size changes when the window is resized or the device turned.
	start = function(self: Hud)
		self.gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			self:resize()
		end)
		self:resize()
	end,

	toggleScoreTab = function(self: Hud)
		self._touchToggled = not self._touchToggled
	end,

	destroy = function(self: Hud)
		self._root:unmount()
	end,

	resize = function(self: Hud)
		measure(self, self._preferredInput())
	end,

	step = function(self: Hud, _dt: number)
		local state = self._store.state
		local device = self._preferredInput()
		local carrier = self._carrier.carrier
		local skate = self._skate
		local hasSkater = skate:hasSkater()
		-- SkateController keeps its last reading once the skater is gone.
		local knockedDown = hasSkater and skate.knockedDown
		if device ~= self._device then
			measure(self, device)
		end
		local over = state.ended ~= nil
		if device ~= Enum.PreferredInput.Touch or over ~= self._over then
			self._touchToggled = false
			self._over = over
		end
		local scoreTabOpen = self._input:scoreTabHeld() or self._touchToggled
		if
			state.version ~= self._version
			or device ~= self._device
			or carrier ~= self._shownCarrier
			or hasSkater ~= self._hasSkater
			or knockedDown ~= self._knockedDown
			or scoreTabOpen ~= self._scoreTabOpen
		then
			self._version = state.version
			self._device = device
			self._shownCarrier = carrier
			self._hasSkater = hasSkater
			self._knockedDown = knockedDown
			self._scoreTabOpen = scoreTabOpen
			self.renders += 1
			self._root:render(React.createElement(App, {
				config = self._config,
				text = self._text,
				state = state,
				device = device,
				localId = self._localId,
				carrier = carrier,
				hasSkater = hasSkater,
				keys = hintKeys(self, device, hasSkater),
				getUpKeys = if knockedDown then moveKeys(self, device) else nil,
				scoreTabOpen = scoreTabOpen,
				onScoreButton = self._onScoreButton,
				bindings = self._bindings,
				centre = self.centre,
			}))
		end

		show(self._clock, self._text:clock(state:clockSeconds()))
		local skater = skate.skater
		if hasSkater and skater ~= nil then
			show(self._speed, self._text:speed(skater:shownSpeed()))
		end
		local config, actions = self._config, self._actions
		for _, control: Config.TouchControl in ControlLabels.CONTROLS do
			show(self._labels[control], ControlLabels.label(control, config, actions, skate) or "")
		end
	end,
}

return Hud
