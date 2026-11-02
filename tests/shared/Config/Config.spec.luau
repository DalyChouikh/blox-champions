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
		expect(m.durationSeconds).toBe(420)
		expect(m.overtimeSeconds).toBe(180)
		expect(m.goalPointsByLap).toEqual({ 1, 3, 5 })
		expect(m.celebrationSeconds).toBe(3)
		expect(m.kickoffCountdownSeconds).toBe(5)
		expect(m.clockPausesDuringKickoff).toBe(true)
		expect(m.postMatchSeconds).toBe(15)
		expect(m.lastChance).toEqual({ enabled = true })
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
			strandedSeconds = 5,
			restSpeed = 1,
			dropIn = { outerIn = 8, innerIn = 6, speed = 20, descent = 40 },
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
			maxGetUpsPerSecond = 2,
			posedLandingTolerance = 0.3,
		})
	end)

	-- Roller Champions' gravity, timed by frames and read in body heights, no speedometer (the owner, #279, Q44-Q46).
	it("pull with two thirds of Roblox's default gravity", function()
		expect(Config.defaults().World).toEqual({ gravity = 130.8 })
	end)

	it("leap the jump, the Air Pose and the Uppercut as high as at Roblox's gravity, hanging longer", function()
		local d = Config.defaults()
		local gravity = d.World.gravity
		local leapImpulse = assert(d.Actions.Uppercut.motion).leapImpulse :: number
		-- Each impulse, the height it rose at 196.2 and how long it now hangs (at 196.2: 0.612, 0.428 and 1.121 s).
		local cases = {
			{ d.Movement.jumpImpulse, 9.174, 0.749 },
			{ d.Movement.airPoseImpulse, 4.495, 0.524 },
			{ leapImpulse, 30.836, 1.373 },
		}
		for _, case in cases do
			local impulse, height, hang = case[1], case[2], case[3]
			expect(impulse ^ 2 / (2 * gravity)).toBeCloseTo(height, 2)
			expect(2 * impulse / gravity).toBeCloseTo(hang, 3)
		end
	end)

	it("match the spec's actions, plus this phase's", function()
		local requires = function(ball: string, grounded: string?): any
			return { ball = ball, grounded = grounded or "any", notKnockedDown = true }
		end
		expect(Config.defaults().Actions).toEqual({
			airMultiplier = 0.8,
			callPassWindow = 3,
			getUpAfter = 1.5,
			-- On the ground and in the air; its key dives from 0.1 to 1.0 s after it (#240: RC's "Dive" offer).
			Tackle = {
				phases = { windup = 0.05, active = 0.25, recovery = 0.35 },
				cooldown = 1,
				requires = requires("without"),
				effect = "Knockdown",
				pose = "Lunge",
				hit = { range = 7, coneDeg = 90, aimUpDeg = 0, knockdownSeconds = 1.5 },
				-- Q57-Q61: 2 bodies in the front half, else 3 bodies within 45°; a quarter-turn over its strike.
				seek = {
					snap = { range = 12, coneDeg = 90, aimUpDeg = 0 },
					bend = { range = 18, coneDeg = 45, aimUpDeg = 0 },
					turnDegPerSecond = 300,
				},
				-- 48 km/h more, never past 72 km/h; in the air 0.4 as much (#241: RC's 27 -> 42 km/h).
				motion = { lungeSpeed = 40, lungeCap = 60 },
				airMultiplier = 0.4,
				followUp = { action = "Dive", from = 0.1, to = 1 },
			},
			-- Only as the Tackle's follow-up, a 0.3 s flight (#277, Q66), then on the belly at the first touch of the
			-- ground until the slide stops (#221, #240, #242).
			Dive = {
				phases = { windup = 0, active = 0.3, recovery = 0.9 },
				cooldown = 0.8,
				requires = requires("without"),
				effect = "Knockdown",
				pose = "Lunge",
				hit = { range = 11, coneDeg = 90, aimUpDeg = 0, knockdownSeconds = 1.5 },
				-- Q64: 3 bodies up to 120° (beside, a little behind), else within 45°.
				seek = {
					snap = { range = 18, coneDeg = 120, aimUpDeg = 0 },
					bend = { range = 18, coneDeg = 45, aimUpDeg = 0 },
					turnDegPerSecond = 300,
				},
				-- 72 km/h along the way, or a faster skater's own speed (#241).
				motion = { diveSpeed = 60 },
				landing = { knockdownSeconds = 1.5, stopSpeed = 2 },
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
				phases = { windup = 0.05, active = 0.2, recovery = 0 },
				cooldown = 1.2,
				requires = requires("without", "grounded"),
				effect = "Knockdown",
				pose = "None",
				hit = { range = 6, coneDeg = 90, aimUpDeg = 0, knockdownSeconds = 1.5 },
				-- Q58: an opponent above within 45° of straight up; Q89: only as far as its hit reaches (27.4 studs).
				seek = {
					snap = { range = 12, coneDeg = 90, aimUpDeg = 0 },
					bend = { range = 27, coneDeg = 45, aimUpDeg = 90 },
					turnDegPerSecond = 360,
				},
				-- √(2/3) of 110: as high at two thirds of the gravity (#279).
				motion = { leapImpulse = 89.81 },
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
			-- Roller Champions' stride on the flat: 55 km/h (#265).
			cruiseSpeed = 46,
			softCap = 90,
			hardCap = 121,
			overSpeedBleed = 5,
			-- Back to the earlier rates (#272, Q37): RC's skaters circle with W, A, S, D pressed in turn (Video 19).
			turnRateLow = 5.0,
			turnRateHigh = 2.0,
			-- A half-turn of the facing, never a snap (#246: RC turned round over ~0.3 s), and how near the way back
			-- the stick and the facing keep a skater riding backwards.
			turnRoundSeconds = 0.3,
			backwardsConeDeg = 30,
			airTurnRate = 1,
			airUprightRate = 6,
			-- A diver's way down (#241: RC's dive gained ~75 km/h per s).
			fallLineDeg = 20,
			wallAngle = 30,
			-- Walls grip the skates against a bend away (#289, Q71): round the middle glass's round ends slower than
			-- √(38 × 22.5) = 29 studs/s, 5 body lengths a second.
			wallGrip = 38,
			wallTurnRate = 1,
			-- A climb up any solid surface while the stick points up it, never the glass (#299, Q85: trial S4).
			climbSpeed = 40,
			climbAccel = 45,
			curvatureWindow = 10,
			pumpSlopeMultiplier = 1.6,
			pumpFlatAccel = 8,
			pumpFlatSlopeDeg = 3,
			brakeDecel = 120,
			tiptoeSpeed = 12,
			-- √(2/3) of 60 and 42: as high at two thirds of the gravity (#279).
			jumpImpulse = 48.99,
			jumpSpeedCost = 0.1,
			airPoseImpulse = 34.29,
			-- A touchdown on the belly from the air keeps this much of the speed (#245: RC kept 59-73%).
			bellyLandingKeep = 0.65,
			-- A sharper turn of the ground's normal is a corner (or a seam's side face); the body eases where the
			-- skating turns at once (#255: smoothing the skating's normal added energy on curved walls).
			cornerDeg = 30,
			bodyUpSmoothing = 30,
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
			-- Every knockdown slides evenly to a stop in its kind's time (#252: RC's tackle and posed falls 1.5 s,
			-- dives 0.7-0.8 s, whatever the speed).
			knockdownSlideSeconds = { Hit = 1.5, Fall = 1.5, Dive = 0.8 },
			hardLanding = { drop = 40, knockdownSeconds = 1.5 },
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
			knockdownTiltDeg = 85,
			airPoseDeg = 70,
			airPoseArmDeg = 150,
			-- The owner (#243): every knockdown eases down and up; a diver kneels on the belly (RC, Video 4),
			-- anyone else lies flat on the back (was tipped 60° back, floating).
			knockdownEaseSeconds = 0.3,
			knockdownSinkStuds = 1.3,
			diveDeg = 70,
			diveHipDeg = 50,
			diveKneeDeg = 110,
			diveSinkStuds = 0.7,
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
		-- Degrees per pixel, per second at full tilt, per pixel: the mouse at a fifth of Roblox's own (#275, Q35 ->
		-- Q52), the stick and touch at Roblox's own.
		expect(input.look).toEqual({
			mouse = { key = Enum.KeyCode.MouseDelta, degPerUnit = Vector2.new(0.1, 0.077), responseCurve = 1 },
			stick = { key = Enum.KeyCode.Thumbstick2, degPerUnit = Vector2.new(240, -185), responseCurve = 2 },
			touch = { key = Enum.KeyCode.TouchDelta, degPerUnit = Vector2.new(1, 0.66), responseCurve = 1 },
		})
		expect(input.ballFocus).toEqual({ Enum.KeyCode.MouseRightButton, Enum.KeyCode.ButtonL2 })
		expect(input.ballFocusMode).toBe("Hold")
		expect(input.touchBallFocusMode).toBe("Toggle")
		expect(input.scoreTab).toEqual({ Enum.KeyCode.Tab, Enum.KeyCode.ButtonSelect })
		expect(input.actions).toEqual({
			tackle = { "Dive", "Tackle", "Dodge" },
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
			-- The owner's trial A3 (#276, Q53).
			framing = {
				{ pitchDeg = -55, distance = 22, height = 5 },
				{ pitchDeg = -35, distance = 19, height = 5 },
				{ pitchDeg = -20, distance = 16, height = 5 },
				{ pitchDeg = -10, distance = 14, height = 5 },
				{ pitchDeg = 0, distance = 12, height = 5 },
				{ pitchDeg = 15, distance = 10, height = 5 },
				{ pitchDeg = 30, distance = 5, height = 1.5 },
				{ pitchDeg = 45, distance = 1, height = -1.5 },
			},
			fade = { seen = 4, gone = 1.5 },
			collisionMargin = 0.5,
			fovBase = 70,
			fovMax = 90,
			fovResponse = 6,
			minPitchDeg = -70,
			maxPitchDeg = 60,
			rollResponse = 8,
			maxTiltDeg = 30,
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
			GetUp = "Get Up",
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
			lap = "Lap %d",
			goalWorth = "Lap %d: goal +%d",
			overtime = "OVERTIME",
			goal = "GOAL!",
			denied = "DENIED!",
			clockWarning = "%d SECONDS",
			lastChance = "LAST CHANCE",
			speed = "%d km/h",
			possession = "%s has the ball",
			lapCompleted = "Lap %d completed",
			goalOpen = "%s goal is active",
			scored = "%s scored!",
			wins = "%s WINS",
			go = "GO %s TEAM!",
			draw = "DRAW",
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
			touchMove = "Move",
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
			countdown = { textSize = 76, ringSize = 200, ringThickness = 8 },
			feedSeconds = 6,
			feedMaxEntries = 5,
			glowThickness = 3,
			spacing = 6,
			pipSize = 10,
			screenMargin = 8,
			layout = {
				scoreboard = { position = UDim2.new(0.5, 0, 0, 8), size = UDim2.fromOffset(440, 84) },
				banner = { position = UDim2.new(0.5, 0, 0, 200), size = UDim2.fromOffset(720, 110) },
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
				getUp = { position = UDim2.new(0.5, 0, 1, -172), size = UDim2.fromOffset(320, 40) },
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
		-- The owner's pick (#268, trial 6): the straights' foot curve tops out at 34.2, so the wall rises to 40.
		expect(a.outerWallHeight).toBe(40)
		-- The owner (#217): twice the first 8, like Roller Champions' wide ramp into the middle of Pixel City.
		expect(a.innerBankHeight).toBe(16)
		-- The owner's pick (#268, trial 6): a wider bank, a flat spawn room, a steep rise onto a gentle incline and a
		-- wide foot curve on the straights; a bowl rising to the foot curve at the curved ends.
		expect(a.straight).toEqual({
			bankWidth = 24,
			roomEnd = 30,
			riseEnd = 44,
			riseHeight = 8,
			inclineDeg = 14,
			footRadius = 22,
		})
		expect(a.curvedEnd).toEqual({ bowlHeight = 14, bowlPower = 2, footRadius = 18 })
		for _, gone in { "wallCurveRadius", "stepHeight", "stepWidth", "upperFloorWidth" } do
			expect((a :: any)[gone]).toBeNil()
		end
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
			-- Trial 6's: the floor under the ring rose with #268's sections; the arm's post stays 14 long.
			heightAboveFloor = 29,
			panelThickness = 0.5,
			panelTransparency = 0.3,
			rimThickness = 1,
			rimSegments = 16,
			across = 0.75,
			arm = { thickness = 1, height = 51 },
		})
		expect((a.goal :: any).wallGap).toBeNil()
		expect(a.gatePanel).toEqual({ depth = 0.2 })
		expect((a :: any).marker).toBeNil()
		expect(a.teamSpawnSpacing).toBe(10)
	end)

	it("size and shade the arena parts that only carry a tag", function()
		local a = Config.defaults().Arena
		expect(a.gateThickness).toBe(0.2)
		expect(a.spawnPad).toEqual({ width = 4, thickness = 0.2, transparency = 0.4 })
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

describe("Config.gravity", function()
	it("points the world's pull straight down", function()
		Fixtures.expectNear(Config.gravity(Config.defaults()), Vector3.new(0, -130.8, 0))
		Fixtures.expectNear(Config.gravity(Fixtures.config({ World = { gravity = 50 } })), Vector3.new(0, -50, 0))
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
		local c = Fixtures.config({ Scoring = { points = { goal = 200 } } })
		expect(c.Scoring.points.goal).toBe(200)
		expect(c.Scoring.points.assist).toBe(50)
		expect(c.Match.pointsToWin).toBe(5)
		expect(Config.defaults().Scoring.points.goal).toBe(100)
		expect(table.isfrozen(c.Scoring.points)).toBe(true)
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

	it("rejects goal points that are missing, not whole, or do not rise lap by lap", function()
		expect(function()
			Fixtures.config({ Match = { goalPointsByLap = {} } })
		end).toThrow("Match.goalPointsByLap: must not be empty")
		expect(function()
			Fixtures.config({ Match = { goalPointsByLap = { 1, 0.5 } } })
		end).toThrow("Match.goalPointsByLap[2]: must be an integer")
		expect(function()
			Fixtures.config({ Match = { goalPointsByLap = { 0, 3 } } })
		end).toThrow("Match.goalPointsByLap[1]: must be >= 1")
		expect(function()
			Fixtures.config({ Match = { goalPointsByLap = { 1, 3, 3 } } })
		end).toThrow("Match.goalPointsByLap: must rise, each lap worth more than the one before")
	end)

	-- The owner (#305): the streak point goes; the goal's worth by laps replaces the laps to open it.
	it("rejects the old lap-target and streak-point settings as unknown", function()
		for _, key in { "lapsToOpenGoal", "lapsForStreakPoint", "pointValue" } do
			expect(function()
				Fixtures.config({ Match = { [key] = 1 } })
			end).toThrow(`Match.{key}: unknown key`)
		end
		expect(function()
			Fixtures.config({ Scoring = { points = { streakPoint = 100 } } })
		end).toThrow("Scoring.points.streakPoint: unknown key")
	end)

	it("rejects a regulation or overtime clock under a second", function()
		expect(function()
			Fixtures.config({ Match = { durationSeconds = 0.5 } })
		end).toThrow("Match.durationSeconds: must be >= 1 (got 0.5)")
		expect(function()
			Fixtures.config({ Match = { overtimeSeconds = 0 } })
		end).toThrow("Match.overtimeSeconds: must be >= 1 (got 0)")
	end)

	it("accepts regulation and overtime clocks just inside their limits", function()
		local config = Fixtures.config({ Match = { durationSeconds = 1, overtimeSeconds = 1 } })
		expect(config.Match.durationSeconds).toBe(1)
		expect(config.Match.overtimeSeconds).toBe(1)
	end)

	-- The owner (Q94, #306): Last Chance is one attack at any deficit, so no deficit limits it.
	it("rejects the old Last Chance deficit limit as unknown", function()
		expect(function()
			Fixtures.config({ Match = { lastChance = { maxDeficit = 2 } } })
		end).toThrow("Match.lastChance.maxDeficit: unknown key")
	end)

	it("accepts goal points just inside their limits", function()
		local config = Fixtures.config({ Match = { goalPointsByLap = { 1 } } })
		expect(config.Match.goalPointsByLap).toEqual({ 1 })
		config = Fixtures.config({ Match = { goalPointsByLap = { 1, 2 } } })
		expect(config.Match.goalPointsByLap).toEqual({ 1, 2 })
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
		local STRAIGHTS = "Arena: trackWidth must fit the straights' pieces in order: the inner bank, the spawn room, "
			.. "the rise, the incline and the outer wall's foot curve"
		local CURVED_ENDS =
			"Arena: trackWidth must fit the curved ends' inner bank, a bowl and the outer wall's foot curve"
		local OUTER_WALL = "Arena: the outer wall must rise above its foot curves"
		local cases: { { overrides: { [string]: any }, message: string } } = {
			-- On the straights the bank ends at 24, the room at 30 and the rise at 44; the foot curve (22, leaving the
			-- 14° incline) starts at 80 − 22 (1 − sin 14°) = 63.32, or at 43.32 across a 60-stud track.
			{ overrides = { straight = { roomEnd = 24 } }, message = STRAIGHTS },
			{ overrides = { straight = { riseEnd = 30 } }, message = STRAIGHTS },
			{ overrides = { straight = { riseEnd = 63.4 } }, message = STRAIGHTS },
			{ overrides = { trackWidth = 60 }, message = STRAIGHTS },
			-- At the curved ends the bowl runs from the bank's foot (16) to past trackWidth − footRadius.
			{ overrides = { curvedEnd = { footRadius = 64 } }, message = CURVED_ENDS },
			{ overrides = { innerBankHeight = 62 }, message = CURVED_ENDS },
			-- The straights' foot curve tops out at 12.82 + 22 cos 14° = 34.16; the curved ends' at most bowlHeight +
			-- footRadius (28 + 18 cos 43.77° = 41.00 with this bowl).
			{ overrides = { outerWallHeight = 34 }, message = OUTER_WALL },
			{ overrides = { curvedEnd = { bowlHeight = 28 } }, message = OUTER_WALL },
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
				-- The lip (12) would start at 28, under the outer wall's top (40).
				overrides = { glass = { top = 40 } },
				message = "Arena: the glass must rise above the inner bank's and the outer wall's tops before its lip",
			},
			{
				-- Its lip would start over the outer wall (40), under a bank of 50.
				overrides = { innerBankHeight = 50, glass = { top = 61 } },
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
			{
				overrides = { straight = { bankWidth = 0 } },
				message = "Arena.straight.bankWidth: must be > 0 (got 0)",
			},
			-- Every piece of a straight and of a curved end has a size (#268).
			{ overrides = { straight = { roomEnd = 0 } }, message = "Arena.straight.roomEnd: must be > 0 (got 0)" },
			{ overrides = { straight = { riseEnd = 0 } }, message = "Arena.straight.riseEnd: must be > 0 (got 0)" },
			{
				overrides = { straight = { riseHeight = 0 } },
				message = "Arena.straight.riseHeight: must be > 0 (got 0)",
			},
			{
				overrides = { straight = { footRadius = 0 } },
				message = "Arena.straight.footRadius: must be > 0 (got 0)",
			},
			{
				overrides = { curvedEnd = { bowlHeight = 0 } },
				message = "Arena.curvedEnd.bowlHeight: must be > 0 (got 0)",
			},
			{
				overrides = { curvedEnd = { footRadius = 0 } },
				message = "Arena.curvedEnd.footRadius: must be > 0 (got 0)",
			},
			-- The incline's slope must stay finite.
			{
				overrides = { straight = { inclineDeg = -1 } },
				message = "Arena.straight.inclineDeg: must be >= 0 (got -1)",
			},
			{ overrides = { straight = { inclineDeg = 90 } }, message = "Arena.straight.inclineDeg: must be < 90" },
			-- The bowl must leave the bank's foot flat, where the bank meets it.
			{
				overrides = { curvedEnd = { bowlPower = 1 } },
				message = "Arena.curvedEnd.bowlPower: must be > 1 (got 1)",
			},
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

	-- Each just inside the limit the rejections above cross: the incline ending at 63.3, before the straights' foot
	-- curve starts (63.32); the wall at 34.2, over that curve's top (34.16); a curved end's bowl at 21.9, its bound
	-- (+ 18) under the wall's 40; a bank of 61.9, leaving its bowl room before 80 − 18.
	it("accepts arena shapes just inside the limits of the straights, the curved ends and the outer wall", function()
		local shapes: { { [string]: any } } = {
			{ straight = { riseEnd = 63.3 } },
			{ outerWallHeight = 34.2 },
			{ curvedEnd = { bowlHeight = 21.9 } },
			{ innerBankHeight = 61.9 },
		}
		for _, overrides in shapes do
			expect(function()
				Fixtures.config({ Arena = overrides })
			end).never.toThrow()
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
				-- Its drop-in lines clear of so wide a ball (#321).
				overrides = { Ball = { radius = 7, dropIn = { innerIn = 8 } } },
				message = "Ball: radius must be smaller than the goal ring's opening (Arena.goal.ringRadius)",
			},
		}
		for _, case in cases do
			expect(function()
				Fixtures.config(case.overrides)
			end).toThrow(case.message)
		end
	end)

	-- The owner (Q93, #308): a loose ball stays where it rolls; only one resting on something nobody skates respawns.
	it("rejects a ball stranded for no time, or resting at no speed", function()
		expect(function()
			Fixtures.config({ Ball = { strandedSeconds = 0 } })
		end).toThrow("Ball.strandedSeconds: must be > 0 (got 0)")
		expect(function()
			Fixtures.config({ Ball = { restSpeed = 0 } })
		end).toThrow("Ball.restSpeed: must be > 0 (got 0)")
	end)

	it("accepts a stranded wait and a rest speed just inside their limits", function()
		local ball = Fixtures.config({ Ball = { strandedSeconds = 0.01, restSpeed = 0.01 } }).Ball
		expect(ball.strandedSeconds).toBe(0.01)
		expect(ball.restSpeed).toBe(0.01)
	end)

	it("rejects the old idle respawn as unknown", function()
		expect(function()
			Fixtures.config({ Ball = { ballIdleResetSeconds = 15 } })
		end).toThrow("Ball.ballIdleResetSeconds: unknown key")
	end)

	-- The owner (Q111-Q116, #321): the ball drops in at a random spot by either wall, as trialled.
	it("rejects a drop starting in the glass, on lines that cross, that never falls or rolls backwards", function()
		local clear = "Ball: the drop-in must start clear of the glass (dropIn.innerIn and dropIn.outerIn >= radius)"
		local apart = "Ball: the drop-in's two lines must lie apart across the track "
			.. "(dropIn.innerIn + dropIn.outerIn < Arena.trackWidth)"
		local cases: { { dropIn: { [string]: number }, message: string } } = {
			{ dropIn = { innerIn = 1 }, message = clear },
			{ dropIn = { outerIn = 1 }, message = clear },
			{ dropIn = { innerIn = 40, outerIn = 40 }, message = apart },
			{ dropIn = { descent = 0 }, message = "Ball.dropIn.descent: must be > 0 (got 0)" },
			{ dropIn = { speed = -1 }, message = "Ball.dropIn.speed: must be >= 0 (got -1)" },
		}
		for _, case in cases do
			expect(function()
				Fixtures.config({ Ball = { dropIn = case.dropIn } })
			end).toThrow(case.message)
		end
	end)

	it("accepts a drop just inside its limits", function()
		local inside = { innerIn = 1.5, outerIn = 78.4, speed = 0, descent = 0.01 }
		expect(Fixtures.config({ Ball = { dropIn = inside } }).Ball.dropIn).toEqual(inside)
	end)

	it("rejects the old ball spawn settings as unknown", function()
		for _, key in { "ballSpawnHeight", "ballSpawnSize" } do
			expect(function()
				Fixtures.config({ Arena = { [key] = 1 } })
			end).toThrow(`Arena.{key}: unknown key`)
		end
	end)

	it("rejects skating speeds, turn rates and sizes that contradict each other", function()
		local cases: { { overrides: { [string]: any }, message: string } } = {
			{
				overrides = { Movement = { softCap = 150 } },
				message = "Movement: speeds must rise: cruiseSpeed <= softCap < hardCap",
			},
			{
				overrides = { Movement = { turnRateHigh = 6 } },
				message = "Movement: turnRateHigh must not exceed turnRateLow",
			},
			{
				overrides = { Movement = { groundProbeLength = 2 } },
				message = "Movement: groundProbeLength must reach past hoverHeight",
			},
			{
				overrides = { Movement = { climbSpeed = 0 } },
				message = "Movement.climbSpeed: must be > 0 (got 0)",
			},
			{
				overrides = { Movement = { climbAccel = 0 } },
				message = "Movement.climbAccel: must be > 0 (got 0)",
			},
			{
				overrides = { Movement = { climbSpeed = 46 } },
				message = "Movement: climbSpeed must stay below cruiseSpeed",
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
				overrides = { Movement = { bellyLandingKeep = 0 } },
				message = "Movement.bellyLandingKeep: must be > 0 (got 0)",
			},
			{
				overrides = { Movement = { bellyLandingKeep = 1.5 } },
				message = "Movement.bellyLandingKeep: must be <= 1 (got 1.5)",
			},
			{
				overrides = { Movement = { hardLanding = { drop = 0 } } },
				message = "Movement.hardLanding.drop: must be > 0 (got 0)",
			},
			{
				overrides = { Movement = { hardLanding = { knockdownSeconds = 0 } } },
				message = "Movement.hardLanding.knockdownSeconds: must be > 0 (got 0)",
			},
			-- A corner and the body's easing (#255).
			{
				overrides = { Movement = { cornerDeg = 0 } },
				message = "Movement.cornerDeg: must be > 0 (got 0)",
			},
			{
				overrides = { Movement = { cornerDeg = 91 } },
				message = "Movement.cornerDeg: must be <= 90 (got 91)",
			},
			{
				overrides = { Movement = { bodyUpSmoothing = 0 } },
				message = "Movement.bodyUpSmoothing: must be > 0 (got 0)",
			},
			-- A slide's time (#252): every kind must stop in some time.
			{
				overrides = { Movement = { knockdownSlideSeconds = { Hit = 0 } } },
				message = "Movement.knockdownSlideSeconds.Hit: must be > 0 (got 0)",
			},
			{
				overrides = { Movement = { knockdownSlideSeconds = { Fall = 0 } } },
				message = "Movement.knockdownSlideSeconds.Fall: must be > 0 (got 0)",
			},
			{
				overrides = { Movement = { knockdownSlideSeconds = { Dive = 0 } } },
				message = "Movement.knockdownSlideSeconds.Dive: must be > 0 (got 0)",
			},
			{
				overrides = { Movement = { wallTurnRate = -1 } },
				message = "Movement.wallTurnRate: must be >= 0 (got -1)",
			},
			{
				overrides = { Movement = { wallGrip = -1 } },
				message = "Movement.wallGrip: must be >= 0 (got -1)",
			},
			{
				overrides = { Movement = { turnRoundSeconds = 0 } },
				message = "Movement.turnRoundSeconds: must be > 0 (got 0)",
			},
			{
				overrides = { Movement = { backwardsConeDeg = 0 } },
				message = "Movement.backwardsConeDeg: must be > 0 (got 0)",
			},
			{
				overrides = { Movement = { backwardsConeDeg = 91 } },
				message = "Movement.backwardsConeDeg: must be <= 90 (got 91)",
			},
			-- The fall line (#241): below the facing, at most straight down.
			{
				overrides = { Movement = { fallLineDeg = 0 } },
				message = "Movement.fallLineDeg: must be > 0 (got 0)",
			},
			{
				overrides = { Movement = { fallLineDeg = 91 } },
				message = "Movement.fallLineDeg: must be <= 90 (got 91)",
			},
			-- A wall is steeper than wallAngle from flat: some slope, short of upright (#216, the review #303).
			{ overrides = { Movement = { wallAngle = 0 } }, message = "Movement.wallAngle: must be > 0 (got 0)" },
			{ overrides = { Movement = { wallAngle = 90 } }, message = "Movement.wallAngle: must be < 90" },
		}
		for _, case in cases do
			expect(function()
				Fixtures.config(case.overrides)
			end).toThrow(case.message)
		end
	end)

	it("accepts strike seeks just inside their limits", function()
		local cone = { range = 0.01, coneDeg = 180, aimUpDeg = 90 }
		local actions = Fixtures.config({
			Actions = { Tackle = { seek = { snap = cone, bend = cone, turnDegPerSecond = 0 } } },
		}).Actions
		local seek = actions.Tackle.seek :: Config.Seek
		expect(seek.snap).toEqual(cone)
		expect(seek.bend).toEqual(cone)
		expect(seek.turnDegPerSecond).toBe(0)
	end)

	it("accepts a climb just inside its limits", function()
		local movement = Fixtures.config({ Movement = { climbSpeed = 45.9, climbAccel = 0.01 } }).Movement
		expect(movement.climbSpeed).toBe(45.9)
		expect(movement.climbAccel).toBe(0.01)
	end)

	it("rejects actions that contradict themselves", function()
		local cases: { { overrides: { [string]: any }, message: string } } = {
			{
				overrides = { ChargeThrow = { throw = { maxSpeed = 50 } } },
				message = "Actions.ChargeThrow.throw: maxSpeed must be at least minSpeed",
			},
			-- The Tackle's follow-up (#240): another action, in a window that ends after it starts.
			{
				overrides = { Tackle = { followUp = { action = "Tackle" } } },
				message = "Actions.Tackle.followUp.action: must name another action",
			},
			{
				overrides = { Tackle = { followUp = { from = 1, to = 0.5 } } },
				message = "Actions.Tackle.followUp: to must be after from",
			},
			{
				overrides = { Tackle = { followUp = { from = -0.1 } } },
				message = "Actions.Tackle.followUp.from: must be >= 0 (got -0.1)",
			},
			{
				overrides = { Dodge = { followUp = { action = "Dive", from = 0, to = 1 } } },
				message = "Actions.Dodge.followUp: unknown key",
			},
			{
				overrides = { Dive = { landing = { knockdownSeconds = 0 } } },
				message = "Actions.Dive.landing.knockdownSeconds: must be > 0 (got 0)",
			},
			{
				overrides = { Dive = { landing = { stopSpeed = 0 } } },
				message = "Actions.Dive.landing.stopSpeed: must be > 0 (got 0)",
			},
			{
				overrides = { Dodge = { hit = { range = 1, coneDeg = 1, aimUpDeg = 0, knockdownSeconds = 1 } } },
				message = "Actions.Dodge.hit: unknown key",
			},
			{
				overrides = { Tackle = { effect = "Throw" } },
				message = 'Actions.Tackle.effect: must be one of Knockdown (got "Throw")',
			},
			{
				overrides = { Uppercut = { motion = { leapImpulse = 0 } } },
				message = "Actions.Uppercut.motion.leapImpulse: must be > 0 (got 0)",
			},
			-- The lunges (#241): a tackle's ceiling and air strength, a dive's speed.
			{
				overrides = { Tackle = { motion = { lungeCap = 0 } } },
				message = "Actions.Tackle.motion.lungeCap: must be > 0 (got 0)",
			},
			{
				overrides = { Tackle = { airMultiplier = 1.5 } },
				message = "Actions.Tackle.airMultiplier: must be <= 1 (got 1.5)",
			},
			{
				overrides = { Dodge = { airMultiplier = 0.5 } },
				message = "Actions.Dodge.airMultiplier: unknown key",
			},
			{
				overrides = { Dive = { motion = { diveSpeed = 0 } } },
				message = "Actions.Dive.motion.diveSpeed: must be > 0 (got 0)",
			},
			-- The strikes' seeks (#277): cones like the hits', a turn rate of zero or more, only on the strikes.
			{
				overrides = { Tackle = { seek = { snap = { range = 0 } } } },
				message = "Actions.Tackle.seek.snap.range: must be > 0 (got 0)",
			},
			{
				overrides = { Dive = { seek = { snap = { coneDeg = 181 } } } },
				message = "Actions.Dive.seek.snap.coneDeg: must be <= 180 (got 181)",
			},
			{
				overrides = { Uppercut = { seek = { bend = { aimUpDeg = 91 } } } },
				message = "Actions.Uppercut.seek.bend.aimUpDeg: must be <= 90 (got 91)",
			},
			{
				overrides = { Tackle = { seek = { bend = { coneDeg = 0 } } } },
				message = "Actions.Tackle.seek.bend.coneDeg: must be > 0 (got 0)",
			},
			{
				overrides = { Tackle = { seek = { turnDegPerSecond = -1 } } },
				message = "Actions.Tackle.seek.turnDegPerSecond: must be >= 0 (got -1)",
			},
			{
				overrides = { Dodge = { seek = { turnDegPerSecond = 1 } } },
				message = "Actions.Dodge.seek: unknown key",
			},
		}
		for _, case in cases do
			expect(function()
				Fixtures.config({ Actions = case.overrides })
			end).toThrow(case.message)
		end
	end)

	it("rejects getting up with no wait, or with no requests to get up let through", function()
		expect(function()
			Fixtures.config({ Actions = { getUpAfter = 0 } })
		end).toThrow("Actions.getUpAfter: must be > 0 (got 0)")
		expect(function()
			Fixtures.config({ Network = { maxGetUpsPerSecond = 0 } })
		end).toThrow("Network.maxGetUpsPerSecond: must be > 0 (got 0)")
	end)

	-- The review (#303): a knockdown lasts at least getUpAfter (Network.maxGetUpsPerSecond's honest client), and a
	-- leap homes no farther than its hit can reach (Q89).
	it("rejects getting up after a knockdown ends, and a leap homing past what its hit reaches", function()
		local GET_UP = "Actions: getUpAfter must not exceed any hit's knockdownSeconds nor "
			.. "Movement.hardLanding.knockdownSeconds"
		-- The Uppercut's strike ends 0.25 s after the press, the leap then 89.81 × 0.25 − 130.8 × 0.25² / 2 = 18.365
		-- up; its hit reaches 6 more, and 3 for the server's lag: 27.365.
		local REACH = "Actions: a leap's seek.bend.range must be within what its hit reaches by its strike's end "
			.. "(the leap's rise, hit.range and Network.hitLagToleranceStuds)"
		local cases: { { overrides: { [string]: any }, message: string } } = {
			{ overrides = { Actions = { getUpAfter = 1.6 } }, message = GET_UP },
			{ overrides = { Actions = { Tackle = { hit = { knockdownSeconds = 1.4 } } } }, message = GET_UP },
			{ overrides = { Movement = { hardLanding = { knockdownSeconds = 1.4 } } }, message = GET_UP },
			{ overrides = { Actions = { Uppercut = { seek = { bend = { range = 27.4 } } } } }, message = REACH },
			-- A shorter strike reaches less: 0.15 s, 12.0 up, 21.0 in all.
			{ overrides = { Actions = { Uppercut = { phases = { active = 0.1 } } } }, message = REACH },
			{ overrides = { Network = { hitLagToleranceStuds = 0 } }, message = REACH },
		}
		for _, case in cases do
			expect(function()
				Fixtures.config(case.overrides)
			end).toThrow(case.message)
		end
		local inside = Fixtures.config({ Actions = { Uppercut = { seek = { bend = { range = 27.36 } } } } })
		expect((inside.Actions.Uppercut.seek :: Config.Seek).bend.range).toBe(27.36)
	end)

	-- The review (#303): the Feel part's settings, each just inside its limit (getUpAfter brought down with the
	-- knockdowns it must not outlast).
	it(
		"accepts the Feel part's skating, action, network, pose, camera and label settings just inside their limits",
		function()
			local movement: { [string]: any } = {
				backwardsConeDeg = 90,
				fallLineDeg = 90,
				cornerDeg = 90,
				wallAngle = 89.9,
				bellyLandingKeep = 1,
				jumpSpeedCost = 1,
				airPoseImpulse = 0,
				overSpeedBleed = 0,
				wallGrip = 0,
				wallTurnRate = 0,
				turnRoundSeconds = 0.01,
				bodyUpSmoothing = 0.01,
				knockdownSlideSeconds = { Hit = 0.01, Fall = 0.01, Dive = 0.01 },
				hardLanding = { drop = 0.01, knockdownSeconds = 0.01 },
			}
			local pose: { [string]: any } = {
				airPoseDeg = 180,
				airPoseArmDeg = 0,
				diveDeg = 0,
				diveHipDeg = 180,
				diveKneeDeg = 0,
				diveSinkStuds = 0,
				knockdownEaseSeconds = 0.01,
				knockdownSinkStuds = 0,
			}
			local config = Fixtures.config({
				Movement = movement,
				Actions = {
					getUpAfter = 0.01,
					Tackle = { followUp = { from = 0, to = 0.01 } },
					Dive = { landing = { knockdownSeconds = 0.01, stopSpeed = 0.01 } },
				},
				Network = { maxGetUpsPerSecond = 0.01, posedLandingTolerance = 0 },
				Pose = pose,
				Camera = { maxTiltDeg = 89 },
				UI = { controlLabels = { AirPose = "A", GetUp = "G" }, text = { touchMove = "M" } },
			})
			local readMovement: any, readPose: any = config.Movement, config.Pose
			for name, value in movement do
				expect(readMovement[name]).toEqual(value)
			end
			for name, value in pose do
				expect(readPose[name]).toBe(value)
			end
			expect(config.Actions.getUpAfter).toBe(0.01)
			expect(config.Actions.Tackle.followUp).toEqual({ action = "Dive", from = 0, to = 0.01 })
			expect(config.Actions.Dive.landing).toEqual({ knockdownSeconds = 0.01, stopSpeed = 0.01 })
			expect(config.Network.maxGetUpsPerSecond).toBe(0.01)
			expect(config.Network.posedLandingTolerance).toBe(0)
			expect(config.Camera.maxTiltDeg).toBe(89)
			expect(config.UI.controlLabels.AirPose).toBe("A")
			expect(config.UI.controlLabels.GetUp).toBe("G")
			expect(config.UI.text.touchMove).toBe("M")
		end
	)

	it("rejects a posed landing reported for less than no time", function()
		expect(function()
			Fixtures.config({ Network = { posedLandingTolerance = -0.1 } })
		end).toThrow("Network.posedLandingTolerance: must be >= 0 (got -0.1)")
	end)

	it("rejects a world with no gravity or gravity pulling up, and takes any pull down", function()
		for _, gravity in { 0, -130.8 } do
			expect(function()
				Fixtures.config({ World = { gravity = gravity } })
			end).toThrow(`World.gravity: must be > 0 (got {gravity})`)
		end
		expect(Fixtures.config({ World = { gravity = 0.001 } }).World.gravity).toBe(0.001)
	end)

	it("rejects a knockdown pose that snaps, bends past half a turn or sinks upward", function()
		expect(function()
			Fixtures.config({ Pose = { knockdownEaseSeconds = 0 } })
		end).toThrow("Pose.knockdownEaseSeconds: must be > 0 (got 0)")
		expect(function()
			Fixtures.config({ Pose = { diveDeg = 181 } })
		end).toThrow("Pose.diveDeg: must be <= 180 (got 181)")
		expect(function()
			Fixtures.config({ Pose = { diveHipDeg = -1 } })
		end).toThrow("Pose.diveHipDeg: must be >= 0 (got -1)")
		expect(function()
			Fixtures.config({ Pose = { diveKneeDeg = 181 } })
		end).toThrow("Pose.diveKneeDeg: must be <= 180 (got 181)")
		expect(function()
			Fixtures.config({ Pose = { diveSinkStuds = -0.5 } })
		end).toThrow("Pose.diveSinkStuds: must be >= 0 (got -0.5)")
		expect(function()
			Fixtures.config({ Pose = { knockdownSinkStuds = -0.5 } })
		end).toThrow("Pose.knockdownSinkStuds: must be >= 0 (got -0.5)")
		-- The Air Pose's stretch (#218).
		expect(function()
			Fixtures.config({ Pose = { airPoseDeg = 181 } })
		end).toThrow("Pose.airPoseDeg: must be <= 180 (got 181)")
		expect(function()
			Fixtures.config({ Pose = { airPoseArmDeg = -1 } })
		end).toThrow("Pose.airPoseArmDeg: must be >= 0 (got -1)")
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

	it("rejects a camera that would not lean with the surface, or would lean all the way onto a wall", function()
		expect(function()
			Fixtures.config({ Camera = { maxTiltDeg = 0 } })
		end).toThrow("Camera.maxTiltDeg: must be > 0 (got 0)")
		expect(function()
			Fixtures.config({ Camera = { maxTiltDeg = 90 } })
		end).toThrow("Camera.maxTiltDeg: must be <= 89 (got 90)")
	end)

	it("rejects a camera framing that is empty, out of order, past the pitch limits or not behind its focus", function()
		local function point(pitchDeg: number, distance: number): { [string]: number }
			return { pitchDeg = pitchDeg, distance = distance, height = 5 }
		end
		local ORDER = "Camera: framing must rise in pitchDeg, each point above the one before"
		local LIMITS = "Camera: framing's pitchDeg must lie within minPitchDeg and maxPitchDeg"
		local cases: { { framing: { { [string]: number } }, message: string } } = {
			{ framing = {}, message = "Camera.framing: must not be empty" },
			{ framing = { point(0, 12), point(-10, 14) }, message = ORDER },
			{ framing = { point(0, 12), point(0, 10) }, message = ORDER },
			{ framing = { point(-71, 22), point(0, 12) }, message = LIMITS },
			{ framing = { point(0, 12), point(61, 1) }, message = LIMITS },
			{ framing = { point(0, 12), point(45, 0) }, message = "Camera.framing[2].distance: must be > 0 (got 0)" },
		}
		for _, case in cases do
			expect(function()
				Fixtures.config({ Camera = { framing = case.framing } })
			end).toThrow(case.message)
		end
	end)

	it("rejects a skater fade that ends past the focus, or starts no farther out than it ends", function()
		expect(function()
			Fixtures.config({ Camera = { fade = { gone = -1 } } })
		end).toThrow("Camera.fade.gone: must be >= 0 (got -1)")
		expect(function()
			Fixtures.config({ Camera = { fade = { seen = 1.5 } } })
		end).toThrow("Camera: fade.seen must be above fade.gone")
	end)

	-- Each just inside a limit the rejections above cross: the pitch limits themselves, points a hair apart, a
	-- distance a hair out, a focus below the root, a fade a hair wide ending at the focus; one point holds at every
	-- pitch.
	it("accepts a camera framing and fade just inside their limits", function()
		expect(function()
			Fixtures.config({
				Camera = {
					framing = {
						{ pitchDeg = -70, distance = 30, height = 6 },
						{ pitchDeg = -69.99, distance = 0.01, height = -3 },
						{ pitchDeg = 60, distance = 1, height = 0 },
					},
					fade = { seen = 0.01, gone = 0 },
				},
			})
		end).never.toThrow()
		expect(function()
			Fixtures.config({ Camera = { framing = { { pitchDeg = 0, distance = 12, height = 5 } } } })
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

	it("accepts a kickoff count whose digit just fits inside its ring", function()
		-- 116 - 2 x 8 = 100: a 99 px digit fits.
		local countdown =
			Fixtures.config({ UI = { hud = { countdown = { textSize = 99, ringSize = 116 } } } }).UI.hud.countdown
		expect(countdown).toEqual({ textSize = 99, ringSize = 116, ringThickness = 8 })
	end)

	it("rejects HUD text and settings that contradict themselves", function()
		local cases: { { overrides: { [string]: any }, message: string } } = {
			-- A text takes exactly as many values as the HUD gives it.
			{
				overrides = { UI = { text = { goalWorth = "goal +%d" } } },
				message = "UI.text.goalWorth: placeholder count must be 2",
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
			{
				overrides = { UI = { controlLabels = { GetUp = "" } } },
				message = "UI.controlLabels.GetUp: must not be empty",
			},
			{
				overrides = { UI = { controlLabels = { AirPose = "" } } },
				message = "UI.controlLabels.AirPose: must not be empty",
			},
			{ overrides = { UI = { text = { touchMove = "" } } }, message = "UI.text.touchMove: must not be empty" },
			{ overrides = { UI = { text = { draw = "" } } }, message = "UI.text.draw: must not be empty" },
			{ overrides = { UI = { text = { go = "GO!" } } }, message = "UI.text.go: placeholder count must be 1" },
			{
				overrides = { UI = { hud = { countdown = { ringThickness = 0 } } } },
				message = "UI.hud.countdown.ringThickness: must be > 0",
			},
			-- Inside the ring's stroke, 116 - 2 x 8 leaves 100 px: a 100 px digit would touch it.
			{
				overrides = { UI = { hud = { countdown = { textSize = 100, ringSize = 116 } } } },
				message = "UI: the count's digit must fit inside its ring (textSize < ringSize - 2 × ringThickness)",
			},
			{
				overrides = { UI = { hud = { layout = { getUp = { size = UDim2.fromScale(0.5, 0.1) } } } } },
				message = "UI.hud.layout.getUp.size: must be in pixels (scales 0, offsets > 0)",
			},
			-- 12 px is all padding at the default spacing (6 px at the top and the bottom): no room for its keys.
			{
				overrides = { UI = { hud = { layout = { getUp = { size = UDim2.fromOffset(320, 12) } } } } },
				message = "UI: the Get Up prompt must be taller than its padding (2 × hud.spacing)",
			},
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
