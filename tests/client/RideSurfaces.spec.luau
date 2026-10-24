--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local afterEach = JestGlobals.afterEach

local RideSurfaces = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.RideSurfaces)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

local folder: Folder?

afterEach(function()
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
end)
