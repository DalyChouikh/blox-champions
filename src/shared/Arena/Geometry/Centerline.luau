--!strict
-- The track's centerline (spec §9.1): a loop of four sections in travel order — the top straight (z = −endRadius,
-- heading −X), the left curved end, the bottom straight and the right curved end — centered on the origin at
-- y = 0. Travel is counter-clockwise seen from above, so a frame's RightVector points at the outer wall.
-- Distances are measured along the centerline from Gate 1 (the start of the top straight) and wrap around.

local Config = require(script.Parent.Parent.Parent.Config)

type ArenaConfig = Config.ArenaConfig

local SECTION_COUNT = 4

local Centerline = {}

-- A lap gate stands at the start of each section.
Centerline.gateCount = SECTION_COUNT

-- Odd sections are straights, even ones the half circles around each curved end.
local function isStraight(index: number): boolean
	return index % 2 == 1
end

local function sectionLength(arena: ArenaConfig, index: number): number
	return if isStraight(index) then arena.straightLength else math.pi * arena.endRadius
end

-- The section a distance falls in, and how far into that section it is.
local function locate(arena: ArenaConfig, distance: number): (number, number)
	local offset = distance % Centerline.length(arena)
	for index = 1, SECTION_COUNT - 1 do
		local length = sectionLength(arena, index)
		if offset < length then
			return index, offset
		end
		offset -= length
	end
	return SECTION_COUNT, offset
end

function Centerline.length(arena: ArenaConfig): number
	return 2 * arena.straightLength + 2 * math.pi * arena.endRadius
end

-- A point on the cross-section at `distance` (lateral measured from the inner wall face toward the outer wall, height
-- from the lower floor), and the heading's yaw in radians: Roblox's Orientation Y, so CFrame.Angles(0, yaw, 0) looks
-- along the travel direction, (-sin yaw, 0, -cos yaw). Plain numbers and a Vector3 (a native value), so a caller
-- placing a part every frame allocates nothing.
function Centerline.pose(arena: ArenaConfig, distance: number, lateral: number, height: number): (Vector3, number)
	local index, offset = locate(arena, distance)
	local halfStraight, radius = arena.straightLength / 2, arena.endRadius
	-- The centerline's point and heading on the first half of the loop.
	local x: number, z: number, headingX: number, headingZ: number
	if isStraight(index) then
		x, z, headingX, headingZ = halfStraight - offset, -radius, -1, 0
	else
		local angle = offset / radius
		x, z = -halfStraight - radius * math.sin(angle), -radius * math.cos(angle)
		headingX, headingZ = -math.cos(angle), math.sin(angle)
	end
	-- The second half of the loop is the first half turned 180° about the vertical axis.
	local turn = if index <= SECTION_COUNT / 2 then 1 else -1
	x, z, headingX, headingZ = x * turn, z * turn, headingX * turn, headingZ * turn
	-- Across the track, toward the outer wall: the heading turned a quarter clockwise, seen from above.
	local across = lateral - arena.trackWidth / 2
	return Vector3.new(x - headingZ * across, height, z + headingX * across), math.atan2(-headingX, -headingZ)
end

function Centerline.frameAt(arena: ArenaConfig, distance: number): CFrame
	return Centerline.at(arena, distance, arena.trackWidth / 2, 0)
end

-- The pose at `distance` as a frame facing the travel direction, its RightVector toward the outer wall.
function Centerline.at(arena: ArenaConfig, distance: number, lateral: number, height: number): CFrame
	local position, yaw = Centerline.pose(arena, distance, lateral, height)
	return CFrame.new(position) * CFrame.Angles(0, yaw, 0)
end

-- How far along the track a point is: the inverse of `at` for any point across the track, found by projecting it onto
-- the centerline seen from above. Each section gives a distance within its own stretch of [0, length): around a curved
-- end the point lies past the straights' ends, so its angle from the end's start stays strictly inside a half turn.
function Centerline.distanceOf(arena: ArenaConfig, position: Vector3): number
	local halfStraight, radius = arena.straightLength / 2, arena.endRadius
	local x, z = position.X, position.Z
	if x > halfStraight then
		-- The right curved end, the loop's last section.
		return 2 * arena.straightLength + math.pi * radius + radius * math.atan2(x - halfStraight, z)
	elseif x < -halfStraight then
		return arena.straightLength + radius * math.atan2(-(x + halfStraight), -z)
	elseif z < 0 then
		return halfStraight - x
	end
	return arena.straightLength + math.pi * radius + x + halfStraight
end

-- Gate g stands at the start of section g.
function Centerline.gateDistance(arena: ArenaConfig, gateIndex: number): number
	local distance = 0
	for index = 1, gateIndex - 1 do
		distance += sectionLength(arena, index)
	end
	return distance
end

-- One section split into equal pieces at most segmentLength long: the distances from its start to its end.
function Centerline.sectionStations(arena: ArenaConfig, index: number): { number }
	local start = Centerline.gateDistance(arena, index)
	local length = sectionLength(arena, index)
	local count = math.ceil(length / arena.segmentLength)
	local stations: { number } = {}
	for step = 0, count do
		table.insert(stations, start + step * (length / count))
	end
	return stations
end

-- Cross-section positions for the swept surface around the whole loop, each section's stations without its end
-- (the next section's start), so every gate is exactly a station.
function Centerline.stations(arena: ArenaConfig): { number }
	local stations: { number } = {}
	for index = 1, SECTION_COUNT do
		local section = Centerline.sectionStations(arena, index)
		for step = 1, #section - 1 do
			table.insert(stations, section[step])
		end
	end
	return stations
end

-- How much of the straights' step the cross-section at `distance` has: 1 on a straight, 0 on a curved end, eased
-- with a cosine across profileBlendLength centered on each corner.
function Centerline.stepBlend(arena: ArenaConfig, distance: number): number
	local index, offset = locate(arena, distance)
	local fromNearestEnd = math.min(offset, sectionLength(arena, index) - offset)
	local signed = if isStraight(index) then fromNearestEnd else -fromNearestEnd
	local blend = arena.profileBlendLength
	if signed >= blend / 2 then
		return 1
	elseif signed <= -blend / 2 then
		return 0
	end
	return (1 - math.cos(math.pi * (signed + blend / 2) / blend)) / 2
end

return Centerline
