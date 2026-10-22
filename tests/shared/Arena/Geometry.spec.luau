--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Geometry = require(ReplicatedStorage.Shared.Arena.Geometry)

describe("Geometry.build", function()
	it("collects the whole arena, with one team spawn per team slot", function()
		local geometry = Geometry.build(Fixtures.config({ Match = { teamSize = 2 } }))
		expect(#geometry.surface).toBe(7334)
		expect(#geometry.roof).toBe(8106)
		expect(#geometry.infield).toBe(193)
		expect(#geometry.gates).toBe(4)
		expect(#geometry.markers).toBe(4)
		expect(#geometry.teamSpawns.Blue).toBe(2)
		expect(#geometry.teamSpawns.Orange).toBe(2)
		expect(#geometry.ballSpawns).toBe(2)
		expect(geometry.goal.openingRadius).toBe(7)
	end)
end)
