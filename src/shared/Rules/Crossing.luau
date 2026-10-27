--!strict
-- Crossings of flat shapes by the ball's per-tick path, either way: lap gates (rectangles) and the goal ring (disc).
-- The owner (2026-10-27): a gate counts from its back as from its front, and the goal scores from behind too.
-- A shape lies in its frame's XY plane, centered on frame.Position (width along RightVector, height along
-- UpVector). The segment starts off the plane and ends on it or past it, so a ball that stops exactly on the
-- plane is counted once, not again when it moves on. Edges are inclusive.

export type Rectangle = { frame: CFrame, width: number, height: number }
export type Disc = { frame: CFrame, radius: number }

local Crossing = {}

-- Returns the fraction along from -> to where the segment crosses the frame's plane, either way, and the crossing
-- point in the frame's object space; nil when there is no crossing.
local function planeCrossing(frame: CFrame, from: Vector3, to: Vector3): (number?, Vector3?)
	local localFrom = frame:PointToObjectSpace(from)
	local localTo = frame:PointToObjectSpace(to)
	-- Object space looks down -Z, so -Z is the signed distance along LookVector.
	local distanceFrom = -localFrom.Z
	local distanceTo = -localTo.Z
	-- Off the plane at the start, and on it or on its other side at the end.
	if distanceFrom == 0 or distanceFrom * distanceTo > 0 then
		return nil, nil
	end
	local fraction = distanceFrom / (distanceFrom - distanceTo)
	return fraction, localFrom:Lerp(localTo, fraction)
end

local function insideDisc(disc: Disc, localPoint: Vector3): boolean
	return localPoint.X * localPoint.X + localPoint.Y * localPoint.Y <= disc.radius * disc.radius
end

function Crossing.throughRectangle(rectangle: Rectangle, from: Vector3, to: Vector3): number?
	local fraction, hit = planeCrossing(rectangle.frame, from, to)
	if fraction == nil or hit == nil then
		return nil
	end
	if math.abs(hit.X) <= rectangle.width / 2 and math.abs(hit.Y) <= rectangle.height / 2 then
		return fraction
	end
	return nil
end

function Crossing.throughDisc(disc: Disc, from: Vector3, to: Vector3): number?
	local fraction, hit = planeCrossing(disc.frame, from, to)
	if fraction ~= nil and hit ~= nil and insideDisc(disc, hit) then
		return fraction
	end
	return nil
end

function Crossing.withinDisc(disc: Disc, point: Vector3): boolean
	return insideDisc(disc, disc.frame:PointToObjectSpace(point))
end

return Crossing
