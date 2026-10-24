--!strict
-- The HUD on screen (spec §11.1), drawn with React Luau into its own ScreenGui through a legacy root, which renders
-- at once. Before each frame is drawn (FrameController), after HudStore has counted the clocks, it renders App again
-- only when something App shows has changed: the HUD state's version, the device, the carrier, or whether the local
-- player has a skater.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local App = require(script.App)
local BallCarrier = require(script.Parent.BallCarrier)
local Config = require(ReplicatedStorage.Shared.Config)
local HudStore = require(script.Parent.HudStore)
local HudText = require(ReplicatedStorage.Shared.Hud.HudText)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)
local SkateController = require(script.Parent.SkateController)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

type PlayerId = Types.PlayerId

-- Spelled out so the module is a Loader.LoadableModule and callers see its members.
export type Hud = {
	name: string,
	dependencies: { string },
	init: (self: Hud, deps: { [string]: any }) -> (),
	start: ((self: Hud) -> ())?,
	step: (self: Hud, dt: number) -> (),
	gui: ScreenGui,
	-- How many times App has rendered.
	renders: number,
	_config: Config.GameConfig,
	_text: HudText.HudText,
	_store: HudStore.HudStore,
	_skate: SkateController.SkateController,
	_carrier: BallCarrier.BallCarrier,
	_localId: PlayerId,
	_preferredInput: () -> Enum.PreferredInput,
	_root: ReactRoblox.RootType,
	-- What App last rendered from; the version is nil before the first render.
	_version: number?,
	_device: Enum.PreferredInput?,
	_shownCarrier: PlayerId?,
	_hasSkater: boolean,
}

local Hud: Hud = {
	name = "Hud",
	dependencies = { "Config", "HudStore", "SkateController", "BallCarrier" },
	gui = nil :: any,
	renders = 0,
	_config = nil :: any,
	_text = nil :: any,
	_store = nil :: any,
	_skate = nil :: any,
	_carrier = nil :: any,
	_localId = "",
	_preferredInput = function(): Enum.PreferredInput
		return Enum.PreferredInput.KeyboardAndMouse
	end,
	_root = nil :: any,
	_version = nil,
	_device = nil,
	_shownCarrier = nil,
	_hasSkater = false,

	-- deps.Parent keeps the gui out of the local player's PlayerGui in tests; deps.PreferredInput and deps.LocalId
	-- replace the live game there.
	init = function(self: Hud, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		self._config = config
		self._text = HudText.new(config)
		self._store = deps.HudStore
		self._skate = deps.SkateController
		self._carrier = deps.BallCarrier
		self._localId = deps.LocalId or PlayerIds.of(Players.LocalPlayer :: Player)
		self._preferredInput = deps.PreferredInput
			or function(): Enum.PreferredInput
				return UserInputService.PreferredInput
			end
		self.renders = 0
		self._version = nil
		self._device = nil
		self._shownCarrier = nil
		self._hasSkater = false

		-- Kept across respawns, below Roblox's own top bar.
		local gui = Instance.new("ScreenGui")
		gui.Name = "Hud"
		gui.ResetOnSpawn = false
		gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
		gui.Parent = deps.Parent or (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
		self.gui = gui
		self._root = ReactRoblox.createLegacyRoot(gui)
	end,

	step = function(self: Hud, _dt: number)
		local version = self._store.state.version
		local device = self._preferredInput()
		local carrier = self._carrier.carrier
		local hasSkater = self._skate.skater ~= nil
		if
			version == self._version
			and device == self._device
			and carrier == self._shownCarrier
			and hasSkater == self._hasSkater
		then
			return
		end
		self._version = version
		self._device = device
		self._shownCarrier = carrier
		self._hasSkater = hasSkater
		self.renders += 1
		self._root:render(React.createElement(App, {
			config = self._config,
			text = self._text,
			state = self._store.state,
			device = device,
			localId = self._localId,
			carrier = carrier,
			hasSkater = hasSkater,
		}))
	end,
}

return Hud
