--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local InputController = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.InputController)
local SkateController = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.SkateController)
local SkaterBody = require(ServerScriptService.Server.SkaterBody)
local SkateMath = require(ReplicatedStorage.Shared.Skate.SkateMath)
local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

local config = Config.defaults()
local movement = config.Movement
-- Looking toward -Z, so the stick's forward is -Z.
local CAMERA = { CFrame = CFrame.lookAt(Vector3.new(0, 5, 10), Vector3.new(0, 5, 0)) }

local folder: Folder
local floor: Folder
local rig: Model
local sent: { { boolean } }
local others: { any }

local function root(model: Model): BasePart
	return model.PrimaryPart :: BasePart
end

local function velocityOf(model: Model): Vector3
	return (root(model):FindFirstChild(SkaterRig.velocity) :: LinearVelocity).VectorVelocity
end

local function alignOf(model: Model): AlignOrientation
	return root(model):FindFirstChild(SkaterRig.align) :: AlignOrientation
end

-- A rig with its skater body, its root at hoverHeight above `ground`.
local function skaterAt(name: string, ground: Vector3): Model
	local model = Fixtures.rig(folder, name, CFrame.new(ground + Vector3.new(0, movement.hoverHeight, 0)))
	SkaterBody.build(model, movement)
	return model
end

local function action(name: string): InputAction
	return InputController.context:FindFirstChild(name) :: InputAction
end

local function setup(overrides: { [string]: any }?)
	local deps: { [string]: any } = {
		Config = config,
		InputController = InputController,
		Camera = CAMERA,
		Skaters = function(): { any }
			return others
		end,
		SendSkateState = function(pump: boolean, brake: boolean)
			table.insert(sent, { pump, brake })
		end,
		Gravity = Fixtures.GRAVITY,
		Team = function(): string?
			return "Blue"
		end,
	}
	local extra: { [string]: any } = overrides or {}
	for key, value in extra do
		deps[key] = value
	end
	SkateController:init(deps)
end

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "SkateControllerTest"
	folder.Parent = workspace
	-- Only the floor is a ride surface: the skater's own parts must never be.
	floor = Instance.new("Folder")
	floor.Name = "Floor"
	local slab = Instance.new("Part")
	slab.Anchored = true
	slab.Size = Vector3.new(400, 1, 400)
	slab.CFrame = CFrame.new(0, -0.5, 0)
	slab.Parent = floor
	floor.Parent = folder
	floor:AddTag(Tags.RideSurface)
	sent = {}
	others = {}
	InputController:init({ Config = config, Parent = folder })
	rig = skaterAt("Skater", Vector3.zero)
	setup()
	SkateController:bind(rig)
end)
afterEach(function()
	InputController:destroy()
	folder:Destroy()
end)

describe("SkateController", function()
	it("takes over a character and drives its skater body from the stick", function()
		expect((rig:FindFirstChildOfClass("Humanoid") :: Humanoid).EvaluateStateMachine).toBe(false)
		Fixtures.scriptedBinding(action("Move")):Fire(Vector2.new(0, 1))
		SkateController:step(0.1)
		Fixtures.expectNear(velocityOf(rig), Vector3.new(0, 0, -2.594)) -- SkateMath's first push, at hover height
		Fixtures.expectNear(alignOf(rig).SecondaryAxis, Vector3.yAxis)
		Fixtures.expectNear(alignOf(rig).PrimaryAxis, Vector3.xAxis)
	end)

	it("holds still while the root is anchored, then starts from rest", function()
		Fixtures.scriptedBinding(action("Move")):Fire(Vector2.new(0, 1))
		for _ = 1, 10 do
			SkateController:step(0.1)
		end
		root(rig).Anchored = true
		SkateController:step(0.1)
		Fixtures.expectNear((SkateController.skater :: any).velocity, Vector3.zero)
		root(rig).Anchored = false
		SkateController:step(0.1)
		Fixtures.expectNear(velocityOf(rig), Vector3.new(0, 0, -2.594))
	end)

	it("falls when no riding surface is below", function()
		rig:PivotTo(CFrame.new(1000, 50, 1000))
		SkateController:step(0.1)
		expect((SkateController.skater :: any).mode).toBe("Airborne")
		Fixtures.expectNear(velocityOf(rig), Vector3.new(0, -19.5808, 0))
	end)

	it("drives a new character after a respawn", function()
		Fixtures.scriptedBinding(action("Move")):Fire(Vector2.new(0, 1))
		SkateController:step(0.1)
		local before = velocityOf(rig)
		local respawned = skaterAt("Respawned", Vector3.new(50, 0, 0))
		SkateController:bind(respawned)
		SkateController:step(0.1)
		Fixtures.expectNear(velocityOf(respawned), Vector3.new(0, 0, -2.594))
		Fixtures.expectNear(velocityOf(rig), before)
	end)

	it("tells the server about pump and brake only when they change", function()
		local pump = Fixtures.scriptedBinding(action("Pump"))
		pump:Fire(true)
		for _ = 1, 3 do
			SkateController:step(1 / 60)
		end
		expect(sent).toEqual({ { true, false } })
		pump:Fire(false)
		SkateController:step(1 / 60)
		expect(sent).toEqual({ { true, false }, { false, false } })
	end)

	it("ignores one seam ray's side face, so the skater's up holds", function()
		-- Measured in Phase 3: a downward ray exactly on a seam of the step hit a slab's side face.
		local seam = Vector3.new(0, 0.49, -0.87)
		local normals = { Vector3.yAxis, Vector3.yAxis, seam, Vector3.yAxis }
		local ray = 0
		setup({
			Raycast = function(): any
				ray += 1
				return { Normal = normals[ray], Distance = movement.hoverHeight }
			end,
		})
		SkateController:bind(rig)
		local turnCos = math.cos(math.rad(movement.normalFilter.maxTurnDeg))
		for _ = 1, #normals do
			-- Faster than minWallSpeed, so a steep normal would be ridden rather than fallen from.
			local riding = SkateController.skater :: any
			riding.velocity = Vector3.new(60, 0, 0)
			SkateController:step(1 / 60)
			expect(riding.up:Dot(Vector3.yAxis) >= turnCos).toBe(true)
		end
	end)

	it("steps in under half a millisecond", function()
		local spots: { { any } } = {
			{ Vector3.new(0, 0, -5), "Blue" },
			{ Vector3.new(3, 0, -6), "Blue" },
			{ Vector3.new(-8, 0, 4), "Orange" },
			{ Vector3.new(10, 0, -12), "Orange" },
			{ Vector3.new(-4, 0, -15), "Orange" },
		}
		for index, spot in spots do
			local other = skaterAt(`Other{index}`, spot[1])
			root(other).AssemblyLinearVelocity = Vector3.new(0, 0, -40)
			table.insert(others, { player = tostring(index + 1), team = spot[2], root = root(other) })
		end
		Fixtures.scriptedBinding(action("Move")):Fire(Vector2.new(0, 1))
		Fixtures.scriptedBinding(action("Pump")):Fire(true)
		local started = os.clock()
		for _ = 1, 600 do
			SkateController:step(1 / 60)
		end
		expect((os.clock() - started) / 600).toBeLessThan(0.0005)
	end)
end)

-- The controller over an arc of roof (A3): its ray returns the arc's normal, and the test drives the skater along it.
describe("SkateController over the roof", function()
	local RADIUS = 22
	local DT = 1 / 60

	-- Whether the skater stays on from level up to the top of the arc at `speed`. With `strips`, the roof is that many
	-- flat strips over the half circle, as the arena builds it, so the ray's normal turns only at strip edges.
	local function holdsOverTheTop(speed: number, strips: number?): boolean
		local phi = 0
		setup({
			Raycast = function(): any
				local facing = phi
				if strips ~= nil then
					local width = math.pi / strips
					facing = (math.floor(phi / width) + 0.5) * width
				end
				local normal = Vector3.new(-math.cos(facing), -math.sin(facing), 0)
				return { Normal = normal, Distance = movement.hoverHeight }
			end,
		})
		SkateController:bind(rig)
		local skater = SkateController.skater :: SkateMath.Skater
		local step = speed * DT / RADIUS
		for frame = 0, math.ceil((math.pi / 2) / step) do
			phi = frame * step
			skater.velocity = Vector3.new(-math.sin(phi), math.cos(phi), 0) * speed
			SkateController:step(DT)
			if skater.mode == "Airborne" then
				return false
			end
		end
		return true
	end

	it("holds a skater over the top of the roof at 70 studs/s and drops one at 60, as the loop rule says", function()
		expect(holdsOverTheTop(70)).toBe(true)
		expect(holdsOverTheTop(60)).toBe(false)
	end)

	it("does the same over the arena's roof of 21 flat strips, through its own normal filter", function()
		expect(holdsOverTheTop(70, 21)).toBe(true)
		expect(holdsOverTheTop(60, 21)).toBe(false)
	end)
end)
