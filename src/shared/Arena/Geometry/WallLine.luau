--!strict
-- A line along the outer wall at one height, from a gate to the next (the fire lines, #412, the owner's Q300 and Q329;
-- Arena spec §5.4). At each of the section's stations, where the swept surface's cross-sections stand, it passes the
-- wall's point at that height on the section as built there (Profile.outerWallAt), lifted `lift` off the surface
-- along its normal: a chord between two stations then lies along the surface's facet. Chords that keep one direction
-- join into one straight piece, so a straight's middle is one piece and a curved end keeps a piece a chord.

local Centerline = require(script.Parent.Centerline)
local Config = require(script.Parent.Parent.Parent.Config)
local Profile = require(script.Parent.Profile)

type ArenaConfig = Config.ArenaConfig

-- A chord whose direction differs from its piece's first by less than this (about radians) goes on that piece: a
-- straight's float32 points put its chords about 1e-6 apart, while a curved end's turn about 0.04 each.
local STRAIGHT = 1e-4

-- One straight piece: the distances along the track it runs between, and its two ends.
export type Piece = { from: number, to: number, start: Vector3, finish: Vector3 }

local WallLine = {}

-- The line along section `gate` (from gate `gate` to the next) at `height` above the lowest floor, in travel order.
function WallLine.section(arena: ArenaConfig, gate: number, height: number, lift: number): { Piece }
	local stations = Centerline.sectionStations(arena, gate)
	local points: { Vector3 } = {}
	for _, distance in stations do
		local across, normal = Profile.outerWallAt(arena, Centerline.straightness(arena, distance), height)
		table.insert(points, (Centerline.pose(arena, distance, across + normal.X * lift, height + normal.Y * lift)))
	end
	local pieces: { Piece } = {}
	local direction: Vector3? = nil
	for index = 2, #points do
		local along = (points[index] - points[index - 1]).Unit
		if direction ~= nil and (along - direction).Magnitude < STRAIGHT then
			local piece = pieces[#pieces]
			piece.to, piece.finish = stations[index], points[index]
		else
			direction = along
			table.insert(pieces, {
				from = stations[index - 1],
				to = stations[index],
				start = points[index - 1],
				finish = points[index],
			})
		end
	end
	return pieces
end

return WallLine
