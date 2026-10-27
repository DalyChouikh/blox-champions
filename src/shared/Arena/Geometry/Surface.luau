--!strict
-- The riding surface: the cross-section swept around the centerline. At every station the profile (with the step
-- blended to that station's height) is placed across the track; each strip between two neighboring stations is a
-- quad, built as one block when it is a flat rectangle and as two wedge-pair triangles otherwise. The glass and the
-- top are swept the same way (Features).

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

-- p10 is the next station's point, p01 the next profile point.
local function isRectangle(p00: Vector3, p10: Vector3, p01: Vector3, p11: Vector3): boolean
	local across, along = p01 - p00, p10 - p00
	return ((p11 - p10) - across).Magnitude < RECTANGLE_TOLERANCE
		and math.abs(across.Unit:Dot(along.Unit)) < RECTANGLE_TOLERANCE
end

-- A flat rectangle as one block, its slab `thickness` behind the surface.
local function block(p00: Vector3, p10: Vector3, p01: Vector3, p11: Vector3, thickness: number): Piece
	local across, along = p01 - p00, p10 - p00
	-- Points into the track for floors and walls alike.
	local normal = across:Cross(along).Unit
	return {
		shape = "Block",
		cframe = CFrame.fromMatrix((p00 + p11) / 2 - normal * (thickness / 2), across.Unit, normal),
		size = Vector3.new(across.Magnitude, thickness, along.Magnitude),
	}
end

-- Whether the rectangle a → b continues the rectangle that starts at a0 → b0 in a straight line: the same width
-- across and the same direction along, so the two make one longer rectangle.
local function continues(a0: Vector3, b0: Vector3, a1: Vector3, a: Vector3, b: Vector3, a2: Vector3): boolean
	return ((b - a) - (b0 - a0)).Magnitude < RECTANGLE_TOLERANCE
		and ((a2 - a).Unit - (a1 - a0).Unit).Magnitude < RECTANGLE_TOLERANCE
end

-- Every slab hangs `thickness` behind the surface.
function Surface.quadPieces(p00: Vector3, p10: Vector3, p01: Vector3, p11: Vector3, thickness: number): { Piece }
	if isRectangle(p00, p10, p01, p11) then
		return { block(p00, p10, p01, p11, thickness) }
	end
	local normal = (p01 - p00):Cross(p10 - p00).Unit
	local pieces = Triangles.wedges(p00, p01, p11, normal, thickness)
	append(pieces, Triangles.wedges(p00, p11, p10, normal, thickness))
	return pieces
end

-- The cross-section `section(distance)` gives (points (u, y), as Profile's) placed across the track at every station
-- around the loop: one ring of world points per station.
function Surface.rings(arena: ArenaConfig, section: (distance: number) -> { Vector2 }): { { Vector3 } }
	local rings: { { Vector3 } } = {}
	for _, distance in Centerline.stations(arena) do
		local ring: { Vector3 } = {}
		for _, point in section(distance) do
			table.insert(ring, Centerline.at(arena, distance, point.X, point.Y).Position)
		end
		table.insert(rings, ring)
	end
	return rings
end

-- The strips between every two neighboring points of the rings, around the whole loop, each slab `thickness` behind
-- the side a strip faces: the side to the left of the ring's direction, seen along the travel direction (into the
-- track for a profile run from the inner top across to the outer top). Neighboring rectangles that continue each
-- other in a straight line (a strip whose cross-section does not change along a straight) merge into one long block:
-- fewer parts, and no seams across the strip for a rolling ball to bump on.
function Surface.sweep(rings: { { Vector3 } }, thickness: number): { Piece }
	local pieces: { Piece } = {}
	for point = 1, #rings[1] - 1 do
		-- The open run of rectangles: its first quad's near edge, and its far edge so far.
		local runStart: { Vector3 }? = nil
		local runEnd: { Vector3 }? = nil
		local function flush()
			if runStart ~= nil and runEnd ~= nil then
				table.insert(
					pieces,
					block(runStart[point], runEnd[point], runStart[point + 1], runEnd[point + 1], thickness)
				)
			end
			runStart, runEnd = nil, nil
		end
		for index, ring in rings do
			-- The last station pairs with the first; a run never wraps past it, since one starts fresh at the first.
			local nextRing = rings[index % #rings + 1]
			local p00, p10, p01, p11 = ring[point], nextRing[point], ring[point + 1], nextRing[point + 1]
			if not isRectangle(p00, p10, p01, p11) then
				flush()
				append(pieces, Surface.quadPieces(p00, p10, p01, p11, thickness))
			else
				local start = runStart
				if
					start == nil
					or not continues(start[point], start[point + 1], (runEnd :: { Vector3 })[point], p00, p01, p10)
				then
					flush()
					runStart = ring
				end
				runEnd = nextRing
			end
		end
		flush()
	end
	return pieces
end

-- The riding surface: the floors, the inner bank and the outer wall, from the bank's top to the outer wall's top.
function Surface.build(arena: ArenaConfig): { Piece }
	local rings = Surface.rings(arena, function(distance: number): { Vector2 }
		return Profile.points(arena, arena.stepHeight * Centerline.stepBlend(arena, distance))
	end)
	return Surface.sweep(rings, arena.surfaceThickness)
end

return Surface
