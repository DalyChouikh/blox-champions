--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local LastChance = require(ReplicatedStorage.Shared.Rules.LastChance)

describe("LastChance", function()
	it("ends the match when a leading-team player picks up the ball", function()
		expect(LastChance.endsOnPickup("Blue", "Orange")).toBe(true)
		expect(LastChance.endsOnPickup("Blue", "Blue")).toBe(false)
	end)

	it("goes to overtime when the trailing team ties, and continues while it is still behind", function()
		expect(LastChance.afterPoint({ Blue = 3, Orange = 3 }, "Blue")).toBe("Overtime")
		expect(LastChance.afterPoint({ Blue = 2, Orange = 3 }, "Blue")).toBe("Continue")
	end)

	it("lets the trailing team win when a point worth more than the deficit puts it ahead", function()
		expect(LastChance.afterPoint({ Blue = 4, Orange = 3 }, "Blue")).toBe("Win")
	end)
end)
