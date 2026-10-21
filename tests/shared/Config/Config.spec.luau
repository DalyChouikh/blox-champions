--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local NormalChampions = require(ReplicatedStorage.Shared.Modes.NormalChampions)

local function mode(overrides: { [string]: any })
	return { id = "Test", displayName = "Test", itemsEnabled = false, overrides = overrides }
end

describe("Config defaults", function()
	it("match the spec's match rules", function()
		local m = Config.defaults().Match
		expect(m.teamSize).toBe(3)
		expect(m.minPlayersToStart).toBe(1)
		expect(m.pointsToWin).toBe(5)
		expect(m.durationSeconds).toBe(300)
		expect(m.lapsToOpenGoal).toBe(4)
		expect(m.lapsForStreakPoint).toBe(12)
		expect(m.pointValue).toEqual({ goal = 1, streak = 1 })
		expect(m.celebrationSeconds).toBe(3)
		expect(m.kickoffCountdownSeconds).toBe(3)
		expect(m.clockPausesDuringKickoff).toBe(true)
		expect(m.postMatchSeconds).toBe(15)
		expect(m.lastChance).toEqual({ enabled = true, maxDeficit = 1 })
	end)

	it("match the spec's scoring values", function()
		local s = Config.defaults().Scoring
		expect(s.points).toEqual({
			goal = 100,
			streakPoint = 100,
			assist = 50,
			save = 50,
			lapCompleted = 10,
			steal = 20,
			tackleKnockdown = 10,
		})
		expect(s.assistWindowSeconds).toBe(8)
		expect(s.saveLookaheadSeconds).toBe(1.5)
	end)

	it("are valid and deeply frozen", function()
		local d = Config.defaults()
		expect(#Config.schema(d, "")).toBe(0)
		expect(table.isfrozen(d)).toBe(true)
		expect(table.isfrozen(d.Match.lastChance)).toBe(true)
	end)
end)

describe("Config.forMode", function()
	it("returns the defaults for Normal Champions", function()
		expect(NormalChampions.id).toBe("NormalChampions")
		expect(NormalChampions.displayName).toBe("Normal Champions")
		expect(NormalChampions.itemsEnabled).toBe(false)
		expect(Config.forMode(NormalChampions)).toEqual(Config.defaults())
	end)

	it("deep-merges nested overrides without touching the defaults", function()
		local c = Config.forMode(mode({ Match = { lastChance = { maxDeficit = 2 } } }))
		expect(c.Match.lastChance).toEqual({ enabled = true, maxDeficit = 2 })
		expect(c.Match.pointsToWin).toBe(5)
		expect(Config.defaults().Match.lastChance.maxDeficit).toBe(1)
		expect(table.isfrozen(c.Match)).toBe(true)
	end)

	it("rejects an override key that does not exist", function()
		expect(function()
			Config.forMode(mode({ Match = { lapsToOpenGaol = 3 } }))
		end).toThrow("Match.lapsToOpenGaol: unknown key")
	end)

	it("rejects an override with the wrong type", function()
		expect(function()
			Config.forMode(mode({ Match = { pointsToWin = "5" } }))
		end).toThrow("Match.pointsToWin: expected number, got string")
	end)

	it("rejects a streak target that does not exceed the goal-opening laps", function()
		expect(function()
			Config.forMode(mode({ Match = { lapsForStreakPoint = 4 } }))
		end).toThrow("Match: lapsForStreakPoint must be greater than lapsToOpenGoal")
	end)

	it("rejects more required players than two full teams", function()
		expect(function()
			Config.forMode(mode({ Match = { minPlayersToStart = 7 } }))
		end).toThrow("Match: minPlayersToStart must be <= 2 × teamSize")
	end)

	it("rejects a malformed mode", function()
		expect(function()
			Config.forMode({ id = "X", displayName = "X", itemsEnabled = "no", overrides = {} } :: any)
		end).toThrow("Mode.itemsEnabled: expected boolean, got string")
	end)
end)
