--!strict
-- The arena's smooth riding shape (#294): the direction of the ground at a point on any ride surface, read from the
-- shape the arena is built from instead of the flat strip a ray hits. Every ride surface is one closed cross-section
-- (the inner glass down to the bank's top, the solid section across to the outer wall's top, the outer glass, the top)
-- swept round the loop's stations, and Profile gives each strip's direction at its two ends from the shape's own
-- pieces. A point reads its strip's normals interpolated along it and between the two stations round it (smooth
-- shading: every seam is continuous, a real corner stays one), and across the track the section's frame turns with the
-- centerline, so round the ends the glass is a true cylinder. Prepared once per arena; a lookup allocates nothing.

local Centerline = require(script.Parent.Centerline)
local Config = require(script.Parent.Parent.Parent.Config)
local Profile = require(script.Parent.Profile)

type ArenaConfig = Config.ArenaConfig

-- Where two outlines meet they share a point: closer than this is the same one.
local SAME_POINT = 1e-6

export type Field = {
	arena: ArenaConfig,
	-- The stations' distances along the loop, ascending from 0, and the loop's length.
	stations: { number },
	length: number,
	-- Strips per section (a closed "O": the last strip ends at the first point).
	count: number,
	-- Flat over the stations' strips (index (station - 1) * count + strip): each strip's start point (u, y), and its
	-- normal (into the track) at its start and at its end.
	u: { number },
	y: { number },
	startU: { number },
	startY: { number },
	endU: { number },
	endY: { number },
}

-- The ride surface's normal at a point a ray found on it, given the face the ray met there: what the skating and the
-- server's look at the ground read. Specs whose slabs are not the arena keep the face.
export type Reader = (position: Vector3, face: Vector3) -> Vector3

local SmoothNormals = {}

-- The closed cross-section at `distance`: its points and each strip's direction at its start and end, in running
-- order. A run without directions (the top's flat strips) runs along its chords.
local function closedSection(arena: ArenaConfig, distance: number): ({ Vector2 }, { Vector2 }, { Vector2 })
	local points: { Vector2 }, starts: { Vector2 }, ends: { Vector2 } = {}, {}, {}
	local function add(run: { Vector2 }, runStarts: { Vector2 }?, runEnds: { Vector2 }?)
		for index, point in run do
			local last: Vector2? = points[#points]
			if last == nil or (point - last).Magnitude > SAME_POINT then
				table.insert(points, point)
			end
			if index < #run then
				local chord = (run[index + 1] - point).Unit
				table.insert(starts, if runStarts ~= nil then runStarts[index] else chord)
				table.insert(ends, if runEnds ~= nil then runEnds[index] else chord)
			end
		end
	end
	local straightness = Centerline.straightness(arena, distance)
	add(Profile.innerGlass(arena), Profile.innerGlassDirections(arena))
	add(Profile.points(arena, straightness), Profile.directions(arena, straightness))
	add(Profile.outerGlass(arena), Profile.outerGlassDirections(arena))
	add(Profile.top(arena))
	if (points[#points] - points[1]).Magnitude <= SAME_POINT then
		table.remove(points)
	end
	return points, starts, ends
end

-- `cornerDeg`: where two strips meet turning less than this, they meet in one direction, their mean (a half-blended
-- section's pieces meet at slightly different angles); at a sharper turn, a real corner, each keeps its own.
function SmoothNormals.prepare(arena: ArenaConfig, cornerDeg: number): Field
	local stations = Centerline.stations(arena)
	local cornerCos = math.cos(math.rad(cornerDeg))
	local field: Field = {
		arena = arena,
		stations = stations,
		length = Centerline.length(arena),
		count = 0,
		u = {},
		y = {},
		startU = {},
		startY = {},
		endU = {},
		endY = {},
	}
	for _, distance in stations do
		local points, starts, ends = closedSection(arena, distance)
		local count = #points
		assert(count == #starts, "the section closes: as many strips as points")
		assert(field.count == 0 or field.count == count, "every station's section has the same strips")
		field.count = count
		for strip = 1, count do
			local before = (strip - 2) % count + 1
			if ends[before]:Dot(starts[strip]) >= cornerCos then
				local mean = (ends[before] + starts[strip]).Unit
				ends[before], starts[strip] = mean, mean
			end
		end
		-- A strip's normal is its direction turned a quarter toward the track (the "O" runs with it on the left).
		for strip, point in points do
			table.insert(field.u, point.X)
			table.insert(field.y, point.Y)
			table.insert(field.startU, -starts[strip].Y)
			table.insert(field.startY, starts[strip].X)
			table.insert(field.endU, -ends[strip].Y)
			table.insert(field.endY, ends[strip].X)
		end
	end
	return field
end

-- The last station at or before `distance` (a binary search: the stations start at 0).
local function stationAt(field: Field, distance: number): number
	local stations = field.stations
	local low, high = 1, #stations
	while low < high do
		local middle = (low + high + 1) // 2
		if stations[middle] <= distance then
			low = middle
		else
			high = middle - 1
		end
	end
	return low
end

-- The smooth normal (unit, into the track) of the ride surface at `position`, a point on it.
function SmoothNormals.at(field: Field, position: Vector3): Vector3
	local arena = field.arena
	local distance = Centerline.distanceOf(arena, position)
	local stations, count = field.stations, field.count
	local i = stationAt(field, distance)
	local j = i % #stations + 1
	local t = (distance - stations[i]) / ((if j == 1 then field.length else stations[j]) - stations[i])
	-- The point in the section's frame at its own distance: u across toward the outer glass, y up.
	local centre, yaw = Centerline.pose(arena, distance, arena.trackWidth / 2, 0)
	local acrossX, acrossZ = math.cos(yaw), -math.sin(yaw)
	local u = (position.X - centre.X) * acrossX + (position.Z - centre.Z) * acrossZ + arena.trackWidth / 2
	local y = position.Y
	local baseI, baseJ = (i - 1) * count, (j - 1) * count
	local fu, fy = field.u, field.y
	-- The nearest strip of the section between the two stations, and how far along it the point lies.
	local nearest, along, gap = 1, 0, math.huge
	for strip = 1, count do
		local onward = strip % count + 1
		local pu = fu[baseI + strip] + (fu[baseJ + strip] - fu[baseI + strip]) * t
		local py = fy[baseI + strip] + (fy[baseJ + strip] - fy[baseI + strip]) * t
		local du = fu[baseI + onward] + (fu[baseJ + onward] - fu[baseI + onward]) * t - pu
		local dy = fy[baseI + onward] + (fy[baseJ + onward] - fy[baseI + onward]) * t - py
		local s = math.clamp(((u - pu) * du + (y - py) * dy) / (du * du + dy * dy), 0, 1)
		local gu, gy = pu + du * s - u, py + dy * s - y
		if gu * gu + gy * gy < gap then
			nearest, along, gap = strip, s, gu * gu + gy * gy
		end
	end
	local a, b = baseI + nearest, baseJ + nearest
	local nu = (field.startU[a] + (field.endU[a] - field.startU[a]) * along) * (1 - t)
		+ (field.startU[b] + (field.endU[b] - field.startU[b]) * along) * t
	local ny = (field.startY[a] + (field.endY[a] - field.startY[a]) * along) * (1 - t)
		+ (field.startY[b] + (field.endY[b] - field.startY[b]) * along) * t
	return Vector3.new(acrossX * nu, ny, acrossZ * nu).Unit
end

-- The arena's own Reader: its shape prepared once, read at the point whatever face the ray met.
function SmoothNormals.reader(arena: ArenaConfig, cornerDeg: number): Reader
	local field = SmoothNormals.prepare(arena, cornerDeg)
	return function(position: Vector3, _face: Vector3): Vector3
		return SmoothNormals.at(field, position)
	end
end

return SmoothNormals
