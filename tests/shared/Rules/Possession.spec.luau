--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Possession = require(ReplicatedStorage.Shared.Rules.Possession)

describe("Possession", function()
	it("starts neutral", function()
		local possession = Possession.new()
		expect(possession.team).toBeNil()
		expect(possession.lastHolder).toBeNil()
	end)

	it("gives possession to the first team to pick up the ball", function()
		local possession = Possession.new()
		expect(possession:pickUp("B1", "Blue")).toBe(true)
		expect(possession.team).toBe("Blue")
		expect(possession.lastHolder).toBe("B1")
	end)

	it("keeps possession on a teammate pickup and changes it on an opponent pickup", function()
		local possession = Possession.new()
		possession:pickUp("B1", "Blue")
		expect(possession:pickUp("B2", "Blue")).toBe(false)
		expect(possession.team).toBe("Blue")
		expect(possession.lastHolder).toBe("B2")
		expect(possession:pickUp("O1", "Orange")).toBe(true)
		expect(possession.team).toBe("Orange")
		expect(possession.lastHolder).toBe("O1")
	end)

	it("returns to neutral on reset", function()
		local possession = Possession.new()
		possession:pickUp("B1", "Blue")
		possession:reset()
		expect(possession.team).toBeNil()
		expect(possession.lastHolder).toBeNil()
	end)
end)
