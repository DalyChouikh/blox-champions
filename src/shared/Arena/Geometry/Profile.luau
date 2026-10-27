--!strict
-- The track's cross-sections (Arena spec §3.1) as points (u, y): u is the lateral distance from the inner glass's face
-- toward the outer glass, y the height above the lower floor. The solid section has six pieces, from the inner bank's
-- top down and across: the inner bank (a quarter circle, vertical where the glass stands on it), the lower floor, the
-- step, the upper floor, the outer wall's foot curve and the outer wall, up to its top. Every solid section has the
-- same point layout and only the step's height changes, so the straights' stepped profile blends point by point into
-- the curved ends' flat one. Rideable glass rises from the two solid tops and curls inward into its lips (R15), and
-- the top section closes the arena between the lips' ends (R14). Every section runs the same way around the track's
-- "O" (down the inner side, across, up the outer side, back across the top), so every slab hangs outside the track.

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

-- Where the glass stops being vertical and its lip starts curling inward (R15): the goal's arm stays under it, and
-- the carrier's beam ends there.
function Profile.lipStart(arena: ArenaConfig): number
	return arena.glass.top - arena.glass.lipRadius
end

-- The outer lip (R15): a quarter circle of glass.lipRadius curling inward from the outer glass's face, where it
-- stops being vertical (lipStart), to the top (glass.top). Its lipStrips + 1 points are evenly spaced by angle; the
-- inner lip mirrors it across the track.
local function outerLip(arena: ArenaConfig): { Vector2 }
	local glass = arena.glass
	local center = Vector2.new(arena.trackWidth - glass.lipRadius, Profile.lipStart(arena))
	local points: { Vector2 } = {}
	for strip = 0, glass.lipStrips do
		local angle = (math.pi / 2) * strip / glass.lipStrips
		table.insert(points, center + glass.lipRadius * Vector2.new(math.cos(angle), math.sin(angle)))
	end
	return points
end

-- The outer glass, run up the profile's way: from the outer wall's top up its face and round its lip to where the
-- top begins.
function Profile.outerGlass(arena: ArenaConfig): { Vector2 }
	local points = { Vector2.new(arena.trackWidth, arena.outerWallHeight) }
	for _, point in outerLip(arena) do
		table.insert(points, point)
	end
	return points
end

-- The inner glass, the outer one mirrored across the track and run down the profile's way: from where the top
-- begins, round its lip and down its face to the inner bank's top.
function Profile.innerGlass(arena: ArenaConfig): { Vector2 }
	local lip = outerLip(arena)
	local points: { Vector2 } = {}
	for index = #lip, 1, -1 do
		table.insert(points, Vector2.new(arena.trackWidth - lip[index].X, lip[index].Y))
	end
	table.insert(points, Vector2.new(0, arena.innerBankHeight))
	return points
end

-- The walls' top across the track as built (R15), as points in u order: the inner lip from the inner glass's face up
-- to its end, then the outer lip from its end down to the outer glass's face, glass.top between the two ends. A gate
-- panel ends at it (heightAt), so it meets the lips' chords and never pokes through them.
function Profile.topOutline(arena: ArenaConfig): { Vector2 }
	local lip = outerLip(arena)
	local points: { Vector2 } = {}
	for index = 1, #lip do
		table.insert(points, Vector2.new(arena.trackWidth - lip[index].X, lip[index].Y))
	end
	for index = #lip, 1, -1 do
		table.insert(points, lip[index])
	end
	return points
end

-- The height of a cross-section at a lateral position: along the first of its segments that spans it running toward
-- the outer glass (a vertical one never does), or nil where none does.
function Profile.heightAt(points: { Vector2 }, lateral: number): number?
	for index = 1, #points - 1 do
		local from, to = points[index], points[index + 1]
		if from.X < to.X and from.X <= lateral and lateral <= to.X then
			return from.Y + (to.Y - from.Y) * (lateral - from.X) / (to.X - from.X)
		end
	end
	return nil
end

-- How high the arena is closed (R14): at the walls' top under a closed map's roof, or ceilingAbove higher under an
-- open map's ceiling. The gates are this tall, and nothing in play is found above it (Bounds.inArena).
function Profile.topHeight(arena: ArenaConfig): number
	local wallTop = arena.glass.top
	return if arena.top.kind == "Open" then wallTop + arena.top.ceilingAbove else wallTop
end

-- The top's cross-section. It closes the track's "O", running on from the outer lip's end back across to the inner
-- lip's, so its slabs hang above it, outside the track, as every section's do: a closed map's roof between the lips'
-- ends, or an open map's strip up from the outer lip's end, its ceiling, and a strip down to the inner lip's end.
function Profile.top(arena: ArenaConfig): { Vector2 }
	local outer = Profile.outerGlass(arena)
	local outerEnd, innerEnd = outer[#outer], Profile.innerGlass(arena)[1]
	if arena.top.kind ~= "Open" then
		return { outerEnd, innerEnd }
	end
	local ceiling = Profile.topHeight(arena)
	return { outerEnd, Vector2.new(outerEnd.X, ceiling), Vector2.new(innerEnd.X, ceiling), innerEnd }
end

return Profile
