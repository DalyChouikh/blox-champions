--!strict
-- What the HUD shows, as the server last said (spec §10.2): each MatchSnapshot and each batch of RuleEvents goes into
-- one HudState, whose clocks count on before each frame is drawn (FrameController). One module every HUD module reads,
-- so only one listens. The server fires each frame's batch, then a snapshot, both marked with the server frame, and
-- remotes arrive in the order they are fired. Those that arrive before the client connects wait, and are then handed
-- over one remote at a time, in the order the handlers connected (probed in Play): here every waiting snapshot, then
-- every waiting batch. So a batch from a frame the last snapshot already holds is dropped.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local HudState = require(ReplicatedStorage.Shared.Hud.HudState)
local Payloads = require(ReplicatedStorage.Shared.Net.Payloads)
local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type HudStore = {
	name: string,
	dependencies: { string },
	init: (self: HudStore, deps: { [string]: any }) -> (),
	start: (self: HudStore) -> (),
	state: HudState.HudState,
	onSnapshot: (self: HudStore, payload: Payloads.MatchSnapshot) -> (),
	onEvents: (self: HudStore, payload: Payloads.RuleEvents) -> (),
	step: (self: HudStore, dt: number) -> (),
	-- The server frame of the snapshot applied last; -inf before the first, so every batch is newer.
	_snapshotFrame: number,
}

local HudStore: HudStore = {
	name = "HudStore",
	dependencies = { "Config" },
	state = nil :: any,
	_snapshotFrame = -math.huge,

	-- deps.LocalId replaces the local player in tests.
	init = function(self: HudStore, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		self.state = HudState.new(config, deps.LocalId or PlayerIds.of(Players.LocalPlayer :: Player))
		self._snapshotFrame = -math.huge
	end,

	start = function(self: HudStore)
		-- Connected first, so snapshots that waited for the client are applied before the batches that waited.
		Remotes.get(ReplicatedStorage, Remotes.names.MatchSnapshot).OnClientEvent
			:Connect(function(payload: Payloads.MatchSnapshot)
				self:onSnapshot(payload)
			end)
		Remotes.get(ReplicatedStorage, Remotes.names.RuleEvents).OnClientEvent
			:Connect(function(payload: Payloads.RuleEvents)
				self:onEvents(payload)
			end)
	end,

	onSnapshot = function(self: HudStore, payload: Payloads.MatchSnapshot)
		self._snapshotFrame = payload.frame
		self.state:applySnapshot(payload)
	end,

	onEvents = function(self: HudStore, payload: Payloads.RuleEvents)
		if payload.frame > self._snapshotFrame then
			self.state:applyEvents(payload.events)
		end
	end,

	step = function(self: HudStore, dt: number)
		self.state:step(dt)
	end,
}

return HudStore
