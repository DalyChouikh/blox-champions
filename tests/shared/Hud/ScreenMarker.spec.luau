--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local ScreenMarker = require(ReplicatedStorage.Shared.Hud.ScreenMarker)

local VIEWPORT = Vector2.new(1000, 500)
local MARGIN = 50

local function placed(point: Vector3, onScreen: boolean): ScreenMarker.Placement
	local placement = ScreenMarker.newPlacement()
	ScreenMarker.place(point, onScreen, VIEWPORT, MARGIN, placement)
	return placement
end

describe("ScreenMarker", function()
	it("leaves an on-screen point where it is, pointing down at it", function()
		local placement = placed(Vector3.new(300, 200, 10), true)
		expect(placement.x).toBe(300)
		expect(placement.y).toBe(200)
		expect(placement.pinned).toBe(false)
		expect(placement.angle).toBeCloseTo(math.pi, 6)
	end)

	it("pins an off-screen point to the screen's edge, pointing at it", function()
		local placement = placed(Vector3.new(2000, 250, 10), false)
		expect(placement.x).toBeCloseTo(950, 6)
		expect(placement.y).toBeCloseTo(250, 6)
		expect(placement.angle).toBeCloseTo(math.pi / 2, 6)
		expect(placement.pinned).toBe(true)
		-- Up and to the left, steeper than the screen's corner: it meets the top edge.
		local corner = placed(Vector3.new(-500, -250, 10), false)
		expect(corner.x).toBeCloseTo(100, 6)
		expect(corner.y).toBeCloseTo(50, 6)
		-- Right and a little down, flatter than the corner: it meets the right edge.
		local side = placed(Vector3.new(2000, 300, 10), false)
		expect(side.x).toBeCloseTo(950, 6)
		expect(side.y).toBeCloseTo(265, 6)
	end)

	it("points the right way at a point behind the camera", function()
		local placement = placed(Vector3.new(2000, 250, -10), false)
		expect(placement.x).toBeCloseTo(50, 6)
		expect(placement.y).toBeCloseTo(250, 6)
		expect(placement.angle).toBeCloseTo(-math.pi / 2, 6)
		expect(placement.pinned).toBe(true)
	end)
end)
