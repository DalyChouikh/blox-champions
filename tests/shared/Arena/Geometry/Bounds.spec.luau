--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Bounds = require(ReplicatedStorage.Shared.Arena.Geometry.Bounds)
local Config = require(ReplicatedStorage.Shared.Config)

local arena = Config.defaults().Arena
local MARGIN = 2

describe("Bounds.isOut", function()
	it("keeps the ball in on the track, high over the infield, and up to the margin past the outer wall", function()
		local inside = {
			Vector3.new(0, 5, -60),
			Vector3.new(-140, 5, 0),
			Vector3.new(0, 40, 0),
			Vector3.new(0, 5, -83.5),
			Vector3.new(-163.5, 5, 0),
		}
		for _, position in inside do
			expect(Bounds.isOut(arena, position, MARGIN)).toBe(false)
		end
	end)

	it("puts the ball out past the outer wall and below the floor", function()
		for _, position in { Vector3.new(0, 5, -85), Vector3.new(-165, 5, 0), Vector3.new(30, -3, -60) } do
			expect(Bounds.isOut(arena, position, MARGIN)).toBe(true)
		end
	end)

	it("puts the ball out once it comes down onto the infield, but not while it flies over", function()
		expect(Bounds.isOut(arena, Vector3.new(0, 21.5, 0), MARGIN)).toBe(true)
		expect(Bounds.isOut(arena, Vector3.new(-100, 21.5, 10), MARGIN)).toBe(true)
		expect(Bounds.isOut(arena, Vector3.new(0, 22.5, 0), MARGIN)).toBe(false)
	end)
end)
