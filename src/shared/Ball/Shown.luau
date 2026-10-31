--!strict
-- Where a screen draws the loose ball between the server's states (spec §9.3, #316, Q101): a state carried on to now
-- (in a straight line while its weight is cancelled, else falling), and each frame's drawn spot, which moves with the
-- server's ball and closes on it smoothly, or jumps to it across a gap too wide to close (a drop-in's start, a
-- respawn). Pure: Vector3s and numbers only, so a screen drawing the ball every frame allocates nothing here.

local Shown = {}

-- Where a ball in a state `age` seconds old is now, and how fast it moves: it falls under `gravity`, which is zero
-- while its weight is cancelled.
function Shown.predict(position: Vector3, velocity: Vector3, gravity: Vector3, age: number): (Vector3, Vector3)
	return position + velocity * age + gravity * (age * age / 2), velocity + gravity * age
end

-- This frame's drawn spot, `dt` after `shown`: moved with the server's ball (`velocity`), then the gap left to
-- `target` shrunk to e^(-dt / correctionSeconds) of itself; at `target` at once when that gap is wider than
-- `snapStuds`. The second result says whether it jumped.
function Shown.follow(
	shown: Vector3,
	target: Vector3,
	velocity: Vector3,
	dt: number,
	correctionSeconds: number,
	snapStuds: number
): (Vector3, boolean)
	local moved = shown + velocity * dt
	local gap = target - moved
	if gap.Magnitude > snapStuds then
		return target, true
	end
	return moved + gap * (1 - math.exp(-dt / correctionSeconds)), false
end

return Shown
