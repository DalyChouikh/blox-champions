--!strict
-- Gravity-only ball flight (no bounces), used to predict whether a thrown ball is headed into the goal
-- (spec §6.3).

local Trajectory = {}

-- Below this, gravity along the plane's normal counts as zero and the path as a straight line.
local FLAT_EPSILON = 1e-9

function Trajectory.positionAt(position: Vector3, velocity: Vector3, gravity: Vector3, t: number): Vector3
	return position + velocity * t + gravity * (0.5 * t * t)
end

-- t must be strictly ahead: like Crossing, a ball already on the plane has crossed it.
local function ahead(t: number, maxTime: number): boolean
	return t > 0 and t <= maxTime
end

-- The times in (0, maxTime] at which the path meets the frame's plane, either way through it (the goal scores from
-- either side), the earlier first; nil for each one there is not. Returned as two values, so it never allocates.
function Trajectory.crossingTimes(
	position: Vector3,
	velocity: Vector3,
	gravity: Vector3,
	frame: CFrame,
	maxTime: number
): (number?, number?)
	-- Signed distance along LookVector: s(t) = start + speedAlong * t + gravityAlong * t^2 / 2.
	local normal = frame.LookVector
	local start = (position - frame.Position):Dot(normal)
	local speedAlong = velocity:Dot(normal)
	local gravityAlong = gravity:Dot(normal)

	if math.abs(gravityAlong) < FLAT_EPSILON then
		if speedAlong == 0 then
			return nil, nil
		end
		local t = -start / speedAlong
		return if ahead(t, maxTime) then t else nil, nil
	end

	local discriminant = speedAlong * speedAlong - 2 * gravityAlong * start
	if discriminant < 0 then
		return nil, nil
	end
	local root = math.sqrt(discriminant)
	local a = (-speedAlong - root) / gravityAlong
	local b = (-speedAlong + root) / gravityAlong
	local first, second = math.min(a, b), math.max(a, b)
	-- A path that only touches the plane meets it once.
	local later = if root > 0 and ahead(second, maxTime) then second else nil
	if ahead(first, maxTime) then
		return first, later
	end
	return later, nil
end

return Trajectory
