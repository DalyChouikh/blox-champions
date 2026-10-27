--!strict
-- Builds the arena into the workspace at server start and exposes its tagged layout to later services (spec §9.2).
-- A failed build or read stops the server's boot with this module named, so no match starts on a broken arena
-- (spec §13), nor on one a skater could leave under the world's gravity (Arena spec §4.2).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Builder = require(script.Parent.Arena.Builder)
local Config = require(ReplicatedStorage.Shared.Config)
local Geometry = require(ReplicatedStorage.Shared.Arena.Geometry)
local TaggedLayout = require(ReplicatedStorage.Shared.Arena.TaggedLayout)

-- Spelled out so the module is a Loader.LoadableModule (whose start is optional) and callers still see a
-- non-optional init.
export type ArenaService = {
	name: string,
	dependencies: { string },
	init: (self: ArenaService, deps: { [string]: any }) -> (),
	start: ((self: ArenaService) -> ())?,
	-- Both set by init.
	model: Model?,
	arena: TaggedLayout.TaggedArena?,
}

local ArenaService: ArenaService = {
	name = "ArenaService",
	dependencies = { "Config" },
	-- deps.Gravity (studs/s²) replaces the world's in tests.
	init = function(self: ArenaService, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		local gravity: number = deps.Gravity or workspace.Gravity
		local model = Builder.build(Geometry.build(config, gravity), config, workspace)
		-- Tags are read from the place, so the arena is parented first; an unreadable one is removed again.
		local ok, arena = pcall(TaggedLayout.read, model)
		if not ok then
			model:Destroy()
			error(arena, 0)
		end
		self.model = model
		self.arena = arena
	end,
}

return ArenaService
