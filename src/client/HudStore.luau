--!strict
-- What the HUD shows, as the server last said (spec §10.2): each MatchSnapshot and each batch of RuleEvents goes into
-- one HudState, whose clocks count on before each frame is drawn (FrameController). One module every HUD module reads,
-- so only one listens. The server fires a snapshot after each batch, and remotes arrive in the order they are fired.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local Payloads = require(ReplicatedStorage.Shared.Net.Payloads)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type HudStore = {
	name: string,
	dependencies: { string },
	init: (self: HudStore, deps: { [string]: any }) -> (),
	start: (self: HudStore) -> (),
	state: HudState.HudState,
	onSnapshot: (self: HudStore, payload: Payloads.MatchSnapshot) -> (),
	onEvents: (self: HudStore, events: { Types.Event }) -> (),
	step: (self: HudStore, dt: number) -> (),
}

local HudStore: HudStore = {
	name = "HudStore",
	dependencies = { "Config" },
	state = nil :: any,

	init = function(self: HudStore, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		self.state = HudState.new(config)
	end,

	start = function(self: HudStore)
		Remotes.get(ReplicatedStorage, Remotes.names.MatchSnapshot).OnClientEvent
			:Connect(function(payload: Payloads.MatchSnapshot)
				self:onSnapshot(payload)
			end)
		Remotes.get(ReplicatedStorage, Remotes.names.RuleEvents).OnClientEvent:Connect(function(events: { Types.Event })
			self:onEvents(events)
		end)
	end,

	onSnapshot = function(self: HudStore, payload: Payloads.MatchSnapshot)
		self.state:applySnapshot(payload)
	end,

	onEvents = function(self: HudStore, events: { Types.Event })
		self.state:applyEvents(events)
	end,

	step = function(self: HudStore, dt: number)
		self.state:step(dt)
	end,
}

return HudStore
