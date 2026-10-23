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
local SkateController = require(Client.SkateController)
local SkaterBody = require(ServerScriptService.Server.SkaterBody)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

local config = Config.defaults()
local movement = config.Movement
local DT = 1 / 60
-- Looking toward -Z from behind the skater, so the skater's right is the camera's right, +X.
local CAMERA = { CFrame = CFrame.lookAt(Vector3.new(0, 5, 10), Vector3.new(0, 5, 0)) }
local LOCAL_ID = "1"

local folder: Folder
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
	InputController:init({ Config = config, Parent = folder })
	BallCarrier:init({})
	SkateController:init({
		Config = config,
		InputController = InputController,
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

	it("dives when tackle is pressed again during the tackle", function()
		setup()
		press("Tackle")
		frame()
		-- Past the tackle's 0.05 s windup.
		for _ = 1, 4 do
			frame()
		end
		press("Tackle")
		frame()
		expect(requests).toEqual({ { action = "Tackle" }, { action = "Dive" } })
		-- Into the dive's recovery, after its 0.35 s active phase: nothing more starts.
		for _ = 1, 25 do
			frame()
		end
		press("Tackle")
		frame()
		expect(#requests).toBe(2)
	end)

	it("charges a throw for as long as it is held", function()
		setup()
		BallCarrier:set(LOCAL_ID)
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

	it("leaps off a wall with an uppercut, and only near one", function()
		-- A wall facing the skater, 4 studs ahead.
		local wall: BasePart = Instance.new("Part")
		wall.Anchored = true
		wall.Size = Vector3.new(20, 10, 1)
		wall.CFrame = CFrame.new(0, 5, -4.5)
		setup({ wall })
		frame()
		press("Uppercut")
		frame()
		expect(skater().mode).toBe("Airborne")
		expect(skater().velocity.Y).toBeCloseTo(110, 3)

		wall:Destroy()
		skater():stop()
		ActionController.runner:reset()
		press("Uppercut")
		frame()
		expect(skater().mode).toBe("Grounded")
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
