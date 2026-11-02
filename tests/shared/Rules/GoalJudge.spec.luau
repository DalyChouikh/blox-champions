--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local GoalJudge = require(ReplicatedStorage.Shared.Rules.GoalJudge)

-- RC's values (the owner, sessions 20-21): +1 after a lap, +3 after two, +5 after three.
local POINTS_BY_LAP = { 1, 3, 5 }

describe("GoalJudge", function()
	it("starts closed and does not score while closed", function()
		local goal = GoalJudge.new(Fixtures.ring())
		expect(goal.openFor).toBeNil()
		expect(goal:scored(Fixtures.throughRing())).toBe(false)
	end)

	-- The owner (#305): the goal opens after the first 4 markers, a lap from the goal's gate.
	it("opens once, for the team that completes its first lap", function()
		local goal = GoalJudge.new(Fixtures.ring())
		expect(goal:lapCompleted("Blue", 1)).toBe(true)
		expect(goal.openFor).toBe("Blue")
		expect(goal:lapCompleted("Blue", 2)).toBe(false)
		expect(goal.openFor).toBe("Blue")
	end)

	-- The owner (#305): +1 after 4 markers, +3 after 8, +5 after 12; more markers add nothing.
	it("is worth the points of the laps completed, the last value from then on", function()
		local worth = {}
		for laps = 0, 5 do
			table.insert(worth, GoalJudge.worth(POINTS_BY_LAP, laps))
		end
		expect(worth).toEqual({ 0, 1, 3, 5, 5, 5 })
	end)

	-- The owner, 2026-10-27: the goal scores from behind as from the front.
	it("scores when the ball passes through the ring either way while open", function()
		local goal = GoalJudge.new(Fixtures.ring())
		local from, to = Fixtures.throughRing()
		expect(goal:scored(from, to)).toBe(false)
		goal:lapCompleted("Orange", 1)
		expect(goal:scored(to, from)).toBe(true)
		expect(goal:scored(Fixtures.throughGate(2))).toBe(false)
		expect(goal:scored(from, to)).toBe(true)
	end)

	it("reports whether closing changed anything", function()
		local goal = GoalJudge.new(Fixtures.ring())
		goal:lapCompleted("Blue", 1)
		expect(goal:close()).toBe(true)
		expect(goal.openFor).toBeNil()
		expect(goal:close()).toBe(false)
	end)
end)
