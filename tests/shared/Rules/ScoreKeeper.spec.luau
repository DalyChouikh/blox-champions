--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local ScoreKeeper = require(ReplicatedStorage.Shared.Rules.ScoreKeeper)
local Types = require(ReplicatedStorage.Shared.Rules.Types)

local function keeper(overrides: { [string]: any }?): ScoreKeeper.ScoreKeeper
	local scores = ScoreKeeper.new(Fixtures.config(overrides))
	scores:addPlayer("B1", "Blue")
	scores:addPlayer("B2", "Blue")
	scores:addPlayer("O1", "Orange")
	return scores
end

local function mvpAfter(events: { Types.Event }): string?
	local scores = keeper()
	for _, event in events do
		scores:apply(event)
	end
	return scores:mvp("Blue")
end

describe("ScoreKeeper", function()
	it("starts with zero scores and empty stats in join order", function()
		local scores = keeper()
		expect(scores:teamScores()).toEqual({ Blue = 0, Orange = 0 })
		expect(scores:player("O1")).toEqual({
			player = "O1",
			team = "Orange",
			joinOrder = 3,
			present = true,
			score = 0,
			goals = 0,
			assists = 0,
			saves = 0,
			steals = 0,
		})
		expect(scores:player("Nobody")).toBeNil()
	end)

	it("scores goals, assists and streak points", function()
		local scores = keeper()
		scores:apply({ name = "GoalScored", team = "Blue", scorer = "B1", assister = "B2" })
		expect(scores:teamScores()).toEqual({ Blue = 1, Orange = 0 })
		expect(scores:player("B1")).toMatchObject({ score = 100, goals = 1 })
		expect(scores:player("B2")).toMatchObject({ score = 0, assists = 0 })
		scores:apply({ name = "AssistAwarded", player = "B2" })
		expect(scores:player("B2")).toMatchObject({ score = 50, assists = 1 })
		scores:apply({ name = "StreakPointScored", team = "Blue", holder = "B2" })
		expect(scores:teamScores()).toEqual({ Blue = 2, Orange = 0 })
		expect(scores:player("B2")).toMatchObject({ score = 150, goals = 0 })
	end)

	it("scores saves, steals, laps and knockdowns", function()
		local scores = keeper()
		scores:apply({ name = "SaveMade", player = "O1", kind = "Block" })
		scores:apply({ name = "Steal", player = "O1", fromTeam = "Blue" })
		scores:apply({ name = "TackleKnockdown", attacker = "O1", victim = "B1" })
		scores:apply({ name = "LapCompleted", team = "Blue", streak = 1, holder = "B1" })
		expect(scores:player("O1")).toMatchObject({ score = 80, saves = 1, steals = 1 })
		expect(scores:player("B1")).toMatchObject({ score = 10 })
		expect(scores:teamScores()).toEqual({ Blue = 0, Orange = 0 })
	end)

	it("uses the configured point values", function()
		local scores = keeper({ Match = { pointValue = { goal = 2 } }, Scoring = { points = { goal = 7 } } })
		scores:apply({ name = "GoalScored", team = "Orange", scorer = "O1" })
		expect(scores:teamScores()).toEqual({ Blue = 0, Orange = 2 })
		expect(scores:player("O1")).toMatchObject({ score = 7 })
	end)

	it("ignores events that carry no points", function()
		local scores = keeper()
		scores:apply({ name = "GoalOpened", team = "Blue" })
		scores:apply({ name = "KickoffStarted", countdownSeconds = 3 })
		expect(scores:stats()).toEqual(keeper():stats())
	end)

	it("keeps a departed player's stats and restores them when the player returns", function()
		local scores = keeper()
		scores:apply({ name = "GoalScored", team = "Blue", scorer = "B1" })
		scores:removePlayer("B1")
		expect(scores:player("B1")).toMatchObject({ present = false, score = 100 })
		scores:addPlayer("B1", "Blue")
		expect(scores:player("B1")).toMatchObject({ present = true, team = "Blue", score = 100, joinOrder = 1 })
	end)

	it("rejects duplicate and unknown players, unknown teams, and a returning player on another team", function()
		local scores = keeper()
		expect(function()
			scores:addPlayer("B1", "Blue")
		end).toThrow('ScoreKeeper: player "B1" is already in the match')
		expect(function()
			scores:removePlayer("X")
		end).toThrow('ScoreKeeper: unknown player "X"')
		expect(function()
			scores:addPlayer("X", "Red" :: any)
		end).toThrow('ScoreKeeper: unknown team "Red"')
		scores:removePlayer("B2")
		expect(function()
			scores:addPlayer("B2", "Orange")
		end).toThrow('ScoreKeeper: player "B2" played for Blue and can only return to Blue')
	end)

	it("lists stats grouped by team, then by score, as a copy", function()
		local scores = ScoreKeeper.new(Config.defaults())
		scores:addPlayer("O1", "Orange")
		scores:addPlayer("B1", "Blue")
		scores:addPlayer("B2", "Blue")
		scores:apply({ name = "GoalScored", team = "Blue", scorer = "B2" })
		local stats = scores:stats()
		expect(stats.scores).toEqual({ Blue = 1, Orange = 0 })
		local order = {}
		for _, entry in stats.players do
			table.insert(order, entry.player)
		end
		expect(order).toEqual({ "B2", "B1", "O1" })
		stats.players[1].score = 999
		expect(scores:player("B2")).toMatchObject({ score = 100 })
	end)
end)

describe("ScoreKeeper:mvp", function()
	it("picks the top scorer of the team", function()
		expect(mvpAfter({
			{ name = "GoalScored", team = "Blue", scorer = "B1" },
			{ name = "SaveMade", player = "B2", kind = "Block" },
		})).toBe("B1")
	end)

	it("breaks score ties by goals, then saves, then assists, then join order", function()
		local streakB1: Types.Event = { name = "StreakPointScored", team = "Blue", holder = "B1" }
		local saveB1: Types.Event = { name = "SaveMade", player = "B1", kind = "Block" }
		local saveB2: Types.Event = { name = "SaveMade", player = "B2", kind = "Block" }
		local assistB2: Types.Event = { name = "AssistAwarded", player = "B2" }
		expect(mvpAfter({ { name = "GoalScored", team = "Blue", scorer = "B2" }, saveB1, saveB1 })).toBe("B2")
		expect(mvpAfter({ saveB2, saveB2, streakB1 })).toBe("B2")
		expect(mvpAfter({ assistB2, assistB2, streakB1 })).toBe("B2")
		expect(mvpAfter({ saveB1, saveB2 })).toBe("B1")
	end)

	it("ignores departed players and returns nil when nobody on the team is present", function()
		local scores = keeper()
		scores:apply({ name = "GoalScored", team = "Blue", scorer = "B1" })
		scores:apply({ name = "SaveMade", player = "B2", kind = "Block" })
		scores:removePlayer("B1")
		expect(scores:mvp("Blue")).toBe("B2")
		scores:removePlayer("B2")
		expect(scores:mvp("Blue")).toBeNil()
	end)
end)
