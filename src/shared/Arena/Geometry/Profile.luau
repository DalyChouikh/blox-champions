--!strict
-- The track's cross-section (spec §9.1) as points (u, y): u is the lateral distance from the inner wall face toward
-- the outer wall, y the height above the lower floor. Seven pieces, from the inner wall top down and across:
-- the inner wall, its foot curve, the lower floor, the step, the upper floor, the outer wall's foot curve and the
-- outer wall. Every cross-section has the same point layout and only the step's height changes, so the straights'
-- stepped profile blends point by point into the curved ends' flat one.

local Config = require(script.Parent.Parent.Parent.Config)

type ArenaConfig = Config.ArenaConfig
type Piece = (t: number) -> Vector2

-- The wall curves and the step share the strips left after one per straight piece, by length.
local CURVED_PIECES = { 2, 4, 6 }
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

	local order = { 1, 2, 3 }
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

-- The middle of the lower floor: the lane the team spawns line up on.
function Profile.lowerFloorCenter(arena: ArenaConfig): number
	return (arena.wallCurveRadius + stepStart(arena)) / 2
end

return Profile
