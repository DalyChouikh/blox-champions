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
end)
