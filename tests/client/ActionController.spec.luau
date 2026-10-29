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
local Vectors = require(ReplicatedStorage.Shared.Util.Vectors)

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
-- The other skaters the skating sees (SkateController's views), reset before each test.
local others: { any } = {}

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
			return others
		end,
		SendSkateState = function() end,
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

-- Another skater standing at `position` (an Orange opponent unless `team` says otherwise): a character with a
-- root, as the skating's views show the other players.
local function standing(name: string, position: Vector3, team: string?): Model
	local character = Instance.new("Model")
	character.Name = name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Anchored = true
	root.CanCollide = false
	root.Size = Vector3.new(2, 2, 1)
	root.Position = position
	root.Parent = character
	character.Parent = folder
	table.insert(others, { player = name, team = team or "Orange", root = root })
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
	others = {}
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

		-- In the air the keys name the same (#240: the first press of the tackle key tackles there too), but the
		-- uppercut key nothing: the Uppercut starts only from a surface (#262: RC greys it in the air).
		skater().mode = "Airborne"
		expect(names()).toEqual({ tackle = "Dodge", uppercut = "none", pass = "Pass", throw = "ChargeThrow" })
		BallCarrier:set(nil)
		expect(names()).toEqual({ tackle = "Tackle", uppercut = "none", pass = "CallPass", throw = "none" })
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

describe("ActionController's magnetic strikes (#277)", function()
	local HOVER = movement.hoverHeight
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
		skater().velocity = Vector3.new(0, 0, -30)
		press("Tackle")
		actionsOnly()
		expect(across(skater().forward):Dot(-Vector3.zAxis)).toBeGreaterThan(0.999)
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
