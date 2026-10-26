--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local Bounds = require(ReplicatedStorage.Shared.Arena.Geometry.Bounds)
local Config = require(ReplicatedStorage.Shared.Config)
local Fixtures = require(ReplicatedStorage.Tests.Fixtures)

local arena = Config.defaults().Arena
-- An open map's ceiling stands top.ceilingAbove (20) over the walls' top.
local openArena = Fixtures.config({ Arena = { top = { kind = "Open" } } }).Arena
local MARGIN = 2

-- The arena is the box inside the glass (Arena spec §4.4): seen from above, between the inner glass (20 studs from the
-- long axis) and the outer glass (100), from the lower floor (0) up to the top (120 closed, 140 open), each within the
-- margin.
describe("Bounds.inArena", function()
	it("holds the ball or a skater anywhere inside the glass, and up to the margin past it", function()
		local inside = {
			Vector3.new(0, 2.5, 42), -- on a straight's lower floor
			Vector3.new(0, 8, 20.5), -- on the inner bank's top, beside the glass
			Vector3.new(0, 60, 99), -- riding the outer glass
			Vector3.new(0, 121.5, 70), -- under the roof, within the margin over it
			Vector3.new(-160, 2.5, 0), -- across a curved end
			Vector3.new(0, -1.5, 42), -- within the margin under the floor
		}
		for _, position in inside do
			expect(Bounds.inArena(arena, position, MARGIN)).toBe(true)
		end
		-- Under an open map's ceiling, within the margin over it.
		expect(Bounds.inArena(openArena, Vector3.new(0, 141.5, 70), MARGIN)).toBe(true)
	end)

	it("puts the ball or a skater out past either glass, under the floor or over the top", function()
		local outside = {
			Vector3.new(0, 60, 103), -- past the outer glass
			Vector3.new(-203, 5, 0), -- past a curved end's outer glass
			Vector3.new(0, 60, 17), -- past the inner glass
			Vector3.new(0, 30, 0), -- over the infield
			Vector3.new(0, -3, 42), -- under the floor
			Vector3.new(0, 123, 60), -- over the top
		}
		for _, position in outside do
			expect(Bounds.inArena(arena, position, MARGIN)).toBe(false)
		end
		expect(Bounds.inArena(openArena, Vector3.new(0, 143, 60), MARGIN)).toBe(false)
	end)
end)
