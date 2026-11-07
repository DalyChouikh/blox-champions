--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local ActionController = require(Client.ActionController)
local ArenaParts = require(Client.ArenaParts)
local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local BallCarrier = require(Client.BallCarrier)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local InputController = require(Client.InputController)
local RideSurfaces = require(Client.RideSurfaces)
local SkateController = require(Client.SkateController)
local SkaterBody = require(ServerScriptService.Server.SkaterBody)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)
local Vectors = require(ReplicatedStorage.Shared.Util.Vectors)

local config = Config.defaults()
local movement = config.Movement
-- A root standing on the floor.
local HOVER = movement.hoverHeight
-- The Tackle's Dive (#240).
local FOLLOW_UP = config.Actions.Tackle.followUp :: Config.FollowUp
-- The line a diver facing -Z flies along (#241): fallLineDeg below the facing.
local FALL_LINE = Vector3.new(0, -math.sin(math.rad(movement.fallLineDeg)), -math.cos(math.rad(movement.fallLineDeg)))
local DT = 1 / 60
-- One charge, ChargeThrow's: a roll spends it too (#312).
local THROW = config.Actions.ChargeThrow.throw :: Config.ThrowSettings
-- Magnetic Pass (#315): its cone and range.
local PASS = config.Actions.Pass.pass :: Config.PassSettings
-- Where the camera's ray through the crosshair goes: above its look, unlike any of its own axes.
local AIM = Vector3.new(0, 0.26, -0.97).Unit
-- Looking toward -Z from behind the skater, so the skater's right is the camera's right, +X.
local CAMERA = Fixtures.camera(CFrame.lookAt(Vector3.new(0, 5, 10), Vector3.new(0, 5, 0)), AIM)
local LOCAL_ID = "1"
-- The other skaters the skating sees (SkateController's views), reset before each test.
local others: { any } = {}
-- The arena's parts as ArenaParts holds them: only the goal ring's opening matters here (#313; the skating's goal
-- tunnel too, #423), none until a test hangs one.
local arenaParts: ArenaParts.Goal = { parts = nil }

local folder: Folder
-- Roblox's menu: opening it pauses the controls.
local menu: Fixtures.Menu
local rig: Model
local requests: { { [string]: any } }
local bindings: { [string]: InputBinding }

local function bindingOf(name: string): InputBinding
	local existing: InputBinding? = bindings[name]
	if existing then
		return existing
	end
	local binding = Fixtures.scriptedBinding(InputController.context, name)
	bindings[name] = binding
	return binding
end

local function press(name: string)
	local binding = bindingOf(name)
	binding:Fire(true)
	task.wait() -- Pressed is deferred
	binding:Fire(false)
end

local function skater(): any
	return SkateController.skater
end

-- Puts the skater high above the floor, flying at `velocity`, facing -Z.
local function flying(velocity: Vector3)
	rig:PivotTo(CFrame.new(0, 60, 0))
	skater().mode = "Airborne"
	skater().velocity = velocity
	skater().forward = -Vector3.zAxis
end

-- A wall across the way ahead, its near face 59.5 studs ahead of the camera along -Z (#313: what a throw's spot meets).
local function wallAhead(): BasePart
	local wall = Instance.new("Part")
	wall.Anchored = true
	wall.Size = Vector3.new(400, 400, 1)
	wall.CFrame = CFrame.new(0, 0, -50)
	return wall
end

-- A pane standing on the floor 20 studs ahead along -Z, 4 studs wide and taller than any skater (#315 Q155: what hides
-- a teammate from a pass, as the middle glass does).
local function paneAhead(): BasePart
	local pane = Instance.new("Part")
	pane.Anchored = true
	pane.Size = Vector3.new(4, 20, 0.5)
	pane.CFrame = CFrame.new(0, 10, -20)
	return pane
end

-- The controllers over a floor, on a skater facing -Z. `surfaces` become ride surfaces too, before the rays read them.
local function setup(surfaces: { BasePart }?)
	local floor = Instance.new("Part")
	floor.Anchored = true
	floor.Size = Vector3.new(400, 1, 400)
	floor.CFrame = CFrame.new(0, -0.5, 0)
	floor.Parent = folder
	floor:AddTag(Tags.RideSurface)
	local extra: { BasePart } = surfaces or {}
	for _, surface in extra do
		surface.Parent = folder
		surface:AddTag(Tags.RideSurface)
	end
	menu = Fixtures.menu()
	InputController:init({ Config = config, Parent = folder, GuiService = menu })
	BallCarrier:init({})
	RideSurfaces:init({})
	SkateController:init({
		Config = config,
		InputController = InputController,
		RideSurfaces = RideSurfaces,
		SmoothNormal = Fixtures.faceNormal,
		Camera = CAMERA,
		Skaters = function(): { any }
			return others
		end,
		SendSkateState = function() end,
		Team = function(): string?
			return "Blue"
		end,
		ArenaParts = arenaParts,
	})
	rig = Fixtures.rig(folder, "Skater", CFrame.new(0, movement.hoverHeight, 0))
	SkaterBody.build(rig, movement)
	SkateController:bind(rig)
	ActionController:init({
		Config = config,
		InputController = InputController,
		BallCarrier = BallCarrier,
		SkateController = SkateController,
		RideSurfaces = RideSurfaces,
		ArenaParts = arenaParts,
		Camera = CAMERA,
		SendRequest = function(payload: { [string]: any })
			table.insert(requests, payload)
		end,
		LocalId = LOCAL_ID,
	})
end

-- Another skater standing at `position` (an Orange opponent unless `team` says otherwise): a character with a
-- root, as the skating's views show the other players.
local function standing(name: string, position: Vector3, team: string?): Model
	local view, character = Fixtures.otherSkater(folder, name, position, team or "Orange")
	table.insert(others, view)
	return character
end

-- Moves `character` 14 studs from the skater, `degrees` to the right of the way `from` points.
local function aside(character: Model, from: Vector3, degrees: number)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Position = rig:GetPivot().Position + CFrame.Angles(0, -math.rad(degrees), 0):VectorToWorldSpace(from) * 14
end

-- The skater's facing and way across the ground, as unit vectors.
local function across(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z).Unit
end

-- One physics step as the game runs it: the skating first, then the actions.
local function frame()
	SkateController:step(DT)
	ActionController:step(DT)
end

-- Only the actions' step: the skater's velocity is then only what the pushes made it.
local function actionsOnly()
	ActionController:step(DT)
end

-- Steps `step` past the start of `window` (the Tackle's follow-up window by default), two frames in.
local function intoWindow(step: () -> (), window: Config.FollowUp?)
	for _ = 1, math.floor((window or FOLLOW_UP).from / DT) + 2 do
		step()
	end
end

-- Roller Champions' tackle key (#240): a press tackles, or with the ball dodges (#314), and a second one in that
-- action's follow-up window dives.
local function dive(step: () -> ())
	local source: Config.ActionName = if BallCarrier.carrier == LOCAL_ID then "Dodge" else "Tackle"
	press("Tackle")
	step()
	intoWindow(step, config.Actions[source].followUp :: Config.FollowUp)
	press("Tackle")
	step()
end

-- The local player holds the ball and the throw key, charging for `frames` steps (#312).
local function charging(frames: number): InputBinding
	BallCarrier:set(LOCAL_ID)
	frame() -- the throw key seen up while holding the ball
	local throw = bindingOf("Throw")
	throw:Fire(true)
	for _ = 1, frames do
		frame()
	end
	return throw
end

-- What each action key would start now, by key ("none" for nothing).
local function names(): { [string]: string }
	local found: { [string]: string } = {}
	for _, key: Config.ActionKey in { "tackle", "uppercut", "pass", "throw" } :: { Config.ActionKey } do
		found[key] = ActionController:keyAction(key) or "none"
	end
	return found
end

-- A request's aim went along the crosshair's line (#312, Q123/Q127), as the camera gives it (CameraController:
-- crosshair, #315).
local function expectAimedThroughCrosshair(request: { [string]: any })
	expect(CAMERA.crosshairs).toBeGreaterThan(0)
	Fixtures.expectNear(request.aim, AIM, 1e-6)
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "ActionControllerTest"
	folder.Parent = workspace
	requests = {}
	bindings = {}
	others = {}
	arenaParts.parts = nil
	CAMERA.crosshairs = 0
end)
afterEach(function()
	InputController:destroy()
	folder:Destroy()
end)

describe("ActionController", function()
	it("tackles: lunges forward and asks the server", function()
		setup()
		frame()
		local before = skater().velocity
		press("Tackle")
		ActionController:step(DT)
		expect(requests).toEqual({ { action = "Tackle" } })
		Fixtures.expectNear(skater().velocity, before + skater().forward * 40)
		expect(ActionController:pose()).toBe("Lunge")
	end)

	it("poses a strike until its recovery", function()
		setup()
		frame()
		press("Tackle")
		actionsOnly()
		expect(ActionController:pose()).toBe("Lunge")
		local phases = config.Actions.Tackle.phases
		for _ = 1, math.ceil((phases.windup + phases.active) / DT) + 1 do
			actionsOnly()
		end
		expect(ActionController.runner.phase).toBe("Recovery")
		expect(ActionController:pose()).toBe("None")
	end)

	it("dodges with the ball, sideways along the stick", function()
		setup()
		BallCarrier:set(LOCAL_ID)
		bindingOf("Move"):Fire(Vector2.new(1, 0))
		SkateController:step(DT)
		local before = skater().velocity
		press("Tackle")
		ActionController:step(DT)
		expect(requests).toEqual({ { action = "Dodge" } })
		Fixtures.expectNear(skater().velocity, before + CAMERA.CFrame.RightVector * 45)
		expect(ActionController:pose()).toBe("None")
	end)

	-- The owner (#241): a tackle adds 48 km/h but never past 72 km/h, and eases back to the speed before over its
	-- recovery (RC's readout: 75 -> 33 km/h within ~0.3 s), so it never makes a skater faster.
	it("lunges up to the tackle's ceiling, then eases back to the speed before over the recovery", function()
		setup()
		local phases = config.Actions.Tackle.phases
		-- Frames from the press: inside the strike, halfway through the recovery, and past the tackle's end.
		local striking = math.floor((phases.windup + phases.active) / DT) - 2
		local easing = math.floor(phases.recovery / 2 / DT)
		local ended = math.ceil(phases.recovery / DT)
		-- From rest (+40), at 72 km/h (60, held at 60) and at 108 km/h (90, slowed to 60).
		for _, case in { { before = 0, lunge = 40 }, { before = 60, lunge = 60 }, { before = 90, lunge = 60 } } do
			ActionController.runner:reset()
			skater().velocity = Vector3.new(0, 0, -case.before)
			press("Tackle")
			for _ = 1, striking do
				actionsOnly()
			end
			expect(skater():shownSpeed()).toBeCloseTo(case.lunge, 3)
			for _ = 1, 2 + easing do
				actionsOnly()
			end
			local eased = skater():shownSpeed()
			for _ = 1, ended do
				actionsOnly()
			end
			-- The slower of the lunge and the speed before, and between the two halfway through.
			local after = math.min(case.lunge, case.before)
			expect(skater():shownSpeed()).toBeCloseTo(after, 3)
			if case.lunge > after then
				expect(eased > after + 10 and eased < case.lunge - 10).toBe(true)
			end
		end
	end)

	it("leaves a skater the tackle slowed free to gain speed in its recovery", function()
		setup()
		local phases = config.Actions.Tackle.phases
		-- 108 km/h, slowed to 60 by the lunge: nothing to give back, so speed gained after it stays.
		skater().velocity = Vector3.new(0, 0, -90)
		press("Tackle")
		for _ = 1, math.floor((phases.windup + phases.active) / DT) + 2 do
			actionsOnly()
		end
		expect(ActionController.runner.phase).toBe("Recovery")
		skater().velocity = Vector3.new(0, 0, -80)
		actionsOnly()
		Fixtures.expectNear(skater().velocity, Vector3.new(0, 0, -80))
	end)

	it("gives a refused tackle's lunge back at once", function()
		setup()
		press("Tackle")
		actionsOnly()
		ActionController:rejected({ action = "Tackle" })
		actionsOnly()
		Fixtures.expectNear(skater().velocity, Vector3.zero)
	end)

	-- Roller Champions' tackle key (#240): "Air Tackle Dive: X then Square then Square".
	it("tackles in the air at the tackle's own air strength, then dives down the fall line", function()
		setup()
		flying(Vector3.new(0, 0, -10))
		press("Tackle")
		actionsOnly()
		expect(requests).toEqual({ { action = "Tackle" } })
		-- 10 + lungeSpeed 40 × the tackle's airMultiplier 0.4 (#241: RC's 27 -> 42 km/h).
		Fixtures.expectNear(skater().velocity, Vector3.new(0, 0, -26))
		intoWindow(actionsOnly)
		press("Tackle")
		actionsOnly()
		expect(requests).toEqual({ { action = "Tackle" }, { action = "Dive" } })
		-- 26 across is under diveSpeed 60: 60 along the line 20° below the facing, never airMultiplier'd.
		Fixtures.expectNear(skater().velocity, FALL_LINE * 60)
		expect(ActionController:pose()).toBe("Lunge")
		-- Past the tackle's phases the dive keeps its own speed: nothing eases it back.
		for _ = 1, math.ceil(config.Actions.Tackle.phases.recovery * 2 / DT) do
			actionsOnly()
		end
		Fixtures.expectNear(skater().velocity, FALL_LINE * 60)
	end)

	it("holds an air tackle under the same ceiling as on the ground", function()
		setup()
		-- 80 + 16 held at 60, and 60 after: the slower of that and the speed before.
		flying(Vector3.new(0, 0, -80))
		press("Tackle")
		actionsOnly()
		Fixtures.expectNear(skater().velocity, Vector3.new(0, 0, -60))
		for _ = 1, math.ceil(config.Actions.Tackle.cooldown / DT) do
			actionsOnly()
		end
		Fixtures.expectNear(skater().velocity, Vector3.new(0, 0, -60))
	end)

	it("dives on the ground after a tackle, at the dive's speed along the facing", function()
		setup()
		dive(actionsOnly)
		expect(requests).toEqual({ { action = "Tackle" }, { action = "Dive" } })
		expect(SkateController.diving).toBe(true)
		-- The tackle's 40, then diveSpeed 60 along the facing.
		Fixtures.expectNear(skater().velocity, skater().forward * 60)
	end)

	-- The owner (#242): RC's dive glides ~0.3 s at ~70 km/h before the belly slide (Video 6).
	it("glides a ground dive through its strike, slowed by friction and drag only", function()
		setup()
		dive(frame)
		local speed = skater():shownSpeed()
		for _ = 1, 30 do
			frame()
		end
		-- 0.5 s of rollingFriction 4 and airDrag 0.02 × ~59: about 2.6, where a knockdown's slowing would take ~40.
		expect(speed - skater():shownSpeed()).toBeCloseTo((movement.rollingFriction + movement.airDrag * 59) * 0.5, 1)
	end)

	-- Roller Champions (Video 6): the readout climbed ~7.5 km/h every 0.1 s as the diver went down.
	it("flies a dive down the fall line, gravity speeding the diver up along it", function()
		setup()
		flying(Vector3.new(0, 0, -10))
		dive(frame)
		for _ = 1, 30 do
			frame()
		end
		-- 60 along the line, then 0.5 s of the world's pull along it (130.8 × sin 20°) less air drag: 81.656.
		Fixtures.expectNear(skater().velocity, FALL_LINE * 81.656)
	end)

	it("dodges in the air airMultiplier as hard as on the ground", function()
		setup()
		BallCarrier:set(LOCAL_ID)
		bindingOf("Move"):Fire(Vector2.new(1, 0))
		frame()
		flying(Vector3.zero)
		press("Tackle")
		ActionController:step(DT)
		expect(requests).toEqual({ { action = "Dodge" } })
		-- sideSpeed 45 × airMultiplier 0.8 = 36, to the right.
		Fixtures.expectNear(skater().velocity, CAMERA.CFrame.RightVector * 36)
	end)

	-- A dive ends on the skater's belly: the server knocks them down at their first touch of the ground (#221).
	it("does nothing more while diving, until the knockdown that ends the dive is over", function()
		setup()
		flying(Vector3.new(0, 0, -30))
		dive(frame)
		expect(SkateController.diving).toBe(true)
		press("Tackle")
		frame()
		local dived = { { action = "Tackle" }, { action = "Dive" } }
		expect(requests).toEqual(dived)
		-- Nor once the dive's phases are over, while they still fly.
		local phases = config.Actions.Dive.phases
		for _ = 1, math.ceil((phases.windup + phases.active + phases.recovery) / DT) do
			frame()
		end
		press("Tackle")
		frame()
		expect(requests).toEqual(dived)
		-- The server's knockdown arrives: the dive is over and stops, as the server stops it, and the knockdown holds
		-- the skater.
		rig:SetAttribute(Attributes.KnockedDown, "Hit")
		frame()
		expect(SkateController.diving).toBe(false)
		press("Tackle")
		frame()
		expect(requests).toEqual(dived)
		rig:SetAttribute(Attributes.KnockedDown, nil)
		frame()
		press("Tackle")
		frame()
		expect(requests).toEqual({ { action = "Tackle" }, { action = "Dive" }, { action = "Tackle" } })
	end)

	-- #286: the server's knockdown at a touchdown already slower than stopSpeed lasts one of its frames, and can come
	-- and go between two of this client's steps (a dive that stops at once, into a slope or a wall).
	it("ends a dive hold its knockdown never showed: strike over, on the ground, slower than stopSpeed", function()
		setup()
		frame()
		skater().velocity = Vector3.new(0, 0, -30)
		dive(actionsOnly)
		expect(SkateController.diving).toBe(true)
		local stopSpeed = (config.Actions.Dive.landing :: Config.Landing).stopSpeed
		local function sliding(speed: number)
			skater().velocity = Vector3.new(0, 0, -speed)
			actionsOnly()
		end
		-- Slower than stopSpeed on the ground, but the dive still strikes.
		sliding(stopSpeed - 0.5)
		expect(SkateController.diving).toBe(true)
		-- Faster through the rest of its strike.
		skater().velocity = Vector3.new(0, 0, -(stopSpeed + 0.5))
		local phases = config.Actions.Dive.phases
		for _ = 1, math.ceil((phases.windup + phases.active) / DT) do
			actionsOnly()
		end
		expect(ActionController.runner:striking()).toBeNil()
		-- Its strike over: still faster, then exactly at stopSpeed (the server's rule is strictly slower).
		sliding(stopSpeed + 0.5)
		expect(SkateController.diving).toBe(true)
		sliding(stopSpeed)
		expect(SkateController.diving).toBe(true)
		-- Slower, but still in the air.
		skater().mode = "Airborne"
		sliding(stopSpeed - 0.5)
		expect(SkateController.diving).toBe(true)
		-- On the ground: the hold ends.
		skater().mode = "Grounded"
		sliding(stopSpeed - 0.5)
		expect(SkateController.diving).toBe(false)
	end)

	it("frees a diver the server refused", function()
		setup()
		flying(Vector3.new(0, 0, -30))
		dive(frame)
		expect(SkateController.diving).toBe(true)
		ActionController:rejected({ action = "Dive" })
		expect(SkateController.diving).toBe(false)
	end)

	-- RC (#314, Q102; Video 33 at 17.0-19.2 s): with the ball the tackle key dodges, and the same key in the dodge's
	-- window dives, the ball kept.
	it("dodges with the ball, then dives with it from the same key in the dodge's window", function()
		setup()
		BallCarrier:set(LOCAL_ID)
		skater().velocity = Vector3.new(0, 0, -30)
		dive(frame)
		expect(requests).toEqual({ { action = "Dodge" }, { action = "Dive" } })
		expect(SkateController.diving).toBe(true)
		expect(BallCarrier.carrier).toBe(LOCAL_ID)
	end)

	-- The owner (#314, Q154): RC keeps Charge Throw lit through the carrier's dive and slide (Video 33 at 17.6-19.0 s).
	it("throws from the belly after the carrier's own dive, and starts nothing else there", function()
		setup()
		local throw = charging(6)
		rig:SetAttribute(Attributes.KnockedDown, "Dive")
		frame()
		expect(names()).toEqual({ tackle = "none", uppercut = "none", pass = "none", throw = "ChargeThrow" })
		throw:Fire(false)
		frame()
		expect(#requests).toBe(1)
		expect(requests[1].action).toBe("ChargeThrow")
		rig:SetAttribute(Attributes.KnockedDown, nil)
	end)

	-- Through the crosshair above the skater (#312, Q123/Q127), so aiming forward or up never drops the camera to the
	-- skater's feet, and at the spot where the crosshair's line first meets the arena (#313, Q148): the wall ahead,
	-- with the ball's centre a radius off its face there, so the ball itself touches it at the spot.
	it("charges a throw for as long as it is held, and throws it at the crosshair's spot", function()
		setup({ wallAhead() })
		local half = math.round(THROW.chargeMaxSeconds / 2 / DT)
		local throw = charging(half)
		expect(#requests).toBe(0)
		throw:Fire(false)
		frame()
		expect(#requests).toBe(1)
		local request = requests[1]
		expect(request.action).toBe("ChargeThrow")
		expectAimedThroughCrosshair(request)
		local way = AIM.Unit
		local face = CAMERA.CFrame.Position + way * (59.5 / -way.Z)
		Fixtures.expectNear(request.spot, face + Vector3.zAxis * config.Ball.radius, 1e-3)
		expect(request.charge).toBeCloseTo(half * DT / THROW.chargeMaxSeconds, 6)
	end)

	-- A line that meets nothing on its way (#313): the spot is where it ends, aimReach studs out.
	it("throws at the end of the crosshair's line when it meets nothing", function()
		setup()
		local throw = charging(6)
		throw:Fire(false)
		frame()
		Fixtures.expectNear(requests[1].spot, CAMERA.CFrame.Position + AIM.Unit * THROW.aimReach, 1e-3)
	end)

	-- Through the goal ring's opening before the wall (#313): at the ring's centre, though the line passes 3 studs
	-- beside it.
	it("throws at the goal ring's centre when the crosshair's line passes through its opening", function()
		setup({ wallAhead() })
		local onLine = CAMERA.CFrame.Position + AIM.Unit * 30
		local centre = onLine + Vector3.new(3, 0, 0)
		arenaParts.parts = { goal = { frame = CFrame.new(centre), radius = config.Arena.goal.ringRadius } }
		local throw = charging(6)
		throw:Fire(false)
		frame()
		Fixtures.expectNear(requests[1].spot, centre, 1e-6)
	end)

	-- The key's time goes on past a full charge: the crosshair's closed ring blinks then (Q142).
	it("charges no further than a full charge, however long the throw is held", function()
		setup()
		local steps = math.round(2 * THROW.chargeMaxSeconds / DT)
		local throw = charging(steps)
		expect(ActionController:chargeSeconds()).toBeCloseTo(steps * DT, 6)
		throw:Fire(false)
		frame()
		expect(requests[1].charge).toBe(1)
	end)

	-- What the crosshair's ring shows (#312): how long the throw key has been held, from the press.
	it("tells how long a throw has charged while it charges, and nothing otherwise", function()
		setup()
		expect(ActionController:chargeSeconds()).toBeNil()
		local throw = charging(6)
		expect(ActionController:chargeSeconds()).toBeCloseTo(6 * DT, 6)
		throw:Fire(false)
		frame()
		expect(ActionController:chargeSeconds()).toBeNil()
	end)

	it("keeps a throw charged and let go during a dodge for when the dodge ends", function()
		setup()
		BallCarrier:set(LOCAL_ID)
		frame() -- the throw key seen up while holding the ball
		press("Tackle")
		frame()
		expect(requests).toEqual({ { action = "Dodge" } })
		-- Charged and let go while the dodge runs (0.5 s, 30 steps).
		local throw = bindingOf("Throw")
		throw:Fire(true)
		for _ = 1, 10 do
			frame()
		end
		throw:Fire(false)
		for _ = 1, 17 do
			frame()
		end
		expect(#requests).toBe(1)
		for _ = 1, 6 do
			frame()
		end
		expect(#requests).toBe(2)
		expect(requests[2].action).toBe("ChargeThrow")
		expect(requests[2].charge).toBeCloseTo(10 * DT / THROW.chargeMaxSeconds, 6)
	end)

	-- RC's Cancel & Dodge (#312, Q100; Videos 32 and 33): the tackle key while charging drops the charge and dodges.
	it("drops the charge when it dodges while a throw charges: letting go then throws nothing", function()
		setup()
		local throw = charging(10)
		press("Tackle")
		frame()
		expect(requests).toEqual({ { action = "Dodge" } })
		expect(ActionController:chargeSeconds()).toBeNil()
		-- Still held through the dodge, then let go after it: nothing.
		for _ = 1, 40 do
			frame()
		end
		expect(ActionController:chargeSeconds()).toBeNil()
		throw:Fire(false)
		frame()
		expect(requests).toEqual({ { action = "Dodge" } })
		-- A new press charges again.
		throw:Fire(true)
		frame()
		throw:Fire(false)
		frame()
		expect(#requests).toBe(2)
		expect(requests[2].action).toBe("ChargeThrow")
	end)

	-- RC's Roll Ball (#312, Q100; Video 31 at 1:19.4): the uppercut key while charging puts the ball on the floor
	-- rolling ahead at the charge's speed; the server places it and spends the charge.
	it("rolls the ball with the uppercut key while charging, spending the charge, through the crosshair", function()
		setup()
		charging(12)
		press("Uppercut")
		frame()
		expect(#requests).toBe(1)
		local request = requests[1]
		expect(request.action).toBe("RollBall")
		expectAimedThroughCrosshair(request)
		-- Along the floor the aim's way: no spot to come down on (#313).
		expect(request.spot).toBeNil()
		-- Twelve steps held, and the press's own: the throw key is still down.
		expect(request.charge).toBeCloseTo(13 * DT / THROW.chargeMaxSeconds, 6)
		-- The ball leaves at once, as a throw's does; no leap.
		expect(BallCarrier.carrier).toBeNil()
		expect(skater().mode).toBe("Grounded")
		expect(ActionController:chargeSeconds()).toBeNil()
		-- Refused: the ball is back.
		ActionController:rejected({ action = "RollBall" })
		expect(BallCarrier.carrier).toBe(LOCAL_ID)
	end)

	-- The uppercut key does nothing in the air (#262), with the ball or charging alike.
	it("never rolls the ball in the air", function()
		setup()
		BallCarrier:set(LOCAL_ID)
		flying(Vector3.new(0, -10, -30))
		ActionController:step(DT)
		bindingOf("Throw"):Fire(true)
		ActionController:step(DT)
		press("Uppercut")
		ActionController:step(DT)
		expect(requests).toEqual({})
		expect(BallCarrier.carrier).toBe(LOCAL_ID)
	end)

	-- RC greys Magnetic Pass while a throw charges (Q140, Video 32 at 2.6-3.2 s): the pass key does nothing.
	it("never passes while a throw charges, and the charge goes on", function()
		setup()
		standing("Mate", Vector3.new(0, HOVER, -40), "Blue")
		charging(5)
		press("Pass")
		frame()
		expect(requests).toEqual({})
		expect(BallCarrier.carrier).toBe(LOCAL_ID)
		expect(ActionController:chargeSeconds()).toBeCloseTo(6 * DT, 6)
	end)

	-- RC greys Pump while a throw charges (Q106; Videos 13, 31, 32): the skating ignores the pump key meanwhile.
	it("holds the pump off while a throw charges, from the press until it ends however it ends", function()
		setup()
		expect(SkateController.charging).toBe(false)
		local throw = charging(1)
		expect(SkateController.charging).toBe(true)
		throw:Fire(false)
		frame()
		expect(SkateController.charging).toBe(false)
		-- Cancelled by a dodge.
		charging(1)
		press("Tackle")
		frame()
		expect(SkateController.charging).toBe(false)
		throw:Fire(false)
		-- The ball lost (a knockdown takes it).
		ActionController.runner:reset()
		charging(1)
		BallCarrier:set(nil)
		frame()
		expect(SkateController.charging).toBe(false)
		throw:Fire(false)
		-- Held still (a kickoff's placement).
		charging(1)
		Fixtures.placed(rig)
		frame()
		expect(SkateController.charging).toBe(false)
	end)

	it("starts a charge only from a press made while holding the ball", function()
		setup()
		local throw = bindingOf("Throw")
		-- Held for Ball Focus without the ball, through the catch, then let go: nothing is thrown.
		throw:Fire(true)
		frame()
		BallCarrier:set(LOCAL_ID)
		for _ = 1, 10 do
			frame()
		end
		throw:Fire(false)
		frame()
		expect(requests).toEqual({})
		-- A new press with the ball charges, and letting go throws.
		throw:Fire(true)
		for _ = 1, 10 do
			frame()
		end
		throw:Fire(false)
		frame()
		expect(#requests).toBe(1)
		expect(requests[1].action).toBe("ChargeThrow")
		expect(requests[1].charge).toBeCloseTo(10 * DT / THROW.chargeMaxSeconds, 6)
	end)

	it("drops a charge, without throwing, when Roblox's menu opens", function()
		setup()
		BallCarrier:set(LOCAL_ID)
		frame()
		local throw = bindingOf("Throw")
		throw:Fire(true)
		for _ = 1, 10 do
			frame()
		end
		-- The menu lets go of the key, not the player.
		menu.MenuOpened:Fire()
		frame()
		frame()
		menu.MenuClosed:Fire()
		frame()
		expect(requests).toEqual({})
	end)

	it("predicts the ball leaving with a pass, and takes it back if the pass is refused", function()
		setup()
		standing("Mate", Vector3.new(0, HOVER, -40), "Blue")
		BallCarrier:set(LOCAL_ID)
		press("Pass")
		frame()
		expect(requests[1].action).toBe("Pass")
		expect(BallCarrier.carrier).toBeNil()
		-- The tackle key right after is a tackle, not a dodge.
		press("Tackle")
		frame()
		expect(requests[2]).toEqual({ action = "Tackle" })
		-- Refused: the ball is back.
		ActionController.runner:reset()
		BallCarrier:set(LOCAL_ID)
		press("Pass")
		frame()
		ActionController:rejected({ action = "Pass" })
		expect(BallCarrier.carrier).toBe(LOCAL_ID)
	end)

	it("passes with the ball and calls for one without", function()
		setup()
		standing("Mate", Vector3.new(0, HOVER, -40), "Blue")
		BallCarrier:set(LOCAL_ID)
		press("Pass")
		frame()
		BallCarrier:set(nil)
		press("Pass")
		frame()
		expect(#requests).toBe(2)
		expect(requests[1].action).toBe("Pass")
		expectAimedThroughCrosshair(requests[1])
		expect(requests[2]).toEqual({ action = "CallPass" })
	end)

	-- Magnetic Pass, RC's way (#315, the owner: Q103, Q105; Video 34 at 41.6-43.2 s): with the ball the pass key names
	-- the teammate nearest the crosshair's line within the cone and the range; with nobody there it is greyed and does
	-- nothing.
	it("passes only to a teammate in the crosshair's cone and range, and names them while carrying", function()
		setup()
		BallCarrier:set(LOCAL_ID)
		frame()
		local action, ready = ActionController:keyAction("pass")
		expect(action).toBe("Pass")
		expect(ready).toBe(false)
		expect(ActionController:passTarget()).toBeNil()
		press("Pass")
		frame()
		expect(requests).toEqual({})
		expect(BallCarrier.carrier).toBe(LOCAL_ID)
		-- An opponent in the aim, a teammate behind, a teammate past the range: still nobody.
		standing("Opponent", Vector3.new(0, HOVER, -20))
		standing("Behind", Vector3.new(0, HOVER, 20), "Blue")
		standing("Far", Vector3.new(0, HOVER, -(PASS.maxRange + 5)), "Blue")
		frame()
		expect(ActionController:passTarget()).toBeNil()
		-- A teammate 20 deg off the crosshair's line.
		standing("Mate", Vector3.new(10, HOVER, -40), "Blue")
		frame()
		action, ready = ActionController:keyAction("pass")
		expect(action).toBe("Pass")
		expect(ready).toBe(true)
		expect(ActionController:passTarget()).toBe("Mate")
		press("Pass")
		frame()
		expect(requests[1].action).toBe("Pass")
		expectAimedThroughCrosshair(requests[1])
		expect(BallCarrier.carrier).toBeNil()
		-- Without the ball the key calls for it, and names no target.
		frame()
		expect(ActionController:passTarget()).toBeNil()
		expect((ActionController:keyAction("pass"))).toBe("CallPass")
	end)

	-- The server's own rule (PassTarget.choose): a caller in the cone first, the latest of two by the call's time that
	-- their CallingPass holds; nobody knocked down catches.
	it("names a teammate calling in the cone first, the latest caller of two, and nobody who is down", function()
		setup()
		BallCarrier:set(LOCAL_ID)
		local onLine = standing("OnLine", Vector3.new(0, HOVER, -40), "Blue")
		local right = standing("Right", Vector3.new(30, HOVER, -40), "Blue")
		frame()
		expect(ActionController:passTarget()).toBe("OnLine")
		right:SetAttribute(Attributes.CallingPass, 12.5)
		frame()
		expect(ActionController:passTarget()).toBe("Right")
		onLine:SetAttribute(Attributes.CallingPass, 13)
		frame()
		expect(ActionController:passTarget()).toBe("OnLine")
		right:SetAttribute(Attributes.CallingPass, 14)
		frame()
		expect(ActionController:passTarget()).toBe("Right")
		right:SetAttribute(Attributes.KnockedDown, "Hit")
		frame()
		expect(ActionController:passTarget()).toBe("OnLine")
		onLine:SetAttribute(Attributes.KnockedDown, "Hit")
		frame()
		expect(ActionController:passTarget()).toBeNil()
	end)

	-- The owner (Q155): no pass through the middle glass, nor anything else of the arena between the two skaters: no
	-- letter over a teammate the ride surfaces hide, the key greyed and doing nothing.
	it("names no teammate the arena hides from the skater, a caller neither", function()
		setup({ paneAhead() })
		BallCarrier:set(LOCAL_ID)
		local hidden = standing("Hidden", Vector3.new(0, HOVER, -40), "Blue")
		hidden:SetAttribute(Attributes.CallingPass, 12.5)
		frame()
		expect(ActionController:passTarget()).toBeNil()
		local _, ready = ActionController:keyAction("pass")
		expect(ready).toBe(false)
		press("Pass")
		frame()
		expect(requests).toEqual({})
		-- One in the open beside them: the line to them crosses the pane's plane 7.5 studs aside.
		standing("Open", Vector3.new(15, HOVER, -40), "Blue")
		frame()
		expect(ActionController:passTarget()).toBe("Open")
	end)

	-- RC greys Magnetic Pass while a throw charges (Q140) and through a carrier's dive (Q154): no target is named then.
	it("names no pass target while a throw charges or the controls are locked", function()
		setup()
		standing("Mate", Vector3.new(0, HOVER, -40), "Blue")
		BallCarrier:set(LOCAL_ID)
		frame()
		expect(ActionController:passTarget()).toBe("Mate")
		local skate: any = SkateController
		for _, field in { "diving", "knockedDown" } do
			skate[field] = true
			expect(ActionController:passTarget()).toBeNil()
			skate[field] = false
		end
		-- Held still (a kickoff's hold): the actions' step names nobody.
		skate.frozen = true
		actionsOnly()
		expect(ActionController:passTarget()).toBeNil()
		skate.frozen = false
		charging(2)
		expect(ActionController:passTarget()).toBeNil()
		expect((ActionController:keyAction("pass"))).toBeNil()
	end)

	-- Roller Champions' uppercut launches on flat floor, away from any wall (#219): 89.81 studs/s up, about 31 studs at
	-- the world's gravity (#279).
	it("leaps up with an uppercut from the ground anywhere, on open floor as beside a wall", function()
		setup()
		frame()
		press("Uppercut")
		frame()
		expect(skater().mode).toBe("Airborne")
		expect(skater().velocity.Y).toBeCloseTo(89.81, 3)

		-- A wall facing the skater, 4 studs ahead, changes nothing.
		local wall: BasePart = Instance.new("Part")
		wall.Anchored = true
		wall.Size = Vector3.new(20, 10, 1)
		wall.CFrame = CFrame.new(0, 5, -4.5)
		wall.Parent = folder
		wall:AddTag(Tags.RideSurface)
		skater():stop()
		ActionController.runner:reset()
		press("Uppercut")
		frame()
		expect(skater().mode).toBe("Airborne")
		expect(skater().velocity.Y).toBeCloseTo(89.81, 3)
		expect(requests).toEqual({ { action = "Uppercut" }, { action = "Uppercut" } })
	end)

	-- The owner (#262, Videos 10-11): "if a player jump, he can't sequence it with an uppercut unless he touches a
	-- ground or wall, basically something solid"; RC greys the Uppercut in the air.
	it("never uppercuts in the air", function()
		setup()
		flying(Vector3.new(0, -10, -30))
		press("Uppercut")
		frame()
		expect(requests).toEqual({})
		expect(ActionController.runner.action).toBe(nil)
		expect(skater().velocity.Y).toBeLessThan(0)
	end)

	it("does nothing while knocked down", function()
		setup()
		rig:SetAttribute(Attributes.KnockedDown, "Hit")
		frame()
		press("Tackle")
		frame()
		expect(requests).toEqual({})
	end)

	it("spends the keys and resets the runner while a placement holds the skater still", function()
		setup()
		press("Tackle")
		frame()
		expect(ActionController.runner.action).toBe("Tackle")
		Fixtures.placed(rig)
		press("Tackle")
		frame()
		expect(ActionController.runner.action).toBeNil()
		frame()
		expect(#requests).toBe(1)
		-- The tackle's cooldown went with the reset.
		press("Tackle")
		frame()
		expect(requests).toEqual({ { action = "Tackle" }, { action = "Tackle" } })
	end)

	it("cancels a rejected action and refunds its cooldown", function()
		setup()
		press("Tackle")
		frame()
		ActionController:rejected({ action = "Tackle" })
		expect(ActionController.runner.action).toBeNil()
		press("Tackle")
		frame()
		expect(requests).toEqual({ { action = "Tackle" }, { action = "Tackle" } })
	end)

	it("names the action each key would start now", function()
		setup()
		expect(names()).toEqual({ tackle = "Tackle", uppercut = "Uppercut", pass = "CallPass", throw = "none" })
		BallCarrier:set(LOCAL_ID)
		expect(names()).toEqual({ tackle = "Dodge", uppercut = "none", pass = "Pass", throw = "ChargeThrow" })

		-- In the air the keys name the same (#240: the first press of the tackle key tackles there too), but the
		-- uppercut key nothing: the Uppercut starts only from a surface (#262: RC greys it in the air).
		skater().mode = "Airborne"
		expect(names()).toEqual({ tackle = "Dodge", uppercut = "none", pass = "Pass", throw = "ChargeThrow" })
		BallCarrier:set(nil)
		expect(names()).toEqual({ tackle = "Tackle", uppercut = "none", pass = "CallPass", throw = "none" })
	end)

	-- RC's hints while a throw charges (#312, Video 32 at 3.2 s): Throw, Cancel & Dodge (the Dodge, which drops the
	-- charge) and Roll Ball; Magnetic Pass greyed (Q140). In the air the uppercut key rolls nothing (#262).
	it("names the dodge, Roll Ball and the throw for the keys while a throw charges, and no pass", function()
		setup()
		charging(3)
		expect(names()).toEqual({ tackle = "Dodge", uppercut = "RollBall", pass = "none", throw = "ChargeThrow" })
		skater().mode = "Airborne"
		expect(names()).toEqual({ tackle = "Dodge", uppercut = "none", pass = "none", throw = "ChargeThrow" })
	end)

	-- Roller Champions (the owner's Video 4): "Dive" replaces "Tackle" 0.1-0.2 s after the press, and "Tackle" is back
	-- 0.9-1.0 s after it.
	it("names the dive for the tackle key only in the tackle's follow-up window, then tackles again", function()
		setup()
		press("Tackle")
		actionsOnly()
		expect((ActionController:keyAction("tackle"))).toBe("Tackle")
		intoWindow(actionsOnly)
		expect((ActionController:keyAction("tackle"))).toBe("Dive")
		-- Past the window, which closes as the tackle's cooldown ends (both at 1 s).
		for _ = 1, math.ceil((FOLLOW_UP.to - FOLLOW_UP.from) / DT) do
			actionsOnly()
		end
		expect((ActionController:keyAction("tackle"))).toBe("Tackle")
		press("Tackle")
		actionsOnly()
		expect(requests).toEqual({ { action = "Tackle" }, { action = "Tackle" } })
	end)

	-- The owner (Q178): a Dive keeps to the move it follows, so the key names it after a tackle only with empty hands
	-- and after a dodge only while the ball is still held; else the key's own action for the hands it has.
	it("names no dive for a tackler the ball reached in the tackle's window: the key dodges", function()
		setup()
		press("Tackle")
		actionsOnly()
		BallCarrier:set(LOCAL_ID)
		intoWindow(actionsOnly)
		expect((ActionController:keyAction("tackle"))).toBe("Dodge")
	end)

	it("names no dive for a carrier whose ball went in the dodge's window: the key tackles", function()
		setup()
		BallCarrier:set(LOCAL_ID)
		press("Tackle")
		actionsOnly()
		BallCarrier:set(nil)
		intoWindow(actionsOnly, config.Actions.Dodge.followUp :: Config.FollowUp)
		expect((ActionController:keyAction("tackle"))).toBe("Tackle")
	end)

	it("steps in under 0.1 ms", function()
		setup()
		BallCarrier:set(LOCAL_ID)
		local throw, move = bindingOf("Throw"), bindingOf("Move")
		local total = 0
		for step = 1, 600 do
			-- Idle for the first half, then the stick and a throw held.
			if step == 301 then
				throw:Fire(true)
				move:Fire(Vector2.new(0, 1))
			end
			SkateController:step(DT)
			local started = os.clock()
			ActionController:step(DT)
			total += os.clock() - started
		end
		expect(#requests).toBe(0)
		Fixtures.expectWithinBudget(total / 600, 0.0001)
	end)
end)

describe("ActionController's magnetic strikes (#277)", function()
	-- One step's turn at the Tackle's turn rate, in degrees: 300 deg/s over 1/60 s.
	local TACKLE_STEP = (config.Actions.Tackle.seek :: Config.Seek).turnDegPerSecond * DT

	-- A Tackle pressed at 30 studs/s with an opponent 15 studs ahead, 30 deg right: in the cone, past the snap zone.
	-- Returns the opponent and the facing the press turned to.
	local function tackleAhead(): (Model, Vector3)
		setup()
		frame()
		local target = standing("Ahead", Vector3.new(7.5, HOVER, -13))
		skater().velocity = Vector3.new(0, 0, -30)
		press("Tackle")
		actionsOnly()
		return target, across(skater().forward)
	end

	-- Degrees the facing turned across the ground since `before`.
	local function turnedFrom(before: Vector3): number
		return math.deg(Vectors.angleBetween(before, across(skater().forward)))
	end

	it("strikes the stick's way when nobody is near: D and the Tackle key lunge to the right (Video 26)", function()
		setup()
		frame()
		skater().velocity = Vector3.new(0, 0, -30)
		bindingOf("Move"):Fire(Vector2.new(1, 0))
		press("Tackle")
		frame()
		expect(across(skater().forward):Dot(Vector3.xAxis)).toBeGreaterThan(0.999)
		expect(across(skater().velocity):Dot(Vector3.xAxis)).toBeGreaterThan(0.999)
	end)

	it("snaps at once to an opponent close beside, facing and moving at them (Q61)", function()
		setup()
		frame()
		standing("Beside", Vector3.new(8, HOVER, -0.5))
		skater().velocity = Vector3.new(0, 0, -30)
		press("Tackle")
		actionsOnly()
		local way = across(Vector3.new(8, 0, -0.5))
		expect(across(skater().forward):Dot(way)).toBeGreaterThan(0.999)
		expect(across(skater().velocity):Dot(way)).toBeGreaterThan(0.999)
	end)

	it(
		"turns at once toward a target in its cone, then bends at most turnDegPerSecond while the strike runs",
		function()
			local target, before = tackleAhead()
			local way = across(Vector3.new(7.5, 0, -13))
			expect(before:Dot(way)).toBeGreaterThan(0.999)
			expect(across(skater().velocity):Dot(way)).toBeGreaterThan(0.999)
			-- 20 deg further right, still in the 45 deg cone: one step turns 5 deg toward them.
			aside(target, before, 20)
			actionsOnly()
			expect(turnedFrom(before)).toBeCloseTo(TACKLE_STEP, 1)
		end
	)

	it("turns no further while its target is outside the cone, and bends again once they are back in it", function()
		local target, before = tackleAhead()
		aside(target, before, 60)
		actionsOnly()
		expect(turnedFrom(before)).toBeLessThan(1e-3)
		aside(target, before, 20)
		actionsOnly()
		expect(turnedFrom(before)).toBeCloseTo(TACKLE_STEP, 1)
	end)

	it("never homes onto a teammate, a knocked-down or a dodging opponent", function()
		setup()
		frame()
		standing("Mate", Vector3.new(8, HOVER, -0.5), "Blue")
		standing("Down", Vector3.new(6, HOVER, -0.5)):SetAttribute(Attributes.KnockedDown, "Hit")
		standing("Dodging", Vector3.new(7, HOVER, -0.5)):SetAttribute(Attributes.Action, "Dodge")
		-- On the belly after a dive without the ball (#314: only a carrier's own dive leaves them in reach).
		standing("Diver", Vector3.new(7.5, HOVER, -0.5)):SetAttribute(Attributes.KnockedDown, "Dive")
		skater().velocity = Vector3.new(0, 0, -30)
		press("Tackle")
		actionsOnly()
		expect(across(skater().forward):Dot(-Vector3.zAxis)).toBeGreaterThan(0.999)
	end)

	-- The owner (#314, Q153): a carrier sliding after their own dive can be struck, so a strike homes onto them.
	it("homes onto an opponent carrier sliding on the belly after their own dive", function()
		setup()
		frame()
		standing("Carrier", Vector3.new(8, HOVER, -0.5)):SetAttribute(Attributes.KnockedDown, "Dive")
		BallCarrier:set("Carrier")
		skater().velocity = Vector3.new(0, 0, -30)
		press("Tackle")
		actionsOnly()
		expect(across(skater().forward):Dot(across(Vector3.new(8, 0, -0.5)))).toBeGreaterThan(0.999)
	end)

	it("never homes onto an opponent knocked down since the last strike", function()
		setup()
		frame()
		standing("Ahead", Vector3.new(0, HOVER, -10))
		-- Nearer, 85 deg right: the first strike's target.
		local near = standing("Near", Vector3.new(6, HOVER, -0.5))
		skater().velocity = Vector3.new(0, 0, -30)
		press("Tackle")
		actionsOnly()
		near:SetAttribute(Attributes.KnockedDown, "Hit")
		ActionController.runner:reset()
		skater().forward = -Vector3.zAxis
		skater().velocity = Vector3.new(0, 0, -30)
		press("Tackle")
		actionsOnly()
		expect(across(skater().forward):Dot(-Vector3.zAxis)).toBeGreaterThan(0.999)
	end)

	it("stops bending once its target is knocked down", function()
		local target, before = tackleAhead()
		target:SetAttribute(Attributes.KnockedDown, "Hit")
		aside(target, before, 20)
		actionsOnly()
		expect(turnedFrom(before)).toBeLessThan(1e-3)
	end)

	-- Q153 (#314): a carrier on the belly after their own dive stays in reach, so the strike keeps after them.
	it("keeps bending toward a target who carries the ball and lies down after their own dive", function()
		local target, before = tackleAhead()
		BallCarrier:set(target.Name)
		target:SetAttribute(Attributes.KnockedDown, "Dive")
		aside(target, before, 20)
		actionsOnly()
		expect(turnedFrom(before)).toBeCloseTo(TACKLE_STEP, 1)
	end)

	it("stops bending once its target's character is gone", function()
		local target, before = tackleAhead()
		aside(target, before, 20)
		target:Destroy()
		actionsOnly()
		expect(turnedFrom(before)).toBeLessThan(1e-3)
	end)

	it("stops bending at the strike's recovery", function()
		local target, before = tackleAhead()
		local phases = config.Actions.Tackle.phases
		for _ = 1, math.ceil((phases.windup + phases.active) / DT) + 1 do
			actionsOnly()
		end
		expect(ActionController.runner.phase).toBe("Recovery")
		before = across(skater().forward)
		aside(target, before, 20)
		actionsOnly()
		expect(turnedFrom(before)).toBeLessThan(1e-3)
	end)

	it("stops bending when the server refuses the strike", function()
		local target, before = tackleAhead()
		ActionController:rejected({ action = "Tackle" })
		aside(target, before, 20)
		actionsOnly()
		expect(turnedFrom(before)).toBeLessThan(1e-3)
	end)

	it("looks for its target along the stick's way (Q59)", function()
		setup()
		frame()
		-- 15 studs away, 30 deg behind the stick's way (D: +X), 120 deg off the facing.
		standing("BehindRight", Vector3.new(13, HOVER, 7.5))
		skater().velocity = Vector3.new(0, 0, -30)
		bindingOf("Move"):Fire(Vector2.new(1, 0))
		press("Tackle")
		frame()
		local way = across(Vector3.new(13, 0, 7.5) - rig:GetPivot().Position)
		expect(across(skater().forward):Dot(way)).toBeGreaterThan(0.999)
	end)

	it("forgets the last strike's target: a Dive after a Tackle looks for its own", function()
		local target, before = tackleAhead()
		intoWindow(actionsOnly)
		-- 30 studs ahead: past the Dive's reach.
		local root = target:FindFirstChild("HumanoidRootPart") :: BasePart
		root.Position = rig:GetPivot().Position + before * 30
		press("Tackle")
		actionsOnly()
		expect(ActionController.runner.action).toBe("Dive")
		local facing = across(skater().forward)
		aside(target, facing, 20)
		actionsOnly()
		expect(turnedFrom(facing)).toBeLessThan(1e-3)
	end)

	it("dives at an opponent beside, a little behind, whom its Tackle left (Q64)", function()
		setup()
		frame()
		-- 15 studs away, 100 deg right of the facing: past the Tackle's snap zone and cone, inside the Dive's snap.
		local offset = Vector3.new(15 * math.sin(math.rad(100)), 0, -15 * math.cos(math.rad(100)))
		standing("Beside", offset + Vector3.new(0, HOVER, 0))
		skater().velocity = Vector3.new(0, 0, -30)
		press("Tackle")
		actionsOnly()
		expect(across(skater().forward):Dot(-Vector3.zAxis)).toBeGreaterThan(0.999)
		intoWindow(actionsOnly)
		press("Tackle")
		actionsOnly()
		expect(ActionController.runner.action).toBe("Dive")
		expect(across(skater().forward):Dot(across(offset))).toBeGreaterThan(0.999)
	end)

	it("takes an opponent in the snap zone before a nearer one only in the cone", function()
		setup()
		frame()
		-- 10.4 studs up and a little behind: in the Uppercut's cone round straight up, outside its front half.
		standing("Above", Vector3.new(0, HOVER + 10, 3))
		-- 11 studs away, 85 deg right: in its snap zone.
		standing("Beside", Vector3.new(11, HOVER, -1))
		press("Uppercut")
		actionsOnly()
		expect(across(skater().forward):Dot(across(Vector3.new(11, 0, -1)))).toBeGreaterThan(0.999)
	end)

	it("bends an Uppercut's leap toward an opponent above (Q56)", function()
		setup()
		frame()
		-- 26.9 studs away, 21.8 deg from straight up.
		standing("Above", Vector3.new(0, HOVER + 25, -10))
		skater().velocity = Vector3.zero
		press("Uppercut")
		actionsOnly()
		local leap = skater().velocity
		actionsOnly()
		-- The leap straight up turned one step (6 deg) toward them: (0, 89.32, -9.39) for 89.81 studs/s.
		local step = math.rad((config.Actions.Uppercut.seek :: Config.Seek).turnDegPerSecond * DT)
		Fixtures.expectNear(skater().velocity, Vector3.new(0, math.cos(step), -math.sin(step)) * leap.Magnitude)
	end)

	it("never bends an Uppercut's leap toward an opponent on the ground", function()
		setup()
		frame()
		standing("Ground", Vector3.new(0, HOVER, -8))
		press("Uppercut")
		actionsOnly()
		local leap = skater().velocity
		actionsOnly()
		expect(Vectors.angleBetween(leap, skater().velocity)).toBeLessThan(1e-3)
	end)
end)
