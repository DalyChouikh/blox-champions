--!strict
-- Forward crossings of flat shapes by the ball's per-tick path: lap gates (rectangles) and the goal ring (disc).
-- A shape lies in its frame's XY plane, centered on frame.Position (width along RightVector, height along
-- UpVector). A crossing counts only when moving along frame.LookVector: the segment starts behind the plane
-- and ends on or in front of it, so a ball that stops exactly on the plane is counted once, not again when
-- it moves on. Edges are inclusive.

export type Rectangle = { frame: CFrame, width: number, height: number }
export type Disc = { frame: CFrame, radius: number }

local Crossing = {}

-- Returns the fraction along from -> to where the segment crosses the frame's plane moving along LookVector,
-- and the crossing point in the frame's object space; nil when there is no forward crossing.
local function forwardCrossing(frame: CFrame, from: Vector3, to: Vector3): (number?, Vector3?)
	local localFrom = frame:PointToObjectSpace(from)
	local localTo = frame:PointToObjectSpace(to)
	-- Object space looks down -Z, so -Z is the signed distance along LookVector.
	local distanceFrom = -localFrom.Z
	local distanceTo = -localTo.Z
	if distanceFrom >= 0 or distanceTo < 0 then
		return nil, nil
	end
	local fraction = distanceFrom / (distanceFrom - distanceTo)
	return fraction, localFrom:Lerp(localTo, fraction)
end

local function insideDisc(disc: Disc, localPoint: Vector3): boolean
	return localPoint.X * localPoint.X + localPoint.Y * localPoint.Y <= disc.radius * disc.radius
end

function Crossing.throughRectangle(rectangle: Rectangle, from: Vector3, to: Vector3): number?
	local fraction, hit = forwardCrossing(rectangle.frame, from, to)
	if fraction == nil or hit == nil then
		return nil
	end
	if math.abs(hit.X) <= rectangle.width / 2 and math.abs(hit.Y) <= rectangle.height / 2 then
		return fraction
	end
	return nil
end

function Crossing.throughDisc(disc: Disc, from: Vector3, to: Vector3): number?
	local fraction, hit = forwardCrossing(disc.frame, from, to)
	if fraction ~= nil and hit ~= nil and insideDisc(disc, hit) then
		return fraction
	end
	return nil
end

function Crossing.withinDisc(disc: Disc, point: Vector3): boolean
	return insideDisc(disc, disc.frame:PointToObjectSpace(point))
end

return Crossing
