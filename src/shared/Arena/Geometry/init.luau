--!strict
-- The whole graybox arena as pure data (spec §9.2, Arena spec §6.1): the pieces to build and the frames the rules and
-- spawning need. Nothing here touches an Instance; server/Arena/Builder turns it into parts. An arena a skater could
-- leave is never built: its glass must rise above the highest any skater can reach (Reach), under the world's gravity.

local Config = require(script.Parent.Parent.Config)
local Crossing = require(script.Parent.Parent.Rules.Crossing)
local Features = require(script.Features)
local Reach = require(script.Reach)
local Surface = require(script.Surface)
local Types = require(script.Types)

type Piece = Types.Piece

export type ArenaGeometry = {
	surface: { Piece },
	-- The glass on the inner bank's and the outer wall's tops.
	barriers: { Piece },
	infield: { Piece },
	gates: { Crossing.Rectangle },
	goal: Types.Goal,
	markers: { Piece },
	teamSpawns: Types.TeamSpawns,
	ballSpawns: { CFrame },
}

local Geometry = {}

-- The skater's collider reaches half its width above the root.
local function checkReach(config: Config.GameConfig, gravity: number)
	local top = config.Arena.barrier.top
	local reach = Reach.skaterTop(config, gravity) + config.Movement.colliderDiameter / 2
	if top <= reach then
		error(
			string.format(
				"Arena: the glass (barrier.top %s) must rise above the highest a skater can reach (%.2f)",
				tostring(top),
				reach
			),
			0
		)
	end
end

-- gravity: the world's pull, in studs/s² (workspace.Gravity).
function Geometry.build(config: Config.GameConfig, gravity: number): ArenaGeometry
	checkReach(config, gravity)
	local arena = config.Arena
	return {
		surface = Surface.build(arena),
		barriers = Features.barriers(arena),
		infield = Features.infield(arena),
		gates = Features.gates(arena),
		goal = Features.goal(arena),
		markers = Features.markers(arena),
		teamSpawns = Features.teamSpawns(arena, config.Match.teamSize),
		ballSpawns = Features.ballSpawns(arena),
	}
end

return Geometry
