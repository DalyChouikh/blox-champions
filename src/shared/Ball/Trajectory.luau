--!strict
-- Gravity-only ball flight (no bounces), used to predict whether a thrown ball is headed into the goal
-- (spec §6.3).

local Trajectory = {}

-- Below this, gravity along the plane's normal counts as zero and the path as a straight line.
local FLAT_EPSILON = 1e-9

function Trajectory.positionAt(position: Vector3, velocity: Vector3, gravity: Vector3, t: number): Vector3
	return position + velocity * t + gravity * (0.5 * t * t)
end

local function isForwardCrossing(t: number, speedAlong: number, gravityAlong: number, maxTime: number): boolean
	return t >= 0 and t <= maxTime and speedAlong + gravityAlong * t > 0
end

-- Earliest time in [0, maxTime] at which the path crosses the frame's plane moving along frame.LookVector.
function Trajectory.forwardCrossingTime(
	position: Vector3,
	velocity: Vector3,
	gravity: Vector3,
	frame: CFrame,
	maxTime: number
): number?
	-- Signed distance along LookVector: s(t) = start + speedAlong * t + gravityAlong * t^2 / 2.
	local normal = frame.LookVector
	local start = (position - frame.Position):Dot(normal)
	local speedAlong = velocity:Dot(normal)
	local gravityAlong = gravity:Dot(normal)

	if math.abs(gravityAlong) < FLAT_EPSILON then
		if speedAlong <= 0 then
			return nil
		end
		local t = -start / speedAlong
		return if isForwardCrossing(t, speedAlong, gravityAlong, maxTime) then t else nil
	end

	local discriminant = speedAlong * speedAlong - 2 * gravityAlong * start
	if discriminant < 0 then
		return nil
	end
	local root = math.sqrt(discriminant)
	local a = (-speedAlong - root) / gravityAlong
	local b = (-speedAlong + root) / gravityAlong
	local first, second = math.min(a, b), math.max(a, b)
	if isForwardCrossing(first, speedAlong, gravityAlong, maxTime) then
		return first
	end
	if isForwardCrossing(second, speedAlong, gravityAlong, maxTime) then
		return second
	end
	return nil
end

return Trajectory
