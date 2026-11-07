--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Arena = require(ReplicatedStorage.Shared.Config.Arena)
local Builder = require(ServerScriptService.Server.Arena.Builder)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Geometry = require(ReplicatedStorage.Shared.Arena.Geometry)
local GoalLook = require(ServerScriptService.Server.GoalLook)
local TaggedLayout = require(ReplicatedStorage.Shared.Arena.TaggedLayout)

local config = Fixtures.config()
local meshes = config.Arena.goal.meshes
-- The four mesh ids in the build's order, the one they are asked for in.
local IDS = { meshes.Shell, meshes.Strips, meshes.Lip, meshes.Band }

local parent: Folder
-- The mesh ids asked for, and the lines logged, since the last init.
local asked: { string }
-- Whether each mesh asked for was asked for as solid, in the same order.
local solids: { boolean }
local logged: { string }

-- An arena as ArenaService builds one, and GoalLook started on it with a mesh maker that never reaches Roblox: an
-- empty MeshPart, or what `make` does. Returns the arena's Goal folder.
local function init(make: ((id: string) -> MeshPart)?): Folder
	asked, solids, logged = {}, {}, {}
	local arena = Builder.build(Geometry.build(config), config, parent)
	GoalLook:init({
		Config = config,
		ArenaService = { model = arena, arena = TaggedLayout.read(arena) },
		MakeMesh = function(id: string, solid: boolean): MeshPart
			table.insert(asked, id)
			table.insert(solids, solid)
			return if make ~= nil then make(id) else Instance.new("MeshPart")
		end,
		Log = function(line: string)
			table.insert(logged, line)
		end,
	})
	return arena:FindFirstChild("Goal") :: Folder
end

-- Whether the ring's blocks are the goal's look (shown) or hidden under its meshes.
local function blocksShow(goal: Folder): boolean
	for _, block in (goal:FindFirstChild("GoalHoop") :: Model):GetChildren() do
		if (block :: BasePart).Transparency ~= 0 then
			return false
		end
	end
	return true
end

beforeEach(function()
	parent = Instance.new("Folder")
	parent.Name = "GoalLookTest"
	parent.Parent = ServerStorage
end)

afterEach(function()
	parent:Destroy()
end)

-- #410 (the owner's Q314-Q315): the Halo pylon, four meshes made once in Blender, on the goal the arena was built with.
describe("GoalLook", function()
	it("dresses the arena's goal in its four meshes, each asked for once in the build's order", function()
		local goal = init()
		task.wait()
		expect(asked).toEqual(IDS)
		-- The housing and pylon are solid (#422, Q335-Q337); the strips, lip and band only draw.
		expect(solids).toEqual({ true, false, false, false })
		local look = goal:FindFirstChild("GoalLook")
		expect(look).never.toBeNil()
		for _, name in Arena.goalPieces do
			expect(((look :: Model):FindFirstChild(name) :: MeshPart):IsA("MeshPart")).toBe(true)
		end
		expect(blocksShow(goal)).toBe(false)
		-- The door shuts the opening in the panel's place (Q324).
		expect((look :: Model):FindFirstChild("GoalDoor") ~= nil).toBe(true)
		expect((goal:FindFirstChild("GoalPanel") :: BasePart).Transparency).toBe(1)
		expect(logged).toEqual({})
	end)

	-- Found in Play (#400): a start held up by a mesh's download let Roblox load a joining player's default character.
	it("never holds up the start: the ring's blocks show until every mesh has come", function()
		local arrived = Instance.new("BindableEvent")
		local goal = init(function(_id: string): MeshPart
			arrived.Event:Wait()
			return Instance.new("MeshPart")
		end)
		expect(asked).toEqual({ IDS[1] })
		for _ = 1, #IDS - 1 do
			arrived:Fire()
			task.wait()
			expect(goal:FindFirstChild("GoalLook")).toBeNil()
			expect(blocksShow(goal)).toBe(true)
		end
		arrived:Fire()
		task.wait()
		expect(goal:FindFirstChild("GoalLook") ~= nil).toBe(true)
		expect(blocksShow(goal)).toBe(false)
		arrived:Destroy()
	end)

	it("keeps the ring's blocks as the goal's look when a mesh does not load, and says so once", function()
		local goal = init(function(id: string): MeshPart
			if id == meshes.Lip then
				error("HTTP 403 (Forbidden)")
			end
			return Instance.new("MeshPart")
		end)
		task.wait()
		expect(asked).toEqual({ IDS[1], IDS[2], IDS[3] })
		expect(goal:FindFirstChild("GoalLook")).toBeNil()
		expect(blocksShow(goal)).toBe(true)
		expect(#logged).toBe(1)
		local said = logged[1]
		local opening = `GoalLook: the goal's mesh {meshes.Lip} did not load`
		expect(string.find(said, opening, 1, true) ~= nil).toBe(true)
		expect(string.find(said, "HTTP 403 (Forbidden)", 1, true) ~= nil).toBe(true)
	end)

	it("lets a download from before a new start change nothing", function()
		local arrived = Instance.new("BindableEvent")
		local before = init(function(_id: string): MeshPart
			arrived.Event:Wait()
			return Instance.new("MeshPart")
		end)
		local after = init()
		for _ = 1, #IDS do
			arrived:Fire()
			task.wait()
		end
		expect(before:FindFirstChild("GoalLook")).toBeNil()
		expect(blocksShow(before)).toBe(true)
		expect(after:FindFirstChild("GoalLook") ~= nil).toBe(true)
		arrived:Destroy()
	end)

	it("says nothing of a download from before a new start that does not load", function()
		local arrived = Instance.new("BindableEvent")
		init(function(_id: string): MeshPart
			arrived.Event:Wait()
			error("offline")
		end)
		local after = init()
		arrived:Fire()
		task.wait()
		expect(logged).toEqual({})
		expect(after:FindFirstChild("GoalLook") ~= nil).toBe(true)
		arrived:Destroy()
	end)
end)
