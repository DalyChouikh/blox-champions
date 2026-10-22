--!strict
-- The riding surface: the cross-section swept around the centerline. At every station the profile (with the step
-- blended to that station's height) is placed across the track; each strip between two neighboring stations is a
-- quad, built as one block when it is a flat rectangle and as two wedge-pair triangles otherwise.

local Centerline = require(script.Parent.Centerline)
local Config = require(script.Parent.Parent.Parent.Config)
local Profile = require(script.Parent.Profile)
local Triangles = require(script.Parent.Triangles)
local Types = require(script.Parent.Types)

type ArenaConfig = Config.ArenaConfig
type Piece = Types.Piece

-- How far a quad may be from a perfect rectangle and still become a block: float error on a long straight far from
-- the origin stays well under it, while the least-skewed real trapezoid exceeds it many times over.
local RECTANGLE_TOLERANCE = 1e-3

local Surface = {}

-- A plain loop: table.move into a growing list measured ~300× slower in Studio (70 ms against 0.2 ms here).
local function append(target: { Piece }, items: { Piece })
	for _, item in items do
		table.insert(target, item)
	end
end

-- p10 is the next station's point, p01 the next profile point. Every slab hangs `thickness` behind the surface.
function Surface.quadPieces(p00: Vector3, p10: Vector3, p01: Vector3, p11: Vector3, thickness: number): { Piece }
	local across, along = p01 - p00, p10 - p00
	-- Points into the track for floors and walls alike.
	local normal = across:Cross(along).Unit
	local isRectangle = ((p11 - p10) - across).Magnitude < RECTANGLE_TOLERANCE
		and math.abs(across.Unit:Dot(along.Unit)) < RECTANGLE_TOLERANCE
	if isRectangle then
		return {
			{
				shape = "Block",
				cframe = CFrame.fromMatrix((p00 + p11) / 2 - normal * (thickness / 2), across.Unit, normal),
				size = Vector3.new(across.Magnitude, thickness, along.Magnitude),
			},
		}
	end
	local pieces = Triangles.wedges(p00, p01, p11, normal, thickness)
	append(pieces, Triangles.wedges(p00, p11, p10, normal, thickness))
	return pieces
end

function Surface.pieces(arena: ArenaConfig): { Piece }
	local rings: { { Vector3 } } = {}
	for _, distance in Centerline.stations(arena) do
		local ring: { Vector3 } = {}
		for _, point in Profile.points(arena, arena.stepHeight * Centerline.stepBlend(arena, distance)) do
			table.insert(ring, Centerline.at(arena, distance, point.X, point.Y).Position)
		end
		table.insert(rings, ring)
	end

	local pieces: { Piece } = {}
	for index, ring in rings do
		local nextRing = rings[index % #rings + 1]
		for point = 1, #ring - 1 do
			append(
				pieces,
				Surface.quadPieces(
					ring[point],
					nextRing[point],
					ring[point + 1],
					nextRing[point + 1],
					arena.surfaceThickness
				)
			)
		end
	end
	return pieces
end

return Surface
