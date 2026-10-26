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
		expect(Bounds.isOut(arena, Vector3.new(0, 29.5, 0), MARGIN)).toBe(true)
		expect(Bounds.isOut(arena, Vector3.new(-100, 29.5, 10), MARGIN)).toBe(true)
		expect(Bounds.isOut(arena, Vector3.new(0, 30.5, 0), MARGIN)).toBe(false)
	end)
end)

-- A skater's space is the tube (A2): between its walls (38 and 82 studs from the long axis), above the lower floor and
-- under the roof's half circle (centred 22 studs across from the inner wall's face, 28 up, radius 22).
describe("Bounds.inTube", function()
	it("holds a skater anywhere inside the tube, and up to the margin past its surfaces", function()
		local inside = {
			Vector3.new(0, 2.5, 53), -- on a straight's lower floor
			Vector3.new(-140, 2.5, 0), -- across a curved end
			Vector3.new(0, 20, 39.5), -- riding the inner wall
			Vector3.new(0, 20, 80.5), -- riding the outer wall
			Vector3.new(0, 47.5, 60), -- under the roof's top
			Vector3.new(0, 25, 36.5), -- within the margin behind the inner wall's face
			Vector3.new(0, 51.5, 60), -- within the margin over the roof's top
			Vector3.new(0, -1.5, 53), -- within the margin under the floor
		}
		for _, position in inside do
			expect(Bounds.inTube(arena, position, MARGIN)).toBe(true)
		end
	end)

	it("puts a skater out past either wall, under the floor and over the roof", function()
		local outside = {
			Vector3.new(0, 20, 85), -- past the outer wall
			Vector3.new(-165, 5, 0), -- past a curved end's outer wall
			Vector3.new(0, 20, 35), -- past the inner wall
			Vector3.new(0, 30, 0), -- over the infield
			Vector3.new(0, -3, 53), -- under the floor
			Vector3.new(0, 53, 60), -- over the roof's top
			Vector3.new(0, 42, 80), -- over the roof's side, 24.4 studs from its centre
		}
		for _, position in outside do
			expect(Bounds.inTube(arena, position, MARGIN)).toBe(false)
		end
	end)
end)
