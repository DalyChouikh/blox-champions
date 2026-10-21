--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local MatchOutcome = require(ReplicatedStorage.Shared.Rules.MatchOutcome)
local Team = require(ReplicatedStorage.Shared.Rules.Team)

local LAST_CHANCE = { enabled = true, maxDeficit = 1 }

local function timeUp(
	scores: { [Team.Team]: number },
	possessingTeam: Team.Team?,
	lastChance: { enabled: boolean, maxDeficit: number }
): { any }
	return { MatchOutcome.atTimeUp(scores, possessingTeam, lastChance) }
end

describe("MatchOutcome.afterPoint", function()
	it("declares a winner only when a team reaches pointsToWin", function()
		expect(MatchOutcome.afterPoint("Regulation", { Blue = 5, Orange = 3 }, "Blue", 5)).toBe("Blue")
		expect(MatchOutcome.afterPoint("Regulation", { Blue = 4, Orange = 3 }, "Blue", 5)).toBeNil()
		expect(MatchOutcome.afterPoint("LastChance", { Blue = 3, Orange = 3 }, "Blue", 5)).toBeNil()
	end)

	it("ends overtime on the next point", function()
		expect(MatchOutcome.afterPoint("Overtime", { Blue = 2, Orange = 3 }, "Orange", 5)).toBe("Orange")
	end)
end)

describe("MatchOutcome.atTimeUp", function()
	it("goes to overtime when the scores are tied", function()
		expect(timeUp({ Blue = 2, Orange = 2 }, "Blue", LAST_CHANCE)).toEqual({ "Overtime" })
	end)

	it("gives Last Chance to a team one point behind that has the ball", function()
		expect(timeUp({ Blue = 2, Orange = 3 }, "Blue", LAST_CHANCE)).toEqual({ "LastChance", "Blue" })
	end)

	it("lets the leader win when the trailing team does not have the ball", function()
		expect(timeUp({ Blue = 2, Orange = 3 }, "Orange", LAST_CHANCE)).toEqual({ "Win", "Orange" })
		expect(timeUp({ Blue = 2, Orange = 3 }, nil, LAST_CHANCE)).toEqual({ "Win", "Orange" })
	end)

	it("lets the leader win when the deficit exceeds maxDeficit or Last Chance is disabled", function()
		expect(timeUp({ Blue = 1, Orange = 3 }, "Blue", LAST_CHANCE)).toEqual({ "Win", "Orange" })
		expect(timeUp({ Blue = 1, Orange = 3 }, "Blue", { enabled = true, maxDeficit = 2 })).toEqual({
			"LastChance",
			"Blue",
		})
		expect(timeUp({ Blue = 2, Orange = 3 }, "Blue", { enabled = false, maxDeficit = 1 })).toEqual({
			"Win",
			"Orange",
		})
	end)
end)
