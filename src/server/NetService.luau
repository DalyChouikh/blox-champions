--!strict
-- Creates the remotes at server start and fires them by name, addressing players by PlayerId like every rule event.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

-- Spelled out so the module is a Loader.LoadableModule (whose start is optional) and callers see its methods.
export type NetService = {
	name: string,
	dependencies: { string },
	init: (self: NetService, deps: { [string]: any }) -> (),
	start: ((self: NetService) -> ())?,
	fireAll: (self: NetService, name: string, payload: any) -> (),
	fireTo: (self: NetService, player: Types.PlayerId, name: string, payload: any) -> (),
	destroy: (self: NetService) -> (),
	_folder: Folder?,
	_events: { [string]: RemoteEvent },
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

	-- deps.Parent lets tests keep the remotes out of ReplicatedStorage.
	init = function(self: NetService, deps: { [string]: any })
		local folder = Remotes.create(deps.Parent or ReplicatedStorage)
		self._folder = folder
		self._events = {}
		for _, name in Remotes.names do
			self._events[name] = folder:FindFirstChild(name) :: RemoteEvent
		end
	end,

	fireAll = function(self: NetService, name: string, payload: any)
		event(self, name):FireAllClients(payload)
	end,

	-- A player who has already left is skipped.
	fireTo = function(self: NetService, player: Types.PlayerId, name: string, payload: any)
		local remote = event(self, name)
		local userId = tonumber(player)
		local target = if userId ~= nil then Players:GetPlayerByUserId(userId) else nil
		if target ~= nil then
			remote:FireClient(target, payload)
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
