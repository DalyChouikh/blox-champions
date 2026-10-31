--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Pull = require(ReplicatedStorage.Shared.Ball.Pull)

local FROM = Vector3.new(6, 0, 0)
local TO = Vector3.new(1.7, -0.8, -0.3)

-- The owner (Q91, Q132, #311): a caught ball flies into the hand over 0.3 s.
describe("Pull", function()
	it("draws a caught ball straight from where it was shown to the carry spot, over the pull's time", function()
		Fixtures.expectNear(Pull.offset(FROM, TO, 0, 0.3), FROM)
		-- Half the time, half the way: (6 + 1.7) / 2, -0.8 / 2, -0.3 / 2.
		Fixtures.expectNear(Pull.offset(FROM, TO, 0.15, 0.3), Vector3.new(3.85, -0.4, -0.15))
		Fixtures.expectNear(Pull.offset(FROM, TO, 0.3, 0.3), TO)
	end)

	it("holds the carry spot once the time is up, and goes there at once when the pull takes none", function()
		Fixtures.expectNear(Pull.offset(FROM, TO, 1, 0.3), TO)
		Fixtures.expectNear(Pull.offset(FROM, TO, 0, 0), TO)
		expect(Pull.over(0.29, 0.3)).toBe(false)
		expect(Pull.over(0.3, 0.3)).toBe(true)
		expect(Pull.over(0, 0)).toBe(true)
	end)
end)
