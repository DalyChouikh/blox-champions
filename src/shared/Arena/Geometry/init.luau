--!strict
-- The whole graybox arena as pure data (spec §9.2): the pieces to build and the frames the rules and spawning
-- need. Nothing here touches an Instance; server/Arena/Builder turns it into parts.

local Config = require(script.Parent.Parent.Config)
local Crossing = require(script.Parent.Parent.Rules.Crossing)
local Features = require(script.Features)
local Surface = require(script.Surface)
local Types = require(script.Types)

type Piece = Types.Piece

export type ArenaGeometry = {
	surface: { Piece },
	roof: { Piece },
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
	local riding = Surface.build(arena)
	return {
		surface = riding.surface,
		roof = riding.roof,
		infield = Features.infield(arena),
		gates = Features.gates(arena),
		goal = Features.goal(arena),
		markers = Features.markers(arena),
		teamSpawns = Features.teamSpawns(arena, config.Match.teamSize),
		ballSpawns = Features.ballSpawns(arena),
	}
end

return Geometry
