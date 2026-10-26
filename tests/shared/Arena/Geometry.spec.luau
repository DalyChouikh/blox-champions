--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Geometry = require(ReplicatedStorage.Shared.Arena.Geometry)

local GRAVITY = Fixtures.GRAVITY.Magnitude

describe("Geometry.build", function()
	it("collects the whole arena, with one team spawn per team slot", function()
		local geometry = Geometry.build(Fixtures.config({ Match = { teamSize = 2 } }), GRAVITY)
		expect(#geometry.surface).toBe(9182)
		expect(#geometry.barriers).toBe(224)
		expect((geometry :: any).roof).toBeNil()
		expect(#geometry.infield).toBe(221)
		expect(#geometry.gates).toBe(4)
		expect(#geometry.markers).toBe(4)
		expect(#geometry.teamSpawns.Blue).toBe(2)
		expect(#geometry.teamSpawns.Orange).toBe(2)
		expect(#geometry.ballSpawns).toBe(2)
		expect(geometry.goal.openingRadius).toBe(7)
	end)

	-- The owner's rule: no skater ever gets out (Arena spec §4.2). A mode that lowers the glass or raises hardCap
	-- builds no arena at all.
	it("refuses glass a skater could clear, naming both heights", function()
		expect(function()
			Geometry.build(Fixtures.config({ Arena = { barrier = { top = 70 } } }), GRAVITY)
		end).toThrow("Arena: the glass (barrier.top 70) must rise above the highest a skater can reach (78.95)")
		expect(function()
			Geometry.build(Fixtures.config({ Movement = { hardCap = 155, softCap = 90 } }), GRAVITY)
		end).toThrow("Arena: the glass (barrier.top 85) must rise above the highest a skater can reach (90.23)")
	end)
end)
