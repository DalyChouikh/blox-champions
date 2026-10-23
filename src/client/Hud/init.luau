--!strict
-- The HUD on screen (spec §11.1), drawn with React Luau through legacy roots, which render at once. Its panels sit in
-- the ScreenGui "Hud", below Roblox's own top bar; the reticle sits in "HudCentre", which spans the whole screen, so
-- its centre is where the camera aims (drawn once: it never changes). Before each frame is drawn (FrameController),
-- after HudStore has counted the clocks, the Hud renders App again only when something App shows has changed: the HUD
-- state's version, the device, the carrier, or whether the local player has a skater. What changes every frame (the
-- clock, the speed, what each control does now) goes through bindings instead, each set only when its text changes;
-- the texts come from caches and the config, so a quiet frame allocates nothing. Hints name each key as the device
-- shows it: on a gamepad Roblox's glyph, otherwise the name the player's own keyboard layout gives it, else
-- Config.UI.keyNames, else the KeyCode's name. There are none on touch, where the buttons carry the labels.

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
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local Reticle = require(script.Reticle)
local SkateController = require(script.Parent.SkateController)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

type PlayerId = Types.PlayerId

-- A text shown through a binding: its setter, and the value last set.
type Shown = { binding: React.Binding<string>, set: (text: string) -> (), value: string }

-- Spelled out so the module is a Loader.LoadableModule and callers see its members.
export type Hud = {
	name: string,
	dependencies: { string },
	init: (self: Hud, deps: { [string]: any }) -> (),
	start: ((self: Hud) -> ())?,
	step: (self: Hud, dt: number) -> (),
	gui: ScreenGui,
	-- Spans the whole screen: the reticle's.
	centre: ScreenGui,
	-- How many times App has rendered.
	renders: number,
	_config: Config.GameConfig,
	_text: HudText.HudText,
	_store: HudStore.HudStore,
	_skate: SkateController.SkateController,
	_actions: ActionController.ActionController,
	_carrier: BallCarrier.BallCarrier,
	_localId: PlayerId,
	_preferredInput: () -> Enum.PreferredInput,
	-- UserInputService's key names and glyphs, or fakes.
	_keyString: (key: Enum.KeyCode) -> string,
	_keyImage: (key: Enum.KeyCode) -> string,
	_root: ReactRoblox.RootType,
	_bindings: App.HudBindings,
	_clock: Shown,
	_speed: Shown,
	_labels: { [string]: Shown },
	-- What App last rendered from; the version is nil before the first render.
	_version: number?,
	_device: Enum.PreferredInput?,
	_shownCarrier: PlayerId?,
	_hasSkater: boolean,
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

-- The first of `codes` the device has: on a gamepad the first with a glyph; otherwise the first without one, named.
local function keyView(self: Hud, codes: { Enum.KeyCode }, gamepad: boolean): ControlHints.KeyView
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
	dependencies = { "Config", "HudStore", "SkateController", "ActionController", "BallCarrier" },
	gui = nil :: any,
	centre = nil :: any,
	renders = 0,
	_config = nil :: any,
	_text = nil :: any,
	_store = nil :: any,
	_skate = nil :: any,
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
	_root = nil :: any,
	_bindings = nil :: any,
	_clock = nil :: any,
	_speed = nil :: any,
	_labels = {},
	_version = nil,
	_device = nil,
	_shownCarrier = nil,
	_hasSkater = false,

	-- deps.Parent keeps the guis out of the local player's PlayerGui in tests; deps.PreferredInput, deps.LocalId,
	-- deps.KeyString and deps.KeyImage replace the live game there.
	init = function(self: Hud, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		self._config = config
		self._text = HudText.new(config)
		self._store = deps.HudStore
		self._skate = deps.SkateController
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
		self.renders = 0
		self._version = nil
		self._device = nil
		self._shownCarrier = nil
		self._hasSkater = false

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
		self._bindings = { clock = self._clock.binding, speed = self._speed.binding, labels = labelBindings }

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
		ReactRoblox.createLegacyRoot(centre):render(React.createElement(React.Fragment, nil, {
			Reticle = React.createElement(Reticle, { config = config }),
		}))
	end,

	step = function(self: Hud, _dt: number)
		local state = self._store.state
		local device = self._preferredInput()
		local carrier = self._carrier.carrier
		local skate = self._skate
		local hasSkater = skate:hasSkater()
		if
			state.version ~= self._version
			or device ~= self._device
			or carrier ~= self._shownCarrier
			or hasSkater ~= self._hasSkater
		then
			self._version = state.version
			self._device = device
			self._shownCarrier = carrier
			self._hasSkater = hasSkater
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
				bindings = self._bindings,
			}))
		end

		show(self._clock, self._text:clock(state:clockSeconds()))
		local skater = skate.skater
		if hasSkater and skater ~= nil then
			show(self._speed, self._text:speed(skater.velocity.Magnitude))
		end
		local config, actions = self._config, self._actions
		for _, control: Config.TouchControl in ControlLabels.CONTROLS do
			show(self._labels[control], ControlLabels.label(control, config, actions, skate) or "")
		end
	end,
}

return Hud
