--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, it, expect = JestGlobals.describe, JestGlobals.it, JestGlobals.expect

local ScreenMarker = require(ReplicatedStorage.Shared.Hud.ScreenMarker)

local VIEWPORT = Vector2.new(1000, 500)
local WHOLE = Rect.new(0, 0, 1000, 500)
local MARGIN = 50

-- The path `inset` pixels inside `bounds` on the viewport, its points kept `keep` pixels from `boxes`.
local function routed(bounds: Rect, inset: number, boxes: { Rect }, keep: number): ScreenMarker.Path
	local path = ScreenMarker.newPath()
	ScreenMarker.route(VIEWPORT, bounds, inset, boxes, keep, path)
	return path
end

local function placed(point: Vector3, onScreen: boolean, path: ScreenMarker.Path?): ScreenMarker.Placement
	local placement = ScreenMarker.newPlacement()
	ScreenMarker.place(point, onScreen, path or routed(WHOLE, MARGIN, {}, 0), placement)
	return placement
end

describe("ScreenMarker", function()
	it("leaves an on-screen point where it is, pointing down at it", function()
		local placement = placed(Vector3.new(300, 200, 10), true)
		expect(placement.x).toBe(300)
		expect(placement.y).toBe(200)
		expect(placement.pinned).toBe(false)
		expect(placement.angle).toBeCloseTo(math.pi, 6)
		expect(placement.covered).toBe(false)
	end)

	it("keeps an on-screen marker on its point, covered where a box kept clear of reaches it", function()
		-- A box from (250, 150) to (350, 250), kept 3 px from: covered from x 247 to 353 and y 147 to 253; and a
		-- second box.
		local path = routed(WHOLE, MARGIN, { Rect.new(250, 150, 350, 250), Rect.new(600, 300, 700, 400) }, 3)
		expect(placed(Vector3.new(650, 350, 10), true, path).covered).toBe(true)
		local inside = placed(Vector3.new(300, 200, 10), true, path)
		expect(inside.x).toBe(300)
		expect(inside.y).toBe(200)
		expect(inside.covered).toBe(true)
		expect(placed(Vector3.new(352, 252, 10), true, path).covered).toBe(true)
		expect(placed(Vector3.new(248, 148, 10), true, path).covered).toBe(true)
		expect(placed(Vector3.new(354, 200, 10), true, path).covered).toBe(false)
		expect(placed(Vector3.new(300, 254, 10), true, path).covered).toBe(false)
		expect(placed(Vector3.new(246, 200, 10), true, path).covered).toBe(false)
		expect(placed(Vector3.new(300, 146, 10), true, path).covered).toBe(false)
		-- A pinned marker slides clear instead, never covered, in the same record a covered one left.
		local placement = ScreenMarker.newPlacement()
		ScreenMarker.place(Vector3.new(300, 200, 10), true, path, placement)
		ScreenMarker.place(Vector3.new(2000, 260, 10), false, path, placement)
		expect(placement.covered).toBe(false)
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

	it("pins inside its bounds, on the line from the viewport's centre", function()
		-- A notched phone's safe area: 60 px in from each side, 20 px down from the top.
		local path = routed(Rect.new(60, 20, 940, 500), 10, {}, 0)
		local right = placed(Vector3.new(2000, 250, 10), false, path)
		expect(right.x).toBeCloseTo(930, 6)
		expect(right.y).toBeCloseTo(250, 6)
		-- Straight up from the viewport's centre (500, 250) to the path's top (30).
		local up = placed(Vector3.new(500, -900, 10), false, path)
		expect(up.x).toBeCloseTo(500, 6)
		expect(up.y).toBeCloseTo(30, 6)
		expect(up.angle).toBeCloseTo(0, 6)
	end)

	it("slides a pinned marker along the edge to the nearest point clear of a box, keeping its angle", function()
		-- A box on the right edge from y 200 to 300, kept 3 px from: the path at x 950 is blocked from 197 to 303. The
		-- line to (2000, 260) meets the path at y 253, 50 px from 303 and 56 from 197.
		local path = routed(WHOLE, MARGIN, { Rect.new(940, 200, 1000, 300) }, 3)
		local below = placed(Vector3.new(2000, 260, 10), false, path)
		expect(below.x).toBeCloseTo(950, 6)
		expect(below.y).toBeCloseTo(303, 6)
		expect(below.angle).toBeCloseTo(math.atan2(1500, -10), 6)
		local above = placed(Vector3.new(2000, 240, 10), false, path)
		expect(above.y).toBeCloseTo(197, 6)
		-- A box that does not reach the path blocks nothing.
		local far =
			placed(Vector3.new(2000, 260, 10), false, routed(WHOLE, MARGIN, { Rect.new(990, 200, 1000, 300) }, 3))
		expect(far.y).toBeCloseTo(253, 6)
	end)

	it("slides past boxes that overlap as one, and round a corner", function()
		-- Two boxes down the right edge, 150-260 and 250-480: one stretch from 147 down to the bottom corner and on
		-- along the bottom edge to x 894 (the second box reaches 103 px in, 3 px kept).
		local path = routed(WHOLE, MARGIN, { Rect.new(900, 150, 1000, 260), Rect.new(897, 250, 1000, 480) }, 3)
		local high = placed(Vector3.new(2000, 200, 10), false, path)
		expect(high.x).toBeCloseTo(950, 6)
		expect(high.y).toBeCloseTo(147, 6)
		-- Low on the right edge (y 440), nearer the stretch's far end round the corner: it comes out on the bottom
		-- edge.
		local low = placed(Vector3.new(2000, 883, 10), false, path)
		expect(low.x).toBeCloseTo(894, 6)
		expect(low.y).toBeCloseTo(450, 6)
	end)

	it("keeps a stretch whole where a smaller box lies inside it", function()
		-- Down the right edge, 150-400 and inside it 200-300: one stretch from y 150 to 400. The line to (5000, 1050)
		-- meets the path at y 330, 70 px from 400 and 180 from 150.
		local path = routed(WHOLE, MARGIN, { Rect.new(900, 150, 1000, 400), Rect.new(900, 200, 1000, 300) }, 0)
		local placement = placed(Vector3.new(5000, 1050, 10), false, path)
		expect(placement.x).toBeCloseTo(950, 6)
		expect(placement.y).toBeCloseTo(400, 6)
	end)

	it("slides across the path's start at the top-left corner", function()
		-- A box over the top-left corner: one stretch up the left edge from y 120, round the corner, along the top to x
		-- 120.
		local path = routed(WHOLE, MARGIN, { Rect.new(0, 0, 120, 120) }, 0)
		local top = placed(Vector3.new(-500, -250, 10), false, path)
		expect(top.x).toBeCloseTo(120, 6)
		expect(top.y).toBeCloseTo(50, 6)
		local left = placed(Vector3.new(-2000, -583, 10), false, path)
		expect(left.x).toBeCloseTo(50, 6)
		expect(left.y).toBeCloseTo(120, 6)
		-- Near the corner the stretch's nearer end lies round it: from x 60 on the top edge, 60 px on to x 120 rather
		-- than 80 back down the left edge; from y 60 on the left edge, 60 px down to y 120.
		local nearTop = placed(Vector3.new(-3900, -1750, 10), false, path)
		expect(nearTop.x).toBeCloseTo(120, 6)
		expect(nearTop.y).toBeCloseTo(50, 6)
		local nearLeft = placed(Vector3.new(-4000, -1650, 10), false, path)
		expect(nearLeft.x).toBeCloseTo(50, 6)
		expect(nearLeft.y).toBeCloseTo(120, 6)
	end)

	it("blocks nothing for a box clear of the path's edges, even beside its start", function()
		-- The corner's box, and a box above the path crossing its left edge's line (from x 20 to 80, above y 50): that
		-- one meets no point of the path, so the corner's stretch stays whole.
		local path = routed(WHOLE, MARGIN, { Rect.new(0, 0, 120, 120), Rect.new(20, 0, 80, 30) }, 0)
		local placement = placed(Vector3.new(-3900, -1750, 10), false, path)
		expect(placement.x).toBeCloseTo(120, 6)
		expect(placement.y).toBeCloseTo(50, 6)
	end)

	it("stays on its line where every point of the path is blocked", function()
		local path = routed(WHOLE, MARGIN, { Rect.new(0, 0, 1000, 500) }, 0)
		local placement = placed(Vector3.new(2000, 250, 10), false, path)
		expect(placement.x).toBeCloseTo(950, 6)
		expect(placement.y).toBeCloseTo(250, 6)
	end)

	it("routes again into the same record, forgetting the old boxes", function()
		local path = routed(WHOLE, MARGIN, { Rect.new(940, 200, 1000, 300) }, 3)
		expect(placed(Vector3.new(960, 250, 10), true, path).covered).toBe(true)
		ScreenMarker.route(VIEWPORT, WHOLE, MARGIN, {}, 3, path)
		expect(placed(Vector3.new(2000, 260, 10), false, path).y).toBeCloseTo(253, 6)
		expect(placed(Vector3.new(960, 250, 10), true, path).covered).toBe(false)
		-- The record holds the new stretches and boxes alone: none.
		expect(path.count).toBe(0)
		expect(#path.blocks).toBe(0)
		expect(#path.covers).toBe(0)
	end)
end)
