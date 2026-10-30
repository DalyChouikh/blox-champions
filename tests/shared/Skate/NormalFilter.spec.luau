--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local NormalFilter = require(ReplicatedStorage.Shared.Skate.NormalFilter)

local cornerDeg = Config.defaults().Movement.cornerDeg
-- Measured in Phase 3: a downward ray exactly on a seam of the step hit a slab's side face.
local SEAM = Vector3.new(0, 0.49, -0.87)
-- A side face on a seam the other way: a sharp turn from both the floor and SEAM.
local CROSS_SEAM = Vector3.new(0.87, 0.49, 0)

describe("NormalFilter", function()
	it("ignores a lone normal that turns sharply, such as a seam's side face", function()
		local filter = NormalFilter.new(cornerDeg, Vector3.yAxis)
		Fixtures.expectNear(filter:update(SEAM), Vector3.yAxis)
		Fixtures.expectNear(filter:update(Vector3.yAxis), Vector3.yAxis)
	end)

	it("forgets a lone sharp ray once a ray is trusted, so the next lone one is ignored too", function()
		local filter = NormalFilter.new(cornerDeg, Vector3.yAxis)
		filter:update(SEAM)
		filter:update(Vector3.yAxis)
		Fixtures.expectNear(filter:update(SEAM), Vector3.yAxis)
	end)

	it("accepts a sharp turn that lasts for two rays", function()
		local filter = NormalFilter.new(cornerDeg, Vector3.yAxis)
		filter:update(SEAM)
		Fixtures.expectNear(filter:update(SEAM), SEAM.Unit)
	end)

	it("accepts a sharp turn only when the very next ray agrees with it", function()
		local filter = NormalFilter.new(cornerDeg, Vector3.yAxis)
		filter:update(SEAM)
		Fixtures.expectNear(filter:update(CROSS_SEAM), Vector3.yAxis)
		Fixtures.expectNear(filter:update(CROSS_SEAM), CROSS_SEAM.Unit)
	end)

	-- The owner's re-playtest (#255): smoothing small turns made the skating lag the surface on curved walls, which
	-- added energy on every wall visit, so swings between the walls never died. Over the middle bank's six 15° strips
	-- onto the glass (#234), each ray's normal is the surface's, at once.
	it("passes every small turn through as it is, and starts over from a reset", function()
		local filter = NormalFilter.new(cornerDeg, Vector3.yAxis)
		for _, tilt in { 7.5, 22.5, 37.5, 52.5, 67.5, 82.5, 90 } do
			local strip = Vector3.new(0, math.cos(math.rad(tilt)), -math.sin(math.rad(tilt)))
			local out = filter:update(strip)
			expect(math.atan2(out:Cross(strip).Magnitude, out:Dot(strip))).toBeLessThan(1e-6)
		end
		filter:reset(Vector3.xAxis)
		Fixtures.expectNear(filter.normal, Vector3.xAxis)
	end)
end)
