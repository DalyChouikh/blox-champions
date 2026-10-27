--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Actions = require(ReplicatedStorage.Shared.Config.Actions)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local NormalChampions = require(ReplicatedStorage.Shared.Modes.NormalChampions)

describe("Config.Actions", function()
	it("names every action once, and finds an action by its name", function()
		expect(Actions.names).toEqual({ "Tackle", "Dive", "Dodge", "Uppercut", "ChargeThrow", "Pass", "CallPass" })
		expect(Actions.nameOf("Dive")).toBe("Dive")
		expect(Actions.nameOf("Fly")).toBeNil()
		expect(Actions.nameOf(nil)).toBeNil()
	end)
end)

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
		expect(d.Network).toEqual({
			pickupLagToleranceStuds = 2,
			maxSkateStatesPerSecond = 20,
			guardSampleSeconds = 0.25,
			speedTolerance = 1.2,
			guardStrikes = 3,
			guardTeleportFactor = 2,
			guardOutsideMargin = 2,
			maxActionsPerSecond = 15,
			hitLagToleranceStuds = 3,
			actionTimingTolerance = 0.1,
		})
	end)

	it("match the spec's actions, plus this phase's", function()
		local requires = function(ball: string): any
			return { ball = ball, grounded = "any", notKnockedDown = true }
		end
		expect(Config.defaults().Actions).toEqual({
			airMultiplier = 0.8,
			callPassWindow = 3,
			Tackle = {
				phases = { windup = 0.05, active = 0.25, recovery = 0.35 },
				cooldown = 0.8,
				requires = requires("without"),
				effect = "Knockdown",
				pose = "Lunge",
				hit = { range = 7, coneDeg = 50, aimUpDeg = 0, knockdownSeconds = 1.5 },
				motion = { lungeSpeed = 40 },
				followUp = { action = "Dive", window = "Active" },
			},
			Dive = {
				phases = { windup = 0, active = 0.35, recovery = 0.9 },
				cooldown = 0.8,
				requires = requires("without"),
				effect = "Knockdown",
				pose = "Lunge",
				hit = { range = 11, coneDeg = 50, aimUpDeg = 0, knockdownSeconds = 1.5 },
				motion = { lungeSpeed = 60 },
			},
			Dodge = {
				phases = { windup = 0, active = 0.3, recovery = 0.2 },
				cooldown = 1.5,
				requires = requires("with"),
				effect = "Dodge",
				pose = "None",
				motion = { sideSpeed = 45 },
			},
			Uppercut = {
				phases = { windup = 0.05, active = 0.2, recovery = 0.4 },
				cooldown = 1.2,
				requires = requires("without"),
				effect = "Knockdown",
				pose = "None",
				hit = { range = 6, coneDeg = 60, aimUpDeg = 30, knockdownSeconds = 1.5 },
				motion = { wallLeapDistance = 5, wallLeapImpulse = 110 },
			},
			ChargeThrow = {
				phases = { windup = 0, active = 0, recovery = 0 },
				cooldown = 0,
				requires = requires("with"),
				effect = "Throw",
				pose = "None",
				throw = { chargeMaxSeconds = 1, minSpeed = 60, maxSpeed = 160, inheritCarrierVelocity = 0.5 },
			},
			Pass = {
				phases = { windup = 0, active = 0, recovery = 0 },
				cooldown = 0,
				requires = requires("with"),
				effect = "Pass",
				pose = "None",
				pass = {
					speed = 90,
					homingAccel = 60,
					coneDeg = 70,
					maxRange = 120,
					angleWeight = 0.6,
					distanceWeight = 0.4,
				},
			},
			CallPass = {
				phases = { windup = 0, active = 0, recovery = 0 },
				cooldown = 1,
				requires = requires("without"),
				effect = "CallPass",
				pose = "None",
			},
		})
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
			coastDecel = 7.5,
			cruiseSpeed = 60,
			softCap = 90,
			hardCap = 121,
			overSpeedBleed = 5,
			turnRateLow = 4.0,
			turnRateHigh = 1.5,
			airTurnRate = 1,
			airUprightRate = 6,
			wallAngle = 30,
			wallGravityScale = 1 / 3,
			curvatureWindow = 10,
			pumpSlopeMultiplier = 1.6,
			pumpFlatAccel = 8,
			pumpFlatSlopeDeg = 3,
			brakeDecel = 120,
			tiptoeSpeed = 12,
			jumpImpulse = 60,
			jumpSpeedCost = 0.1,
			airPoseImpulse = 42,
			normalFilter = { maxTurnDeg = 30, smoothing = 30 },
			draftRange = 18,
			draftConeDeg = 30,
			draftMaxAccel = 20,
			attachRange = 8,
			attachConeDeg = 45,
			attachFollowDistance = 4,
			attachSpring = 10,
			attachMaxSeconds = 3,
			attachBoostSpeed = 75,
			attachCooldown = 3,
			knockdownDecel = 75,
			speedometerScale = 1.2,
		})
	end)

	-- Roller Champions' readout, measured in the owner's recordings (#214): nothing past 145 km/h, extra speed bleeding
	-- back to about 108, and a whip release adding about 90.
	it("read Roller Champions' speeds on the speedometer", function()
		local movement = Config.defaults().Movement
		local function kmh(studsPerSecond: number): number
			return math.round(studsPerSecond * movement.speedometerScale)
		end
		expect(kmh(movement.hardCap)).toBe(145)
		expect(kmh(movement.softCap)).toBe(108)
		expect(kmh(movement.attachBoostSpeed)).toBe(90)
	end)

	it("pose skaters with the starting angles", function()
		expect(Config.defaults().Pose).toEqual({
			maxLeanDeg = 30,
			leanSmoothing = 10,
			crouchDeg = 30,
			brakeLeanDeg = 15,
			tuckDeg = 60,
			carryArmDeg = 75,
			airborneProbe = 1.5,
			lungeDeg = 35,
			knockdownTiltDeg = 60,
			airPoseDeg = 70,
			airPoseArmDeg = 150,
		})
	end)

	it("bind the skating and action keys of spec §8.3", function()
		local input = Config.defaults().Input
		expect(input.contextPriority).toBe(1000)
		expect(input.robloxContextsWaitSeconds).toBe(10)
		expect(input.move).toEqual({
			composites = {
				{ up = Enum.KeyCode.W, down = Enum.KeyCode.S, left = Enum.KeyCode.A, right = Enum.KeyCode.D },
			},
			sticks = { Enum.KeyCode.Thumbstick1 },
		})
		expect(input.jump).toEqual({ Enum.KeyCode.Space, Enum.KeyCode.ButtonA })
		expect(input.pump).toEqual({ Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonR2 })
		expect(input.brake).toEqual({ Enum.KeyCode.LeftControl, Enum.KeyCode.ButtonR1 })
		expect(input.attach).toEqual({ Enum.KeyCode.F, Enum.KeyCode.ButtonL1 })
		expect(input.tackle).toEqual({ Enum.KeyCode.E, Enum.KeyCode.ButtonX })
		expect(input.uppercut).toEqual({ Enum.KeyCode.Q, Enum.KeyCode.ButtonB })
		expect(input.pass).toEqual({ Enum.KeyCode.R, Enum.KeyCode.ButtonY })
		expect(input.throw).toEqual({ Enum.KeyCode.MouseLeftButton, Enum.KeyCode.ButtonL2 })
		-- Roblox's own camera scales (degrees per pixel, per second at full tilt, per pixel).
		expect(input.look).toEqual({
			mouse = { key = Enum.KeyCode.MouseDelta, degPerUnit = Vector2.new(0.5, 0.385), responseCurve = 1 },
			stick = { key = Enum.KeyCode.Thumbstick2, degPerUnit = Vector2.new(240, -185), responseCurve = 2 },
			touch = { key = Enum.KeyCode.TouchDelta, degPerUnit = Vector2.new(1, 0.66), responseCurve = 1 },
		})
		expect(input.ballFocus).toEqual({ Enum.KeyCode.MouseRightButton, Enum.KeyCode.ButtonL2 })
		expect(input.ballFocusMode).toBe("Hold")
		expect(input.touchBallFocusMode).toBe("Toggle")
		expect(input.scoreTab).toEqual({ Enum.KeyCode.Tab, Enum.KeyCode.ButtonSelect })
		expect(input.actions).toEqual({
			tackle = { "Tackle", "Dodge" },
			uppercut = { "Uppercut" },
			pass = { "Pass", "CallPass" },
			throw = { "ChargeThrow" },
		})
		expect(input.touch).toEqual({
			stickArea = UDim2.fromScale(0.4, 2 / 3),
			stickDeadZone = 2,
			stickRadius = 20,
			stickRingSize = 74,
			stickKnobSize = 36,
			bigScreenSide = 500,
			bigScreenStickScale = 2,
			bigScreenButtonScale = 1.5,
			buttonSize = UDim2.fromOffset(72, 72),
			-- Pixels from the bottom-right corner, 80 apart: three columns, the right one a step higher.
			buttons = {
				uppercut = UDim2.new(1, -50, 1, -230),
				tackle = UDim2.new(1, -50, 1, -150),
				jump = UDim2.new(1, -50, 1, -70),
				pass = UDim2.new(1, -130, 1, -210),
				throw = UDim2.new(1, -130, 1, -130),
				pump = UDim2.new(1, -130, 1, -50),
				attach = UDim2.new(1, -210, 1, -130),
				brake = UDim2.new(1, -210, 1, -50),
			},
		})
	end)

	it("set the camera of spec §8.4, plus this phase's", function()
		expect(Config.defaults().Camera).toEqual({
			distance = 12,
			height = 4,
			collisionMargin = 0.5,
			fovBase = 70,
			fovMax = 90,
			fovResponse = 6,
			minPitchDeg = -70,
			maxPitchDeg = 60,
			rollResponse = 8,
			recenterDelay = 0.5,
			recenterResponse = 2.5,
			recenterMinSpeed = 10,
			ballFocusResponse = 10,
			spectator = { distance = 30, height = 6 },
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
		local ui = Config.defaults().UI
		expect(ui.clockWarnings).toEqual({ 60, 30 })
		expect(ui.controlLabels).toEqual({
			Jump = "Jump",
			AirPose = "Air Pose",
			Pump = "Pump",
			Brake = "Brake",
			Attach = "Attach",
			Tackle = "Tackle",
			Dive = "Dive",
			Dodge = "Dodge",
			Uppercut = "Uppercut",
			ChargeThrow = "Throw",
			Pass = "Pass",
			CallPass = "Call",
			BallFocus = "Focus",
		})
		-- Roblox's own touch thumbstick colors.
		expect(ui.touchStyle).toEqual({
			background = Color3.fromRGB(18, 18, 21),
			backgroundTransparency = 0.4,
			foreground = Color3.fromRGB(213, 215, 221),
			font = Enum.Font.BuilderSansBold,
			corner = UDim.new(0.5, 0),
			textSize = 18,
			textPadding = 6,
			knobTransparency = 0,
		})
		expect(ui.teamNames).toEqual({ Blue = "Blue", Orange = "Orange" })
		-- Keys Roblox's GetStringForKeyCode names "" or " ".
		expect(ui.keyNames).toEqual({
			Space = "Space",
			LeftShift = "Shift",
			RightShift = "Shift",
			LeftControl = "Ctrl",
			RightControl = "Ctrl",
			Tab = "Tab",
			MouseLeftButton = "LMB",
			MouseRightButton = "RMB",
		})
		expect(ui.text).toEqual({
			clock = "%d:%02d",
			lap = "Lap %d/%d",
			streak = "Streak %d/%d",
			overtime = "OVERTIME",
			goal = "GOAL!",
			streakPoint = "STREAK POINT!",
			denied = "DENIED!",
			clockWarning = "%d SECONDS",
			lastChance = "LAST CHANCE",
			speed = "%d km/h",
			possession = "%s has the ball",
			lapCompleted = "Lap %d completed",
			goalOpen = "%s goal is active",
			scored = "%s scored!",
			scoredStreak = "%s scored a streak point!",
			wins = "%s WINS",
			mvp = "MVP",
			scores = "SCORES",
			columns = {
				player = "Player",
				score = "Score",
				goals = "Goals",
				assists = "Assists",
				saves = "Saves",
				steals = "Steals",
			},
			unknownPlayer = "Player",
			-- A raised hand.
			callPass = "\u{270B}",
		})
		expect(ui.hud).toEqual({
			font = Enum.Font.BuilderSansBold,
			textColor = Color3.fromRGB(245, 245, 245),
			panel = Color3.fromRGB(18, 18, 21),
			panelTransparency = 0.35,
			overlayTransparency = 0,
			dimTransparency = 0.6,
			corner = UDim.new(0, 8),
			textSize = 20,
			titleSize = 32,
			bannerSize = 96,
			bannerSeconds = 2,
			feedSeconds = 6,
			feedMaxEntries = 5,
			glowThickness = 3,
			spacing = 6,
			pipSize = 10,
			screenMargin = 8,
			layout = {
				scoreboard = { position = UDim2.new(0.5, 0, 0, 8), size = UDim2.fromOffset(440, 84) },
				banner = { position = UDim2.new(0.5, 0, 0, 200), size = UDim2.fromOffset(640, 110) },
				feed = { position = UDim2.new(0.5, 0, 1, -24), size = UDim2.fromOffset(460, 140), rowHeight = 24 },
				hints = { position = UDim2.new(1, -24, 0.5, 0), size = UDim2.fromOffset(220, 300), rowHeight = 30 },
				speedometer = {
					position = UDim2.new(1, -24, 1, -24),
					touchPosition = UDim2.fromOffset(16, 8),
					size = UDim2.fromOffset(160, 40),
				},
				reticle = { size = 6 },
				scoreTab = {
					position = UDim2.fromScale(0.5, 0.5),
					size = UDim2.fromOffset(640, 360),
					rowHeight = 28,
					columnWidth = 80,
				},
				scoreButton = { position = UDim2.new(1, -16, 0, 16), size = UDim2.fromOffset(96, 36) },
				endScreen = { position = UDim2.fromScale(0.5, 0.5), size = UDim2.fromOffset(720, 520) },
			},
		})
		expect(ui.markers).toEqual({
			ringSize = 56,
			ringThickness = 3,
			lineWidth = 0.2,
			groundProbe = 100,
			groundMarkerSize = 4,
			groundMarkerThickness = 0.2,
			groundMarkerTransparency = 0.4,
			edgeMargin = 48,
			arrowSize = 28,
			arrowImage = "rbxasset://textures/ui/MenuBar/arrow_up.png",
		})
		expect(ui.nameTag).toEqual({
			size = UDim2.fromOffset(200, 48),
			studsOffset = Vector3.new(0, 4, 0),
			textSize = 20,
			callSize = 28,
		})
		expect(ui.arenaGlow).toEqual({
			material = Enum.Material.Neon,
			panelSlide = 16,
			panelSlideSeconds = 0.4,
			beam = { width = 2, thickness = 0.5 },
		})
	end)

	it("match the spec's arena layout", function()
		local a = Config.defaults().Arena
		expect(a.straightLength).toBe(200)
		expect(a.endRadius).toBe(60)
		expect(a.trackWidth).toBe(80)
		expect(a.outerWallHeight).toBe(28)
		expect(a.innerBankHeight).toBe(8)
		expect(a.wallCurveRadius).toBe(18)
		expect(a.stepHeight).toBe(4)
		expect(a.stepWidth).toBe(18)
		expect(a.upperFloorWidth).toBe(8)
		expect(a.profileBlendLength).toBe(20)
		expect(a.segmentLength).toBe(4)
		expect(a.stripsPerSection).toBe(20)
		expect(a.surfaceThickness).toBe(1)
		expect(a.glass).toEqual({
			top = 120,
			lipRadius = 12,
			lipStrips = 4,
			transparency = 0.85,
			material = Enum.Material.SmoothPlastic,
		})
		expect(a.top).toEqual({ kind = "Closed", ceilingAbove = 20 })
		expect(a.goalGateIndex).toBe(2)
		expect(a.goal).toEqual({
			ringRadius = 7,
			heightAboveFloor = 18,
			panelThickness = 0.5,
			panelTransparency = 0.3,
			rimThickness = 1,
			rimSegments = 16,
			across = 0.75,
			arm = { thickness = 1, height = 40 },
		})
		expect((a.goal :: any).wallGap).toBeNil()
		expect(a.gatePanel).toEqual({ depth = 0.2 })
		expect((a :: any).marker).toBeNil()
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
			glass = Color3.fromRGB(200, 225, 240),
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

	it("rejects a movement guard that could never return a skater", function()
		expect(function()
			Fixtures.config({ Network = { guardStrikes = 0 } })
		end).toThrow("Network.guardStrikes: must be >= 1 (got 0)")
	end)

	it("rejects an outside margin below zero, which would place skaters still inside the arena", function()
		expect(function()
			Fixtures.config({ Network = { guardOutsideMargin = -1 } })
		end).toThrow("Network.guardOutsideMargin: must be >= 0 (got -1)")
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
		local WALL_THICKNESS = "Arena: the gate panel must be thinner than half the goal's thinnest part, so its faces "
			.. "never meet the goal's"
		local cases: { { overrides: { [string]: any }, message: string } } = {
			{
				overrides = { trackWidth = 52 },
				message = "Arena: trackWidth must fit the inner bank, the outer wall's foot curve, the step, the upper "
					.. "floor and a lower floor",
			},
			{
				overrides = { endRadius = 30 },
				message = "Arena: endRadius must leave room for the infield behind the inner glass",
			},
			{
				-- 1.2 studs behind the inner glass's face: room for a 1-stud slab, not for a 1.5-stud one.
				overrides = { endRadius = 41.2, surfaceThickness = 1.5 },
				message = "Arena: endRadius must leave room for the infield behind the inner glass",
			},
			{
				overrides = { wallCurveRadius = 25 },
				message = "Arena: the outer wall must rise above its foot curve and the step",
			},
			{
				-- The lip (12) would start at the outer wall's top (28).
				overrides = { glass = { top = 40 } },
				message = "Arena: the glass must rise above the inner bank's and the outer wall's tops before its lip",
			},
			{
				-- Its lip would start over the outer wall (28), under a bank of 30.
				overrides = { innerBankHeight = 30, glass = { top = 41 } },
				message = "Arena: the glass must rise above the inner bank's and the outer wall's tops before its lip",
			},
			{
				-- Two lips of 40 would meet across the 80-stud track.
				overrides = { glass = { lipRadius = 40 } },
				message = "Arena: the lips must leave the top open between them",
			},
			{
				-- Longer than a straight (200), so the blends at its two ends would overlap.
				overrides = { profileBlendLength = 250 },
				message = "Arena: profileBlendLength must fit within a straight and a curved end",
			},
			-- The ring's centre lies between the glass faces, as a fraction of the track's width.
			{ overrides = { goal = { across = 1.2 } }, message = "Arena.goal.across: must be <= 1 (got 1.2)" },
			{ overrides = { goal = { across = -0.1 } }, message = "Arena.goal.across: must be >= 0 (got -0.1)" },
			{ overrides = { goal = { arm = { height = 0 } } }, message = "Arena.goal.arm.height: must be > 0 (got 0)" },
			{ overrides = { stripsPerSection = 5 }, message = "Arena.stripsPerSection: must be >= 6 (got 5)" },
			{ overrides = { goalGateIndex = 5 }, message = "Arena.goalGateIndex: must be <= 4 (got 5)" },
			{ overrides = { glass = { lipStrips = 0 } }, message = "Arena.glass.lipStrips: must be >= 1 (got 0)" },
			-- Counts of parts and gates are whole numbers.
			{
				overrides = { stripsPerSection = 20.5 },
				message = "Arena.stripsPerSection: must be an integer (got 20.5)",
			},
			{ overrides = { goalGateIndex = 2.5 }, message = "Arena.goalGateIndex: must be an integer (got 2.5)" },
			{
				overrides = { glass = { lipStrips = 4.5 } },
				message = "Arena.glass.lipStrips: must be an integer (got 4.5)",
			},
			{
				overrides = { goal = { rimSegments = 16.5 } },
				message = "Arena.goal.rimSegments: must be an integer (got 16.5)",
			},
			{
				overrides = { top = { kind = "Lid" } },
				message = 'Arena.top.kind: must be one of Closed, Open (got "Lid")',
			},
			{
				overrides = { glass = { material = "Glass" } },
				message = 'Arena.glass.material: must be a Material (got "Glass")',
			},
			-- The goal hangs centred on its gate's plane and the gate's wall hangs behind it: a wall as thick as half
			-- the goal's thinnest part (the panel's 0.5 by default), or any one part thinner than twice the wall's 0.2,
			-- would put a face of each in one plane, where they flicker.
			{ overrides = { gatePanel = { depth = 0.25 } }, message = WALL_THICKNESS },
			{ overrides = { goal = { rimThickness = 0.3 } }, message = WALL_THICKNESS },
			{ overrides = { goal = { panelThickness = 0.3 } }, message = WALL_THICKNESS },
			{ overrides = { goal = { arm = { thickness = 0.3 } } }, message = WALL_THICKNESS },
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
			{
				overrides = { gatePanel = { depth = 2500 } },
				message = "Arena.gatePanel.depth: must be <= 2048 (got 2500)",
			},
			{
				overrides = { goal = { arm = { thickness = 2500 } } },
				message = "Arena.goal.arm.thickness: must be <= 2048 (got 2500)",
			},
			{ overrides = { glass = { top = 3000 } }, message = "Arena.glass.top: must be <= 2048 (got 3000)" },
			{
				overrides = { top = { ceilingAbove = 3000 } },
				message = "Arena.top.ceilingAbove: must be <= 2048 (got 3000)",
			},
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
			{
				overrides = { Movement = { overSpeedBleed = -1 } },
				message = "Movement.overSpeedBleed: must be >= 0 (got -1)",
			},
			{
				overrides = { Movement = { coastDecel = -1 } },
				message = "Movement.coastDecel: must be >= 0 (got -1)",
			},
			{
				overrides = { Movement = { jumpSpeedCost = -0.1 } },
				message = "Movement.jumpSpeedCost: must be >= 0 (got -0.1)",
			},
			{
				overrides = { Movement = { jumpSpeedCost = 1.5 } },
				message = "Movement.jumpSpeedCost: must be <= 1 (got 1.5)",
			},
			{
				overrides = { Movement = { airPoseImpulse = -1 } },
				message = "Movement.airPoseImpulse: must be >= 0 (got -1)",
			},
			{
				overrides = { Movement = { wallGravityScale = 0 } },
				message = "Movement.wallGravityScale: must be > 0 (got 0)",
			},
			{
				overrides = { Movement = { wallGravityScale = 1.5 } },
				message = "Movement.wallGravityScale: must be <= 1 (got 1.5)",
			},
		}
		for _, case in cases do
			expect(function()
				Fixtures.config(case.overrides)
			end).toThrow(case.message)
		end
	end)

	it("rejects actions that contradict themselves", function()
		local cases: { { overrides: { [string]: any }, message: string } } = {
			{
				overrides = { ChargeThrow = { throw = { maxSpeed = 50 } } },
				message = "Actions.ChargeThrow.throw: maxSpeed must be at least minSpeed",
			},
			{
				overrides = { Tackle = { followUp = { action = "Tackle" } } },
				message = "Actions.Tackle.followUp.action: must name another action",
			},
			{
				overrides = { Dodge = { hit = { range = 1, coneDeg = 1, aimUpDeg = 0, knockdownSeconds = 1 } } },
				message = "Actions.Dodge.hit: unknown key",
			},
			{
				overrides = { Tackle = { effect = "Throw" } },
				message = 'Actions.Tackle.effect: must be one of Knockdown (got "Throw")',
			},
		}
		for _, case in cases do
			expect(function()
				Fixtures.config({ Actions = case.overrides })
			end).toThrow(case.message)
		end
	end)

	it("rejects a key bound to two actions", function()
		expect(function()
			Fixtures.config({ Input = { pump = { Enum.KeyCode.Space } } })
		end).toThrow("Input: Space is bound to more than one action")
		expect(function()
			Fixtures.config({ Input = { throw = { Enum.KeyCode.E } } })
		end).toThrow("Input: E is bound to more than one action")
		expect(function()
			Fixtures.config({ Input = { ballFocus = { Enum.KeyCode.E } } })
		end).toThrow("Input: E is bound to more than one action")
		expect(function()
			Fixtures.config({ Input = { move = { sticks = { Enum.KeyCode.Thumbstick2 } } } })
		end).toThrow("Input: Thumbstick2 is bound to more than one action")
		expect(function()
			Fixtures.config({ Input = { scoreTab = { Enum.KeyCode.E } } })
		end).toThrow("Input: E is bound to more than one action")
		-- Ball Focus may share Charge Throw's keys: one needs the ball, the other works without it.
		expect(function()
			Fixtures.config({ Input = { ballFocus = { Enum.KeyCode.MouseLeftButton, Enum.KeyCode.ButtonL2 } } })
		end).never.toThrow()
	end)

	it("rejects a camera or touch layout that contradicts itself", function()
		local cases: { { overrides: { [string]: any }, message: string } } = {
			{ overrides = { Camera = { fovMax = 60 } }, message = "Camera: fovMax must be at least fovBase" },
			{
				overrides = { Input = { touch = { stickRadius = 1 } } },
				message = "Input.touch: stickRadius must be above stickDeadZone",
			},
			{
				overrides = { Input = { actions = { tackle = { "Fly" } } } },
				message = "Input.actions.tackle[1]: must name an action",
			},
			-- A button nearer another than its size, sideways (Pump 60 px from Jump) or up and down (Brake 20 px
			-- under Throw).
			{
				overrides = { Input = { touch = { buttons = { pump = UDim2.new(1, -110, 1, -70) } } } },
				message = "Input.touch: buttons must not overlap",
			},
			{
				overrides = { Input = { touch = { buttons = { brake = UDim2.new(1, -130, 1, -110) } } } },
				message = "Input.touch: buttons must not overlap",
			},
			-- The buttons' reach (TouchArea) measures from the bottom-right corner.
			{
				overrides = { Input = { touch = { buttons = { jump = UDim2.new(0.5, -50, 1, -70) } } } },
				message = "Input.touch: buttons must sit at the bottom-right corner (scales 1, 1)",
			},
			-- The overlap rule measures pixels, so a button's size must be in pixels.
			{
				overrides = { Input = { touch = { buttonSize = UDim2.fromScale(0.1, 0.1) } } },
				message = "Input.touch.buttonSize: must be in pixels (scales 0, offsets > 0)",
			},
		}
		for _, case in cases do
			expect(function()
				Fixtures.config(case.overrides)
			end).toThrow(case.message)
		end
	end)

	it("rejects HUD text and settings that contradict themselves", function()
		local cases: { { overrides: { [string]: any }, message: string } } = {
			-- A text takes exactly as many values as the HUD gives it.
			{
				overrides = { UI = { text = { lap = "Lap %d" } } },
				message = "UI.text.lap: placeholder count must be 2",
			},
			{
				overrides = { UI = { text = { possession = "has the ball" } } },
				message = "UI.text.possession: placeholder count must be 1",
			},
			-- A doubled percent prints one; it takes no value.
			{
				overrides = { UI = { text = { clockWarning = "%%d SECONDS" } } },
				message = "UI.text.clockWarning: placeholder count must be 1",
			},
			{ overrides = { UI = { hud = { feedMaxEntries = 0 } } }, message = "UI.hud.feedMaxEntries: must be >= 1" },
			{ overrides = { UI = { hud = { pipSize = 0 } } }, message = "UI.hud.pipSize: must be > 0" },
			{
				overrides = { UI = { hud = { overlayTransparency = 2 } } },
				message = "UI.hud.overlayTransparency: must be <= 1 (got 2)",
			},
			{
				overrides = { UI = { markers = { arrowImage = "" } } },
				message = "UI.markers.arrowImage: must not be empty",
			},
			{
				overrides = { UI = { hud = { layout = { scoreTab = { columnWidth = 0 } } } } },
				message = "UI.hud.layout.scoreTab.columnWidth: must be > 0",
			},
			{ overrides = { UI = { hud = { spacing = -1 } } }, message = "UI.hud.spacing: must be >= 0" },
			-- The carrier's beam is one part, which Roblox would clamp to its size limits.
			{
				overrides = { UI = { arenaGlow = { beam = { width = 0.0005 } } } },
				message = "UI.arenaGlow.beam.width: must be >= 0.001 (got 0.0005)",
			},
			{
				overrides = { UI = { arenaGlow = { beam = { thickness = 3000 } } } },
				message = "UI.arenaGlow.beam.thickness: must be <= 2048 (got 3000)",
			},
			{ overrides = { UI = { hud = { screenMargin = -1 } } }, message = "UI.hud.screenMargin: must be >= 0" },
			{ overrides = { UI = { keyNames = { Banana = "B" } } }, message = "UI.keyNames: Banana must name a key" },
			-- The HUD fits its parts by their sizes in pixels.
			{
				overrides = { UI = { hud = { layout = { banner = { size = UDim2.fromScale(0.5, 0.2) } } } } },
				message = "UI.hud.layout.banner.size: must be in pixels (scales 0, offsets > 0)",
			},
			{
				overrides = { UI = { hud = { layout = { scoreTab = { size = UDim2.fromOffset(0, 360) } } } } },
				message = "UI.hud.layout.scoreTab.size: must be in pixels (scales 0, offsets > 0)",
			},
			-- Five number columns of 120 and their gaps, inside the padding: 642 px, wider than the 640 px tab.
			{
				overrides = { UI = { hud = { layout = { scoreTab = { columnWidth = 120 } } } } },
				message = "UI: the score tab's number columns must leave room for names, in the tab and the end screen",
			},
		}
		for _, case in cases do
			expect(function()
				Fixtures.config(case.overrides)
			end).toThrow(case.message)
		end
		-- Prints "60%s": one value, then a percent sign and an s.
		expect(function()
			Fixtures.config({ UI = { text = { clockWarning = "%d%%s" } } })
		end).never.toThrow()
	end)

	it("rejects team spawns that would not fit on a straight", function()
		-- Six spawns span five spacings: exactly a straight's length fits, any more does not.
		local fits = Config.defaults().Arena.straightLength / 5
		expect(function()
			Fixtures.config({ Match = { teamSize = 6 }, Arena = { teamSpawnSpacing = fits + 1 } })
		end).toThrow("Arena: Match.teamSize spawns teamSpawnSpacing apart must fit on a straight")
		expect(function()
			Fixtures.config({ Match = { teamSize = 6 }, Arena = { teamSpawnSpacing = fits } })
		end).never.toThrow()
	end)

	it("rejects a malformed mode", function()
		expect(function()
			Config.forMode({ id = "X", displayName = "X", itemsEnabled = "no", overrides = {} } :: any)
		end).toThrow("Mode.itemsEnabled: expected boolean, got string")
	end)
end)
