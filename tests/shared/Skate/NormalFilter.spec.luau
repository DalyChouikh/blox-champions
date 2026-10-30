--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local NormalFilter = require(ReplicatedStorage.Shared.Skate.NormalFilter)

local settings = Config.defaults().Movement.normalFilter
-- Measured in Phase 3: a downward ray exactly on a seam of the step hit a slab's side face.
local SEAM = Vector3.new(0, 0.49, -0.87)

describe("NormalFilter", function()
	it("ignores a lone normal that turns sharply, such as a seam's side face", function()
		local filter = NormalFilter.new(settings, Vector3.yAxis)
		Fixtures.expectNear(filter:update(SEAM, 1 / 60), Vector3.yAxis)
		Fixtures.expectNear(filter:update(Vector3.yAxis, 1 / 60), Vector3.yAxis)
	end)

	it("accepts a sharp turn that lasts for two rays", function()
		local filter = NormalFilter.new(settings, Vector3.yAxis)
		filter:update(SEAM, 1 / 60)
		Fixtures.expectNear(filter:update(SEAM, 1 / 60), SEAM.Unit)
	end)

	it("smooths small turns, and starts over from a reset", function()
		local filter = NormalFilter.new(settings, Vector3.yAxis)
		local tilted = Vector3.new(math.sin(math.rad(10)), math.cos(math.rad(10)), 0)
		local out = filter:update(tilted, 1 / 60)
		expect(math.deg(math.acos(out:Dot(Vector3.yAxis)))).toBeCloseTo(3.9347, 3) -- 10° × (1 − e^(−30/60))
		filter:reset(Vector3.xAxis)
		Fixtures.expectNear(filter.normal, Vector3.xAxis)
	end)

	-- Measured in Play (#234): over the middle bank's six 15° strips onto the glass, the filtered normal stopped
	-- 1.3e-4 rad from the glass's and swung across it every frame. Pointing that hair down, it let the loop rule drop
	-- a skater off the glass.
	it("settles on a surface it keeps reading, however it came onto it", function()
		local filter = NormalFilter.new(settings, Vector3.yAxis)
		for _, tilt in { 7.5, 22.5, 37.5, 52.5, 67.5, 82.5 } do
			local strip = Vector3.new(0, math.cos(math.rad(tilt)), -math.sin(math.rad(tilt)))
			filter:update(strip, 1 / 60)
			filter:update(strip, 1 / 60)
		end
		local glass = Vector3.new(0, 0, -1)
		for _ = 1, 60 do
			filter:update(glass, 1 / 60)
		end
		-- Two frames, so a swing across the glass's normal shows on one of them.
		for _ = 1, 2 do
			local normal = filter:update(glass, 1 / 60)
			expect(math.atan2(normal:Cross(glass).Magnitude, normal:Dot(glass))).toBeLessThan(1e-6)
		end
	end)
end)
