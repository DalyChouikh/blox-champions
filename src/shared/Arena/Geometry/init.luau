--!strict
-- The whole graybox arena as pure data (spec §9.2, Arena spec §6.1): the pieces to build and the frames the rules and
-- spawning need. Nothing here touches an Instance; server/Arena/Builder turns it into parts. Its top closes it (a
-- glass roof, or an open map's ceiling: R14), so nothing in play leaves it.

local Config = require(script.Parent.Parent.Config)
local Crossing = require(script.Parent.Parent.Rules.Crossing)
local Features = require(script.Features)
local Surface = require(script.Surface)
local Types = require(script.Types)

type Piece = Types.Piece

export type ArenaGeometry = {
	-- The solid surface: the floors, the inner bank and the outer wall.
	surface: { Piece },
	-- The rideable glass on the inner bank's and the outer wall's tops, with its lips.
	glass: { Piece },
	-- What closes the arena between the lips' ends: a roof, or an open map's ceiling and the strips up to it.
	top: { Piece },
	infield: { Piece },
	gates: { Crossing.Rectangle },
	goal: Types.Goal,
	markers: { Piece },
	teamSpawns: Types.TeamSpawns,
	ballSpawns: { CFrame },
}

local Geometry = {}

function Geometry.build(config: Config.GameConfig): ArenaGeometry
	local arena = config.Arena
	return {
		surface = Surface.build(arena),
		glass = Features.glass(arena),
		top = Features.top(arena),
		infield = Features.infield(arena),
		gates = Features.gates(arena),
		goal = Features.goal(arena),
		markers = Features.markers(arena),
		teamSpawns = Features.teamSpawns(arena, config.Match.teamSize),
		ballSpawns = Features.ballSpawns(arena),
	}
end

return Geometry
