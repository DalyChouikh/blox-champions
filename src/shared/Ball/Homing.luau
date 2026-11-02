--!strict
-- A Magnetic Pass steering toward its receiver (spec §8.2): it flies at a steady speed, leaving for and each step
-- turning toward where the receiver's chest will be when it gets there (#315, #346), so it flies straight into the
-- hands of a teammate skating across and bends after one who cuts. Steered at the receiver's spot alone, a pass to a
-- teammate 80 studs out skating across at 55 studs/s passed 25.6 studs from them (#315; s60\lead315.py). Speeding up
-- toward them instead (#315's homing), a pass turned slower the faster it got, and missed receivers who turned late
-- (the owner's trial, Q174; replayed over real receivers' paths: 64% caught, 90% at a steady speed, Q175).
-- Allocates nothing.

local Vectors = require(script.Parent.Parent.Util.Vectors)

local Homing = {}

local UP = Vector3.yAxis

-- Where a pass aims on a receiver whose root is at `root`: `height` straight above it (Q175: the chest, so the pass's
-- line clears the floors and banks between the two skaters). Straight up, not along the receiver's lean: the replay
-- caught as many (90.4% against 90.3%) without reading their frame every step.
function Homing.aimOn(root: Vector3, height: number): Vector3
	return root + UP * height
end

-- Where a pass from `from` at a steady `speed` meets a receiver now at `target` moving at `velocity`: their place at
-- the time t when the pass has flown as far as they are from `from` then, |offset + velocity t| = speed t with offset
-- = target - from: the root of (speed^2 - |velocity|^2) t^2 - 2 (offset . velocity) t - |offset|^2 = 0 that is not
-- negative (0 at the receiver). With none (a receiver at least as fast as the pass), their place now.
function Homing.lead(from: Vector3, speed: number, target: Vector3, velocity: Vector3): Vector3
	local offset = target - from
	local faster = speed * speed - velocity:Dot(velocity)
	if faster <= 0 then
		return target
	end
	local along = offset:Dot(velocity)
	return target + velocity * ((along + math.sqrt(along * along + faster * offset:Dot(offset))) / faster)
end

-- The velocity at a steady `speed` of a pass turning toward `toward` (from the ball to where it should go) after `dt`
-- seconds: by at most turnAccel / speed x dt radians, its sideways acceleration turnAccel (Q175: it never speeds up,
-- so it turns as quickly late in its flight as early). With nowhere to go it keeps its heading; with no heading it
-- takes the way. Exactly opposite ways turn about the world's up.
function Homing.turn(velocity: Vector3, toward: Vector3, speed: number, turnAccel: number, dt: number): Vector3
	if toward.Magnitude <= Vectors.EPSILON then
		return if velocity.Magnitude <= Vectors.EPSILON then velocity else velocity.Unit * speed
	elseif velocity.Magnitude <= Vectors.EPSILON then
		return toward.Unit * speed
	end
	return Vectors.rotateToward(velocity.Unit, toward.Unit, turnAccel / speed * dt, UP) * speed
end

return table.freeze(Homing)
