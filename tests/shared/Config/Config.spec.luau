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
		expect(m.respawnSeconds).toBe(3)
	end)

	it("match the spec's ball and network values", function()
		local d = Config.defaults()
		expect(d.Ball).toEqual({
			radius = 1.5,
			density = 0.7,
			friction = 0.3,
			elasticity = 0.5,
			pickupRadius = 5,
			rethrowPickupDelay = 0.4,
			ballIdleResetSeconds = 15,
			outOfBoundsMargin = 2,
			carryOffset = Vector3.new(2.5, 0, -0.5),
		})
		expect(d.Network).toEqual({ pickupLagToleranceStuds = 2 })
	end)

	it("match the spec's skating values, plus this phase's", function()
		expect(Config.defaults().Movement).toEqual({
			colliderDiameter = 2,
			hoverHeight = 2.5,
			hoverSpring = 15,
			groundProbeLength = 6,
			strideAccel = 30,
			rollingFriction = 4,
			airDrag = 0.02,
			cruiseSpeed = 60,
			softCap = 90,
			hardCap = 140,
			turnRateLow = 4.0,
			turnRateHigh = 1.5,
			airTurnRate = 1,
			airUprightRate = 6,
			minWallSpeed = 35,
			maxStickAngle = 60,
			pumpSlopeMultiplier = 1.6,
			pumpFlatAccel = 8,
			pumpFlatSlopeDeg = 3,
			brakeDecel = 120,
			tiptoeSpeed = 12,
			jumpImpulse = 60,
			normalFilter = { maxTurnDeg = 30, smoothing = 30 },
			draftRange = 18,
			draftConeDeg = 30,
			draftMaxAccel = 20,
			attachRange = 8,
			attachConeDeg = 45,
			attachFollowDistance = 4,
			attachSpring = 10,
			attachMaxSeconds = 3,
			attachBoostSpeed = 40,
			attachCooldown = 3,
		})
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
			panelTransparency = 0.3,
			rimThickness = 1,
			rimSegments = 16,
			wallGap = 1,
		})
		expect(a.marker).toEqual({ width = 2, height = 8 })
		expect(a.teamSpawnSpacing).toBe(10)
		expect(a.ballSpawnHeight).toBe(6)
	end)

	it("size and shade the arena parts that only carry a tag", function()
		local a = Config.defaults().Arena
		expect(a.gateThickness).toBe(0.2)
		expect(a.spawnPad).toEqual({ width = 4, thickness = 0.2, transparency = 0.4 })
		expect(a.ballSpawnSize).toBe(1)
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
			{ overrides = { goal = { wallGap = 0 } }, message = "Arena.goal.wallGap: must be > 0 (got 0)" },
			{ overrides = { stripsPerSection = 6 }, message = "Arena.stripsPerSection: must be >= 7 (got 6)" },
			{ overrides = { goalGateIndex = 5 }, message = "Arena.goalGateIndex: must be <= 4 (got 5)" },
		}
		for _, case in cases do
			expect(function()
				Fixtures.config({ Arena = case.overrides })
			end).toThrow(case.message)
		end
	end)

	it("rejects arena values that would size a part beyond what Roblox can build", function()
		local cases: { { overrides: { [string]: any }, message: string } } = {
			{ overrides = { straightLength = 3000 }, message = "Arena.straightLength: must be <= 2048 (got 3000)" },
			{ overrides = { endRadius = 1100 }, message = "Arena.endRadius: must be <= 1024 (got 1100)" },
			{
				overrides = { surfaceThickness = 0.0005 },
				message = "Arena.surfaceThickness: must be >= 0.001 (got 0.0005)",
			},
			{
				overrides = { goal = { panelThickness = 0.0005 } },
				message = "Arena.goal.panelThickness: must be >= 0.001 (got 0.0005)",
			},
			{ overrides = { marker = { height = 2500 } }, message = "Arena.marker.height: must be <= 2048 (got 2500)" },
		}
		for _, case in cases do
			expect(function()
				Fixtures.config({ Arena = case.overrides })
			end).toThrow(case.message)
		end
	end)

	it("rejects ball physics Roblox would clamp, and a ball too big for the goal", function()
		local cases: { { overrides: { [string]: any }, message: string } } = {
			{ overrides = { Ball = { elasticity = 1.5 } }, message = "Ball.elasticity: must be <= 1 (got 1.5)" },
			{ overrides = { Ball = { friction = -0.1 } }, message = "Ball.friction: must be >= 0 (got -0.1)" },
			{ overrides = { Ball = { density = 0 } }, message = "Ball.density: must be >= 0.0001 (got 0)" },
			{
				overrides = { Ball = { carryOffset = Vector3.new(0 / 0, 0, 0) } },
				message = "Ball.carryOffset: must be finite",
			},
			{
				overrides = { Network = { pickupLagToleranceStuds = -1 } },
				message = "Network.pickupLagToleranceStuds: must be >= 0 (got -1)",
			},
			{
				overrides = { Ball = { radius = 7 } },
				message = "Ball: radius must be smaller than the goal ring's opening (Arena.goal.ringRadius)",
			},
		}
		for _, case in cases do
			expect(function()
				Fixtures.config(case.overrides)
			end).toThrow(case.message)
		end
	end)

	it("rejects skating speeds, turn rates and sizes that contradict each other", function()
		local cases: { { overrides: { [string]: any }, message: string } } = {
			{
				overrides = { Movement = { softCap = 150 } },
				message = "Movement: speeds must rise: cruiseSpeed <= softCap < hardCap",
			},
			{
				overrides = { Movement = { turnRateHigh = 5 } },
				message = "Movement: turnRateHigh must not exceed turnRateLow",
			},
			{
				overrides = { Movement = { groundProbeLength = 2 } },
				message = "Movement: groundProbeLength must reach past hoverHeight",
			},
			{
				overrides = { Movement = { tiptoeSpeed = 70 } },
				message = "Movement: tiptoeSpeed must not exceed cruiseSpeed",
			},
			{
				overrides = { Movement = { colliderDiameter = 6 } },
				message = "Movement: the collider must clear the ground: colliderDiameter / 2 < hoverHeight",
			},
			{
				overrides = { Movement = { pumpSlopeMultiplier = 0.5 } },
				message = "Movement.pumpSlopeMultiplier: must be >= 1 (got 0.5)",
			},
		}
		for _, case in cases do
			expect(function()
				Fixtures.config(case.overrides)
			end).toThrow(case.message)
		end
	end)

	it("rejects team spawns that would not fit on a straight", function()
		expect(function()
			Fixtures.config({ Match = { teamSize = 6 }, Arena = { teamSpawnSpacing = 40 } })
		end).toThrow("Arena: Match.teamSize spawns teamSpawnSpacing apart must fit on a straight")
		expect(function()
			Fixtures.config({ Match = { teamSize = 6 }, Arena = { teamSpawnSpacing = 32 } })
		end).never.toThrow()
	end)

	it("rejects a malformed mode", function()
		expect(function()
			Config.forMode({ id = "X", displayName = "X", itemsEnabled = "no", overrides = {} } :: any)
		end).toThrow("Mode.itemsEnabled: expected boolean, got string")
	end)
end)
