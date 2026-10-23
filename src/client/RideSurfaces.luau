--!strict
-- The arena surfaces skaters ride (Tags.RideSurface), as the one RaycastParams every client ray goes through: the
-- skating's ground and wall rays, the poses' and the camera's. Rays hit only these, never gates, markers, the goal,
-- characters or the ball. It follows the tag as the arena is built or replaced.

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
	refresh: (self: RideSurfaces) -> (),
}

local RideSurfaces: RideSurfaces = {
	name = "RideSurfaces",
	dependencies = {},
	params = nil :: any,

	init = function(self: RideSurfaces, _deps: { [string]: any })
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		self.params = params
		self:refresh()
	end,

	start = function(self: RideSurfaces)
		CollectionService:GetInstanceAddedSignal(Tags.RideSurface):Connect(function()
			self:refresh()
		end)
		CollectionService:GetInstanceRemovedSignal(Tags.RideSurface):Connect(function()
			self:refresh()
		end)
	end,

	refresh = function(self: RideSurfaces)
		self.params.FilterDescendantsInstances = CollectionService:GetTagged(Tags.RideSurface)
	end,
}

return RideSurfaces
