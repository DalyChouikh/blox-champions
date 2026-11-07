--!strict
-- Dresses the arena's goal (Arena spec §5.3, #410, the owner's Q314-Q315) in the Halo pylon: four meshes made once in
-- Blender (scripts/art/build_goal.py) and imported by the owner (Config.Arena.goal.meshes), put on the goal
-- ArenaService built, with the door that shuts its opening (Builder.dressGoal, Q324). They are asked of Roblox in
-- the background (Meshes), and none shows before all four have come; until then, and if one never does, the ring's
-- blocks and the panel are the goal's look as before, and the Output says why once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Arena = require(ReplicatedStorage.Shared.Config.Arena)
local Builder = require(script.Parent.Arena.Builder)
local Config = require(ReplicatedStorage.Shared.Config)
local Meshes = require(script.Parent.Meshes)
local TaggedLayout = require(ReplicatedStorage.Shared.Arena.TaggedLayout)

-- Spelled out so the module is a Loader.LoadableModule (whose start is optional) and callers see its members.
export type GoalLook = {
	name: string,
	dependencies: { string },
	init: (self: GoalLook, deps: { [string]: any }) -> (),
	start: ((self: GoalLook) -> ())?,
	-- Counts the starts: a download from before the latest one changes nothing.
	_generation: number,
}

local GoalLook: GoalLook = {
	name = "GoalLook",
	dependencies = { "Config", "ArenaService" },
	_generation = 0,

	-- deps.MakeMesh replaces Roblox's mesh service (a test never reaches it), deps.Log the Output.
	init = function(self: GoalLook, deps: { [string]: any })
		local config: Config.GameConfig = deps.Config
		local arena: TaggedLayout.TaggedArena = deps.ArenaService.arena
		local make: Meshes.Make = deps.MakeMesh or Meshes.make
		local log: (line: string) -> () = deps.Log or warn
		self._generation += 1
		local generation = self._generation
		local ids: { string } = {}
		for _, name in Arena.goalPieces do
			table.insert(ids, config.Arena.goal.meshes[name])
		end
		Meshes.fetch(ids, make, function(meshes: { MeshPart })
			if generation == self._generation then
				Builder.dressGoal(arena.goalHoop, arena.goalPanel, meshes, config.Arena)
			end
		end, function(id: string, why: string)
			if generation == self._generation then
				log(`GoalLook: the goal's mesh {id} did not load ({why}); drawing the ring's blocks`)
			end
		end)
	end,
}

return GoalLook
