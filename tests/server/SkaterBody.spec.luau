--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect
local beforeEach, afterEach = JestGlobals.beforeEach, JestGlobals.afterEach

local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)
local SkaterBody = require(game:GetService("ServerScriptService").Server.SkaterBody)
local SkaterRig = require(ReplicatedStorage.Shared.Skate.SkaterRig)

local folder: Folder
beforeEach(function()
	folder = Instance.new("Folder")
	folder.Name = "SkaterBodyTest"
	folder.Parent = workspace
end)
afterEach(function()
	folder:Destroy()
end)

describe("SkaterBody", function()
	it(
		"puts avatar parts in a group that touches nothing and the collider in one that touches only the arena",
		function()
			local rig = Fixtures.rig(folder, "Skater", CFrame.new(0, 5, 0))
			SkaterBody.build(rig, Config.defaults().Movement)
			for _, part in rig:GetDescendants() do
				if part:IsA("BasePart") then
					local expected = if part.Name == SkaterRig.collider
						then SkaterRig.groups.collider
						else SkaterRig.groups.body
					expect(part.CollisionGroup).toBe(expected)
				end
			end
		end
	)

	it("registers the skater groups once: bodies touch nothing, colliders the arena but not each other", function()
		local registered: { [string]: boolean } = { Default = true }
		local collides: { [string]: boolean } = {}
		local registrations = 0
		local physics = {
			IsCollisionGroupRegistered = function(_self: any, name: string): boolean
				return registered[name] == true
			end,
			RegisterCollisionGroup = function(_self: any, name: string)
				registered[name] = true
				registrations += 1
			end,
			CollisionGroupSetCollidable = function(_self: any, a: string, b: string, value: boolean)
				collides[`{a}/{b}`] = value
			end,
		}
		SkaterBody.registerGroups(physics)
		SkaterBody.registerGroups(physics)
		expect(registrations).toBe(2)
		expect(collides).toEqual({
			["SkaterBody/Default"] = false,
			["SkaterBody/SkaterBody"] = false,
			["SkaterBody/SkaterCollider"] = false,
			["SkaterCollider/Default"] = true,
			["SkaterCollider/SkaterCollider"] = false,
		})
	end)
end)
