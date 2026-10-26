--!strict
-- The track's cross-section (spec §9.1) as points (u, y): u is the lateral distance from the inner wall face toward
-- the outer wall, y the height above the lower floor. Eight pieces, from the inner wall top down and across:
-- the inner wall, its foot curve, the lower floor, the step, the upper floor, the outer wall's foot curve, the
-- outer wall and the roof, an arc back over to the inner wall top (A2: the tube closes). Every cross-section has the
-- same point layout and only the step's height changes, so the straights' stepped profile blends point by point into
-- the curved ends' flat one.

local Config = require(script.Parent.Parent.Parent.Config)

type ArenaConfig = Config.ArenaConfig
type Piece = (t: number) -> Vector2

-- The wall feet, the step and the roof share the strips left after one per straight piece, by length.
local CURVED_PIECES = { 2, 4, 6, 8 }
local LENGTH_SEGMENTS = 64

local Profile = {}

local function line(from: Vector2, to: Vector2): Piece
	return function(t: number): Vector2
		return from:Lerp(to, t)
	end
end

local function arc(center: Vector2, radius: number, fromAngle: number, toAngle: number): Piece
	return function(t: number): Vector2
		local angle = fromAngle + t * (toAngle - fromAngle)
		return center + radius * Vector2.new(math.cos(angle), math.sin(angle))
	end
end

-- The roof's circle, in the profile's (u, y): its centre (u, y) is the midpoint of the two wall tops and its radius
-- half their distance, so the arc is a half circle when the walls are level (the owner's enclosed arena). Plain
-- numbers, because Bounds.inTube reads it on each check over the wall tops and a Vector2 is a heap object.
function Profile.roofCircle(arena: ArenaConfig): (number, number, number)
	local width, rise = arena.trackWidth, arena.outerWallHeight - arena.infieldWallHeight
	return width / 2, arena.infieldWallHeight + rise / 2, math.sqrt(width * width + rise * rise) / 2
end

local function roofArc(arena: ArenaConfig): Piece
	local centerU, centerY, radius = Profile.roofCircle(arena)
	local from = math.atan2(arena.outerWallHeight - centerY, arena.trackWidth - centerU)
	local to = math.atan2(arena.infieldWallHeight - centerY, -centerU)
	if to < from then
		to += 2 * math.pi
	end
	return arc(Vector2.new(centerU, centerY), radius, from, to)
end

local function stepStart(arena: ArenaConfig): number
	return arena.trackWidth - arena.wallCurveRadius - arena.upperFloorWidth - arena.stepWidth
end

local function pieces(arena: ArenaConfig, stepHeight: number): { Piece }
	local width, radius = arena.trackWidth, arena.wallCurveRadius
	local stepFrom = stepStart(arena)
	local stepTo = stepFrom + arena.stepWidth
	return {
		line(Vector2.new(0, arena.infieldWallHeight), Vector2.new(0, radius)),
		arc(Vector2.new(radius, radius), radius, math.pi, 1.5 * math.pi),
		line(Vector2.new(radius, 0), Vector2.new(stepFrom, 0)),
		function(t: number): Vector2
			return Vector2.new(stepFrom + t * arena.stepWidth, stepHeight * (1 - math.cos(math.pi * t)) / 2)
		end,
		line(Vector2.new(stepTo, stepHeight), Vector2.new(width - radius, stepHeight)),
		arc(Vector2.new(width - radius, stepHeight + radius), radius, 1.5 * math.pi, 2 * math.pi),
		line(Vector2.new(width, stepHeight + radius), Vector2.new(width, arena.outerWallHeight)),
		roofArc(arena),
	}
end

local function measure(piece: Piece): number
	local length = 0
	local previous = piece(0)
	for segment = 1, LENGTH_SEGMENTS do
		local current = piece(segment / LENGTH_SEGMENTS)
		length += (current - previous).Magnitude
		previous = current
	end
	return length
end

-- Strips per piece, summing to stripsPerSection. Every piece gets one; the curved pieces share the rest in
-- proportion to their lengths at full stepHeight, leftovers going to the largest remainders (ties to the earlier
-- piece). The counts never depend on the step's blended height.
function Profile.stripCounts(arena: ArenaConfig): { number }
	local shape = pieces(arena, arena.stepHeight)
	local counts = table.create(#shape, 1)
	local lengths: { number } = {}
	local total = 0
	for slot, index in CURVED_PIECES do
		lengths[slot] = measure(shape[index])
		total += lengths[slot]
	end

	local spare = arena.stripsPerSection - #shape
	local remainders: { number } = {}
	local given = 0
	for slot, index in CURVED_PIECES do
		local share = spare * lengths[slot] / total
		local whole = math.floor(share)
		counts[index] += whole
		given += whole
		remainders[slot] = share - whole
	end

	local order: { number } = {}
	for slot = 1, #CURVED_PIECES do
		order[slot] = slot
	end
	table.sort(order, function(a: number, b: number): boolean
		if remainders[a] ~= remainders[b] then
			return remainders[a] > remainders[b]
		end
		return a < b
	end)
	for rank = 1, spare - given do
		local index = CURVED_PIECES[order[rank]]
		counts[index] += 1
	end
	return counts
end

-- stripsPerSection + 1 points, spaced evenly within each piece (by angle on the curves) and shared where pieces meet.
function Profile.points(arena: ArenaConfig, stepHeight: number): { Vector2 }
	local shape = pieces(arena, stepHeight)
	local counts = Profile.stripCounts(arena)
	local points = { shape[1](0) }
	for index, piece in shape do
		local count = counts[index]
		for strip = 1, count do
			table.insert(points, piece(strip / count))
		end
	end
	return points
end

-- The highest point of the roof: the apex of its circle. The lap gates are as tall as it.
function Profile.roofTop(arena: ArenaConfig): number
	local _, centerY, radius = Profile.roofCircle(arena)
	return centerY + radius
end

-- The point where the roof starts, at the outer wall's top: the roof's strips run from here to the last point.
function Profile.roofEdge(arena: ArenaConfig): number
	local counts = Profile.stripCounts(arena)
	local before = 1
	for index = 1, #counts - 1 do
		before += counts[index]
	end
	return before
end

-- The middle of the lower floor: the lane the team spawns line up on.
function Profile.lowerFloorCenter(arena: ArenaConfig): number
	return (arena.wallCurveRadius + stepStart(arena)) / 2
end

return Profile
