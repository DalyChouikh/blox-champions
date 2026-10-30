--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local MatchOutcome = require(ReplicatedStorage.Shared.Rules.MatchOutcome)
local Team = require(ReplicatedStorage.Shared.Rules.Team)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

type Scores = { [Team.Team]: number }

local function afterPoint(period: Types.Period, scores: Scores, scoringTeam: Team.Team): { any }
	return { MatchOutcome.afterPoint(period, scores, scoringTeam, 5) }
end

local function timeUp(period: Types.Period, scores: Scores, possessingTeam: Team.Team?, lastChance: boolean): { any }
	return { MatchOutcome.atTimeUp(period, scores, possessingTeam, lastChance) }
end

describe("MatchOutcome.afterPoint", function()
	it("declares a winner in regulation only when a team reaches pointsToWin", function()
		expect(afterPoint("Regulation", { Blue = 5, Orange = 3 }, "Blue")).toEqual({ "Win", "Blue" })
		expect(afterPoint("Regulation", { Blue = 4, Orange = 3 }, "Blue")).toEqual({ "Continue" })
	end)

	it("ends overtime on the next goal", function()
		expect(afterPoint("Overtime", { Blue = 2, Orange = 3 }, "Orange")).toEqual({ "Win", "Orange" })
	end)

	-- The owner (Q94): Last Chance is one attack, so its goal ends it whatever the score becomes.
	it("ends Last Chance on the trailing team's goal: level goes to overtime, otherwise whoever leads wins", function()
		expect(afterPoint("LastChance", { Blue = 3, Orange = 3 }, "Blue")).toEqual({ "Overtime" })
		expect(afterPoint("LastChance", { Blue = 4, Orange = 3 }, "Blue")).toEqual({ "Win", "Blue" })
		expect(afterPoint("LastChance", { Blue = 1, Orange = 3 }, "Blue")).toEqual({ "Win", "Orange" })
		expect(afterPoint("LastChance", { Blue = 4, Orange = 0 }, "Orange")).toEqual({ "Win", "Blue" })
	end)
end)

describe("MatchOutcome.atTimeUp", function()
	it("goes to overtime when the scores are level", function()
		expect(timeUp("Regulation", { Blue = 2, Orange = 2 }, "Blue", true)).toEqual({ "Overtime" })
	end)

	it("gives Last Chance to a trailing team that has the ball, at any deficit", function()
		expect(timeUp("Regulation", { Blue = 2, Orange = 3 }, "Blue", true)).toEqual({ "LastChance", "Blue" })
		expect(timeUp("Regulation", { Blue = 0, Orange = 4 }, "Blue", true)).toEqual({ "LastChance", "Blue" })
		expect(timeUp("Regulation", { Blue = 4, Orange = 0 }, "Orange", true)).toEqual({ "LastChance", "Orange" })
	end)

	it("lets the leader win when the trailing team does not have the ball or Last Chance is off", function()
		expect(timeUp("Regulation", { Blue = 2, Orange = 3 }, "Orange", true)).toEqual({ "Win", "Orange" })
		expect(timeUp("Regulation", { Blue = 2, Orange = 3 }, nil, true)).toEqual({ "Win", "Orange" })
		expect(timeUp("Regulation", { Blue = 2, Orange = 3 }, "Blue", false)).toEqual({ "Win", "Orange" })
	end)

	-- The owner (Q95): overtime's 0:00 is a draw at once, even with a team holding the ball.
	it("ends overtime in a draw, whoever has the ball", function()
		expect(timeUp("Overtime", { Blue = 3, Orange = 3 }, "Blue", true)).toEqual({ "Draw" })
		expect(timeUp("Overtime", { Blue = 3, Orange = 3 }, nil, true)).toEqual({ "Draw" })
	end)
end)

describe("MatchOutcome.afterPickup", function()
	it("ends Last Chance with the leaders' win when they pick up the ball, and nothing else", function()
		expect(MatchOutcome.afterPickup("Blue", "Orange")).toBe("Orange")
		expect(MatchOutcome.afterPickup("Blue", "Blue")).toBeNil()
		expect(MatchOutcome.afterPickup(nil, "Orange")).toBeNil()
	end)
end)
