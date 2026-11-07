--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local ArenaParts = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.ArenaParts)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local Tags = require(ReplicatedStorage.Shared.Arena.Tags)

local folder: Folder

beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "ArenaPartsTest"
	folder.Parent = workspace
	ArenaParts:init({})
end)

afterEach(function()
	ArenaParts:destroy()
	folder:Destroy()
end)

describe("ArenaParts", function()
	-- Where a throw through the goal ring aims (#313): the hoop's opening, read as the arena's layout reads it.
	it("holds the goal ring's opening, and no parts while the hoop has no opening radius", function()
		local arena = Fixtures.hudArena(folder)
		ArenaParts:refresh()
		local goal = (ArenaParts.parts :: any).goal
		expect(goal.frame == arena.hoop:GetPivot()).toBe(true)
		expect(goal.radius).toBe(arena.hoop:GetAttribute(Tags.Attribute.OpeningRadius))
		arena.hoop:SetAttribute(Tags.Attribute.OpeningRadius, nil)
		ArenaParts:refresh()
		expect(ArenaParts.parts).toBeNil()
	end)

	it("finds the corner markers by gate index, the goal's glow and its panel once the arena is there", function()
		expect(ArenaParts.parts).toBeNil()
		local arena = Fixtures.hudArena(folder)
		ArenaParts:refresh()
		local parts = ArenaParts.parts :: any
		expect(parts ~= nil).toBe(true)
		-- A marker model's panes, and its pivot: where the carrier's arrow points.
		for index = 1, 4 do
			local marker = parts.markers[index]
			expect(#marker.parts).toBe(2)
			for _, pane in marker.parts do
				expect(pane.Parent == arena.markers[index]).toBe(true)
			end
			Fixtures.expectNear(marker.position, arena.markers[index]:GetPivot().Position)
		end
		-- The ring's blocks, until the goal's meshes come.
		expect(#parts.glow).toBe(2)
		expect(table.find(parts.glow, arena.rim[1]) ~= nil and table.find(parts.glow, arena.rim[2]) ~= nil).toBe(true)
		expect(parts.panel == arena.panel).toBe(true)

		-- A marker that is a single part (an art pass may tag one): its parts are itself, its position its own.
		arena.markers[3]:Destroy()
		local single = Instance.new("Part")
		single.Anchored = true
		single.Position = Vector3.new(300, 20, 0)
		single:SetAttribute(Tags.Attribute.GateIndex, 3)
		single:AddTag(Tags.CornerMarker)
		single.Parent = folder
		ArenaParts:refresh()
		local three = (ArenaParts.parts :: any).markers[3]
		expect(#three.parts == 1 and three.parts[1] == single).toBe(true)
		Fixtures.expectNear(three.position, single.Position)

		-- A new record whenever the arena changes, so readers see it; none once it is gone.
		arena.panel:Destroy()
		ArenaParts:refresh()
		expect(ArenaParts.parts).toBeNil()
	end)

	it("follows the arena's tags from start on, with a new record each time the arena changes", function()
		ArenaParts:start()
		local arena = Fixtures.hudArena(folder)
		-- Tag signals are deferred: they run at the next yield.
		task.wait()
		local first = ArenaParts.parts
		expect(first ~= nil).toBe(true)
		arena.markers[4]:Destroy()
		task.wait()
		local second = ArenaParts.parts :: any
		expect(second ~= nil and second ~= first).toBe(true)
		expect(second.markers[4]).toBeNil()
		arena.panel:Destroy()
		task.wait()
		expect(ArenaParts.parts).toBeNil()
	end)

	-- #410: the goal's meshes reach a client after the arena; the server moves the glow from the ring's blocks to the
	-- goal's lip (Builder.dressGoal), and the arena's parts follow it.
	it("follows what glows when the goal opens: the ring's blocks, then the goal's lip once its meshes come", function()
		ArenaParts:start()
		local arena = Fixtures.hudArena(folder)
		task.wait()
		local before = ArenaParts.parts :: any
		expect(#before.glow).toBe(2)
		local lip = Instance.new("Part")
		lip.Name = "Lip"
		lip.Anchored = true
		lip:AddTag(Tags.GoalGlow)
		lip.Parent = folder
		arena.hoop:RemoveTag(Tags.GoalGlow)
		task.wait()
		local after = ArenaParts.parts :: any
		expect(after ~= before).toBe(true)
		expect(#after.glow == 1 and after.glow[1] == lip).toBe(true)
		-- Nothing glowing is not a broken arena: the goal is still there to aim at.
		lip:RemoveTag(Tags.GoalGlow)
		task.wait()
		local none = ArenaParts.parts :: any
		expect(none ~= nil and #none.glow == 0).toBe(true)
	end)

	-- Q324: the goal's door comes with its meshes (Builder.dressGoal), after the arena.
	it("follows the goal's door: no bars until they come with the goal's meshes", function()
		ArenaParts:start()
		Fixtures.hudArena(folder)
		task.wait()
		local before = ArenaParts.parts :: any
		expect(#before.door).toBe(0)
		local door = Instance.new("Model")
		local bars: { BasePart } = {}
		for index = 1, 2 do
			local bar = Instance.new("Part")
			bar.Name = `Bar{index}`
			bar.Anchored = true
			bar.Parent = door
			bars[index] = bar
		end
		door:AddTag(Tags.GoalDoor)
		door.Parent = folder
		task.wait()
		local after = ArenaParts.parts :: any
		expect(after ~= before).toBe(true)
		expect(#after.door).toBe(2)
		expect(table.find(after.door, bars[1]) ~= nil and table.find(after.door, bars[2]) ~= nil).toBe(true)
	end)
end)
