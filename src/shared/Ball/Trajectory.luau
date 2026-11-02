--!strict
-- Gravity-only ball flight (no bounces), used to predict whether a thrown ball is headed into the goal
-- (spec §6.3) and to aim a throw at the crosshair's spot (§8.2, #313).

local Vectors = require(script.Parent.Parent.Util.Vectors)

local Trajectory = {}

-- Below this, gravity along the plane's normal counts as zero and the path as a straight line.
local FLAT_EPSILON = 1e-9

-- How many rounds Trajectory.toward takes to settle a launch whose aim and flight time depend on each other. Each
-- round shrinks the miss by about the carry's share of the throw across it: 12 hold a tap at 90 studs/s thrown
-- sideways off a skater at the speed limit (a carry of 50) to 0.004 studs; a throw along its carry settles sooner.
local CARRY_ROUNDS = 12

function Trajectory.positionAt(position: Vector3, velocity: Vector3, gravity: Vector3, t: number): Vector3
	return position + velocity * t + gravity * (0.5 * t * t)
end

-- Straight along `up` (against gravity of strength `pull`) at a point `rise` above, which the throw reaches if its
-- speed carries it that high (else the time is the climb's to its top), or straight down at one below.
local function straight(speed: number, up: Vector3, rise: number, pull: number): (Vector3, number, boolean)
	if rise < 0 then
		return -up, (math.sqrt(speed * speed - 2 * pull * rise) - speed) / pull, true
	end
	local rest = speed * speed - 2 * pull * rise
	if rest < 0 then
		return up, speed / pull, false
	end
	return up, (speed - math.sqrt(rest)) / pull, true
end

-- The launch from `from` at `speed` whose flight under `gravity` meets `to` soonest: the flatter of the two arcs
-- through it. Out of reach at that speed, the arc that needs the least speed to get there, halfway between straight
-- up and the line to `to` (it falls short). Returns its unit direction, the time it takes to cover `to`'s distance at
-- right angles to gravity, and whether it reaches `to`. A `to` right above or below `from` is thrown straight at, as
-- everything is with no gravity.
function Trajectory.launch(speed: number, from: Vector3, to: Vector3, gravity: Vector3): (Vector3, number, boolean)
	local offset = to - from
	local pull = gravity.Magnitude
	if pull < FLAT_EPSILON then
		local distance = offset.Magnitude
		local way = if distance > Vectors.EPSILON then offset / distance else Vector3.yAxis
		return way, distance / speed, true
	end
	local up = -gravity / pull
	local rise = offset:Dot(up)
	local level = offset - up * rise
	local across = level.Magnitude
	if across < Vectors.EPSILON then
		return straight(speed, up, rise, pull)
	end
	-- The slope (tan of the launch angle) solves pull x^2 (1 + s^2) / (2 v^2) - x s + rise = 0 for x = across.
	local speed2 = speed * speed
	local rest = speed2 * speed2 - pull * (pull * across * across + 2 * rise * speed2)
	local reaches = rest >= 0
	local slope = if reaches
		then (speed2 - math.sqrt(rest)) / (pull * across)
		else (rise + math.sqrt(across * across + rise * rise)) / across
	local cos = 1 / math.sqrt(1 + slope * slope)
	return level / across * cos + up * (slope * cos), across / (speed * cos), reaches
end

-- The velocity that takes the ball from `from` to `to` as Trajectory.launch's does when the thrower moves at `carry`
-- and the ball keeps it: a launch at `speed` from the hand, plus `carry`. The carry alone moves the ball by carry x
-- time, so the launch aims at `to` less that, and the time follows the aim: CARRY_ROUNDS rounds settle both. Returns
-- the velocity, whether it reaches `to`, and how long its flight takes to get there (Throw.aimed's exact part, #342).
function Trajectory.toward(
	speed: number,
	from: Vector3,
	to: Vector3,
	carry: Vector3,
	gravity: Vector3
): (Vector3, boolean, number)
	local direction, time, reaches = Trajectory.launch(speed, from, to, gravity)
	for _ = 1, CARRY_ROUNDS do
		direction, time, reaches = Trajectory.launch(speed, from, to - carry * time, gravity)
	end
	return direction * speed + carry, reaches, time
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
