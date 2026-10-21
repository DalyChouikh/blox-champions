--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Team = require(ReplicatedStorage.Shared.Rules.Team)

describe("Team", function()
	it("lists both teams in a fixed order, frozen", function()
		expect(Team.list).toEqual({ "Blue", "Orange" })
		expect(table.isfrozen(Team.list)).toBe(true)
	end)

	it("returns each team's opponent", function()
		expect(Team.opponent("Blue")).toBe("Orange")
		expect(Team.opponent("Orange")).toBe("Blue")
	end)
end)
