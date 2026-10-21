--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local GoalJudge = require(ReplicatedStorage.Shared.Rules.GoalJudge)

describe("GoalJudge", function()
	it("starts closed and does not score while closed", function()
		local goal = GoalJudge.new(Fixtures.ring(), 4)
		expect(goal.openFor).toBeNil()
		expect(goal:scored(Fixtures.throughRing())).toBe(false)
	end)

	it("opens once for a team whose streak reaches lapsToOpenGoal", function()
		local goal = GoalJudge.new(Fixtures.ring(), 4)
		expect(goal:lapCompleted("Blue", 3)).toBe(false)
		expect(goal.openFor).toBeNil()
		expect(goal:lapCompleted("Blue", 4)).toBe(true)
		expect(goal.openFor).toBe("Blue")
		expect(goal:lapCompleted("Blue", 5)).toBe(false)
		expect(goal.openFor).toBe("Blue")
	end)

	it("scores only when the ball passes front-to-back through the ring while open", function()
		local goal = GoalJudge.new(Fixtures.ring(), 1)
		goal:lapCompleted("Orange", 1)
		local from, to = Fixtures.throughRing()
		expect(goal:scored(to, from)).toBe(false)
		expect(goal:scored(Fixtures.throughGate(2))).toBe(false)
		expect(goal:scored(from, to)).toBe(true)
	end)

	it("reports whether closing changed anything", function()
		local goal = GoalJudge.new(Fixtures.ring(), 1)
		goal:lapCompleted("Blue", 1)
		expect(goal:close()).toBe(true)
		expect(goal.openFor).toBeNil()
		expect(goal:close()).toBe(false)
	end)
end)
