--!strict
-- Builds the arena into the workspace at server start and exposes its tagged layout to later services (spec §9.2).
-- A failed build or read stops the server's boot with this module named, so no match starts on a broken arena
-- (spec §13).

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
	init = function(self: ArenaService, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		local model = Builder.build(Geometry.build(config), config, workspace)
		self.model = model
		self.arena = TaggedLayout.read(model)
	end,
}

return ArenaService
