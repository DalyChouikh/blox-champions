--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local NormalChampions = require(ReplicatedStorage.Shared.Modes.NormalChampions)

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

	it("match the spec's UI values", function()
		expect(Config.defaults().UI.clockWarnings).toEqual({ 60, 30 })
	end)

	it("match the spec's arena layout", function()
		local a = Config.defaults().Arena
		expect(a.straightLength).toBe(160)
		expect(a.endRadius).toBe(60)
		expect(a.trackWidth).toBe(44)
		expect(a.outerWallHeight).toBe(28)
		expect(a.infieldWallHeight).toBe(20)
		expect(a.wallCurveRadius).toBe(10)
		expect(a.stepHeight).toBe(4)
		expect(a.stepWidth).toBe(10)
		expect(a.upperFloorWidth).toBe(4)
		expect(a.profileBlendLength).toBe(20)
		expect(a.segmentLength).toBe(4)
		expect(a.stripsPerSection).toBe(18)
		expect(a.surfaceThickness).toBe(1)
		expect(a.goalGateIndex).toBe(2)
		expect(a.goal).toEqual({
			ringRadius = 7,
			heightAboveFloor = 18,
			panelThickness = 0.5,
			rimThickness = 1,
			rimSegments = 16,
			wallGap = 1,
		})
		expect(a.marker).toEqual({ width = 2, height = 8 })
		expect(a.teamSpawnSpacing).toBe(10)
		expect(a.ballSpawnHeight).toBe(6)
	end)

	it("give each team and each arena part a color", function()
		local d = Config.defaults()
		expect(d.UI.teamColors).toEqual({ Blue = Color3.fromRGB(13, 105, 172), Orange = Color3.fromRGB(218, 133, 65) })
		expect(d.Arena.colors).toEqual({
			surface = Color3.fromRGB(163, 162, 165),
			infield = Color3.fromRGB(99, 95, 98),
			goal = Color3.fromRGB(248, 248, 248),
			marker = Color3.fromRGB(27, 42, 53),
		})
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
		local c = Fixtures.config({ Match = { lastChance = { maxDeficit = 2 } } })
		expect(c.Match.lastChance).toEqual({ enabled = true, maxDeficit = 2 })
		expect(c.Match.pointsToWin).toBe(5)
		expect(Config.defaults().Match.lastChance.maxDeficit).toBe(1)
		expect(table.isfrozen(c.Match)).toBe(true)
	end)

	it("rejects an override key that does not exist", function()
		expect(function()
			Fixtures.config({ Match = { lapsToOpenGaol = 3 } })
		end).toThrow("Match.lapsToOpenGaol: unknown key")
	end)

	it("rejects an override with the wrong type", function()
		expect(function()
			Fixtures.config({ Match = { pointsToWin = "5" } })
		end).toThrow("Match.pointsToWin: expected number, got string")
	end)

	it("rejects a streak target that does not exceed the goal-opening laps", function()
		expect(function()
			Fixtures.config({ Match = { lapsForStreakPoint = 4 } })
		end).toThrow("Match: lapsForStreakPoint must be greater than lapsToOpenGoal")
	end)

	it("rejects more required players than two full teams", function()
		expect(function()
			Fixtures.config({ Match = { minPlayersToStart = 7 } })
		end).toThrow("Match: minPlayersToStart must be <= 2 × teamSize")
	end)

	it("replaces a list from an override instead of merging it item by item", function()
		expect(Fixtures.config({ UI = { clockWarnings = { 10 } } }).UI.clockWarnings).toEqual({ 10 })
		expect(Fixtures.config({ UI = { clockWarnings = {} } }).UI.clockWarnings).toEqual({})
	end)

	it("rejects duplicate clock warnings", function()
		expect(function()
			Fixtures.config({ UI = { clockWarnings = { 30, 30 } } })
		end).toThrow("UI.clockWarnings: must not contain duplicates")
	end)

	it("rejects a clock warning that is not a whole number of seconds", function()
		expect(function()
			Fixtures.config({ UI = { clockWarnings = { 60, 2.5 } } })
		end).toThrow("UI.clockWarnings[2]: must be an integer (got 2.5)")
	end)

	it("rejects a mode with an empty id or display name", function()
		expect(function()
			Config.forMode({ id = "", displayName = "X", itemsEnabled = false, overrides = {} })
		end).toThrow("Mode.id: must not be empty")
		expect(function()
			Config.forMode({ id = "X", displayName = "", itemsEnabled = false, overrides = {} })
		end).toThrow("Mode.displayName: must not be empty")
	end)

	it("keeps the Normal Champions mode frozen", function()
		expect(table.isfrozen(NormalChampions)).toBe(true)
		expect(table.isfrozen(NormalChampions.overrides)).toBe(true)
	end)

	it("rejects arena sizes that cannot be built", function()
		local cases: { { overrides: { [string]: any }, message: string } } = {
			{
				overrides = { trackWidth = 30 },
				message = "Arena: trackWidth must fit both wall curves, the step, the upper floor and a lower floor",
			},
			{
				overrides = { endRadius = 22 },
				message = "Arena: endRadius must leave room for the infield behind the inner wall",
			},
			{
				overrides = { infieldWallHeight = 10 },
				message = "Arena: each wall must rise above the curve at its foot",
			},
			{
				overrides = { profileBlendLength = 200 },
				message = "Arena: profileBlendLength must fit within a straight and a curved end",
			},
			{
				overrides = { goal = { wallGap = 30 } },
				message = "Arena: the goal ring must fit across the track",
			},
			{
				overrides = { goal = { heightAboveFloor = 24 } },
				message = "Arena: the goal ring must sit between the upper floor and the outer wall top",
			},
			{ overrides = { stripsPerSection = 6 }, message = "Arena.stripsPerSection: must be >= 7 (got 6)" },
			{ overrides = { goalGateIndex = 5 }, message = "Arena.goalGateIndex: must be <= 4 (got 5)" },
		}
		for _, case in cases do
			expect(function()
				Fixtures.config({ Arena = case.overrides })
			end).toThrow(case.message)
		end
	end)

	it("rejects a malformed mode", function()
		expect(function()
			Config.forMode({ id = "X", displayName = "X", itemsEnabled = "no", overrides = {} } :: any)
		end).toThrow("Mode.itemsEnabled: expected boolean, got string")
	end)
end)
