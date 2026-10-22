--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Builder = require(game:GetService("ServerScriptService").Server.Arena.Builder)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Geometry = require(ReplicatedStorage.Shared.Arena.Geometry)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

local config = Config.defaults()
local parent: Folder
beforeEach(function()
	parent = Instance.new("Folder")
	parent.Name = "BuilderTest"
	parent.Parent = ServerStorage
end)
afterEach(function()
	parent:Destroy()
end)

local function folder(arena: Instance, name: string): Folder
	return arena:FindFirstChild(name) :: Folder
end

describe("Builder.build", function()
	it("builds one part per piece, grouped by what it is", function()
		local arena = Builder.build(Geometry.build(config), config, parent)
		expect(arena.Parent).toBe(parent)
		expect(#folder(arena, "Surface"):GetChildren()).toBe(6900)
		expect(#folder(arena, "Infield"):GetChildren()).toBe(193)
		expect(#folder(arena, "Gates"):GetChildren()).toBe(4)
		expect(#folder(arena, "Markers"):GetChildren()).toBe(4)
		expect(#folder(arena, "Spawns"):GetChildren()).toBe(8)
		local hoop = folder(arena, "Goal"):FindFirstChild("GoalHoop") :: Model
		expect(#hoop:GetChildren()).toBe(16)
	end)

	it("makes gates and spawns invisible to physics and queries, and solids smooth and anchored", function()
		local arena = Builder.build(Geometry.build(config), config, parent)
		local gate = folder(arena, "Gates"):FindFirstChild("Gate2") :: Part
		expect(gate.Transparency).toBe(1)
		expect(gate.CanCollide or gate.CanQuery or gate.CanTouch).toBe(false)
		expect(gate:GetAttribute("GateIndex")).toBe(2)
		local pad = folder(arena, "Spawns"):FindFirstChild("Blue1") :: Part
		expect(pad.CanCollide or pad.CanQuery or pad.CanTouch).toBe(false)
		expect(pad.Color).toEqual(config.UI.teamColors.Blue)
		for _, part in folder(arena, "Surface"):GetChildren() do
			local solid = part :: BasePart
			if not (solid.Anchored and solid.CanCollide and solid.TopSurface == Enum.SurfaceType.Smooth) then
				error(`{solid.Name} is not an anchored, colliding, smooth part`)
			end
		end
	end)

	it("tags the riding surfaces so skaters' rays find only them", function()
		local arena = Builder.build(Geometry.build(config), config, parent)
		local tagged: { string } = {}
		for _, instance in arena:GetDescendants() do
			if instance:HasTag(Tags.RideSurface) then
				table.insert(tagged, instance.Name)
			end
		end
		table.sort(tagged)
		expect(tagged).toEqual({ "Infield", "Surface" })
	end)

	it("sends the whole arena to every client and never streams it out", function()
		local arena = Builder.build(Geometry.build(config), config, parent)
		expect(arena.ModelStreamingMode).toBe(Enum.ModelStreamingMode.Persistent)
	end)

	it("takes the tag-only parts' sizes and the goal panel's transparency from config", function()
		local custom = Fixtures.config({
			Arena = {
				gateThickness = 0.5,
				spawnPad = { width = 6, thickness = 0.3, transparency = 0.2 },
				ballSpawnSize = 2,
				goal = { panelTransparency = 0.6 },
			},
		})
		local arena = Builder.build(Geometry.build(custom), custom, parent)
		expect((folder(arena, "Gates"):FindFirstChild("Gate1") :: Part).Size.Z).toBeCloseTo(0.5, 4)
		local pad = folder(arena, "Spawns"):FindFirstChild("Orange2") :: Part
		expect(pad.Size).toEqual(Vector3.new(6, 0.3, 6))
		expect(pad.Transparency).toBeCloseTo(0.2, 4)
		expect((folder(arena, "Spawns"):FindFirstChild("Ball1") :: Part).Size).toEqual(Vector3.new(2, 2, 2))
		expect((folder(arena, "Goal"):FindFirstChild("GoalPanel") :: Part).Transparency).toBeCloseTo(0.6, 4)
	end)

	it("leaves nothing behind when a piece is invalid", function()
		local geometry = Geometry.build(config)
		local broken = table.clone(geometry)
		broken.surface = table.clone(geometry.surface)
		broken.surface[2] = { shape = "Block", cframe = CFrame.identity, size = Vector3.new(0, 1, 1) }
		expect(function()
			Builder.build(broken, config, parent)
		end).toThrow("ArenaBuilder: surface piece 2 is invalid (size 0, 1, 1)")
		local adrift = table.clone(geometry)
		adrift.infield = { { shape = "Block", cframe = CFrame.new(0 / 0, 0, 0), size = Vector3.one } }
		expect(function()
			Builder.build(adrift, config, parent)
		end).toThrow("ArenaBuilder: infield piece 1 is invalid (cframe ")
		-- Roblox would silently clamp it to 2048, leaving a hole.
		local oversized = table.clone(geometry)
		oversized.markers = { { shape = "Block", cframe = CFrame.identity, size = Vector3.new(3000, 1, 1) } }
		expect(function()
			Builder.build(oversized, config, parent)
		end).toThrow("ArenaBuilder: marker piece 1 is invalid (size 3000, 1, 1)")
		expect(#parent:GetChildren()).toBe(0)
	end)
end)
