--!strict
-- The arena surfaces skaters ride (Tags.RideSurface), as the one RaycastParams every client ray goes through: the
-- skating's ground and wall rays, the poses', the camera's and the ball's ground marker. Rays hit only these, never the
-- barriers, gates, markers, the goal, characters or the ball. Beside it, `solid` adds the barriers (Tags.Barrier: the
-- arena's top, A7): the one filter the skater's collider sweep goes through, so a barrier stops a skater as a wall or
-- a ceiling does while every ray looks through it. Both follow their tags as the arena is built or replaced, and
-- `ready` says whether the ride surfaces are here yet.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

-- Spelled out so the module is a Loader.LoadableModule and callers see its members.
export type RideSurfaces = {
	name: string,
	dependencies: { string },
	init: (self: RideSurfaces, deps: { [string]: any }) -> (),
	start: (self: RideSurfaces) -> (),
	-- Include: every ride surface, as of the last refresh.
	params: RaycastParams,
	-- Include: every ride surface and every barrier, as of the last refresh.
	solid: RaycastParams,
	-- Whether the arena's surfaces have reached this client, as of the last refresh. The arena is Persistent, so it
	-- arrives whole (its folders in the same frame, measured), but after this client starts, and in a Studio test
	-- once only 10 ms before the player's character.
	ready: boolean,
	refresh: (self: RideSurfaces) -> (),
	-- Stops following the tags (tests).
	destroy: (self: RideSurfaces) -> (),
	_connections: { RBXScriptConnection },
}

local FOLLOWED = { Tags.RideSurface, Tags.Barrier }

local function includeParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	return params
end

local RideSurfaces: RideSurfaces = {
	name = "RideSurfaces",
	dependencies = {},
	params = nil :: any,
	solid = nil :: any,
	ready = false,
	_connections = {},

	init = function(self: RideSurfaces, _deps: { [string]: any })
		self.params = includeParams()
		self.solid = includeParams()
		self:refresh()
	end,

	start = function(self: RideSurfaces)
		local function refresh()
			self:refresh()
		end
		for _, tag in FOLLOWED do
			table.insert(self._connections, CollectionService:GetInstanceAddedSignal(tag):Connect(refresh))
			table.insert(self._connections, CollectionService:GetInstanceRemovedSignal(tag):Connect(refresh))
		end
	end,

	refresh = function(self: RideSurfaces)
		local surfaces = CollectionService:GetTagged(Tags.RideSurface)
		self.params.FilterDescendantsInstances = surfaces
		local solid = table.clone(surfaces)
		for _, barrier in CollectionService:GetTagged(Tags.Barrier) do
			table.insert(solid, barrier)
		end
		self.solid.FilterDescendantsInstances = solid
		self.ready = #surfaces > 0
	end,

	destroy = function(self: RideSurfaces)
		for _, connection in self._connections do
			connection:Disconnect()
		end
		table.clear(self._connections)
	end,
}

return RideSurfaces
