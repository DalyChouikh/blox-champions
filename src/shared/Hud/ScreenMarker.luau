--!strict
-- Where an on-screen marker for a point in the world sits (spec §11.1), from the point as the camera projects it
-- (Camera:WorldToViewportPoint: x and y in pixels, z the depth, negative behind the camera). A point on the screen is
-- marked where it is, by an arrow pointing down at it. One off it is pinned to the rectangle `margin` inside the
-- screen's edge, on the line from the screen's centre toward it, with the arrow pointing along that line; a point
-- behind the camera projects mirrored, so that line is turned around. It never touches an Instance, and placing a
-- marker writes into a record the caller keeps, so it allocates nothing.

-- x and y in pixels from the screen's top left; angle in radians, 0 pointing up, growing clockwise.
export type Placement = { x: number, y: number, angle: number, pinned: boolean }

local ScreenMarker = {}

-- Straight down, at a point on the screen.
local DOWN = math.pi

function ScreenMarker.newPlacement(): Placement
	return { x = 0, y = 0, angle = 0, pinned = false }
end

function ScreenMarker.place(point: Vector3, onScreen: boolean, viewport: Vector2, margin: number, into: Placement)
	if onScreen then
		into.x, into.y, into.angle, into.pinned = point.X, point.Y, DOWN, false
		return
	end
	local centreX, centreY = viewport.X / 2, viewport.Y / 2
	local dx, dy = point.X - centreX, point.Y - centreY
	if point.Z < 0 then
		dx, dy = -dx, -dy
	end
	if dx == 0 and dy == 0 then
		-- Straight behind: point down, to the bottom edge.
		dy = 1
	end
	-- How far along the line it meets the inner rectangle: the nearer of its side and its top or bottom.
	local reach = math.huge
	if dx ~= 0 then
		reach = (centreX - margin) / math.abs(dx)
	end
	if dy ~= 0 then
		reach = math.min(reach, (centreY - margin) / math.abs(dy))
	end
	into.x, into.y = centreX + dx * reach, centreY + dy * reach
	into.angle = math.atan2(dx, -dy)
	into.pinned = true
end

return table.freeze(ScreenMarker)
