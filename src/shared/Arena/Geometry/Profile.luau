--!strict
-- The track's cross-sections (Arena spec §3.1) as points (u, y): u is the lateral distance from the inner glass's face
-- toward the outer glass, y the height above the lowest floor. The solid section runs from the inner bank's top down,
-- across and up the outer wall to its top, in six pieces laid out two ways (#268, Config.Arena): a straight's (the
-- inner bank, the spawn room, the rise, the incline, the outer wall's foot curve, the wall) and a curved end's (the
-- inner bank, the bowl in three shares, the foot curve, the wall). Both have the same point layout, so a section blends
-- from one to the other point by point around each corner. Rideable glass rises from the two solid tops and curls
-- inward into its lips (R15), and the top section closes the arena between the lips' ends (R14). Every section runs the
-- same way around the track's "O" (down the inner side, across, up the outer side, back across the top), so every slab
-- hangs outside the track.

local Config = require(script.Parent.Parent.Parent.Config)
local Vectors = require(script.Parent.Parent.Parent.Util.Vectors)

type ArenaConfig = Config.ArenaConfig
type Piece = (t: number) -> Vector2

-- Chords a piece is measured along when judging how far it turns.
local TURN_SEGMENTS = 64
-- Halvings of a quarter turn that pin the angle a curved end's bowl arrives at, past the points' float precision.
local ANGLE_HALVINGS = 50
-- The step (in a piece's t) its direction is read over: the second-order differences' error stays under 0.03° on
-- every piece, while Vector2's float32 points read over 1e-4 put the bowl's arrival 0.08° off (measured, #294).
local DIRECTION_STEP = 1e-3

local Profile = {}

local function line(from: Vector2, to: Vector2): Piece
	return function(t: number): Vector2
		return from:Lerp(to, t)
	end
end

-- An arc of the ellipse with these radii across and up around `center`: a circle's when they match.
local function arc(center: Vector2, radii: Vector2, fromAngle: number, toAngle: number): Piece
	return function(t: number): Vector2
		local angle = fromAngle + t * (toAngle - fromAngle)
		return center + radii * Vector2.new(math.cos(angle), math.sin(angle))
	end
end

-- The inner bank: a quarter ellipse `width` wide and innerBankHeight high, vertical where the glass stands on it and
-- flat where it meets the floor.
local function bank(arena: ArenaConfig, width: number): Piece
	local radii = Vector2.new(width, arena.innerBankHeight)
	return arc(radii, radii, math.pi, 1.5 * math.pi)
end

-- A cubic Hermite curve from `from`, leaving it flat, to `to`, arriving with `slope` (rise over run).
local function rise(from: Vector2, to: Vector2, slope: number): Piece
	local run, height = to.X - from.X, to.Y - from.Y
	return function(t: number): Vector2
		return from + Vector2.new(run * t, (3 - 2 * t) * t * t * height + (t - 1) * t * t * slope * run)
	end
end

-- Where across the track the outer wall's foot curve of `radius` starts when it leaves the floor at `angle` (radians up
-- from flat): it turns upright at the outer glass's face.
local function footStart(arena: ArenaConfig, radius: number, angle: number): number
	return arena.trackWidth - radius * (1 - math.sin(angle))
end

-- That foot curve, leaving the floor at `height`.
local function footCurve(arena: ArenaConfig, radius: number, angle: number, height: number): Piece
	local center = Vector2.new(arena.trackWidth - radius, height + radius * math.cos(angle))
	return arc(center, Vector2.one * radius, angle - math.pi / 2, 0)
end

-- The outer wall, from the top of its foot curve up to outerWallHeight, where the glass stands on it.
local function wall(arena: ArenaConfig, foot: Piece): Piece
	local top = foot(1)
	return line(top, Vector2.new(top.X, arena.outerWallHeight))
end

-- A straight's six pieces (Config.Arena.straight), and how far across its floor, from the bank's foot to the foot
-- curve, the spawn room and the rise end.
local function straightPieces(arena: ArenaConfig): ({ Piece }, { number })
	local straight = arena.straight
	local angle = math.rad(straight.inclineDeg)
	local slope = math.tan(angle)
	local floorEnd = footStart(arena, straight.footRadius, angle)
	local crest = Vector2.new(straight.riseEnd, straight.riseHeight)
	local inclineTop = Vector2.new(floorEnd, crest.Y + (floorEnd - crest.X) * slope)
	local foot = footCurve(arena, straight.footRadius, angle, inclineTop.Y)
	local floorWidth = floorEnd - straight.bankWidth
	local shares = {
		(straight.roomEnd - straight.bankWidth) / floorWidth,
		(straight.riseEnd - straight.bankWidth) / floorWidth,
	}
	return {
		bank(arena, straight.bankWidth),
		line(Vector2.new(straight.bankWidth, 0), Vector2.new(straight.roomEnd, 0)),
		rise(Vector2.new(straight.roomEnd, 0), crest, slope),
		line(crest, inclineTop),
		foot,
		wall(arena, foot),
	},
		shares
end

-- The angle a curved end's bowl arrives at its foot curve. The bowl rises bowlHeight · s^bowlPower as s runs from 0 at
-- the bank's foot to 1 where the foot curve starts, so it arrives with slope bowlHeight · bowlPower over its run; that
-- run ends where the foot curve leaving at the same angle starts (footStart). So the angle is the root of
-- tan(angle) · run(angle) − bowlHeight · bowlPower, which grows from below zero when flat past zero before upright
-- (the run stays positive: Config.Arena), and halving a quarter turn finds it.
local function bowlAngle(arena: ArenaConfig): number
	local curvedEnd = arena.curvedEnd
	local arrival = curvedEnd.bowlHeight * curvedEnd.bowlPower
	local low, high = 0, math.pi / 2
	for _ = 1, ANGLE_HALVINGS do
		local angle = (low + high) / 2
		local run = footStart(arena, curvedEnd.footRadius, angle) - arena.innerBankHeight
		if math.tan(angle) * run < arrival then
			low = angle
		else
			high = angle
		end
	end
	return (low + high) / 2
end

-- A curved end's six pieces (Config.Arena.curvedEnd): its bank is a quarter circle, and its bowl splits at a
-- straight's `shares` of the floor, so each of a straight's floor pieces blends into the matching share of the bowl.
local function curvedEndPieces(arena: ArenaConfig, shares: { number }): { Piece }
	local curvedEnd, bankFoot = arena.curvedEnd, arena.innerBankHeight
	local angle = bowlAngle(arena)
	local bowlRun = footStart(arena, curvedEnd.footRadius, angle) - bankFoot
	local function bowl(from: number, to: number): Piece
		return function(t: number): Vector2
			local share = from + t * (to - from)
			return Vector2.new(bankFoot + share * bowlRun, curvedEnd.bowlHeight * share ^ curvedEnd.bowlPower)
		end
	end
	local foot = footCurve(arena, curvedEnd.footRadius, angle, curvedEnd.bowlHeight)
	return {
		bank(arena, bankFoot),
		bowl(0, shares[1]),
		bowl(shares[1], shares[2]),
		bowl(shares[2], 1),
		foot,
		wall(arena, foot),
	}
end

-- How far a piece turns from its start to its end, summed over TURN_SEGMENTS chords: a quarter circle's about 90°, a
-- line's 0.
local function turning(piece: Piece): number
	local total = 0
	local previous = piece(0)
	local heading: Vector3? = nil
	for segment = 1, TURN_SEGMENTS do
		local current = piece(segment / TURN_SEGMENTS)
		local chord = current - previous
		local direction = Vector3.new(chord.X, chord.Y, 0)
		if heading ~= nil then
			total += Vectors.angleBetween(heading, direction)
		end
		heading, previous = direction, current
	end
	return total
end

-- Strips per piece, summing to stripsPerSection. Every piece gets one; the rest are shared by how far each piece
-- turns in the layout where it turns more, so every crease between two strips bends about as much, leftovers going to
-- the largest remainders (ties to the earlier piece). The bank turns a quarter in both, so some piece always turns.
local function stripCountsOf(arena: ArenaConfig, straight: { Piece }, curvedEnd: { Piece }): { number }
	local turns: { number } = {}
	local total = 0
	for index, piece in straight do
		turns[index] = math.max(turning(piece), turning(curvedEnd[index]))
		total += turns[index]
	end

	local counts = table.create(#straight, 1)
	local spare = arena.stripsPerSection - #straight
	local remainders: { number } = {}
	local given = 0
	for index, turn in turns do
		local share = spare * turn / total
		local whole = math.floor(share)
		counts[index] += whole
		given += whole
		remainders[index] = share - whole
	end

	local order: { number } = {}
	for index = 1, #turns do
		order[index] = index
	end
	table.sort(order, function(a: number, b: number): boolean
		if remainders[a] ~= remainders[b] then
			return remainders[a] > remainders[b]
		end
		return a < b
	end)
	for rank = 1, spare - given do
		counts[order[rank]] += 1
	end
	return counts
end

-- Strips per piece (stripCountsOf). They never depend on the blend.
function Profile.stripCounts(arena: ArenaConfig): { number }
	local straight, shares = straightPieces(arena)
	return stripCountsOf(arena, straight, curvedEndPieces(arena, shares))
end

-- The way a piece runs at `t` (unit): its derivative, read over steps that stay inside it (second-order differences,
-- one-sided at its ends, so where two pieces meet both read their own end exactly).
local function heading(piece: Piece, t: number): Vector2
	local step = DIRECTION_STEP
	if t - step < 0 then
		return (piece(t + step) * 4 - piece(t) * 3 - piece(t + 2 * step)).Unit
	elseif t + step > 1 then
		return (piece(t) * 3 - piece(t - step) * 4 + piece(t - 2 * step)).Unit
	end
	return (piece(t + step) - piece(t - step)).Unit
end

-- Each strip of a curved end's section blended toward a straight's by `straightness` (0 at a curved end, 1 on a
-- straight), in running order: `visit` gets the strip's blended piece and the piece's t at the strip's two ends.
-- Each piece's strips are spaced evenly within it (by angle on the arcs, across the floors).
local function eachStrip(
	arena: ArenaConfig,
	straightness: number,
	visit: (piece: Piece, from: number, to: number) -> ()
)
	local straight, shares = straightPieces(arena)
	local curvedEnd = curvedEndPieces(arena, shares)
	for index, count in stripCountsOf(arena, straight, curvedEnd) do
		local function piece(t: number): Vector2
			return curvedEnd[index](t):Lerp(straight[index](t), straightness)
		end
		for strip = 1, count do
			visit(piece, (strip - 1) / count, strip / count)
		end
	end
end

-- stripsPerSection + 1 points: the strips' ends (eachStrip), shared where pieces meet.
function Profile.points(arena: ArenaConfig, straightness: number): { Vector2 }
	local points: { Vector2 } = {}
	eachStrip(arena, straightness, function(piece: Piece, from: number, to: number)
		if #points == 0 then
			table.insert(points, piece(from))
		end
		table.insert(points, piece(to))
	end)
	return points
end

-- Each strip's direction at its start and at its end (unit, the section's running way): the smooth shape's own, read
-- from its pieces, so where two pieces meet smoothly they agree and at a real corner they do not (#294).
function Profile.directions(arena: ArenaConfig, straightness: number): ({ Vector2 }, { Vector2 })
	local starts: { Vector2 }, ends: { Vector2 } = {}, {}
	eachStrip(arena, straightness, function(piece: Piece, from: number, to: number)
		table.insert(starts, heading(piece, from))
		table.insert(ends, heading(piece, to))
	end)
	return starts, ends
end

-- The middle of a straight's spawn room: the lane the team spawns line up on.
function Profile.spawnLane(arena: ArenaConfig): number
	return (arena.straight.bankWidth + arena.straight.roomEnd) / 2
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

-- The outer glass's strips' directions at their starts and ends (unit, Profile.outerGlass's way): up its face, then
-- along the lip's circle, which leaves the face upright (#294).
function Profile.outerGlassDirections(arena: ArenaConfig): ({ Vector2 }, { Vector2 })
	local strips = arena.glass.lipStrips
	local starts: { Vector2 }, ends: { Vector2 } = { Vector2.yAxis }, { Vector2.yAxis }
	for strip = 1, strips do
		local from, to = (math.pi / 2) * (strip - 1) / strips, (math.pi / 2) * strip / strips
		table.insert(starts, Vector2.new(-math.sin(from), math.cos(from)))
		table.insert(ends, Vector2.new(-math.sin(to), math.cos(to)))
	end
	return starts, ends
end

-- The inner glass's strips' directions (Profile.innerGlass's way): the outer glass's mirrored across the track and
-- run backwards, so each strip's start is the mirrored strip's end.
function Profile.innerGlassDirections(arena: ArenaConfig): ({ Vector2 }, { Vector2 })
	local outerStarts, outerEnds = Profile.outerGlassDirections(arena)
	local starts: { Vector2 }, ends: { Vector2 } = {}, {}
	for index = #outerStarts, 1, -1 do
		table.insert(starts, Vector2.new(outerEnds[index].X, -outerEnds[index].Y))
		table.insert(ends, Vector2.new(outerStarts[index].X, -outerStarts[index].Y))
	end
	return starts, ends
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
