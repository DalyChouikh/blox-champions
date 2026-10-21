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

function Centerline.frameAt(arena: ArenaConfig, distance: number): CFrame
	local index, offset = locate(arena, distance)
	local halfStraight, radius = arena.straightLength / 2, arena.endRadius
	local position: Vector3, heading: Vector3
	if isStraight(index) then
		position = Vector3.new(halfStraight - offset, 0, -radius)
		heading = Vector3.new(-1, 0, 0)
	else
		local angle = offset / radius
		position = Vector3.new(-halfStraight - radius * math.sin(angle), 0, -radius * math.cos(angle))
		heading = Vector3.new(-math.cos(angle), 0, math.sin(angle))
	end
	-- The second half of the loop is the first half turned 180° about the vertical axis.
	local turn = if index <= SECTION_COUNT / 2 then 1 else -1
	position *= turn
	return CFrame.lookAt(position, position + heading * turn)
end

-- A point on the cross-section at `distance`: lateral is measured from the inner wall face toward the outer wall,
-- height from the lower floor.
function Centerline.at(arena: ArenaConfig, distance: number, lateral: number, height: number): CFrame
	return Centerline.frameAt(arena, distance) * CFrame.new(lateral - arena.trackWidth / 2, height, 0)
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
