--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Look = require(ReplicatedStorage.Shared.Ball.Look)

describe("Look", function()
	it("finds the part that draws a ball, under its ball part", function()
		local ball = Instance.new("Part")
		local look = Instance.new("MeshPart")
		look.Name = Look.NAME
		look.Parent = ball
		expect(Look.of(ball) == look).toBe(true)
		ball:Destroy()
	end)

	it("finds nothing under a ball without one, nor a child of that name that is not a part", function()
		local ball = Instance.new("Part")
		expect(Look.of(ball)).toBeNil()
		local folder = Instance.new("Folder")
		folder.Name = Look.NAME
		folder.Parent = ball
		expect(Look.of(ball)).toBeNil()
		ball:Destroy()
	end)
end)
