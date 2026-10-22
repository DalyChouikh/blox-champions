--!strict
-- Creates the remotes at server start and fires them by name, addressing players by PlayerId like every rule event.
-- A client's message reaches its listener only within the sender's rate limit and in the exact shape its schema
-- allows; anything else is dropped and counted per player (spec §13).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerIds = require(ReplicatedStorage.Shared.Net.PlayerIds)
local RateLimiter = require(ReplicatedStorage.Shared.Net.RateLimiter)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Types = require(ReplicatedStorage.Shared.Rules.Types)
local Validate = require(ReplicatedStorage.Shared.Config.Validate)

type PlayerId = Types.PlayerId

type Listener = {
	schema: Validate.Validator,
	limiter: RateLimiter.RateLimiter,
	handler: (player: PlayerId, payload: any) -> (),
}

-- Spelled out so the module is a Loader.LoadableModule (whose start is optional) and callers see its methods.
export type NetService = {
	name: string,
	dependencies: { string },
	init: (self: NetService, deps: { [string]: any }) -> (),
	start: (self: NetService) -> (),
	fireAll: (self: NetService, name: string, payload: any) -> (),
	fireTo: (self: NetService, player: PlayerId, name: string, payload: any) -> (),
	listen: (
		self: NetService,
		name: string,
		schema: Validate.Validator,
		perSecond: number,
		handler: (player: PlayerId, payload: any) -> ()
	) -> (),
	-- What a client's message runs: the remote's OnServerEvent, and tests.
	receive: (self: NetService, name: string, player: PlayerId, payload: any) -> (),
	dropped: (self: NetService, player: PlayerId) -> number,
	-- A player who left: their limits and their count of dropped messages go.
	forget: (self: NetService, player: PlayerId) -> (),
	destroy: (self: NetService) -> (),
	_folder: Folder?,
	_events: { [string]: RemoteEvent },
	_listeners: { [string]: Listener },
	_drops: { [PlayerId]: number },
	-- Seconds, for the rate limits (os.clock; a fake in tests).
	_clock: () -> number,
}

local function event(self: NetService, name: string): RemoteEvent
	local remote: RemoteEvent? = self._events[name]
	if remote == nil then
		error(`NetService: unknown remote "{name}"`, 0)
	end
	return remote
end

local NetService: NetService = {
	name = "NetService",
	dependencies = {},
	_events = {},
	_listeners = {},
	_drops = {},
	_clock = os.clock,

	-- deps.Parent lets tests keep the remotes out of ReplicatedStorage; deps.Clock replaces os.clock.
	init = function(self: NetService, deps: { [string]: any })
		local folder = Remotes.create(deps.Parent or ReplicatedStorage)
		self._folder = folder
		self._events = {}
		for _, name in Remotes.names do
			self._events[name] = folder:FindFirstChild(name) :: RemoteEvent
		end
		self._listeners = {}
		self._drops = {}
		self._clock = deps.Clock or os.clock
	end,

	start = function(self: NetService)
		Players.PlayerRemoving:Connect(function(player: Player)
			self:forget(PlayerIds.of(player))
		end)
	end,

	fireAll = function(self: NetService, name: string, payload: any)
		event(self, name):FireAllClients(payload)
	end,

	-- A player who has already left is skipped.
	fireTo = function(self: NetService, player: Types.PlayerId, name: string, payload: any)
		local remote = event(self, name)
		local target = PlayerIds.player(player)
		if target ~= nil then
			remote:FireClient(target, payload)
		end
	end,

	listen = function(
		self: NetService,
		name: string,
		schema: Validate.Validator,
		perSecond: number,
		handler: (player: PlayerId, payload: any) -> ()
	)
		local remote = event(self, name)
		self._listeners[name] = { schema = schema, limiter = RateLimiter.new(perSecond), handler = handler }
		remote.OnServerEvent:Connect(function(player: Player, payload: any)
			self:receive(name, PlayerIds.of(player), payload)
		end)
	end,

	-- The rate limit goes first, so a flood is dropped before anything reads it.
	receive = function(self: NetService, name: string, player: PlayerId, payload: any)
		local listener = self._listeners[name]
		if listener == nil then
			error(`NetService: nothing listens to "{name}"`, 0)
		end
		if not listener.limiter:allow(player, self._clock()) or #listener.schema(payload, name) > 0 then
			self._drops[player] = (self._drops[player] or 0) + 1
			return
		end
		listener.handler(player, payload)
	end,

	dropped = function(self: NetService, player: PlayerId): number
		return self._drops[player] or 0
	end,

	forget = function(self: NetService, player: PlayerId)
		self._drops[player] = nil
		for _, listener in self._listeners do
			listener.limiter:forget(player)
		end
	end,

	destroy = function(self: NetService)
		if self._folder ~= nil then
			self._folder:Destroy()
			self._folder = nil
		end
		self._events = {}
	end,
}

return NetService
