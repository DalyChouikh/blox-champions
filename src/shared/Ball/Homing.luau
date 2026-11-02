--!strict
-- A pass steering toward its receiver (spec §8.2): it leaves for, and each step adds `accel` toward, where the receiver
-- will be when it gets there (#315), so it flies straight into the hands of a teammate skating across, and curves only
-- after one who changes their way. Steered at the receiver's spot alone, a pass to a teammate 80 studs out skating
-- across at 55 studs/s passed 25.6 studs from them (the owner's trial values, Q139; worked in s60\lead315.py).
-- Allocates nothing.

local Vectors = require(script.Parent.Parent.Util.Vectors)

local Homing = {}

-- How many halvings Homing.lead takes to find when a pass meets its receiver: 24 pin it within 2^-24 of its bound.
local LEAD_ROUNDS = 24

-- The velocity after `dt` seconds of steering; unchanged when the ball is already at the target.
function Homing.step(position: Vector3, velocity: Vector3, target: Vector3, accel: number, dt: number): Vector3
	local offset = target - position
	if offset.Magnitude <= Vectors.EPSILON then
		return velocity
	end
	return velocity + offset.Unit * (accel * dt)
end

-- Where a pass from `from` at `speed`, speeding up by `accel` along its way (Homing.step), meets a receiver now at
-- `target` moving at `velocity`: their place at the time t when the pass has covered as far as they are from `from`
-- then, |target + velocity t - from| = speed t + accel t^2 / 2. As the receiver closes or opens that distance no faster
-- than their speed, t comes no later than where speed t + accel t^2 / 2 = |target - from| + |velocity| t, so it is
-- halved down from there (the one t there is while the pass is the faster; for a receiver faster than it, a t where
-- they meet). With none (a receiver faster than a pass that never speeds up), their place now.
function Homing.lead(from: Vector3, speed: number, accel: number, target: Vector3, velocity: Vector3): Vector3
	local distance = (target - from).Magnitude
	local closing = speed - velocity.Magnitude
	local bound: number
	if distance <= Vectors.EPSILON then
		return target
	elseif accel > 0 then
		bound = (math.sqrt(closing * closing + 2 * accel * distance) - closing) / accel
	elseif closing > 0 then
		bound = distance / closing
	else
		return target
	end
	local short, met = 0, bound
	for _ = 1, LEAD_ROUNDS do
		local middle = (short + met) / 2
		if (target + velocity * middle - from).Magnitude > middle * (speed + accel * middle / 2) then
			short = middle
		else
			met = middle
		end
	end
	return target + velocity * met
end

return table.freeze(Homing)
