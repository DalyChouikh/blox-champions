--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Client = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local ActionController = require(Client.ActionController)
local Attributes = require(ReplicatedStorage.Shared.Net.Attributes)
local BallCarrier = require(Client.BallCarrier)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local InputController = require(Client.InputController)
local RideSurfaces = require(Client.RideSurfaces)
local SkateController = require(Client.SkateController)
local SkaterBody = require(ServerScriptService.Server.SkaterBody)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

local config = Config.defaults()
local movement = config.Movement
-- The Tackle's Dive (#240).
local FOLLOW_UP = config.Actions.Tackle.followUp :: Config.FollowUp
-- The line a diver facing -Z flies along (#241): fallLineDeg below the facing.
local FALL_LINE = Vector3.new(0, -math.sin(math.rad(movement.fallLineDeg)), -math.cos(math.rad(movement.fallLineDeg)))
local DT = 1 / 60
-- Looking toward -Z from behind the skater, so the skater's right is the camera's right, +X.
local CAMERA = { CFrame = CFrame.lookAt(Vector3.new(0, 5, 10), Vector3.new(0, 5, 0)) }
local LOCAL_ID = "1"

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
		Camera = CAMERA,
		Skaters = function(): { any }
			return {}
		end,
		SendSkateState = function() end,
		Gravity = Fixtures.GRAVITY,
		Team = function(): string?
			return "Blue"
		end,
	})
	rig = Fixtures.rig(folder, "Skater", CFrame.new(0, movement.hoverHeight, 0))
	SkaterBody.build(rig, movement)
	SkateController:bind(rig)
	ActionController:init({
		Config = config,
		InputController = InputController,
		BallCarrier = BallCarrier,
		SkateController = SkateController,
		Camera = CAMERA,
		SendRequest = function(payload: { [string]: any })
			table.insert(requests, payload)
		end,
		LocalId = LOCAL_ID,
	})
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

-- Steps `step` past the Tackle's follow-up window's start, two frames in.
local function intoWindow(step: () -> ())
	for _ = 1, math.floor(FOLLOW_UP.from / DT) + 2 do
		step()
	end
end

-- Roller Champions' tackle key (#240): a press tackles, a second one in the tackle's follow-up window dives.
local function dive(step: () -> ())
	press("Tackle")
	step()
	intoWindow(step)
	press("Tackle")
	step()
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "ActionControllerTest"
	folder.Parent = workspace
	requests = {}
	bindings = {}
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
		-- From rest (+40), at cruise (60, held at 60) and at 108 km/h (90, slowed to 60).
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

	-- Roller Champions (Video 6): the readout climbed ~7.5 km/h every 0.1 s as the diver went down.
	it("flies a dive down the fall line, gravity speeding the diver up along it", function()
		setup()
		flying(Vector3.new(0, 0, -10))
		dive(frame)
		for _ = 1, 30 do
			frame()
		end
		-- 60 along the line, then 0.5 s of gravity's pull along it (196.2 × sin 20°) less air drag: 92.782.
		Fixtures.expectNear(skater().velocity, FALL_LINE * 92.782)
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
		press("Uppercut")
		frame()
		local dived = { { action = "Tackle" }, { action = "Dive" } }
		expect(requests).toEqual(dived)
		-- Nor once the dive's phases are over, while they still fly.
		local phases = config.Actions.Dive.phases
		for _ = 1, math.ceil((phases.windup + phases.active + phases.recovery) / DT) do
			frame()
		end
		press("Uppercut")
		frame()
		expect(requests).toEqual(dived)
		-- The server's knockdown arrives: the dive is over and stops, as the server stops it, and the knockdown holds
		-- the skater.
		rig:SetAttribute(Attributes.KnockedDown, true)
		frame()
		expect(SkateController.diving).toBe(false)
		press("Uppercut")
		frame()
		expect(requests).toEqual(dived)
		rig:SetAttribute(Attributes.KnockedDown, nil)
		frame()
		press("Uppercut")
		frame()
		expect(requests).toEqual({ { action = "Tackle" }, { action = "Dive" }, { action = "Uppercut" } })
	end)

	it("frees a diver the server refused", function()
		setup()
		flying(Vector3.new(0, 0, -30))
		dive(frame)
		expect(SkateController.diving).toBe(true)
		ActionController:rejected({ action = "Dive" })
		expect(SkateController.diving).toBe(false)
	end)

	it("charges a throw for as long as it is held", function()
		setup()
		BallCarrier:set(LOCAL_ID)
		frame() -- the throw key seen up while holding the ball
		local throw = bindingOf("Throw")
		throw:Fire(true)
		for _ = 1, 30 do
			frame()
		end
		expect(#requests).toBe(0)
		throw:Fire(false)
		frame()
		expect(#requests).toBe(1)
		local request = requests[1]
		expect(request.action).toBe("ChargeThrow")
		Fixtures.expectNear(request.aim, CAMERA.CFrame.LookVector, 1e-6)
		expect(request.charge).toBeCloseTo(0.5, 6)
	end)

	it("keeps a throw released during a dodge for when the dodge ends", function()
		setup()
		BallCarrier:set(LOCAL_ID)
		frame() -- the throw key seen up while holding the ball
		local throw = bindingOf("Throw")
		throw:Fire(true)
		for _ = 1, 15 do
			frame()
		end
		-- A dodge, the throw still held for its first step.
		press("Tackle")
		frame()
		expect(requests).toEqual({ { action = "Dodge" } })
		throw:Fire(false)
		-- The dodge runs 0.5 s (30 steps).
		for _ = 1, 28 do
			frame()
		end
		expect(#requests).toBe(1)
		for _ = 1, 5 do
			frame()
		end
		expect(#requests).toBe(2)
		expect(requests[2].action).toBe("ChargeThrow")
		expect(requests[2].charge).toBeCloseTo(16 * DT, 6)
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
		expect(requests[1].charge).toBeCloseTo(10 * DT, 6)
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
		BallCarrier:set(LOCAL_ID)
		press("Pass")
		frame()
		BallCarrier:set(nil)
		press("Pass")
		frame()
		expect(#requests).toBe(2)
		expect(requests[1].action).toBe("Pass")
		Fixtures.expectNear(requests[1].aim, CAMERA.CFrame.LookVector, 1e-6)
		expect(requests[2]).toEqual({ action = "CallPass" })
	end)

	-- Roller Champions' uppercut launches on flat floor, away from any wall (#219): 110 studs/s up, about 31 studs.
	it("leaps up with an uppercut anywhere, on open floor as beside a wall", function()
		setup()
		frame()
		press("Uppercut")
		frame()
		expect(skater().mode).toBe("Airborne")
		expect(skater().velocity.Y).toBeCloseTo(110, 3)

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
		expect(skater().velocity.Y).toBeCloseTo(110, 3)
		expect(requests).toEqual({ { action = "Uppercut" }, { action = "Uppercut" } })
	end)

	it("does nothing while knocked down", function()
		setup()
		rig:SetAttribute(Attributes.KnockedDown, true)
		frame()
		press("Tackle")
		frame()
		expect(requests).toEqual({})
	end)

	it("spends the keys and resets the runner while frozen", function()
		setup()
		press("Tackle")
		frame()
		expect(ActionController.runner.action).toBe("Tackle")
		Fixtures.root(rig).Anchored = true
		press("Tackle")
		frame()
		expect(ActionController.runner.action).toBeNil()
		Fixtures.root(rig).Anchored = false
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
		local function names(): { [string]: string }
			local found: { [string]: string } = {}
			for _, key: Config.ActionKey in { "tackle", "uppercut", "pass", "throw" } :: { Config.ActionKey } do
				found[key] = ActionController:keyAction(key) or "none"
			end
			return found
		end
		expect(names()).toEqual({ tackle = "Tackle", uppercut = "Uppercut", pass = "CallPass", throw = "none" })
		BallCarrier:set(LOCAL_ID)
		expect(names()).toEqual({ tackle = "Dodge", uppercut = "none", pass = "Pass", throw = "ChargeThrow" })

		-- In the air the keys name the same (#240: the first press of the tackle key tackles there too).
		skater().mode = "Airborne"
		expect(names()).toEqual({ tackle = "Dodge", uppercut = "none", pass = "Pass", throw = "ChargeThrow" })
		BallCarrier:set(nil)
		expect(names()).toEqual({ tackle = "Tackle", uppercut = "Uppercut", pass = "CallPass", throw = "none" })
	end)

	-- Roller Champions (the owner's Video 4): "Dive" replaces "Tackle" 0.1-0.2 s after the press, and "Tackle" is back
	-- 0.9-1.0 s after it.
	it("names the dive for the tackle key only in the tackle's follow-up window, then tackles again", function()
		setup()
		press("Tackle")
		actionsOnly()
		expect(ActionController:keyAction("tackle")).toBe("Tackle")
		intoWindow(actionsOnly)
		expect(ActionController:keyAction("tackle")).toBe("Dive")
		-- Past the window, which closes as the tackle's cooldown ends (both at 1 s).
		for _ = 1, math.ceil((FOLLOW_UP.to - FOLLOW_UP.from) / DT) do
			actionsOnly()
		end
		expect(ActionController:keyAction("tackle")).toBe("Tackle")
		press("Tackle")
		actionsOnly()
		expect(requests).toEqual({ { action = "Tackle" }, { action = "Tackle" } })
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
		expect(total / 600).toBeLessThan(0.0001)
	end)
end)
