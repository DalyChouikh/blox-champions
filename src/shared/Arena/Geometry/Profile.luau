--!strict
-- The track's cross-sections (Arena spec §3.1) as points (u, y): u is the lateral distance from the inner glass's face
-- toward the outer glass, y the height above the lower floor. The solid section has six pieces, from the inner bank's
-- top down and across: the inner bank (a quarter circle, vertical where the glass stands on it), the lower floor, the
-- step, the upper floor, the outer wall's foot curve and the outer wall, up to its top. Glass stands on the two tops
-- (Features.barriers), and the top section closes the arena above them (R14). Every solid section has the same point
-- layout and only the step's height changes, so the straights' stepped profile blends point by point into the curved
-- ends' flat one.

local Config = require(script.Parent.Parent.Parent.Config)

type ArenaConfig = Config.ArenaConfig
type Piece = (t: number) -> Vector2

-- The bank, the step and the outer wall's foot share the strips left after one per piece, by length.
local CURVED_PIECES = { 1, 3, 5 }
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
	local width, radius, bank = arena.trackWidth, arena.wallCurveRadius, arena.innerBankHeight
	local stepFrom = stepStart(arena)
	local stepTo = stepFrom + arena.stepWidth
	return {
		arc(Vector2.new(bank, bank), bank, math.pi, 1.5 * math.pi),
		line(Vector2.new(bank, 0), Vector2.new(stepFrom, 0)),
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

-- The middle of the lower floor: the lane the team spawns line up on.
function Profile.lowerFloorCenter(arena: ArenaConfig): number
	return (arena.innerBankHeight + stepStart(arena)) / 2
end

-- How high the arena is closed (R14): at the walls' top under a closed map's roof, or ceilingAbove higher under an
-- open map's ceiling. The gates are this tall, and nothing in play is found above it (Bounds.inArena).
function Profile.topHeight(arena: ArenaConfig): number
	local wallTop = arena.barrier.top
	return if arena.top.kind == "Open" then wallTop + arena.top.ceilingAbove else wallTop
end

-- The top's cross-section. It closes the track's "O", running on from the outer glass's top back across to the inner
-- glass's, so its slabs hang above it, outside the track, as every section's do: a closed map's roof across the walls'
-- top, or an open map's strip up from the outer glass, its ceiling, and a strip down to the inner glass.
function Profile.top(arena: ArenaConfig): { Vector2 }
	local width, wallTop = arena.trackWidth, arena.barrier.top
	local outerTop, innerTop = Vector2.new(width, wallTop), Vector2.new(0, wallTop)
	if arena.top.kind ~= "Open" then
		return { outerTop, innerTop }
	end
	local ceiling = Profile.topHeight(arena)
	return { outerTop, Vector2.new(width, ceiling), Vector2.new(0, ceiling), innerTop }
end

return Profile
