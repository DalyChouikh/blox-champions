--!strict
-- The ball's part (spec §9.3), as this client sees it: the server tags it (Tags.Ball), and its model streams to every
-- client (Persistent). One cache every client module reads, kept by the tag's signals from start on, with the part's
-- look (#400: what draws the unseen ball part, Ball/Look), found once it is there.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Look = require(ReplicatedStorage.Shared.Ball.Look)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

-- Spelled out so the module is a Loader.LoadableModule and callers see its methods.
export type BallPart = {
	name: string,
	dependencies: { string },
	init: (self: BallPart, deps: { [string]: any }) -> (),
	start: (self: BallPart) -> (),
	-- The ball's part while it is in the workspace; nil while there is none.
	get: (self: BallPart) -> BasePart?,
	-- The ball part's look while there is one; nil without a ball or before its look is there.
	look: (self: BallPart) -> BasePart?,
	-- Lets go of the tag's signals (tests).
	destroy: (self: BallPart) -> (),
	_part: BasePart?,
	-- The look last found, kept while it stays under the ball part (a stale one is never under the part).
	_look: BasePart?,
	_connections: { RBXScriptConnection },
}

local BallPart: BallPart = {
	name = "BallPart",
	dependencies = {},
	_part = nil,
	_look = nil,
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

	look = function(self: BallPart): BasePart?
		local part = self:get()
		if part == nil then
			return nil
		end
		local look = self._look
		if look == nil or look.Parent ~= part then
			look = Look.of(part)
			self._look = look
		end
		return look
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
