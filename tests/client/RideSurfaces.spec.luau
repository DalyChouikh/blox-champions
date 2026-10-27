--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local afterEach = JestGlobals.afterEach

local RideSurfaces = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.RideSurfaces)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

local folder: Folder?

afterEach(function()
	RideSurfaces:destroy()
	if folder then
		folder:Destroy()
		folder = nil
	end
end)

-- Whether rays through the shared filter can hit `part`.
local function hits(part: BasePart): boolean
	return table.find(RideSurfaces.params.FilterDescendantsInstances, part) ~= nil
end

describe("RideSurfaces", function()
	it("includes every tagged ride surface, and follows tags added and removed", function()
		local parent = Instance.new("Folder")
		parent.Name = "RideSurfacesTest"
		parent.Parent = workspace
		folder = parent
		local floor = Instance.new("Part")
		floor.Parent = parent
		floor:AddTag(Tags.RideSurface)
		local wall = Instance.new("Part")
		wall.Parent = parent

		RideSurfaces:init({})
		expect(RideSurfaces.params.FilterType).toBe(Enum.RaycastFilterType.Include)
		expect(hits(floor)).toBe(true)
		expect(hits(wall)).toBe(false)

		wall:AddTag(Tags.RideSurface)
		RideSurfaces:refresh()
		expect(hits(wall)).toBe(true)

		wall:RemoveTag(Tags.RideSurface)
		RideSurfaces:refresh()
		expect(hits(wall)).toBe(false)
	end)

	-- The arena is Persistent: it reaches a client whole, but after the client starts, and possibly after the
	-- player's character (#177).
	it("says whether the arena's surfaces have reached this client", function()
		RideSurfaces:init({})
		expect(RideSurfaces.ready).toBe(false)

		local parent = Instance.new("Folder")
		parent.Name = "RideSurfacesTest"
		parent.Parent = workspace
		folder = parent
		parent:AddTag(Tags.RideSurface)
		RideSurfaces:refresh()
		expect(RideSurfaces.ready).toBe(true)

		parent:RemoveTag(Tags.RideSurface)
		RideSurfaces:refresh()
		expect(RideSurfaces.ready).toBe(false)
	end)

	-- A barrier (the arena's top, Tags.Barrier) stops a skater's collider, but no ray looking for ground or a view sees
	-- it (A7).
	it("keeps the barriers out of every ray, and in the collider's sweep", function()
		local parent = Instance.new("Folder")
		parent.Name = "RideSurfacesTest"
		parent.Parent = workspace
		folder = parent
		local floor = Instance.new("Part")
		floor.Anchored = true
		floor.Size = Vector3.new(20, 1, 20)
		floor.CFrame = CFrame.new(0, -0.5, 0)
		floor.Parent = parent
		floor:AddTag(Tags.RideSurface)
		local barrier = Instance.new("Part")
		barrier.Anchored = true
		barrier.Size = Vector3.new(20, 1, 20)
		barrier.CFrame = CFrame.new(0, 5.5, 0)
		barrier.Parent = parent
		barrier:AddTag(Tags.Barrier)

		RideSurfaces:init({})
		RideSurfaces:start()
		local down = Vector3.new(0, -20, 0)
		local throughBarrier = workspace:Raycast(Vector3.new(0, 10, 0), down, RideSurfaces.params)
		expect(throughBarrier ~= nil and throughBarrier.Instance == floor).toBe(true)
		local intoBarrier = workspace:Raycast(Vector3.new(0, 10, 0), down, RideSurfaces.solid)
		expect(intoBarrier ~= nil and intoBarrier.Instance == barrier).toBe(true)

		-- A slab tagged later joins the sweep through the tag's signal, and leaves it the same way.
		local late = Instance.new("Part")
		late.Anchored = true
		late.Size = Vector3.new(20, 1, 20)
		late.CFrame = CFrame.new(30, 5.5, 0)
		late.Parent = parent
		late:AddTag(Tags.Barrier)
		task.wait()
		local intoLate = workspace:Raycast(Vector3.new(30, 10, 0), down, RideSurfaces.solid)
		expect(intoLate ~= nil and intoLate.Instance == late).toBe(true)
		late:RemoveTag(Tags.Barrier)
		task.wait()
		expect(workspace:Raycast(Vector3.new(30, 10, 0), down, RideSurfaces.solid)).toBeNil()
		expect(RideSurfaces.ready).toBe(true)
	end)
end)
