--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect, afterEach = JestGlobals.describe, JestGlobals.it, JestGlobals.expect, JestGlobals.afterEach

local TaggedLayout = require(ReplicatedStorage.Shared.Arena.TaggedLayout)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

local roots: { Instance } = {}
afterEach(function()
	for _, root in roots do
		root:Destroy()
	end
	table.clear(roots)
end)

local function tagged(parent: Instance, name: string, tag: string, cframe: CFrame?, size: Vector3?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.CFrame = cframe or CFrame.identity
	part.Size = size or Vector3.one
	part:AddTag(tag)
	part.Parent = parent
	return part
end

local function child(root: Instance, name: string): Instance
	return root:FindFirstChild(name) :: Instance
end

-- A corner marker as the arena builder makes one: a model of glass panes, pivoted at its wall's middle.
local function markerModel(parent: Instance, name: string, index: number): Model
	local model = Instance.new("Model")
	model.Name = name
	for pane = 1, 2 do
		local part = Instance.new("Part")
		part.Name = `Pane{pane}`
		part.Parent = model
	end
	model.WorldPivot = CFrame.new(100 * index, 60, 0)
	model:SetAttribute(Tags.Attribute.GateIndex, index)
	model:AddTag(Tags.CornerMarker)
	model.Parent = parent
	return model
end

-- A complete minimal arena, gates created in reverse so reading must sort them.
local function arenaRoot(): Folder
	local root = Instance.new("Folder")
	root.Name = "TaggedLayoutTest"
	for index = 4, 1, -1 do
		local gate =
			tagged(root, "Gate" .. index, Tags.LapGate, CFrame.new(100 * index, 0, 0), Vector3.new(44, 28, 0.2))
		gate:SetAttribute(Tags.Attribute.GateIndex, index)
		markerModel(root, "Marker" .. index, index)
	end
	local hoop = Instance.new("Model")
	hoop.Name = "GoalHoop"
	hoop.WorldPivot = CFrame.new(0, 18, -73)
	hoop:SetAttribute(Tags.Attribute.OpeningRadius, 7)
	hoop:AddTag(Tags.GoalHoop)
	hoop.Parent = root
	tagged(root, "GoalPanel", Tags.GoalPanel)
	tagged(root, "Blue1", Tags.TeamSpawn, CFrame.new(0, 0, -53)):SetAttribute(Tags.Attribute.Team, "Blue")
	tagged(root, "Orange1", Tags.TeamSpawn, CFrame.new(0, 0, 53)):SetAttribute(Tags.Attribute.Team, "Orange")
	tagged(root, "Ball1", Tags.BallSpawn, CFrame.new(-140, 6, 0))
	root.Parent = ServerStorage
	table.insert(roots, root)
	return root
end

describe("TaggedLayout.read", function()
	it("reads the gates in GateIndex order as rectangles the rules can use", function()
		local gates = TaggedLayout.read(arenaRoot()).layout.gates
		expect(#gates).toBe(4)
		for index, gate in gates do
			expect(gate.frame.Position).toEqual(Vector3.new(100 * index, 0, 0))
			expect(gate.width).toBe(44)
			expect(gate.height).toBe(28)
		end
	end)

	it("reads the goal's disc and panel, the markers, and the spawns in name order", function()
		local root = arenaRoot()
		-- Tagged out of name order (Blue1, at x 0, came first), so only sorting by name reads them in order.
		for _, index in { 3, 0, 4, 2 } do
			local pad = tagged(root, `Blue{index}`, Tags.TeamSpawn, CFrame.new(10 * (index - 1), 0, -53))
			pad:SetAttribute(Tags.Attribute.Team, "Blue")
		end
		local arena = TaggedLayout.read(root)
		expect(arena.layout.goal.frame.Position).toEqual(Vector3.new(0, 18, -73))
		expect(arena.layout.goal.radius).toBe(7)
		expect(arena.goalPanel.Name).toBe("GoalPanel")
		expect(#arena.markers).toBe(4)
		expect(arena.markers[2].Name).toBe("Marker2")
		expect(arena.markers[2]:GetPivot().Position).toEqual(Vector3.new(200, 60, 0))
		expect(#arena.teamSpawns.Blue).toBe(5)
		for position, frame in arena.teamSpawns.Blue do
			-- Blue0 first, at x -10.
			expect(frame.Position).toEqual(Vector3.new(10 * (position - 2), 0, -53))
		end
		expect(arena.teamSpawns.Orange[1].Position).toEqual(Vector3.new(0, 0, 53))
		expect(arena.ballSpawns[1].Position).toEqual(Vector3.new(-140, 6, 0))
	end)

	-- An art pass may tag a single part instead of a model.
	it("reads a corner marker that is a model or a part", function()
		local root = arenaRoot()
		child(root, "Marker3"):Destroy()
		tagged(root, "Marker3", Tags.CornerMarker, CFrame.new(300, 20, 0)):SetAttribute(Tags.Attribute.GateIndex, 3)
		local markers = TaggedLayout.read(root).markers
		expect(#markers).toBe(4)
		expect(markers[2]:IsA("Model")).toBe(true)
		expect(markers[3]:IsA("BasePart")).toBe(true)
		expect(markers[3]:GetPivot().Position).toEqual(Vector3.new(300, 20, 0))
	end)

	it("ignores tagged instances outside the root", function()
		local root = arenaRoot()
		local stray = Instance.new("Folder")
		stray.Name = "TaggedLayoutStrayTest"
		tagged(stray, "Gate5", Tags.LapGate):SetAttribute(Tags.Attribute.GateIndex, 5)
		stray.Parent = ServerStorage
		table.insert(roots, stray)
		expect(#TaggedLayout.read(root).layout.gates).toBe(4)
	end)

	it("rejects gates whose GateIndex values have gaps or repeats", function()
		local root = arenaRoot()
		child(root, "Gate3"):SetAttribute(Tags.Attribute.GateIndex, 4)
		expect(function()
			TaggedLayout.read(root)
		end).toThrow("TaggedLayout: LapGate GateIndex values must be 1..n without gaps or repeats (got 1, 2, 4, 4)")
	end)

	it("rejects a missing goal and a second panel", function()
		local root = arenaRoot()
		tagged(root, "ExtraPanel", Tags.GoalPanel)
		expect(function()
			TaggedLayout.read(root)
		end).toThrow("TaggedLayout: expected exactly one GoalPanel, found 2")
		local other = arenaRoot()
		child(other, "GoalHoop"):Destroy()
		expect(function()
			TaggedLayout.read(other)
		end).toThrow("TaggedLayout: expected exactly one GoalHoop, found 0")
	end)

	it("rejects a goal without an opening radius and a spawn with an unknown team", function()
		local root = arenaRoot()
		child(root, "GoalHoop"):SetAttribute(Tags.Attribute.OpeningRadius, nil)
		expect(function()
			TaggedLayout.read(root)
		end).toThrow("TaggedLayout: GoalHoop needs a positive OpeningRadius attribute")
		local other = arenaRoot()
		child(other, "Blue1"):SetAttribute(Tags.Attribute.Team, "Red")
		expect(function()
			TaggedLayout.read(other)
		end).toThrow('TaggedLayout: TeamSpawn "Blue1" has Team "Red"; expected Blue or Orange')
	end)

	it("rejects a tagged non-part, a gate without an index, an arena with no gates and a team with no spawn", function()
		local root = arenaRoot()
		-- Of several, the first by name is the one named, whatever order they were tagged in.
		for _, name in { "Gate9", "Gate7", "Gate8" } do
			local folder = Instance.new("Folder")
			folder.Name = name
			folder:AddTag(Tags.LapGate)
			folder.Parent = root
		end
		expect(function()
			TaggedLayout.read(root)
		end).toThrow('TaggedLayout: LapGate "Gate7" must be a part (got Folder)')
		local markerFolder = arenaRoot()
		local stray = Instance.new("Folder")
		stray.Name = "Marker9"
		stray:SetAttribute(Tags.Attribute.GateIndex, 9)
		stray:AddTag(Tags.CornerMarker)
		stray.Parent = markerFolder
		expect(function()
			TaggedLayout.read(markerFolder)
		end).toThrow('TaggedLayout: CornerMarker "Marker9" must be a model or a part (got Folder)')
		local function withGate2Index(index: any): Folder
			local unnumbered = arenaRoot()
			child(unnumbered, "Gate2"):SetAttribute(Tags.Attribute.GateIndex, index)
			return unnumbered
		end
		for _, unnumbered in { withGate2Index(nil), withGate2Index(0 / 0), withGate2Index(2.5) } do
			expect(function()
				TaggedLayout.read(unnumbered)
			end).toThrow('TaggedLayout: LapGate "Gate2" needs a whole-number GateIndex attribute')
		end
		local gateless = arenaRoot()
		for index = 1, 4 do
			child(gateless, "Gate" .. index):Destroy()
		end
		expect(function()
			TaggedLayout.read(gateless)
		end).toThrow("TaggedLayout: no LapGate found")
		local teamless = arenaRoot()
		child(teamless, "Orange1"):Destroy()
		expect(function()
			TaggedLayout.read(teamless)
		end).toThrow("TaggedLayout: no TeamSpawn found for Orange")
	end)

	it("rejects markers that don't match the gates and an arena with no ball spawn", function()
		local root = arenaRoot()
		child(root, "Marker4"):Destroy()
		expect(function()
			TaggedLayout.read(root)
		end).toThrow("TaggedLayout: CornerMarker GateIndex values must match the gates (got 1, 2, 3)")
		local other = arenaRoot()
		child(other, "Ball1"):Destroy()
		expect(function()
			TaggedLayout.read(other)
		end).toThrow("TaggedLayout: no BallSpawn found")
	end)
end)
