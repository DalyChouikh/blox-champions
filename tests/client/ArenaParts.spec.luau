--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local ArenaParts = require(game:GetService("StarterPlayer").StarterPlayerScripts.Client.ArenaParts)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)

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
	it("finds the corner markers by gate index, the goal hoop's parts and the panel once the arena is there", function()
		expect(ArenaParts.parts).toBeNil()
		local arena = Fixtures.hudArena(folder)
		ArenaParts:refresh()
		local parts = ArenaParts.parts :: any
		expect(parts ~= nil).toBe(true)
		for index = 1, 4 do
			expect(parts.markers[index] == arena.markers[index]).toBe(true)
		end
		expect(#parts.hoop).toBe(2)
		expect(parts.panel == arena.panel).toBe(true)

		-- A new record whenever the arena changes, so readers see it; none once it is gone.
		arena.panel:Destroy()
		ArenaParts:refresh()
		expect(ArenaParts.parts).toBeNil()
	end)
end)
