--!strict
-- A pass steering toward its target (spec §8.2): each step adds `accel` toward the target, so a pass curves after a
-- receiver who moves. Allocates nothing.

local Vectors = require(script.Parent.Parent.Util.Vectors)

local Homing = {}

-- The velocity after `dt` seconds of steering; unchanged when the ball is already at the target.
function Homing.step(position: Vector3, velocity: Vector3, target: Vector3, accel: number, dt: number): Vector3
	local offset = target - position
	if offset.Magnitude <= Vectors.EPSILON then
		return velocity
	end
	return velocity + offset.Unit * (accel * dt)
end

return table.freeze(Homing)
