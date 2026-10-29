--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Centerline = require(ReplicatedStorage.Shared.Arena.Geometry.Centerline)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Profile = require(ReplicatedStorage.Shared.Arena.Geometry.Profile)
local SmoothNormals = require(ReplicatedStorage.Shared.Arena.Geometry.SmoothNormals)
local Vectors = require(ReplicatedStorage.Shared.Util.Vectors)

-- The defaults (Profile.spec's header): the track is 80 wide round ends of radius 60 about (±100, 0), so the inner
-- glass's face (u = 0) is a cylinder of radius 20 about each end's axis; the outer lip is a quarter circle of radius 12
-- centred at (68, 108) across a section. The expected normals are the exact shape's, worked out independently.
local config = Config.defaults()
local arena = config.Arena
local field = SmoothNormals.prepare(arena, config.Movement.cornerDeg)
-- Round the +X end: the loop's last section, from 2 × 200 + π × 60 along it.
local END_START = 2 * arena.straightLength + math.pi * arena.endRadius
local END_AXIS = Vector3.new(arena.straightLength / 2, 0, 0)

local function degreesApart(a: Vector3, b: Vector3): number
	return math.deg(Vectors.angleBetween(a, b))
end

-- The point at (u, y) across the section at `distance`.
local function at(distance: number, u: number, y: number): Vector3
	return (Centerline.pose(arena, distance, u, y))
end

-- The section's u axis (toward the outer glass) at `distance`.
local function across(distance: number): Vector3
	local _, yaw = Centerline.pose(arena, distance, 0, 0)
	return Vector3.new(math.cos(yaw), 0, -math.sin(yaw))
end

-- The most the normal turns between neighbouring points 0.1 studs apart along the solid section at `distance`.
local function steepestStep(distance: number): number
	local points = Profile.points(arena, Centerline.straightness(arena, distance))
	local worst, previous = 0, nil :: Vector3?
	for strip = 1, #points - 1 do
		local from, to = points[strip], points[strip + 1]
		local steps = math.max(1, math.floor((to - from).Magnitude / 0.1))
		for step = 0, steps - 1 do
			local point = from:Lerp(to, step / steps)
			local normal = SmoothNormals.at(field, at(distance, point.X, point.Y))
			if previous ~= nil then
				worst = math.max(worst, degreesApart(normal, previous))
			end
			previous = normal
		end
	end
	return worst
end

describe("SmoothNormals", function()
	it("reads the middle glass's round ends as a true cylinder, all the way round and up", function()
		local worst = 0
		for step = 0, 99 do
			local distance = END_START + 0.2 + step * (math.pi * arena.endRadius - 0.4) / 99
			for _, height in { 20, 60, 100 } do
				local point = at(distance, 0, height)
				local radial = (Vector3.new(point.X, 0, point.Z) - END_AXIS).Unit
				worst = math.max(worst, degreesApart(SmoothNormals.at(field, point), radial))
			end
		end
		-- Within float noise (the directions are stored in Vector2's float32): a flat strip is up to 1.875° off.
		expect(worst).toBeLessThan(0.01)
	end)

	it("reads a straight's floor straight up, its outer glass level, and its lip round the lip's circle", function()
		Fixtures.expectNear(SmoothNormals.at(field, at(50, 27, 0)), Vector3.yAxis)
		Fixtures.expectNear(SmoothNormals.at(field, at(50, 80, 60)), -across(50))
		-- On the lip's circle at 30° and 60° round from its face the normal points at the circle's centre (the lip's
		-- four strips are 22.5° each, so a point between their edges reads the interpolated normal).
		for _, degrees in { 30, 60 } do
			local angle = math.rad(degrees)
			local point = at(50, 68 + 12 * math.cos(angle), 108 + 12 * math.sin(angle))
			local inward = -across(50) * math.cos(angle) - Vector3.yAxis * math.sin(angle)
			expect(degreesApart(SmoothNormals.at(field, point), inward)).toBeLessThan(0.1)
		end
	end)

	-- The strips turn up to ~15° from one to the next (the bank's 6 strips over a quarter turn): a flat strip's normal
	-- would step by that at every seam. Smooth, neighbours 0.1 studs apart turn only as the shape bends: at most 0.93°
	-- (measured, where the rise's S leaves the spawn room, its sharpest bend).
	it("turns the normal smoothly across every seam of a straight's and a curved end's section", function()
		expect(steepestStep(50)).toBeLessThan(1.5)
		expect(steepestStep(END_START + 30)).toBeLessThan(1.5)
	end)

	-- Where a straight's section blends into a curved end's the two layouts' pieces meet at slightly different
	-- angles (a half-blended section's floor kinks 2.7° where its bowl meets the foot curve): a crease under cornerDeg
	-- is no corner, so the normal stays smooth there too.
	it("stays smooth across a half-blended section's creases", function()
		expect(Centerline.straightness(arena, arena.straightLength)).toBeCloseTo(0.5, 5)
		expect(steepestStep(arena.straightLength)).toBeLessThan(1.5)
	end)

	it("reads a curved end's floor round the end, and runs on past the loop's start", function()
		-- A curved end's bowl leaves the bank's foot (u 16) flat: straight up there, a quarter of the way round.
		local quarter = END_START + math.pi * arena.endRadius / 4
		local normal = SmoothNormals.at(field, at(quarter, 16, 0))
		expect(normal.Y).toBeCloseTo(1, 3)
		-- The last station's strips reach on to the first's: on the floor where the loop's start blends a curved end's
		-- section into the top straight's (u 66, the bowl's last share), just before it and just after, the same.
		local length = Centerline.length(arena)
		local function onFloor(distance: number): Vector3
			local points = Profile.points(arena, Centerline.straightness(arena, distance))
			return SmoothNormals.at(field, at(distance, 66, Profile.heightAt(points, 66) :: number))
		end
		expect(degreesApart(onFloor(length - 0.05), onFloor(0.05))).toBeLessThan(0.1)
	end)

	-- What the skating and the server's look down read (#294): the shape at the point a ray found, whatever face
	-- it met there (a flat strip of the round glass is up to 1.875° off it).
	it("reads, for a ray's hit, the arena's own shape at the point, not the face it met", function()
		local read = SmoothNormals.reader(arena, config.Movement.cornerDeg)
		local facet = Vector3.new(math.cos(math.rad(1.875)), 0, math.sin(math.rad(1.875)))
		Fixtures.expectNear(read(END_AXIS + Vector3.new(20, 40, 0), facet), Vector3.xAxis)
	end)

	-- An open map's top rises from the outer lip's end to its ceiling (Profile.top): a real corner, where each strip
	-- keeps its own normal, so the ceiling reads straight down right up to it.
	it("keeps a real corner sharp: an open map's ceiling reads straight down right up to its corner", function()
		local open = Fixtures.config({ Arena = { top = { kind = "Open" } } }).Arena
		local openField = SmoothNormals.prepare(open, config.Movement.cornerDeg)
		local outerGlass = Profile.outerGlass(open)
		local nearCorner = Centerline.pose(open, 50, outerGlass[#outerGlass].X - 0.1, Profile.topHeight(open))
		Fixtures.expectNear(SmoothNormals.at(openField, nearCorner), -Vector3.yAxis)
	end)
end)
