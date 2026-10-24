--!strict
-- The ball's part (spec §9.3), as this client sees it: the server tags it (Tags.Ball), and its model streams to every
-- client (Persistent). One cache every client module reads, kept by the tag's signals from start on.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type BallPart = {
	name: string,
	dependencies: { string },
	init: (self: BallPart, deps: { [string]: any }) -> (),
	start: (self: BallPart) -> (),
	-- The ball's part while it is in the workspace; nil while there is none.
	get: (self: BallPart) -> BasePart?,
	-- Lets go of the tag's signals (tests).
	destroy: (self: BallPart) -> (),
	_part: BasePart?,
	_connections: { RBXScriptConnection },
}

local BallPart: BallPart = {
	name = "BallPart",
	dependencies = {},
	_part = nil,
	_connections = {},

	init = function(self: BallPart, _deps: { [string]: any })
		self._part = nil
		self._connections = {}
	end,

	start = function(self: BallPart)
		local function found(instance: Instance)
			if instance:IsA("BasePart") and instance:IsDescendantOf(workspace) then
				self._part = instance
			end
		end
		table.insert(self._connections, CollectionService:GetInstanceAddedSignal(Tags.Ball):Connect(found))
		table.insert(
			self._connections,
			CollectionService:GetInstanceRemovedSignal(Tags.Ball):Connect(function(instance: Instance)
				if instance == self._part then
					self._part = nil
				end
			end)
		)
		for _, instance in CollectionService:GetTagged(Tags.Ball) do
			found(instance)
		end
	end,

	get = function(self: BallPart): BasePart?
		local part = self._part
		return if part ~= nil and part.Parent ~= nil then part else nil
	end,

	destroy = function(self: BallPart)
		for _, connection in self._connections do
			connection:Disconnect()
		end
		table.clear(self._connections)
		self._part = nil
	end,
}

return BallPart
