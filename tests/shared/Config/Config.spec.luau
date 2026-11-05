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
		expect(Actions.names).toEqual({
			"Tackle",
			"Dive",
			"Dodge",
			"Uppercut",
			"ChargeThrow",
			"RollBall",
			"Pass",
			"CallPass",
		})
		expect(Actions.nameOf("Dive")).toBe("Dive")
		expect(Actions.nameOf("Fly")).toBeNil()
		expect(Actions.nameOf(nil)).toBeNil()
	end)

	-- What each effect carries (Net/Schemas) and does to the ball (ActionController): a throw and a roll leave the
	-- hands spending the charge (#312), a pass leaves them along the aim, the rest keep the ball where it is; only a
	-- throw comes down on the crosshair's spot (#313, Q148).
	it("says which effects let go of the ball, spend the charge and aim at the crosshair's spot", function()
		local releases, spends, spots = {}, {}, {}
		for _, effect: Actions.Effect in
			{ "Knockdown", "Dodge", "Throw", "Roll", "Pass", "CallPass" } :: { Actions.Effect }
		do
			releases[effect] = Actions.releasesBall(effect)
			spends[effect] = Actions.spendsCharge(effect)
			spots[effect] = Actions.aimsAtSpot(effect)
		end
		expect(spots).toEqual({
			Knockdown = false,
			Dodge = false,
			Throw = true,
			Roll = false,
			Pass = false,
			CallPass = false,
		})
		expect(releases).toEqual({
			Knockdown = false,
			Dodge = false,
			Throw = true,
			Roll = true,
			Pass = true,
			CallPass = false,
		})
		expect(spends).toEqual({
			Knockdown = false,
			Dodge = false,
			Throw = true,
			Roll = true,
			Pass = false,
			CallPass = false,
		})
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
		expect(m.teamSwitching).toBe(true)
	end)

	it("match the spec's ball and network values", function()
		local d = Config.defaults()
		-- The owner's trial #311 (Q121-Q133): a 2-stud ball carried low in the right hand, the magnet at 6 studs with
		-- a pull into the hand, 0.2 s since the smooth ball (Q139, #316).
		expect(d.Ball).toEqual({
			radius = 1,
			density = 0.7,
			friction = 0.3,
			elasticity = 0.5,
			pickupRadius = 6,
			pickupPullSeconds = 0.2,
			rethrowPickupDelay = 0.4,
			strandedSeconds = 5,
			restSpeed = 1,
			dropIn = { outerIn = 8, innerIn = 6, speed = 20, descent = 40, outerShare = 0.5 },
			outOfBoundsMargin = 2,
			carryOffset = Vector3.new(1.7, -0.8, -0.3),
			releaseClearance = 0.05,
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
			maxTeamSwitchesPerSecond = 1,
			-- #316: each screen draws the loose ball from the server's states (measured in a 2-player test).
			ballStream = { correctionSeconds = 0.08, snapStuds = 10, maxAgeSeconds = 0.3, restSeconds = 0.25 },
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
		local requires = function(ball: string, grounded: string?, charge: string?): any
			return { ball = ball, grounded = grounded or "any", charge = charge or "any", notKnockedDown = true }
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
			-- Only as a follow-up, a 0.3 s flight (#277, Q66), then on the belly at the first touch of the ground until
			-- the slide stops (#221, #240, #242): the Tackle's with empty hands, the Dodge's with the ball (#314).
			Dive = {
				phases = { windup = 0, active = 0.3, recovery = 0.9 },
				cooldown = 0.8,
				requires = requires("any"),
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
				-- Its key dives with the ball from 0.1 to 1.0 s after it (#314, Q102: RC's "Dive" row, Video 32).
				followUp = { action = "Dive", from = 0.1, to = 1 },
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
			-- Down too: through the carrier's own dive and slide, the one knockdown that keeps the ball (#314, Q154).
			ChargeThrow = {
				phases = { windup = 0, active = 0, recovery = 0 },
				cooldown = 0,
				requires = { ball = "with", grounded = "any", charge = "any", notKnockedDown = false },
				effect = "Throw",
				pose = "None",
				-- A full charge in 0.5 s (Q99, Q133), as RC's crosshair closes; faster after trial 150 (Q151), so a
				-- far spot takes a flatter arc; the crosshair's line runs 1000 studs looking for the spot (Q148); the
				-- throw is exact only as far as it flies in 0.8 s, then falls under it (#342, trial 342 kept, Q170).
				throw = {
					chargeMaxSeconds = 0.5,
					minSpeed = 90,
					maxSpeed = 240,
					inheritCarrierVelocity = 0.5,
					aimReach = 1000,
					exactSeconds = 0.8,
				},
			},
			-- The uppercut key while a throw charges, on a surface (#312, Q100): the charge spent along the floor.
			RollBall = {
				phases = { windup = 0, active = 0, recovery = 0 },
				cooldown = 0,
				requires = requires("with", "grounded", "charging"),
				effect = "Roll",
				pose = "None",
			},
			-- Never while a throw charges (Q140). Magnetic Pass (#315): a teammate within 70 deg of the aim and 120
			-- studs (Q105), at a steady 150 studs/s turning at most 300 studs/s^2 sideways, aimed 1.5 above the root
			-- and let go 0.8 above the hand (#346, the owner's trial: Q175, Q176).
			Pass = {
				phases = { windup = 0, active = 0, recovery = 0 },
				cooldown = 0,
				requires = requires("with", nil, "notCharging"),
				effect = "Pass",
				pose = "None",
				pass = {
					speed = 150,
					turnAccel = 300,
					aimHeight = 1.5,
					releaseHeight = 0.8,
					coneDeg = 70,
					maxRange = 120,
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
			-- Grown with the stride's top, so the top still comes in ~1.8 s (#328, Q161).
			strideAccel = 33,
			rollingFriction = 4,
			airDrag = 0.02,
			-- A tenth over #265's 46: 8.7 body lengths a second (#328, Q161-Q163).
			cruiseSpeed = 51,
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
			-- RC carries the ball low in the right hand, the arm down (Video 13 at 99.0 s; trial #311, Q130).
			carryArmDeg = 0,
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
		expect(input.switchTeam).toEqual({ Enum.KeyCode.T, Enum.KeyCode.DPadUp })
		expect(input.actions).toEqual({
			tackle = { "Dive", "Tackle", "Dodge" },
			uppercut = { "Uppercut", "RollBall" },
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
			-- Arrangement A, sized by use (#355, the owner's Q245, played in Q249): centres in pixels from the whole
			-- screen's bottom-right corner, sizes and words in pixels.
			buttons = {
				jump = { place = UDim2.new(1, -70, 1, -70), size = 96, textSize = 18 },
				throw = { place = UDim2.new(1, -163, 1, -53), size = 70, textSize = 16 },
				tackle = { place = UDim2.new(1, -150, 1, -132), size = 64, textSize = 15 },
				pump = { place = UDim2.new(1, -72, 1, -160), size = 64, textSize = 15 },
				pass = { place = UDim2.new(1, -225, 1, -133), size = 64, textSize = 13 },
				uppercut = { place = UDim2.new(1, -150, 1, -206), size = 64, textSize = 13 },
				brake = { place = UDim2.new(1, -235, 1, -59), size = 58, textSize = 14 },
				attach = { place = UDim2.new(1, -77, 1, -229), size = 50, textSize = 12 },
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
			-- RC's hints while a throw charges (#312; Video 32 at 3.2 s).
			RollBall = "Roll Ball",
			CancelDodge = "Cancel & Dodge",
			-- RC's name for it (#315, Q103; Video 34 at 41.6 s).
			Pass = "Magnetic Pass",
			CallPass = "Call",
			BallFocus = "Focus",
			GetUp = "GET UP!",
		})
		-- Roblox's own touch thumbstick colors; the buttons' fills as the owner played them (#355, Q249).
		expect(ui.touchStyle).toEqual({
			background = Color3.fromRGB(18, 18, 21),
			backgroundTransparency = 0.4,
			foreground = Color3.fromRGB(213, 215, 221),
			corner = UDim.new(0.5, 0),
			textPadding = 6,
			knobTransparency = 0,
			fill = { top = Color3.fromRGB(58, 69, 102), bottom = Color3.fromRGB(28, 35, 64) },
			jumpFill = { top = Color3.fromRGB(255, 178, 90), bottom = Color3.fromRGB(232, 116, 28) },
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
			-- The scoreboard's chip (#352, Q188).
			goalWorth = "+%d",
			overtime = "OVERTIME",
			goal = "GOAL!",
			denied = "DENIED!",
			clockWarning = "%d SECONDS",
			lastChance = "LAST CHANCE",
			-- Big digits over a small unit (#352, Q192).
			speed = "%d",
			speedUnit = "KM/H",
			possession = "%s has the ball",
			lapCompleted = "LAP %d COMPLETED",
			goalOpen = "%s GOAL IS ACTIVE!",
			scored = "%s scored!",
			wins = "%s WINS!",
			mvpLine = "Score %d \u{B7} Goals %d \u{B7} Steals %d",
			teamTotal = "%s %d",
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
			-- A down-pointing triangle: over a pass's target on touch, where no key letter fits (#315).
			touchPassTarget = "PASS",
			touchMove = "Move",
			switchTeam = "Switch team",
			-- A key cooling down shows its seconds left (#354, Q186), to a tenth as the page wrote them.
			cooldown = "%.1f",
			-- RC's >> beside a pressed key (#354, Q186), as the page drew it.
			pressMark = "\u{BB}",
		})
		expect(ui.hud).toEqual({
			font = Enum.Font.BuilderSansBold,
			textColor = Color3.fromRGB(245, 245, 245),
			panel = Color3.fromRGB(18, 18, 21),
			panelTransparency = 0.35,
			dimTransparency = 0.6,
			corner = UDim.new(0, 8),
			textSize = 20,
			titleSize = 32,
			bannerSeconds = { headline = 2.5, lap = 3.6, message = 5 },
			feedSeconds = 6,
			feedMaxEntries = 3,
			glowThickness = 3,
			spacing = 6,
			screenMargin = 8,
			-- Over the touch controls, so the open TAB board covers their buttons on a phone (#357, Q236), with the end
			-- screen's dim one under it and over them too (#358).
			displayOrder = 2,
			-- Each row's avatar on the TAB board (#357): Roblox's headshot of that user, 48 px square.
			avatarImage = "rbxthumb://type=AvatarHeadShot&id=%s&w=48&h=48",
			-- Look C, Bold arcade (#352, Q184), as the design page drew it.
			look = {
				font = Enum.Font.FredokaOne,
				bannerFont = Enum.Font.LuckiestGuy,
				bannerDigitRise = 0.16,
				ink = Color3.fromRGB(11, 14, 24),
				outline = 3,
				shadow = 4,
				textOutline = 2.5,
				corner = UDim.new(0, 14),
				box = Color3.fromRGB(42, 51, 80),
				shade = 0.4,
				-- The page's brighter pair, the HUD's own (Q201); the world keeps UI.teamColors.
				teamColors = { Blue = Color3.fromRGB(61, 139, 255), Orange = Color3.fromRGB(255, 154, 60) },
				-- The page's key caps (#354): yellow, orange while pressed, a 62% black sweep while cooling.
				key = Color3.fromRGB(255, 210, 63),
				pressed = Color3.fromRGB(255, 138, 44),
				sweepTransparency = 0.38,
				-- Probed on the phone emulator: 2 px keep a disc's sides whole (#355, Q254; #383).
				groupRoom = 2,
			},
			-- Every change animates briefly (#352, Q194): the page's pop, bounce, fill and glow.
			motion = {
				pop = { seconds = 0.2, overshoot = 0.12 },
				bounce = { seconds = 0.4, scale = 1.55, rebound = 0.9 },
				press = { seconds = 0.3, scale = 0.88, rebound = 1.06 },
				easeSeconds = 0.25,
				lapHoldSeconds = 0.5,
				glow = { seconds = 2.4, transparency = 0.8 },
				speedRate = 6,
			},
			layout = {
				-- Phones under it (#352): Roblox's own touch UI grows on screens whose shorter side passes 500 px.
				compactBelow = 500,
				-- S2 Shields on desktop, S5 Compact chips on phones (#352, Q196); the page's sizes.
				scoreboard = {
					position = UDim2.new(0.5, 0, 0, 8),
					shield = UDim2.fromOffset(94, 89),
					clock = UDim2.fromOffset(120, 56),
					worth = UDim2.fromOffset(56, 38),
					lapChip = 17,
					chipCorner = UDim.new(0, 7),
					gap = 12,
					chipGap = 6,
					-- The lap chips clear of the shield's drop shadow (the owner, Q200).
					chipClearance = 3,
					textSizes = { score = 55, clock = 41, worth = 26, period = 22 },
				},
				compactScoreboard = {
					position = UDim2.new(0.5, 0, 0, 8),
					score = UDim2.fromOffset(52, 44),
					clock = UDim2.fromOffset(80, 44),
					worth = UDim2.fromOffset(48, 34),
					gap = 8,
					textSizes = { score = 38, clock = 30, worth = 22, period = 18 },
				},
				-- One banner line a fifth of the way down, the goal message at the bottom, the feed above it (#356).
				banner = {
					height = 0.22,
					clearance = 3,
					bottom = 24,
					rise = 0.4,
					sizes = { headline = 50, goal = 67, lap = 36, message = 29, edge = 3 },
					compactSizes = { headline = 32, goal = 43, lap = 23, message = 18, edge = 2 },
				},
				feed = {
					clearance = 3,
					sizes = { height = 30, corner = UDim.new(0, 10), inset = 10, textSize = 18 },
					compactSizes = { height = 24, corner = UDim.new(0, 8), inset = 8, textSize = 15 },
				},
				-- Look C's rows (#354), at the page's sizes, the pressed key's mark outside them (Q195b).
				hints = {
					position = UDim2.new(1, -24, 0.5, 0),
					rowHeight = 41,
					clearance = 3,
					inset = { left = 5, right = 12 },
					gap = 11,
					textSize = 22,
					-- A mouse button's key drawn as a mouse (Q207: A1).
					cap = {
						height = 34,
						padding = 8,
						corner = UDim.new(0, 10),
						textSize = 17,
						mouse = { width = 16, height = 24, buttons = 10, line = 2 },
					},
					press = { textSize = 24, gap = 16 },
				},
				-- Bottom right on desktop, small top left on touch (#352, Q192).
				speedometer = {
					position = UDim2.new(1, -31, 1, -22),
					touchPosition = UDim2.fromOffset(18, 4),
					textSizes = { speed = 55, unit = 17 },
					compactTextSizes = { speed = 30, unit = 12 },
				},
				-- RC's crosshair (#312): 31.5% down (Q123/Q127), its charge ring 130 px across at 1918 x 1078 (Video
				-- 32), blinking every 0.4 s once closed (Q142); X1 (#353, Q188b): the carrying ring growing into it
				-- over the charge's first quarter, the page's phone sizes (Q203), 3 px clear of the scoreboard.
				reticle = {
					size = 6,
					height = 0.315,
					blinkSeconds = 0.4,
					growShare = 0.25,
					clearance = 3,
					sizes = { carry = 61, charge = 130, thickness = 4 },
					compactSizes = { carry = 24, charge = 46, thickness = 3 },
				},
				-- RC's count a third down (#353, Q185): its 200 px ring and 75 px digit (Q108); the page's phone sizes
				-- (Q203).
				countdown = {
					sizes = { textSize = 76, ringSize = 200, ringThickness = 8 },
					compactSizes = { textSize = 40, ringSize = 76, ringThickness = 4 },
				},
				-- One compact table on desktop and phones (#357, Q236, Q237) at the design page's sizes, a 3-a-side
				-- board fitting under a phone's SCORES button.
				scoreTab = {
					margin = 3,
					scrollBar = 6,
					sizes = {
						width = 800,
						side = 12,
						gap = 6,
						avatar = 27,
						column = 76,
						rowHeight = 38,
						textSize = 19,
						headHeight = 23,
						headSize = 14,
						barHeight = 31,
						barSize = 20,
						switchGap = 10,
						switchSize = 18,
					},
					compactSizes = {
						width = 610,
						side = 8,
						gap = 6,
						avatar = 21,
						column = 58,
						rowHeight = 27,
						textSize = 17,
						headHeight = 15,
						headSize = 11,
						barHeight = 25,
						barSize = 17,
						switchGap = 4,
						switchSize = 15,
					},
				},
				-- S2 (#355, the owner's Q250): 96 x 36 under Roblox's top bar, the page's 10 px outer corner.
				scoreButton = { top = 16, size = UDim2.fromOffset(96, 36), corner = UDim.new(0, 7), textSize = 17 },
				endScreen = {
					gap = 16,
					dim = 0.5,
					sizes = {
						cardWidth = 400,
						inset = 12,
						avatar = 44,
						nameSize = 21,
						statSize = 15,
						chipHeight = 24,
						chipSize = 14,
						totalHeight = 34,
						totalSize = 22,
					},
					compactSizes = {
						cardWidth = 350,
						inset = 10,
						avatar = 40,
						nameSize = 19,
						statSize = 14,
						chipHeight = 22,
						chipSize = 13,
						totalHeight = 28,
						totalSize = 17,
					},
				},
				getUp = {
					sizes = {
						bottom = 104,
						gap = 9,
						wordsGap = 15,
						textSize = 40,
						cap = { height = 46, padding = 11, corner = UDim.new(0, 13), textSize = 21, dropShadow = true },
					},
					compactSizes = {
						bottom = 72,
						gap = 6,
						wordsGap = 10,
						textSize = 28,
						cap = { height = 34, padding = 8, corner = UDim.new(0, 10), textSize = 17, dropShadow = true },
					},
				},
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
			studsOffset = Vector3.new(0, 4, 0),
			sizes = {
				width = 240,
				height = 184,
				pillHeight = 26,
				pillInset = 9,
				textSize = 18,
				cap = { height = 34, padding = 8, corner = UDim.new(0, 10), textSize = 17, dropShadow = false },
				pointer = 9,
				gap = 2,
				badge = 24,
				rim = 4,
				ripple = 20,
				rippleLine = 4,
				badgeGap = 3,
				glove = 1,
				gloveDrop = 3,
			},
			compactSizes = {
				width = 190,
				height = 140,
				pillHeight = 20,
				pillInset = 7,
				textSize = 14,
				cap = { height = 24, padding = 6, corner = UDim.new(0, 8), textSize = 13, dropShadow = false },
				pointer = 7,
				gap = 2,
				badge = 18,
				rim = 3,
				ripple = 15,
				rippleLine = 3,
				badgeGap = 2,
				glove = 0.76,
				gloveDrop = 2,
			},
			call = { rippleSeconds = 1, waveDegrees = 12, waveRate = 8, wavePivot = 10 },
			glove = {
				ink = 2.5,
				parts = {
					{ x = -9, y = -6, width = 18, height = 16, corner = 5, turn = 0 },
					{ x = -9, y = -15, width = 4.5, height = 12, corner = 2.25, turn = 0 },
					{ x = -4.5, y = -19, width = 4.5, height = 16, corner = 2.25, turn = 0 },
					{ x = 0, y = -18, width = 4.5, height = 15, corner = 2.25, turn = 0 },
					{ x = 4.5, y = -14, width = 4.5, height = 11, corner = 2.25, turn = 0 },
					{ x = -9, y = -2, width = 7, height = 12, corner = 3.5, turn = -4 },
					{ x = -9.6, y = -6, width = 5, height = 12, corner = 2.5, turn = -26 },
				},
				seams = {
					{ x = -4.95, y = -13, width = 0.9, height = 9, corner = 0.45, turn = 0 },
					{ x = -0.45, y = -16, width = 0.9, height = 12, corner = 0.45, turn = 0 },
					{ x = 4.05, y = -12, width = 0.9, height = 8, corner = 0.45, turn = 0 },
				},
			},
		})
		expect(ui.arenaGlow).toEqual({
			material = Enum.Material.Neon,
			panelSlide = 16,
			panelSlideSeconds = 0.4,
			beam = { width = 2, thickness = 0.5 },
		})
		-- The ball's trail (#313), bolder after the screenshots (Q146); the thrower's arc went (Q149).
		expect(ui.ballTrail).toEqual({ lifetime = 0.4, width = 2, color = Color3.new(1, 1, 1), transparency = 0 })
	end)

	it("match the spec's arena layout", function()
		local a = Config.defaults().Arena
		-- The owner (#329, Q164-Q165): only the straights grew, 200 -> 260; the curved ends kept their shape.
		expect(a.straightLength).toBe(260)
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
				-- Longer than a straight of 150, so the blends at its ends would overlap; within a curved end (188.5).
				overrides = { straightLength = 150, profileBlendLength = 160 },
				message = "Arena: profileBlendLength must fit within a straight and a curved end",
			},
			{
				-- Longer than a curved end (π · 60 = 188.5); within a straight of 240.
				overrides = { straightLength = 240, profileBlendLength = 200 },
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
	-- (+ 18) under the wall's 40; a bank of 61.9, leaving its bowl room before 80 − 18; blends as long as a straight
	-- of 150 and just shorter than a curved end (188.5).
	it("accepts arena shapes just inside the limits of the straights, the curved ends and the outer wall", function()
		local shapes: { { [string]: any } } = {
			{ straight = { riseEnd = 63.3 } },
			{ outerWallHeight = 34.2 },
			{ curvedEnd = { bowlHeight = 21.9 } },
			{ innerBankHeight = 61.9 },
			{ straightLength = 150, profileBlendLength = 150 },
			{ profileBlendLength = 188.4 },
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

	-- #345: a ball let go from a hand in the arena starts a hair off it, on the way out from a root that hovers clear
	-- of the floor.
	it("rejects a ball let go at no clearance, or one that cannot start clear under a hovering root", function()
		expect(function()
			Fixtures.config({ Ball = { releaseClearance = 0 } })
		end).toThrow("Ball.releaseClearance: must be > 0 (got 0)")
		expect(function()
			-- 1.5 + 1 reaches the hover's 2.5.
			Fixtures.config({ Ball = { radius = 1.5, releaseClearance = 1 } })
		end).toThrow(
			"Ball: a ball let go must start clear under a hovering root (radius + releaseClearance < "
				.. "Movement.hoverHeight)"
		)
	end)

	it("accepts a release clearance just inside its limits", function()
		expect(Fixtures.config({ Ball = { releaseClearance = 0.01 } }).Ball.releaseClearance).toBe(0.01)
		expect(Fixtures.config({ Ball = { releaseClearance = 1.49 } }).Ball.releaseClearance).toBe(1.49)
	end)

	-- The owner (Q91, Q132, Q139, #311, #316): a caught ball flies into the hand over 0.2 s on every screen.
	it("rejects a pull into the hand that takes negative time, and accepts none (a snap)", function()
		expect(function()
			Fixtures.config({ Ball = { pickupPullSeconds = -0.1 } })
		end).toThrow("Ball.pickupPullSeconds: must be >= 0 (got -0.1)")
		expect(Fixtures.config({ Ball = { pickupPullSeconds = 0 } }).Ball.pickupPullSeconds).toBe(0)
	end)

	-- #316 (Q101): the server's states of the loose ball and how each screen draws it between them.
	it("rejects ball stream settings outside their limits", function()
		local cases = {
			{ field = "correctionSeconds", value = 0 },
			{ field = "snapStuds", value = 0 },
			{ field = "maxAgeSeconds", value = 0 },
			{ field = "restSeconds", value = 0 },
		}
		for _, case in cases do
			expect(function()
				Fixtures.config({ Network = { ballStream = { [case.field] = case.value } } })
			end).toThrow(`Network.ballStream.{case.field}: must be > 0 (got 0)`)
		end
	end)

	it("accepts ball stream settings just inside their limits", function()
		local stream = Fixtures.config({
			Network = {
				ballStream = {
					correctionSeconds = 0.001,
					snapStuds = 0.001,
					maxAgeSeconds = 0.001,
					restSeconds = 0.001,
				},
			},
		}).Network.ballStream
		expect(stream).toEqual({
			correctionSeconds = 0.001,
			snapStuds = 0.001,
			maxAgeSeconds = 0.001,
			restSeconds = 0.001,
		})
	end)

	-- Magnetic Pass (#315, Q105): a caller in the cone first, else the teammate nearest the aim's line, so the old
	-- score's weights are gone.
	it("rejects the old pass score's weights as unknown", function()
		for _, key in { "angleWeight", "distanceWeight" } do
			expect(function()
				Fixtures.config({ Actions = { Pass = { pass = { [key] = 0.5 } } } })
			end).toThrow(`Actions.Pass.pass.{key}: unknown key`)
		end
	end)

	-- #346: a steady pass that turns after its receiver (turnAccel replaced homingAccel), aimed above their root
	-- and let go above the hand.
	it("rejects a pass with no speed, a negative turn, aim or release height, or the old homing", function()
		local function passWith(settings: { [string]: any }): () -> ()
			return function()
				Fixtures.config({ Actions = { Pass = { pass = settings } } })
			end
		end
		expect(passWith({ speed = 0 })).toThrow("Actions.Pass.pass.speed: must be > 0 (got 0)")
		expect(passWith({ turnAccel = -1 })).toThrow("Actions.Pass.pass.turnAccel: must be >= 0 (got -1)")
		expect(passWith({ aimHeight = -1 })).toThrow("Actions.Pass.pass.aimHeight: must be >= 0 (got -1)")
		expect(passWith({ releaseHeight = -1 })).toThrow("Actions.Pass.pass.releaseHeight: must be >= 0 (got -1)")
		expect(passWith({ homingAccel = 150 })).toThrow("Actions.Pass.pass.homingAccel: unknown key")
		-- Aimed as far above the root as the magnet reaches: a pass on its aim is never caught.
		expect(passWith({ aimHeight = Config.defaults().Ball.pickupRadius })).toThrow(
			"Actions: a Magnetic Pass must aim within the magnet's reach of its receiver's root "
				.. "(pass.aimHeight < Ball.pickupRadius)"
		)
	end)

	it("accepts a pass's turn, aim and release heights just inside their limits", function()
		local low =
			Fixtures.config({ Actions = { Pass = { pass = { turnAccel = 0, aimHeight = 0, releaseHeight = 0 } } } })
		local settings = low.Actions.Pass.pass :: Config.PassSettings
		expect(settings.turnAccel).toBe(0)
		expect(settings.aimHeight).toBe(0)
		expect(settings.releaseHeight).toBe(0)
		local reach = Config.defaults().Ball.pickupRadius
		local high = Fixtures.config({ Actions = { Pass = { pass = { aimHeight = reach - 0.01 } } } })
		expect((high.Actions.Pass.pass :: Config.PassSettings).aimHeight).toBe(reach - 0.01)
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
		-- Each line half the ball's radius from its face: the ball would start inside the glass.
		local inside = Config.defaults().Ball.radius / 2
		local cases: { { dropIn: { [string]: number }, message: string } } = {
			{ dropIn = { innerIn = inside }, message = clear },
			{ dropIn = { outerIn = inside }, message = clear },
			{ dropIn = { innerIn = 40, outerIn = 40 }, message = apart },
			{ dropIn = { descent = 0 }, message = "Ball.dropIn.descent: must be > 0 (got 0)" },
			{ dropIn = { speed = -1 }, message = "Ball.dropIn.speed: must be >= 0 (got -1)" },
			{ dropIn = { outerShare = -0.1 }, message = "Ball.dropIn.outerShare: must be >= 0 (got -0.1)" },
			{ dropIn = { outerShare = 1.1 }, message = "Ball.dropIn.outerShare: must be <= 1 (got 1.1)" },
		}
		for _, case in cases do
			expect(function()
				Fixtures.config({ Ball = { dropIn = case.dropIn } })
			end).toThrow(case.message)
		end
	end)

	it("accepts a drop just inside its limits", function()
		local inside = { innerIn = 1.5, outerIn = 78.4, speed = 0, descent = 0.01, outerShare = 1 }
		expect(Fixtures.config({ Ball = { dropIn = inside } }).Ball.dropIn).toEqual(inside)
		expect(Fixtures.config({ Ball = { dropIn = { outerShare = 0 } } }).Ball.dropIn.outerShare).toBe(0)
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
				overrides = { Movement = { climbSpeed = 51 } },
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
		local movement = Fixtures.config({ Movement = { climbSpeed = 50.9, climbAccel = 0.01 } }).Movement
		expect(movement.climbSpeed).toBe(50.9)
		expect(movement.climbAccel).toBe(0.01)
	end)

	it("accepts a crosshair's line just long enough to find a throw's spot", function()
		local actions = Fixtures.config({ Actions = { ChargeThrow = { throw = { aimReach = 0.01 } } } }).Actions
		expect((actions.ChargeThrow.throw :: Config.ThrowSettings).aimReach).toBe(0.01)
	end)

	it("accepts a throw exact for just a moment of its flight", function()
		local actions = Fixtures.config({ Actions = { ChargeThrow = { throw = { exactSeconds = 0.01 } } } }).Actions
		expect((actions.ChargeThrow.throw :: Config.ThrowSettings).exactSeconds).toBe(0.01)
	end)

	it("rejects actions that contradict themselves", function()
		local cases: { { overrides: { [string]: any }, message: string } } = {
			{
				overrides = { ChargeThrow = { throw = { maxSpeed = 50 } } },
				message = "Actions.ChargeThrow.throw: maxSpeed must be at least minSpeed",
			},
			-- The crosshair's line must run somewhere to find a throw's spot (#313).
			{
				overrides = { ChargeThrow = { throw = { aimReach = 0 } } },
				message = "Actions.ChargeThrow.throw.aimReach: must be > 0 (got 0)",
			},
			-- A throw is exact for some time of its flight before it falls under the crosshair (#342).
			{
				overrides = { ChargeThrow = { throw = { exactSeconds = 0 } } },
				message = "Actions.ChargeThrow.throw.exactSeconds: must be > 0 (got 0)",
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
			-- The Dodge's (#314), by the same rules.
			{
				overrides = { Dodge = { followUp = { action = "Dodge" } } },
				message = "Actions.Dodge.followUp.action: must name another action",
			},
			{
				overrides = { Uppercut = { followUp = { action = "Dive", from = 0, to = 1 } } },
				message = "Actions.Uppercut.followUp: unknown key",
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
			-- Whether a throw charges (#312): it must, it must not, or either.
			{
				overrides = { Pass = { requires = { charge = "sometimes" } } },
				message = 'Actions.Pass.requires.charge: must be one of charging, notCharging, any (got "sometimes")',
			},
			-- A roll spends ChargeThrow's own charge, at its speeds: one charge, one speed range.
			{
				overrides = {
					RollBall = {
						throw = {
							chargeMaxSeconds = 1,
							minSpeed = 1,
							maxSpeed = 2,
							inheritCarrierVelocity = 0,
							aimReach = 1,
							exactSeconds = 1,
						},
					},
				},
				message = "Actions.RollBall.throw: unknown key",
			},
			{
				overrides = { RollBall = { effect = "Throw" } },
				message = 'Actions.RollBall.effect: must be one of Roll (got "Throw")',
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

	-- The owner (Q97, Q117, Q120, #310).
	it("rejects a non-boolean switching flag, a switch key bound twice, and no switch requests", function()
		expect(function()
			Fixtures.config({ Match = { teamSwitching = "yes" } })
		end).toThrow("Match.teamSwitching: expected boolean, got string")
		expect(function()
			Fixtures.config({ Input = { switchTeam = { Enum.KeyCode.E } } })
		end).toThrow("Input: E is bound to more than one action")
		expect(function()
			Fixtures.config({ Network = { maxTeamSwitchesPerSecond = 0 } })
		end).toThrow("Network.maxTeamSwitchesPerSecond: must be > 0 (got 0)")
		expect(function()
			Fixtures.config({ UI = { text = { switchTeam = "" } } })
		end).toThrow("UI.text.switchTeam: must not be empty")
	end)

	it("accepts team switching settings just inside their limits", function()
		local config = Fixtures.config({
			Match = { teamSwitching = false },
			Input = { switchTeam = {} },
			Network = { maxTeamSwitchesPerSecond = 0.01 },
			UI = { text = { switchTeam = "S" } },
		})
		expect(config.Match.teamSwitching).toBe(false)
		expect(config.Input.switchTeam).toEqual({})
		expect(config.Network.maxTeamSwitchesPerSecond).toBe(0.01)
		expect(config.UI.text.switchTeam).toBe("S")
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
					Dodge = { followUp = { from = 0, to = 0.01 } },
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
			expect(config.Actions.Dodge.followUp).toEqual({ action = "Dive", from = 0, to = 0.01 })
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
			-- Throw (70 px) and Attach (50 px) moved clear of the rest: nearer than half of both sizes, 60 px, across
			-- (59 px apart) or down; their hit areas would overlap, whatever the faces' shape.
			{
				overrides = {
					Input = {
						touch = {
							buttons = {
								throw = { place = UDim2.new(1, -500, 1, -300) },
								attach = { place = UDim2.new(1, -559, 1, -300) },
							},
						},
					},
				},
				message = "Input.touch: buttons must not overlap",
			},
			{
				overrides = {
					Input = {
						touch = {
							buttons = {
								throw = { place = UDim2.new(1, -500, 1, -300) },
								attach = { place = UDim2.new(1, -500, 1, -359) },
							},
						},
					},
				},
				message = "Input.touch: buttons must not overlap",
			},
			-- Every pair, the first button's (Jump, 96 px) too: Attach 70 px above it, under half of both, 73.
			{
				overrides = {
					Input = {
						touch = {
							buttons = {
								jump = { place = UDim2.new(1, -500, 1, -300) },
								attach = { place = UDim2.new(1, -500, 1, -370) },
							},
						},
					},
				},
				message = "Input.touch: buttons must not overlap",
			},
			-- The buttons' reach (TouchArea) measures from the bottom-right corner.
			{
				overrides = { Input = { touch = { buttons = { jump = { place = UDim2.new(0.5, -50, 1, -70) } } } } },
				message = "Input.touch: buttons must sit at the bottom-right corner (scales 1, 1)",
			},
			{
				overrides = { Input = { touch = { buttons = { jump = { place = UDim2.new(1, -70, 0.5, -70) } } } } },
				message = "Input.touch: buttons must sit at the bottom-right corner (scales 1, 1)",
			},
			{
				overrides = { Input = { touch = { buttons = { jump = { size = 0 } } } } },
				message = "Input.touch.buttons.jump.size: must be >= 1 (got 0)",
			},
			-- Whole pixels: a UDim's offset would drop the half.
			{
				overrides = { Input = { touch = { buttons = { jump = { size = 96.5 } } } } },
				message = "Input.touch.buttons.jump.size: must be an integer (got 96.5)",
			},
			-- Roblox clamps text sizes to 1..100.
			{
				overrides = { Input = { touch = { buttons = { attach = { textSize = 0 } } } } },
				message = "Input.touch.buttons.attach.textSize: must be >= 1 (got 0)",
			},
			{
				overrides = { Input = { touch = { buttons = { attach = { textSize = 101 } } } } },
				message = "Input.touch.buttons.attach.textSize: must be <= 100 (got 101)",
			},
		}
		for _, case in cases do
			expect(function()
				Fixtures.config(case.overrides)
			end).toThrow(case.message)
		end
	end)

	-- Throw (70 px) and Attach (50 px) moved clear of the rest, half of both sizes apart (60 px) across, or 59 px
	-- across and 60 down: they touch, and neither covers the other.
	it("accepts touch buttons that just touch", function()
		for _, attach in { UDim2.new(1, -560, 1, -300), UDim2.new(1, -559, 1, -360) } do
			local buttons = {
				throw = { place = UDim2.new(1, -500, 1, -300) },
				attach = { place = attach },
			}
			local touch = Fixtures.config({ Input = { touch = { buttons = buttons } } }).Input.touch
			expect(touch.buttons.attach.place).toEqual(attach)
		end
	end)

	-- The X1 crosshair (#353) with a 2 px ink: a 50 px carrying ring with 2 px strokes leaves 50 - 2 x 2 - 4 x 2 = 38
	-- px between the inks, so a 37.9 px dot fits; the carrying ring a hair smaller than the charge ring.
	it("accepts a crosshair just inside its limits", function()
		local rings = { carry = 50, charge = 50.1, thickness = 2 }
		local inside = {
			size = 37.9,
			height = 0.999,
			blinkSeconds = 0.01,
			growShare = 1,
			clearance = 0,
			sizes = rings,
			compactSizes = rings,
		}
		local ui = Fixtures.config({ UI = { hud = { look = { textOutline = 2 }, layout = { reticle = inside } } } }).UI
		expect(ui.hud.layout.reticle).toEqual(inside)
		local top = Fixtures.config({ UI = { hud = { layout = { reticle = { height = 0.001, growShare = 0.001 } } } } })
		expect(top.UI.hud.layout.reticle.height).toBe(0.001)
		expect(top.UI.hud.layout.reticle.growShare).toBe(0.001)
	end)

	-- The ball's trail (#313).
	it("accepts a ball's trail just inside its limits", function()
		local trail = Fixtures.config({ UI = { ballTrail = { lifetime = 0.01, width = 0.01, transparency = 0.99 } } })
		expect(trail.UI.ballTrail).toEqual({
			lifetime = 0.01,
			width = 0.01,
			color = Color3.new(1, 1, 1),
			transparency = 0.99,
		})
	end)

	-- Magnetic Pass (#315): any single character marks a pass's target on touch.
	it("accepts a one-character mark over a pass's target on touch", function()
		expect(Fixtures.config({ UI = { text = { touchPassTarget = "v" } } }).UI.text.touchPassTarget).toBe("v")
	end)

	it("accepts banners at TextSize's cap with no team ring, on a line at the screen's top", function()
		-- TextSize holds at most 100; a 0 edge draws no team colour, a 0 rise fades in place.
		local sizes = { headline = 100, goal = 100, lap = 100, message = 100, edge = 0 }
		local banner = { height = 0.01, clearance = 0, bottom = 0, rise = 0, sizes = sizes, compactSizes = sizes }
		local seconds = { headline = 0.1, lap = 0.1, message = 0.1 }
		local hud = Fixtures.config({ UI = { hud = { bannerSeconds = seconds, layout = { banner = banner } } } }).UI.hud
		expect(hud.layout.banner).toEqual(banner)
		expect(hud.bannerSeconds).toEqual(seconds)
	end)

	it("accepts a kickoff count whose digit just fits inside its ring's ink", function()
		-- With a 2 px ink, 116 - 2 x (8 + 2) = 96: a 95 px digit fits, on either kind of screen.
		local count = { textSize = 95, ringSize = 116, ringThickness = 8 }
		local overrides =
			{ look = { textOutline = 2 }, layout = { countdown = { sizes = count, compactSizes = count } } }
		local countdown = Fixtures.config({ UI = { hud = overrides } }).UI.hud.layout.countdown
		expect(countdown).toEqual({ sizes = count, compactSizes = count })
	end)

	it("rejects HUD text and settings that contradict themselves", function()
		local tagRow = "UI: a name tag must hold its marks' row (the pill, gap, pointer and key cap; "
			.. "the badge's widest ripple, the pass key and the Attach mark)"
		local cases: { { overrides: { [string]: any }, message: string } } = {
			-- A text takes exactly as many values as the HUD gives it.
			{
				overrides = { UI = { text = { goalWorth = "Lap %d: +%d" } } },
				message = "UI.text.goalWorth: placeholder count must be 1",
			},
			{
				overrides = { UI = { text = { speed = "%d km/h at %d" } } },
				message = "UI.text.speed: placeholder count must be 1",
			},
			-- The end screen's: the MVP's score, goals and steals; a team's name and score (#358).
			{
				overrides = { UI = { text = { mvpLine = "Score %d \u{B7} Goals %d" } } },
				message = "UI.text.mvpLine: placeholder count must be 3",
			},
			{
				overrides = { UI = { text = { teamTotal = "%s" } } },
				message = "UI.text.teamTotal: placeholder count must be 2",
			},
			{ overrides = { UI = { text = { speedUnit = "" } } }, message = "UI.text.speedUnit: must not be empty" },
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
			{
				overrides = { UI = { markers = { arrowImage = "" } } },
				message = "UI.markers.arrowImage: must not be empty",
			},
			{
				overrides = { UI = { hud = { layout = { endScreen = { sizes = { cardWidth = 0 } } } } } },
				message = "UI.hud.layout.endScreen.sizes.cardWidth: must be >= 1 (got 0)",
			},
			-- The end screen's sizes in whole pixels (its boxes on pixel edges), its text sizes as every text's.
			{
				overrides = { UI = { hud = { layout = { endScreen = { gap = 16.5 } } } } },
				message = "UI.hud.layout.endScreen.gap: must be an integer (got 16.5)",
			},
			{
				overrides = { UI = { hud = { layout = { endScreen = { dim = 1.5 } } } } },
				message = "UI.hud.layout.endScreen.dim: must be <= 1 (got 1.5)",
			},
			{
				overrides = { UI = { hud = { layout = { endScreen = { sizes = { inset = 2.5 } } } } } },
				message = "UI.hud.layout.endScreen.sizes.inset: must be an integer (got 2.5)",
			},
			{
				overrides = { UI = { hud = { layout = { endScreen = { sizes = { nameSize = 20.5 } } } } } },
				message = "UI.hud.layout.endScreen.sizes.nameSize: must be an integer (got 20.5)",
			},
			{
				overrides = { UI = { hud = { layout = { endScreen = { sizes = { statSize = 101 } } } } } },
				message = "UI.hud.layout.endScreen.sizes.statSize: must be <= 100 (got 101)",
			},
			{
				overrides = { UI = { hud = { layout = { endScreen = { compactSizes = { chipHeight = 0 } } } } } },
				message = "UI.hud.layout.endScreen.compactSizes.chipHeight: must be >= 1 (got 0)",
			},
			{
				overrides = { UI = { hud = { layout = { endScreen = { compactSizes = { chipSize = 0 } } } } } },
				message = "UI.hud.layout.endScreen.compactSizes.chipSize: must be >= 1 (got 0)",
			},
			{
				overrides = { UI = { hud = { layout = { endScreen = { sizes = { totalHeight = 33.5 } } } } } },
				message = "UI.hud.layout.endScreen.sizes.totalHeight: must be an integer (got 33.5)",
			},
			{
				overrides = { UI = { hud = { layout = { endScreen = { compactSizes = { totalSize = 0 } } } } } },
				message = "UI.hud.layout.endScreen.compactSizes.totalSize: must be >= 1 (got 0)",
			},
			{
				overrides = { UI = { hud = { layout = { scoreTab = { sizes = { column = 0 } } } } } },
				message = "UI.hud.layout.scoreTab.sizes.column: must be >= 1 (got 0)",
			},
			-- The old graybox tab's place and table (#357 rebuilt it).
			{
				overrides = { UI = { hud = { layout = { scoreTab = { rowHeight = 28 } } } } },
				message = "UI.hud.layout.scoreTab.rowHeight: unknown key",
			},
			{
				overrides = { UI = { hud = { layout = { scoreTab = { compactSizes = { textSize = 101 } } } } } },
				message = "UI.hud.layout.scoreTab.compactSizes.textSize: must be <= 100",
			},
			-- Whole pixels: a UDim's offset drops a fraction, which would open seams between rows.
			{
				overrides = { UI = { hud = { layout = { scoreTab = { compactSizes = { rowHeight = 27.5 } } } } } },
				message = "UI.hud.layout.scoreTab.compactSizes.rowHeight: must be an integer (got 27.5)",
			},
			{
				overrides = { UI = { hud = { layout = { scoreTab = { margin = -1 } } } } },
				message = "UI.hud.layout.scoreTab.margin: must be >= 0",
			},
			{
				overrides = { UI = { hud = { layout = { scoreTab = { scrollBar = -1 } } } } },
				message = "UI.hud.layout.scoreTab.scrollBar: must be >= 0",
			},
			-- ScrollBarThickness holds whole pixels.
			{
				overrides = { UI = { hud = { layout = { scoreTab = { scrollBar = 6.5 } } } } },
				message = "UI.hud.layout.scoreTab.scrollBar: must be an integer (got 6.5)",
			},
			-- With the dim level with the touch controls, which draws on top would be left to the engine.
			{ overrides = { UI = { hud = { displayOrder = 1 } } }, message = "UI.hud.displayOrder: must be >= 2" },
			{
				overrides = { UI = { hud = { displayOrder = 2.5 } } },
				message = "UI.hud.displayOrder: must be an integer (got 2.5)",
			},
			{
				overrides = { UI = { hud = { avatarImage = "rbxthumb://type=AvatarHeadShot&w=48&h=48" } } },
				message = "UI.hud.avatarImage: placeholder count must be 1",
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
			-- The ball's trail (#313): some time long, some width, seen.
			{
				overrides = { UI = { ballTrail = { lifetime = 0 } } },
				message = "UI.ballTrail.lifetime: must be > 0 (got 0)",
			},
			{
				overrides = { UI = { ballTrail = { width = 0 } } },
				message = "UI.ballTrail.width: must be > 0 (got 0)",
			},
			{
				overrides = { UI = { ballTrail = { transparency = 1 } } },
				message = "UI.ballTrail.transparency: must be < 1 (got 1)",
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
			{
				overrides = { UI = { text = { touchPassTarget = "" } } },
				message = "UI.text.touchPassTarget: must not be empty",
			},
			{ overrides = { UI = { text = { draw = "" } } }, message = "UI.text.draw: must not be empty" },
			{ overrides = { UI = { text = { go = "GO!" } } }, message = "UI.text.go: placeholder count must be 1" },
			{
				overrides = { UI = { hud = { layout = { countdown = { sizes = { ringThickness = 0 } } } } } },
				message = "UI.hud.layout.countdown.sizes.ringThickness: must be > 0 (got 0)",
			},
			{
				overrides = { UI = { hud = { layout = { countdown = { compactSizes = { ringSize = 0 } } } } } },
				message = "UI.hud.layout.countdown.compactSizes.ringSize: must be > 0 (got 0)",
			},
			-- Inside the ring's ink, with a 2 px ink 116 - 2 x (8 + 2) leaves 96 px: a 96 px digit would touch it,
			-- on a desktop's screen or a phone's.
			{
				overrides = {
					UI = {
						hud = {
							look = { textOutline = 2 },
							layout = { countdown = { sizes = { textSize = 96, ringSize = 116, ringThickness = 8 } } },
						},
					},
				},
				message = "UI: the count's digit must fit inside its ring's ink "
					.. "(textSize < ringSize - 2 × (ringThickness + look.textOutline))",
			},
			{
				overrides = {
					UI = {
						hud = {
							look = { textOutline = 2 },
							layout = {
								countdown = { compactSizes = { textSize = 96, ringSize = 116, ringThickness = 8 } },
							},
						},
					},
				},
				message = "UI: the count's digit must fit inside its ring's ink "
					.. "(textSize < ringSize - 2 × (ringThickness + look.textOutline))",
			},
			-- The Get Up prompt (#369): a place, text sizes Roblox draws, caps that show, a real drop-shadow switch.
			{
				overrides = { UI = { hud = { layout = { getUp = { sizes = { bottom = -1 } } } } } },
				message = "UI.hud.layout.getUp.sizes.bottom: must be >= 0 (got -1)",
			},
			{
				overrides = { UI = { hud = { layout = { getUp = { compactSizes = { textSize = 101 } } } } } },
				message = "UI.hud.layout.getUp.compactSizes.textSize: must be <= 100 (got 101)",
			},
			{
				overrides = { UI = { hud = { layout = { getUp = { sizes = { cap = { height = 0 } } } } } } },
				message = "UI.hud.layout.getUp.sizes.cap.height: must be > 0 (got 0)",
			},
			{
				overrides = { UI = { hud = { layout = { getUp = { sizes = { wordsGap = -1 } } } } } },
				message = "UI.hud.layout.getUp.sizes.wordsGap: must be >= 0 (got -1)",
			},
			{
				overrides = { UI = { hud = { layout = { getUp = { compactSizes = { gap = -1 } } } } } },
				message = "UI.hud.layout.getUp.compactSizes.gap: must be >= 0 (got -1)",
			},
			{
				overrides = { UI = { hud = { layout = { getUp = { size = UDim2.fromOffset(320, 40) } } } } },
				message = "UI.hud.layout.getUp.size: unknown key",
			},
			-- The feed's chips (#369): sized in real numbers, and with no team edge (the owner, Q226).
			{
				overrides = { UI = { hud = { layout = { feed = { sizes = { edge = 8 } } } } } },
				message = "UI.hud.layout.feed.sizes.edge: unknown key",
			},
			{
				overrides = { UI = { hud = { layout = { feed = { compactSizes = { height = 0 } } } } } },
				message = "UI.hud.layout.feed.compactSizes.height: must be > 0 (got 0)",
			},
			{
				overrides = { UI = { hud = { layout = { feed = { clearance = -1 } } } } },
				message = "UI.hud.layout.feed.clearance: must be >= 0 (got -1)",
			},
			{
				overrides = { UI = { hud = { layout = { feed = { size = UDim2.fromOffset(460, 140) } } } } },
				message = "UI.hud.layout.feed.size: unknown key",
			},
			-- The banners (#356): a line on the screen, text sizes Roblox draws, an edge, a rise inside the
			-- banner's own height, and each one shown for some time. The feed's place follows the goal message.
			{
				overrides = { UI = { hud = { layout = { banner = { height = 0 } } } } },
				message = "UI.hud.layout.banner.height: must be > 0 (got 0)",
			},
			{
				overrides = { UI = { hud = { layout = { banner = { height = 1 } } } } },
				message = "UI.hud.layout.banner.height: must be < 1 (got 1)",
			},
			{
				overrides = { UI = { hud = { layout = { banner = { clearance = -1 } } } } },
				message = "UI.hud.layout.banner.clearance: must be >= 0 (got -1)",
			},
			{
				overrides = { UI = { hud = { layout = { banner = { bottom = -1 } } } } },
				message = "UI.hud.layout.banner.bottom: must be >= 0 (got -1)",
			},
			{
				overrides = { UI = { hud = { layout = { banner = { rise = 1.5 } } } } },
				message = "UI.hud.layout.banner.rise: must be <= 1 (got 1.5)",
			},
			{
				overrides = { UI = { hud = { layout = { banner = { rise = -0.1 } } } } },
				message = "UI.hud.layout.banner.rise: must be >= 0 (got -0.1)",
			},
			{
				overrides = { UI = { hud = { layout = { banner = { sizes = { goal = 101 } } } } } },
				message = "UI.hud.layout.banner.sizes.goal: must be <= 100 (got 101)",
			},
			{
				overrides = { UI = { hud = { layout = { banner = { compactSizes = { message = 0 } } } } } },
				message = "UI.hud.layout.banner.compactSizes.message: must be >= 1 (got 0)",
			},
			{
				overrides = { UI = { hud = { layout = { banner = { compactSizes = { edge = -1 } } } } } },
				message = "UI.hud.layout.banner.compactSizes.edge: must be >= 0 (got -1)",
			},
			{
				overrides = { UI = { hud = { bannerSeconds = { lap = 0 } } } },
				message = "UI.hud.bannerSeconds.lap: must be > 0 (got 0)",
			},
			{
				overrides = { UI = { hud = { bannerSeconds = { message = 0 } } } },
				message = "UI.hud.bannerSeconds.message: must be > 0 (got 0)",
			},
			{
				overrides = { UI = { hud = { layout = { feed = { position = UDim2.new(0.5, 0, 1, -24) } } } } },
				message = "UI.hud.layout.feed.position: unknown key",
			},
			{
				overrides = { UI = { hud = { layout = { endScreen = { compactSizes = { avatar = 40.5 } } } } } },
				message = "UI.hud.layout.endScreen.compactSizes.avatar: must be an integer (got 40.5)",
			},
			-- RC's crosshair (#312, #353): on the screen, rings that hold their dot, the carrying ring growing into the
			-- charge ring, a blink that takes some time.
			{
				overrides = { UI = { hud = { layout = { reticle = { height = 0 } } } } },
				message = "UI.hud.layout.reticle.height: must be > 0 (got 0)",
			},
			{
				overrides = { UI = { hud = { layout = { reticle = { height = 1 } } } } },
				message = "UI.hud.layout.reticle.height: must be < 1 (got 1)",
			},
			{
				overrides = { UI = { hud = { layout = { reticle = { sizes = { thickness = 0 } } } } } },
				message = "UI.hud.layout.reticle.sizes.thickness: must be > 0 (got 0)",
			},
			{
				overrides = { UI = { hud = { layout = { reticle = { compactSizes = { carry = 0 } } } } } },
				message = "UI.hud.layout.reticle.compactSizes.carry: must be > 0 (got 0)",
			},
			{
				overrides = { UI = { hud = { layout = { reticle = { growShare = 0 } } } } },
				message = "UI.hud.layout.reticle.growShare: must be > 0 (got 0)",
			},
			{
				overrides = { UI = { hud = { layout = { reticle = { growShare = 1.01 } } } } },
				message = "UI.hud.layout.reticle.growShare: must be <= 1 (got 1.01)",
			},
			{
				overrides = { UI = { hud = { layout = { reticle = { clearance = -1 } } } } },
				message = "UI.hud.layout.reticle.clearance: must be >= 0 (got -1)",
			},
			{
				overrides = { UI = { hud = { layout = { reticle = { blinkSeconds = 0 } } } } },
				message = "UI.hud.layout.reticle.blinkSeconds: must be > 0 (got 0)",
			},
			-- With a 2 px ink, a 30 px carrying ring with 2 px strokes leaves 30 - 2 x 2 - 4 x 2 = 18 px between the
			-- inks: an 18 px dot would touch the phone's (the desktop's 61 px ring would hold it).
			{
				overrides = {
					UI = {
						hud = {
							look = { textOutline = 2 },
							layout = {
								reticle = { size = 18, compactSizes = { carry = 30, charge = 40, thickness = 2 } },
							},
						},
					},
				},
				message = "UI: the reticle's dot must fit inside each carrying ring's ink "
					.. "(size < carry - 2 × thickness - 4 × look.textOutline)",
			},
			-- The same 18 px dot would touch a desktop's 30 px carrying ring (a phone's 40 px ring holds it: 40 - 2 x 2
			-- - 4 x 2 = 28 px between the inks).
			{
				overrides = {
					UI = {
						hud = {
							look = { textOutline = 2 },
							layout = {
								reticle = {
									size = 18,
									sizes = { carry = 30, charge = 130, thickness = 2 },
									compactSizes = { carry = 40, charge = 46, thickness = 2 },
								},
							},
						},
					},
				},
				message = "UI: the reticle's dot must fit inside each carrying ring's ink "
					.. "(size < carry - 2 × thickness - 4 × look.textOutline)",
			},
			{
				overrides = { UI = { hud = { layout = { reticle = { sizes = { carry = 130, charge = 130 } } } } } },
				message = "UI: the reticle's carrying ring must be smaller than its charge ring (carry < charge)",
			},
			{
				overrides = { UI = { hud = { layout = { reticle = { compactSizes = { carry = 47 } } } } } },
				message = "UI: the reticle's carrying ring must be smaller than its charge ring (carry < charge)",
			},
			-- The end screen's words taller than their chips (#358): a 25 px MVP word on a 24 px chip; a 29 px total in
			-- its 2 x 3 px of ink over a 34 px chip.
			{
				overrides = { UI = { hud = { layout = { endScreen = { sizes = { chipSize = 25 } } } } } },
				message = "UI: the end screen's words must fit their chips (chipSize <= chipHeight, "
					.. "totalSize + 2 \u{D7} textOutline <= totalHeight)",
			},
			{
				overrides = { UI = { hud = { layout = { endScreen = { sizes = { totalSize = 29 } } } } } },
				message = "UI: the end screen's words must fit their chips (chipSize <= chipHeight, "
					.. "totalSize + 2 \u{D7} textOutline <= totalHeight)",
			},
			-- On a phone: a 23 px MVP word on its 22 px chip; the MVP's 24 px name, its 3 px of ink and their 14 px
			-- numbers, 41 px beside a 40 px avatar.
			{
				overrides = { UI = { hud = { layout = { endScreen = { compactSizes = { chipSize = 23 } } } } } },
				message = "UI: the end screen's words must fit their chips (chipSize <= chipHeight, "
					.. "totalSize + 2 \u{D7} textOutline <= totalHeight)",
			},
			{
				overrides = { UI = { hud = { layout = { endScreen = { compactSizes = { nameSize = 24 } } } } } },
				message = "UI: the end screen's card must hold its name over its numbers beside the avatar "
					.. "(nameSize + textOutline + statSize <= avatar)",
			},
			-- The name tags (#358): whole pixels where their boxes meet, a glove of parts, a call that moves.
			{
				overrides = { UI = { nameTag = { sizes = { pillHeight = 25.5 } } } },
				message = "UI.nameTag.sizes.pillHeight: must be an integer (got 25.5)",
			},
			{
				overrides = { UI = { nameTag = { compactSizes = { cap = { textSize = 0 } } } } },
				message = "UI.nameTag.compactSizes.cap.textSize: must be >= 1 (got 0)",
			},
			{
				overrides = { UI = { nameTag = { sizes = { glove = 0 } } } },
				message = "UI.nameTag.sizes.glove: must be > 0 (got 0)",
			},
			{
				overrides = { UI = { nameTag = { compactSizes = { pointer = 6.5 } } } },
				message = "UI.nameTag.compactSizes.pointer: must be an integer (got 6.5)",
			},
			{
				overrides = { UI = { nameTag = { call = { rippleSeconds = 0 } } } },
				message = "UI.nameTag.call.rippleSeconds: must be > 0 (got 0)",
			},
			{
				overrides = { UI = { nameTag = { glove = { parts = {} } } } },
				message = "UI.nameTag.glove.parts: must not be empty",
			},
			{
				overrides = { UI = { nameTag = { sizes = { width = 2.5 } } } },
				message = "UI.nameTag.sizes.width: must be an integer (got 2.5)",
			},
			{
				overrides = { UI = { nameTag = { sizes = { height = 2.5 } } } },
				message = "UI.nameTag.sizes.height: must be an integer (got 2.5)",
			},
			{
				overrides = { UI = { nameTag = { compactSizes = { pillInset = 2.5 } } } },
				message = "UI.nameTag.compactSizes.pillInset: must be an integer (got 2.5)",
			},
			{
				overrides = { UI = { nameTag = { sizes = { textSize = 2.5 } } } },
				message = "UI.nameTag.sizes.textSize: must be an integer (got 2.5)",
			},
			{
				overrides = { UI = { nameTag = { sizes = { gap = 2.5 } } } },
				message = "UI.nameTag.sizes.gap: must be an integer (got 2.5)",
			},
			{
				overrides = { UI = { nameTag = { sizes = { badge = 2.5 } } } },
				message = "UI.nameTag.sizes.badge: must be an integer (got 2.5)",
			},
			{
				overrides = { UI = { nameTag = { compactSizes = { rim = 2.5 } } } },
				message = "UI.nameTag.compactSizes.rim: must be an integer (got 2.5)",
			},
			{
				overrides = { UI = { nameTag = { sizes = { ripple = 2.5 } } } },
				message = "UI.nameTag.sizes.ripple: must be an integer (got 2.5)",
			},
			{
				overrides = { UI = { nameTag = { sizes = { rippleLine = 0 } } } },
				message = "UI.nameTag.sizes.rippleLine: must be > 0 (got 0)",
			},
			{
				overrides = { UI = { nameTag = { compactSizes = { badgeGap = 2.5 } } } },
				message = "UI.nameTag.compactSizes.badgeGap: must be an integer (got 2.5)",
			},
			{
				overrides = { UI = { nameTag = { sizes = { gloveDrop = -1 } } } },
				message = "UI.nameTag.sizes.gloveDrop: must be >= 0 (got -1)",
			},
			{
				overrides = { UI = { nameTag = { sizes = { cap = { padding = -1 } } } } },
				message = "UI.nameTag.sizes.cap.padding: must be >= 0 (got -1)",
			},
			{
				overrides = { UI = { nameTag = { call = { waveDegrees = -1 } } } },
				message = "UI.nameTag.call.waveDegrees: must be >= 0 (got -1)",
			},
			{
				overrides = { UI = { nameTag = { call = { waveRate = -1 } } } },
				message = "UI.nameTag.call.waveRate: must be >= 0 (got -1)",
			},
			{
				overrides = { UI = { nameTag = { glove = { ink = -1 } } } },
				message = "UI.nameTag.glove.ink: must be >= 0 (got -1)",
			},
			{
				overrides = {
					UI = {
						nameTag = {
							glove = { parts = { { x = 0, y = 0, width = 0, height = 1, corner = 0, turn = 0 } } },
						},
					},
				},
				message = "UI.nameTag.glove.parts[1].width: must be > 0 (got 0)",
			},
			{
				overrides = {
					UI = {
						nameTag = {
							glove = { parts = { { x = 0, y = 0, width = 1, height = 0, corner = 0, turn = 0 } } },
						},
					},
				},
				message = "UI.nameTag.glove.parts[1].height: must be > 0 (got 0)",
			},
			{
				overrides = {
					UI = {
						nameTag = {
							glove = { parts = { { x = 0, y = 0, width = 1, height = 1, corner = -1, turn = 0 } } },
						},
					},
				},
				message = "UI.nameTag.glove.parts[1].corner: must be >= 0 (got -1)",
			},
			-- The name's 21 px and its 2 x 3 px of ink in a 26 px pill; on a phone 15 + 6 in 20.
			{
				overrides = { UI = { nameTag = { sizes = { textSize = 21 } } } },
				message = "UI: a name tag's name must fit its pill (textSize + 2 \u{D7} textOutline <= pillHeight)",
			},
			{
				overrides = { UI = { nameTag = { compactSizes = { textSize = 15 } } } },
				message = "UI: a name tag's name must fit its pill (textSize + 2 \u{D7} textOutline <= pillHeight)",
			},
			-- The marks' row reaching 92 px above the tag's middle (13 + 3 + 2 + 9 + 17, then the badge's 24 + 20 + 4)
			-- in a 182 px tag; on a phone 70 (10 + 3 + 2 + 7 + 12, 18 + 15 + 3) in 138.
			{ overrides = { UI = { nameTag = { sizes = { height = 182 } } } }, message = tagRow },
			{ overrides = { UI = { nameTag = { compactSizes = { height = 138 } } } }, message = tagRow },
			-- Across (#381), the widest row round its words: the badge in its rim (2 x 28), 3, a square key cap
			-- (34), 3, the Attach mark's square cap, inked edge and padding (34 + 3 + 2 x 8) is 149 px, with the
			-- ring's 20 px past the rim each side 189, in a 188 px tag; on a phone 42 + 2 + 24 + 2 + (24 + 3 + 2 x 6)
			-- = 109 and 2 x 15, 139 in 138. With no ripple and look C's ink 2.25 px (the key's edge its whole 3), the
			-- Attach mark's ink past each end reaches 149 + 2 x 2.25 = 153.5 of 153.
			{ overrides = { UI = { nameTag = { sizes = { width = 188 } } } }, message = tagRow },
			{ overrides = { UI = { nameTag = { compactSizes = { width = 138 } } } }, message = tagRow },
			{
				overrides = {
					UI = {
						hud = { look = { textOutline = 2.25 } },
						nameTag = { sizes = { width = 153, ripple = 0, rippleLine = 1 } },
					},
				},
				message = tagRow,
			},
			-- A tall cap with a small badge: 13 + 3 + 2 + 9 + 50 = 77 px to the cap's middle and its 50 px top half,
			-- 127 of the 92 px over the tag's middle, where the ring's 2 px would pass.
			{
				overrides = {
					UI = { nameTag = { sizes = { cap = { height = 100 }, badge = 1, ripple = 0, rippleLine = 1 } } },
				},
				message = tagRow,
			},
			-- The MVP's name (27 px) and its 3 px of ink over their numbers (15 px): 45 px beside a 44 px avatar.
			{
				overrides = { UI = { hud = { layout = { endScreen = { sizes = { nameSize = 27 } } } } } },
				message = "UI: the end screen's card must hold its name over its numbers beside the avatar "
					.. "(nameSize + textOutline + statSize <= avatar)",
			},
			-- The TAB board (#357), each leaving its names no room at all: on a phone 2 x 8 + (21 + 2 x 3) + 6 x 6 + 5
			-- x 106 = 609 px of its 609; on desktop 2 x 12 + (27 + 2 x 3) + 6 x 6 + 5 x 76 = 473 of its 473.
			{
				overrides = {
					UI = { hud = { layout = { scoreTab = { compactSizes = { column = 106, width = 609 } } } } },
				},
				message = "UI: the TAB board's number columns must leave room for names, on either kind of screen",
			},
			{
				overrides = { UI = { hud = { layout = { scoreTab = { sizes = { width = 473 } } } } } },
				message = "UI: the TAB board's number columns must leave room for names, on either kind of screen",
			},
			-- An avatar ringed in look C's 2.5 px ink is 27 + 5 = 32 px, a row 31; a phone's bar text 17 + 5 = 22 over
			-- the bar's ink line, 24 - 3 = 21 left; a 14 px header in 13.
			{
				overrides = { UI = { hud = { layout = { scoreTab = { sizes = { rowHeight = 31 } } } } } },
				message = "UI: a TAB board's rows, header and bars must hold what they show",
			},
			{
				overrides = { UI = { hud = { layout = { scoreTab = { compactSizes = { textSize = 23 } } } } } },
				message = "UI: a TAB board's rows, header and bars must hold what they show",
			},
			{
				overrides = { UI = { hud = { layout = { scoreTab = { compactSizes = { barHeight = 24 } } } } } },
				message = "UI: a TAB board's rows, header and bars must hold what they show",
			},
			{
				overrides = { UI = { hud = { layout = { scoreTab = { sizes = { headHeight = 13 } } } } } },
				message = "UI: a TAB board's rows, header and bars must hold what they show",
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

	-- Look C, its motion and the S2/S5 scoreboards (#352).
	it("rejects look C, motion and scoreboard settings outside their limits", function()
		local function hud(values: { [string]: any }): { [string]: any }
			return { UI = { hud = values } }
		end
		local cases: { { overrides: { [string]: any }, message: string } } = {
			{
				overrides = hud({ look = { bannerFont = "LuckiestGuy" } }),
				message = 'UI.hud.look.bannerFont: must be a Font (got "LuckiestGuy")',
			},
			{ overrides = hud({ look = { outline = -1 } }), message = "UI.hud.look.outline: must be >= 0 (got -1)" },
			{ overrides = hud({ look = { shadow = -1 } }), message = "UI.hud.look.shadow: must be >= 0 (got -1)" },
			{
				overrides = hud({ look = { textOutline = -1 } }),
				message = "UI.hud.look.textOutline: must be >= 0 (got -1)",
			},
			-- Past half its size a digit's middle would sit above its whole line.
			{
				overrides = hud({ look = { bannerDigitRise = -0.01 } }),
				message = "UI.hud.look.bannerDigitRise: must be >= 0 (got -0.01)",
			},
			{
				overrides = hud({ look = { bannerDigitRise = 0.51 } }),
				message = "UI.hud.look.bannerDigitRise: must be <= 0.5 (got 0.51)",
			},
			-- A box as dark at its bottom as the ink would lose its colour there.
			{ overrides = hud({ look = { shade = 1 } }), message = "UI.hud.look.shade: must be < 1 (got 1)" },
			{ overrides = hud({ look = { shade = -0.1 } }), message = "UI.hud.look.shade: must be >= 0 (got -0.1)" },
			{
				overrides = hud({ look = { teamColors = { Orange = "orange" } } }),
				message = "UI.hud.look.teamColors.Orange: expected Color3, got string",
			},
			{
				overrides = hud({ motion = { pop = { seconds = 0 } } }),
				message = "UI.hud.motion.pop.seconds: must be > 0 (got 0)",
			},
			{
				overrides = hud({ motion = { pop = { overshoot = -0.1 } } }),
				message = "UI.hud.motion.pop.overshoot: must be >= 0 (got -0.1)",
			},
			-- A bounce grows, then comes back past its size to a smaller one that still shows.
			{
				overrides = hud({ motion = { bounce = { scale = 0.9 } } }),
				message = "UI.hud.motion.bounce.scale: must be >= 1 (got 0.9)",
			},
			{
				overrides = hud({ motion = { bounce = { rebound = 0 } } }),
				message = "UI.hud.motion.bounce.rebound: must be > 0 (got 0)",
			},
			{
				overrides = hud({ motion = { bounce = { rebound = 1.1 } } }),
				message = "UI.hud.motion.bounce.rebound: must be <= 1 (got 1.1)",
			},
			-- A pressed key goes in no bigger than its size, then springs back to no smaller (#354).
			{
				overrides = hud({ motion = { press = { seconds = 0 } } }),
				message = "UI.hud.motion.press.seconds: must be > 0 (got 0)",
			},
			{
				overrides = hud({ motion = { press = { scale = 0 } } }),
				message = "UI.hud.motion.press.scale: must be > 0 (got 0)",
			},
			{
				overrides = hud({ motion = { press = { scale = 1.1 } } }),
				message = "UI.hud.motion.press.scale: must be <= 1 (got 1.1)",
			},
			{
				overrides = hud({ motion = { press = { rebound = 0.9 } } }),
				message = "UI.hud.motion.press.rebound: must be >= 1 (got 0.9)",
			},
			{
				overrides = hud({ motion = { easeSeconds = 0 } }),
				message = "UI.hud.motion.easeSeconds: must be > 0 (got 0)",
			},
			{
				overrides = hud({ motion = { lapHoldSeconds = -1 } }),
				message = "UI.hud.motion.lapHoldSeconds: must be >= 0 (got -1)",
			},
			{
				overrides = hud({ motion = { glow = { transparency = 2 } } }),
				message = "UI.hud.motion.glow.transparency: must be <= 1 (got 2)",
			},
			{
				overrides = hud({ motion = { speedRate = 0 } }),
				message = "UI.hud.motion.speedRate: must be > 0 (got 0)",
			},
			{
				overrides = hud({ layout = { compactBelow = 0 } }),
				message = "UI.hud.layout.compactBelow: must be > 0 (got 0)",
			},
			{
				overrides = hud({ layout = { scoreboard = { shield = UDim2.fromScale(0.1, 0.1) } } }),
				message = "UI.hud.layout.scoreboard.shield: must be in pixels (scales 0, offsets > 0)",
			},
			{
				overrides = hud({ layout = { scoreboard = { lapChip = 0 } } }),
				message = "UI.hud.layout.scoreboard.lapChip: must be > 0 (got 0)",
			},
			{
				overrides = hud({ layout = { scoreboard = { chipGap = -1 } } }),
				message = "UI.hud.layout.scoreboard.chipGap: must be >= 0 (got -1)",
			},
			{
				overrides = hud({ layout = { scoreboard = { chipClearance = -1 } } }),
				message = "UI.hud.layout.scoreboard.chipClearance: must be >= 0 (got -1)",
			},
			-- Roblox clamps text sizes to 1..100 (measured).
			{
				overrides = hud({ layout = { scoreboard = { textSizes = { score = 101 } } } }),
				message = "UI.hud.layout.scoreboard.textSizes.score: must be <= 100 (got 101)",
			},
			{
				overrides = hud({ layout = { compactScoreboard = { gap = -1 } } }),
				message = "UI.hud.layout.compactScoreboard.gap: must be >= 0 (got -1)",
			},
			{
				overrides = hud({ layout = { compactScoreboard = { worth = UDim2.fromOffset(0, 34) } } }),
				message = "UI.hud.layout.compactScoreboard.worth: must be in pixels (scales 0, offsets > 0)",
			},
			{
				overrides = hud({ layout = { speedometer = { compactTextSizes = { unit = 0 } } } }),
				message = "UI.hud.layout.speedometer.compactTextSizes.unit: must be >= 1 (got 0)",
			},
			-- A 57 px clock in the 56 px clock box, a 39 px worth in the 38 px chip; a 45 px score in the phone's
			-- 44 px score chip.
			{
				overrides = hud({ layout = { scoreboard = { textSizes = { clock = 57 } } } }),
				message = "UI: the desktop scoreboard's texts must fit their boxes (text size <= box height)",
			},
			{
				overrides = hud({ layout = { scoreboard = { textSizes = { worth = 39 } } } }),
				message = "UI: the desktop scoreboard's texts must fit their boxes (text size <= box height)",
			},
			{
				overrides = hud({ layout = { compactScoreboard = { textSizes = { score = 45 } } } }),
				message = "UI: the phone scoreboard's texts must fit their boxes (text size <= box height)",
			},
		}
		for _, case in cases do
			expect(function()
				Fixtures.config(case.overrides)
			end).toThrow(case.message)
		end
	end)

	it("accepts look C, motion and the scoreboards just inside their limits", function()
		local hud = Fixtures.config({
			UI = {
				hud = {
					look = { outline = 0, shadow = 0, textOutline = 0, shade = 0.99, bannerDigitRise = 0 },
					motion = {
						pop = { seconds = 0.01, overshoot = 0 },
						bounce = { seconds = 0.01, scale = 1, rebound = 0.01 },
						press = { seconds = 0.01, scale = 0.01, rebound = 1 },
						easeSeconds = 0.01,
						lapHoldSeconds = 0,
						glow = { seconds = 0.01, transparency = 0 },
						speedRate = 0.01,
					},
					layout = {
						compactBelow = 0.01,
						-- Each text exactly as tall as its box.
						scoreboard = {
							lapChip = 0.01,
							gap = 0,
							chipGap = 0,
							chipClearance = 0,
							textSizes = { score = 89, clock = 56 },
						},
						compactScoreboard = { gap = 0, textSizes = { score = 44, clock = 44, worth = 34 } },
					},
				},
			},
		}).UI.hud
		expect(hud.look.shade).toBe(0.99)
		expect(hud.motion.bounce).toEqual({ seconds = 0.01, scale = 1, rebound = 0.01 })
		expect(hud.motion.press).toEqual({ seconds = 0.01, scale = 0.01, rebound = 1 })
		local still = Fixtures.config({ UI = { hud = { motion = { press = { scale = 1 } } } } }).UI.hud.motion
		expect(still.press.scale).toBe(1)
		expect(hud.motion.glow.transparency).toBe(0)
		expect(hud.layout.scoreboard.textSizes).toEqual({ score = 89, clock = 56, worth = 26, period = 22 })
		expect(hud.layout.compactScoreboard.textSizes).toEqual({ score = 44, clock = 44, worth = 34, period = 18 })
		expect(hud.layout.compactBelow).toBe(0.01)
		expect(hud.layout.scoreboard.chipClearance).toBe(0)
		expect(hud.look.bannerDigitRise).toBe(0)
		local halfway = Fixtures.config({ UI = { hud = { look = { bannerDigitRise = 0.5 } } } }).UI.hud.look
		expect(halfway.bannerDigitRise).toBe(0.5)
	end)

	-- The desktop hints in look C (#354): the page's key caps, its rows and the pressed key's mark (Q186, Q195b).
	it("rejects the hints' look C settings outside their limits", function()
		local function hud(values: { [string]: any }): { [string]: any }
			return { UI = { hud = values } }
		end
		local function hints(values: { [string]: any }): { [string]: any }
			return hud({ layout = { hints = values } })
		end
		local fit = "UI: a hint's key cap and label must fit its row (cap.height and textSize <= rowHeight, "
			.. "cap.textSize <= cap.height)"
		local mouseFit = "UI: a hint cap's mouse must fit its cap in its ink, the line under its buttons on its "
			.. "straight sides (height + 2 × line <= cap.height, width / 2 + line / 2 <= buttons <= "
			.. "height - width / 2 - line / 2)"
		local cases: { { overrides: { [string]: any }, message: string } } = {
			{
				overrides = hud({ look = { key = "yellow" } }),
				message = "UI.hud.look.key: expected Color3, got string",
			},
			{
				overrides = hud({ look = { pressed = 1 } }),
				message = "UI.hud.look.pressed: expected Color3, got number",
			},
			-- A sweep as see-through as nothing would not show the cooldown.
			{
				overrides = hud({ look = { sweepTransparency = 1 } }),
				message = "UI.hud.look.sweepTransparency: must be < 1 (got 1)",
			},
			{
				overrides = hud({ look = { sweepTransparency = -0.1 } }),
				message = "UI.hud.look.sweepTransparency: must be >= 0 (got -0.1)",
			},
			{ overrides = hints({ rowHeight = 0 }), message = "UI.hud.layout.hints.rowHeight: must be > 0 (got 0)" },
			{ overrides = hints({ clearance = -1 }), message = "UI.hud.layout.hints.clearance: must be >= 0 (got -1)" },
			{
				overrides = hints({ inset = { left = -1 } }),
				message = "UI.hud.layout.hints.inset.left: must be >= 0 (got -1)",
			},
			{
				overrides = hints({ inset = { right = -1 } }),
				message = "UI.hud.layout.hints.inset.right: must be >= 0 (got -1)",
			},
			{ overrides = hints({ gap = -1 }), message = "UI.hud.layout.hints.gap: must be >= 0 (got -1)" },
			-- Roblox clamps text sizes to 1..100 (measured).
			{ overrides = hints({ textSize = 0 }), message = "UI.hud.layout.hints.textSize: must be >= 1 (got 0)" },
			{
				overrides = hints({ cap = { height = 0 } }),
				message = "UI.hud.layout.hints.cap.height: must be > 0 (got 0)",
			},
			{
				overrides = hints({ cap = { padding = -1 } }),
				message = "UI.hud.layout.hints.cap.padding: must be >= 0 (got -1)",
			},
			{
				overrides = hints({ cap = { corner = 10 } }),
				message = "UI.hud.layout.hints.cap.corner: expected UDim, got number",
			},
			{
				overrides = hints({ cap = { textSize = 101 } }),
				message = "UI.hud.layout.hints.cap.textSize: must be <= 100 (got 101)",
			},
			{
				overrides = hints({ press = { textSize = 0 } }),
				message = "UI.hud.layout.hints.press.textSize: must be >= 1 (got 0)",
			},
			{
				overrides = hints({ press = { gap = -1 } }),
				message = "UI.hud.layout.hints.press.gap: must be >= 0 (got -1)",
			},
			-- A 42 px cap or label in a 41 px row; an 35 px key name on a 34 px cap.
			{ overrides = hints({ cap = { height = 42 } }), message = fit },
			{ overrides = hints({ textSize = 42 }), message = fit },
			{ overrides = hints({ cap = { textSize = 35 } }), message = fit },
			-- A mouse's sizes in whole pixels (a UDim's offset drops a fraction).
			{
				overrides = hints({ cap = { mouse = { width = 0 } } }),
				message = "UI.hud.layout.hints.cap.mouse.width: must be >= 1 (got 0)",
			},
			{
				overrides = hints({ cap = { mouse = { height = 24.5 } } }),
				message = "UI.hud.layout.hints.cap.mouse.height: must be an integer (got 24.5)",
			},
			{
				overrides = hints({ cap = { mouse = { buttons = 0 } } }),
				message = "UI.hud.layout.hints.cap.mouse.buttons: must be >= 1 (got 0)",
			},
			{
				overrides = hints({ cap = { mouse = { line = 0 } } }),
				message = "UI.hud.layout.hints.cap.mouse.line: must be >= 1 (got 0)",
			},
			-- A 31 px mouse in its 2 px ink on a 34 px cap; the line under its buttons on the 16 px body's round top
			-- (8 - 1 < 8) or round bottom (16 + 1 > 24 - 8).
			{ overrides = hints({ cap = { mouse = { height = 31 } } }), message = mouseFit },
			{ overrides = hints({ cap = { mouse = { buttons = 8 } } }), message = mouseFit },
			{ overrides = hints({ cap = { mouse = { buttons = 16 } } }), message = mouseFit },
			-- The seconds left take one number, to a tenth by default; the mark shows.
			{
				overrides = { UI = { text = { cooldown = "%.1f of %.1f" } } },
				message = "UI.text.cooldown: placeholder count must be 1",
			},
			{ overrides = { UI = { text = { pressMark = "" } } }, message = "UI.text.pressMark: must not be empty" },
			-- The column's rows size themselves: the old fixed size has no reader.
			{
				overrides = hints({ size = UDim2.fromOffset(220, 300) }),
				message = "UI.hud.layout.hints.size: unknown key",
			},
		}
		for _, case in cases do
			expect(function()
				Fixtures.config(case.overrides)
			end).toThrow(case.message)
		end
	end)

	it("accepts the hints' look C settings just inside their limits", function()
		local config = Fixtures.config({
			UI = {
				hud = {
					look = { sweepTransparency = 0 },
					layout = {
						-- The cap, its name and the label exactly as tall as the row.
						hints = {
							rowHeight = 41,
							clearance = 0,
							inset = { left = 0, right = 0 },
							gap = 0,
							textSize = 41,
							-- A mouse as tall as the cap leaves in its ink, its buttons' line just under its round top.
							cap = {
								height = 41,
								padding = 0,
								textSize = 41,
								mouse = { width = 20, height = 37, buttons = 11, line = 2 },
							},
							press = { textSize = 1, gap = 0 },
						},
					},
				},
				text = { cooldown = "%5.2fs" },
			},
		})
		local hints = config.UI.hud.layout.hints
		expect(hints.cap).toEqual({
			height = 41,
			padding = 0,
			corner = UDim.new(0, 10),
			textSize = 41,
			mouse = { width = 20, height = 37, buttons = 11, line = 2 },
		})
		-- The default 16 x 24 mouse with its buttons' line just over its round bottom (15 + 1 = 24 - 8).
		local low = Fixtures.config({ UI = { hud = { layout = { hints = { cap = { mouse = { buttons = 15 } } } } } } })
		expect((low.UI.hud.layout.hints.cap.mouse :: Config.MouseSizes).buttons).toBe(15)
		expect(hints.textSize).toBe(41)
		expect(hints.clearance).toBe(0)
		expect(hints.press).toEqual({ textSize = 1, gap = 0 })
		expect(config.UI.hud.look.sweepTransparency).toBe(0)
		expect(config.UI.text.cooldown).toBe("%5.2fs")
	end)

	-- The name tags (#358): their defaults already stand at the row's edge (92 px in a 184 px tag, 70 in 140);
	-- the names at the pill's edge: 20 + 2 x 3 = 26, a phone's 14 + 6 = 20; the widest row round its words with the
	-- ring each side (#381) 189 across 189, a phone's 139 across 139; with no ripple and 2.25 px of ink, 153.5 in 154.
	it("accepts name tag sizes just inside their limits", function()
		local config = Fixtures.config({
			UI = {
				nameTag = { sizes = { textSize = 20, width = 189 }, compactSizes = { textSize = 14, width = 139 } },
			},
		})
		local tag = config.UI.nameTag
		expect(`{tag.sizes.textSize} {tag.sizes.width} {tag.compactSizes.textSize} {tag.compactSizes.width}`).toBe(
			"20 189 14 139"
		)
		local still = Fixtures.config({
			UI = {
				hud = { look = { textOutline = 2.25 } },
				nameTag = { sizes = { width = 154, ripple = 0, rippleLine = 1 } },
			},
		})
		expect(still.UI.nameTag.sizes.width).toBe(154)
		-- Nothing between its parts, a still call, one square glove part with no seams.
		local bare = Fixtures.config({
			UI = {
				nameTag = {
					sizes = {
						pillInset = 0,
						gap = 0,
						rim = 0,
						ripple = 0,
						badgeGap = 0,
						gloveDrop = 0,
						cap = { padding = 0 },
					},
					call = { waveDegrees = 0, waveRate = 0 },
					glove = {
						ink = 0,
						parts = { { x = 0, y = 0, width = 1, height = 1, corner = 0, turn = 0 } },
						seams = {},
					},
				},
			},
		}).UI.nameTag
		expect(bare.sizes.pillInset + bare.sizes.gap + bare.sizes.rim + bare.sizes.ripple).toBe(0)
		expect(bare.sizes.badgeGap + bare.sizes.gloveDrop + bare.sizes.cap.padding).toBe(0)
		expect(bare.call.waveDegrees + bare.call.waveRate + bare.glove.ink).toBe(0)
		expect(#bare.glove.seams).toBe(0)
	end)

	-- The end screen (#358): a 24 px MVP word on its 24 px chip; a 28 px total in its 2 x 3 px of ink, 34; the
	-- MVP's 26 px name, its 3 px of ink and their 15 px numbers beside the 44 px avatar.
	it("accepts end screen sizes just inside their limits", function()
		local sizes = { chipSize = 24, totalSize = 28, nameSize = 26, inset = 0 }
		local config =
			Fixtures.config({ UI = { hud = { layout = { endScreen = { gap = 0, dim = 1, sizes = sizes } } } } })
		local endScreen = config.UI.hud.layout.endScreen
		expect(endScreen.gap).toBe(0)
		expect(endScreen.dim).toBe(1)
		for key, value in sizes do
			expect(`{key} = {(endScreen.sizes :: any)[key]}`).toBe(`{key} = {value}`)
		end
	end)

	-- The TAB board (#357) at each room rule's edge: names one pixel wide, an avatar's and the text's ink as tall as a
	-- row, the header's text as tall as it, a bar's text and ink just above its ink line.
	it("accepts TAB board sizes just inside their limits", function()
		-- Desktop: 2 x 12 + (27 + 2 x 3) + 6 x 6 + 5 x 76 = 473, one pixel short of 474. A 27 px avatar or text and
		-- their 2.5 px ink in a 32 px row; 20 + 5 = 25 px over a 28 + 3 px bar's ink line.
		local sizes = { width = 474, rowHeight = 32, textSize = 27, headHeight = 14, barHeight = 28, switchGap = 0 }
		-- The phone: 2 x 8 + (21 + 2 x 3) + 6 x 6 + 5 x 106 = 609, one short of 610; 21 + 5 = 26 and 17 + 5 = 22 + 3.
		local compactSizes = { column = 106, rowHeight = 26, textSize = 21, headHeight = 11, barHeight = 25 }
		local overrides = { margin = 0, scrollBar = 0, sizes = sizes, compactSizes = compactSizes }
		local config = Fixtures.config({ UI = { hud = { layout = { scoreTab = overrides } } } })
		local tab = config.UI.hud.layout.scoreTab
		expect(tab.margin).toBe(0)
		expect(tab.scrollBar).toBe(0)
		for key, value in sizes do
			expect(`{key} = {(tab.sizes :: any)[key]}`).toBe(`{key} = {value}`)
		end
		for key, value in compactSizes do
			expect(`{key} = {(tab.compactSizes :: any)[key]}`).toBe(`{key} = {value}`)
		end
	end)

	it("rejects the old lap text, score pips and speedometer size as unknown", function()
		expect(function()
			Fixtures.config({ UI = { text = { lap = "Lap %d" } } })
		end).toThrow("UI.text.lap: unknown key")
		expect(function()
			Fixtures.config({ UI = { hud = { pipSize = 10 } } })
		end).toThrow("UI.hud.pipSize: unknown key")
		expect(function()
			Fixtures.config({ UI = { hud = { layout = { speedometer = { size = UDim2.fromOffset(160, 40) } } } } })
		end).toThrow("UI.hud.layout.speedometer.size: unknown key")
	end)

	-- #355: each touch button has its own size and words; their font is look C's; SCORES sits by its top and the
	-- buttons' edge.
	it("rejects the old touch button size, label font and score button place as unknown", function()
		expect(function()
			Fixtures.config({ Input = { touch = { buttonSize = UDim2.fromOffset(72, 72) } } })
		end).toThrow("Input.touch.buttonSize: unknown key")
		expect(function()
			Fixtures.config({ UI = { touchStyle = { font = Enum.Font.BuilderSansBold } } })
		end).toThrow("UI.touchStyle.font: unknown key")
		expect(function()
			Fixtures.config({ UI = { touchStyle = { textSize = 18 } } })
		end).toThrow("UI.touchStyle.textSize: unknown key")
		expect(function()
			Fixtures.config({ UI = { hud = { layout = { scoreButton = { position = UDim2.new(1, -16, 0, 16) } } } } })
		end).toThrow("UI.hud.layout.scoreButton.position: unknown key")
	end)

	it("rejects touch fills, a fading group's room and a score button outside their limits", function()
		local cases: { { overrides: { [string]: any }, message: string } } = {
			{
				overrides = { UI = { touchStyle = { fill = { top = "#3a4566" } } } },
				message = "UI.touchStyle.fill.top: expected Color3, got string",
			},
			{
				overrides = { UI = { touchStyle = { jumpFill = { bottom = 1 } } } },
				message = "UI.touchStyle.jumpFill.bottom: expected Color3, got number",
			},
			{
				overrides = { UI = { hud = { look = { groupRoom = 0 } } } },
				message = "UI.hud.look.groupRoom: must be >= 1 (got 0)",
			},
			{
				overrides = { UI = { hud = { look = { groupRoom = 1.5 } } } },
				message = "UI.hud.look.groupRoom: must be an integer (got 1.5)",
			},
			{
				overrides = { UI = { hud = { layout = { scoreButton = { top = -1 } } } } },
				message = "UI.hud.layout.scoreButton.top: must be >= 0 (got -1)",
			},
			{
				overrides = { UI = { hud = { layout = { scoreButton = { size = UDim2.fromScale(0.1, 0.1) } } } } },
				message = "UI.hud.layout.scoreButton.size: must be in pixels (scales 0, offsets > 0)",
			},
			{
				overrides = { UI = { hud = { layout = { scoreButton = { corner = 7 } } } } },
				message = "UI.hud.layout.scoreButton.corner: expected UDim, got number",
			},
			{
				overrides = { UI = { hud = { layout = { scoreButton = { textSize = 0 } } } } },
				message = "UI.hud.layout.scoreButton.textSize: must be >= 1 (got 0)",
			},
		}
		for _, case in cases do
			expect(function()
				Fixtures.config(case.overrides)
			end).toThrow(case.message)
		end
		local place = Fixtures.config({ UI = { hud = { layout = { scoreButton = { top = 0 } } } } }).UI.hud.layout
		expect(place.scoreButton.top).toBe(0)
		expect(Fixtures.config({ UI = { hud = { look = { groupRoom = 1 } } } }).UI.hud.look.groupRoom).toBe(1)
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
