--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Bounds = require(ReplicatedStorage.Shared.Arena.Geometry.Bounds)
local Config = require(ReplicatedStorage.Shared.Config)

local arena = Config.defaults().Arena
local MARGIN = 2

-- The arena is the box inside the glass (Arena spec §4.3): seen from above, between the inner glass (40 studs from the
-- long axis) and the outer glass (100), from the lower floor (0) up to the glass top (85), each within the margin.
describe("Bounds.inArena", function()
	it("holds the ball or a skater anywhere inside the glass, and up to the margin past it", function()
		local inside = {
			Vector3.new(0, 2.5, 57), -- on a straight's lower floor
			Vector3.new(0, 8, 40.5), -- on the inner bank's top, beside the glass
			Vector3.new(0, 20, 99), -- riding the outer wall
			Vector3.new(0, 86.5, 99), -- high beside the outer glass, within the margin over its top
			Vector3.new(-170, 2.5, 0), -- across a curved end
			Vector3.new(0, -1.5, 57), -- within the margin under the floor
		}
		for _, position in inside do
			expect(Bounds.inArena(arena, position, MARGIN)).toBe(true)
		end
	end)

	it("puts the ball or a skater out past either glass, under the floor or over the glass top", function()
		local outside = {
			Vector3.new(0, 20, 103), -- past the outer glass
			Vector3.new(-203, 5, 0), -- past a curved end's outer glass
			Vector3.new(0, 20, 37), -- past the inner glass
			Vector3.new(0, 30, 0), -- over the infield
			Vector3.new(0, -3, 57), -- under the floor
			Vector3.new(0, 88, 60), -- over the glass top
		}
		for _, position in outside do
			expect(Bounds.inArena(arena, position, MARGIN)).toBe(false)
		end
	end)
end)
